import bcrypt from 'bcryptjs';
import { Router } from 'express';
import { pool } from '../config/db.js';
import { gerarTokenSessao, requireAuth } from '../middlewares/auth.js';
import { ApiError } from '../middlewares/error-handler.js';
import { cadastroSchema, loginSchema, recuperarSenhaSchema, redefinirSenhaSchema } from '../schemas/api.js';
import { obterTime } from '../services/consultas.js';
import { descreverFalhaEmail, provedorEmail } from '../services/email.js';
import { consultar, emTransacao, repetirEmImpasse, uuid, type Executor } from '../services/helpers.js';
import { mapearUsuario } from '../services/mapeadores.js';
import {
  FORMATO_TOKEN,
  JANELA_LIMITE_MINUTOS,
  LIMITE_PEDIDOS_POR_CONTA,
  VALIDADE_TOKEN_MINUTOS,
  emailRecuperacao,
  gerarTokenRecuperacao,
  hashTokenRecuperacao,
} from '../services/recuperacao-senha.js';

export const authRouter = Router();

const CUSTO_BCRYPT = 12;
/** Comparado quando o e-mail não existe, para o tempo de resposta não revelar isso. */
const HASH_INEXISTENTE = '$2b$12$C6UzMDM.H6dfI/f/IKcEeO7ZzCqmfWkCjD6Jv3c0Fh1VqMFnCwQ5K';
const SENHA_MINIMA = 8;
/** O bcrypt só considera os primeiros 72 bytes (letras acentuadas ocupam 2). */
const SENHA_MAXIMA_BYTES = 72;

/** Capitão + time, no formato de `Sessao` do app. */
async function sessao(db: Executor, idUsuario: string) {
  const [usuario] = await consultar(db, 'SELECT * FROM usuarios WHERE id_usuario = ?', [idUsuario]);
  if (!usuario) throw new ApiError(401, 'Sessão inválida ou expirada.', 'UNAUTHORIZED');
  const [linhaTime] = await consultar(
    db,
    'SELECT id_time FROM times WHERE id_capitao = ? AND data_arquivamento IS NULL',
    [idUsuario],
  );
  if (!linhaTime) throw new ApiError(403, 'Sua conta não possui um time ativo.', 'FORBIDDEN');
  return { usuario: mapearUsuario(usuario), time: await obterTime(db, linhaTime.id_time, true) };
}

// Cria o capitão, o time e as modalidades numa única transação.
authRouter.post('/cadastro', async (req, res) => {
  const { usuario, time } = cadastroSchema.parse(req.body);
  const hashSenha = await bcrypt.hash(usuario.senha, CUSTO_BCRYPT);
  const idUsuario = uuid();
  const idTime = uuid();

  await emTransacao(async (db) => {
    await db.execute(
      `INSERT INTO usuarios (id_usuario, nome, email, hash_senha, telefone, cidade, sigla_estado)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [idUsuario, usuario.nome, usuario.email, hashSenha, usuario.telefone, usuario.cidade, usuario.siglaEstado],
    );
    await db.execute(
      `INSERT INTO times (id_time, id_capitao, nome, cidade, sigla_estado, quantidade_jogadores,
                          id_categoria_etaria, id_nivel_tecnico, telefone_contato)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        idTime, idUsuario, time.nome, time.cidade, time.siglaEstado, time.quantidadeJogadores,
        time.idCategoriaEtaria, time.idNivelTecnico, usuario.telefone,
      ],
    );
    if (time.idsModalidades.length > 0) {
      await db.execute(
        `INSERT INTO times_modalidades (id_time, id_modalidade)
         VALUES ${time.idsModalidades.map(() => '(?, ?)').join(', ')}`,
        time.idsModalidades.flatMap((id) => [idTime, id]),
      );
    }
  });

  res.status(201).json({ data: { token: gerarTokenSessao(idUsuario, hashSenha), ...(await sessao(pool, idUsuario)) } });
});

authRouter.post('/login', async (req, res) => {
  const { email, senha } = loginSchema.parse(req.body);
  const [usuario] = await consultar(
    pool,
    'SELECT id_usuario, hash_senha, status_conta FROM usuarios WHERE email = ? AND data_exclusao IS NULL',
    [email],
  );
  const senhaCorreta = await bcrypt.compare(senha, usuario?.hash_senha ?? HASH_INEXISTENTE);
  if (!usuario || !senhaCorreta) throw new ApiError(401, 'E-mail ou senha inválidos.', 'UNAUTHORIZED');
  if (usuario.status_conta !== 'ativa') throw new ApiError(403, 'Esta conta não está ativa.', 'FORBIDDEN');
  res.json({
    data: {
      token: gerarTokenSessao(usuario.id_usuario, usuario.hash_senha),
      ...(await sessao(pool, usuario.id_usuario)),
    },
  });
});

authRouter.get('/eu', requireAuth, async (req, res) => {
  res.json({ data: await sessao(pool, req.auth!.idUsuario) });
});

// -----------------------------------------------------------------------------
// Recuperação de senha
// -----------------------------------------------------------------------------

export const MENSAGEM_PEDIDO_RECUPERACAO =
  'Se o e-mail estiver cadastrado, você receberá um link para redefinir a senha em alguns minutos.';

/** Pedidos ainda sendo processados depois da resposta (os testes esperam por eles). */
const pedidosEmAndamento = new Set<Promise<void>>();
export const aguardarPedidosRecuperacao = () => Promise.all([...pedidosEmAndamento]);

/**
 * Responde 202 com a mesma mensagem para qualquer e-mail válido, cadastrado ou
 * não, e só depois procura a conta, gera o token e envia o e-mail. Assim nem o
 * conteúdo nem o tempo da resposta revelam quais e-mails existem, e uma falha
 * do provedor de e-mail não muda o que o solicitante vê.
 */
authRouter.post(['/forgot-password', '/recuperar-senha'], async (req, res) => {
  const { email } = recuperarSenhaSchema.parse(req.body);
  res.status(202).json({ data: { mensagem: MENSAGEM_PEDIDO_RECUPERACAO } });

  const pedido: Promise<void> = processarPedidoRecuperacao(email)
    .catch((erro) => console.error(`Recuperação de senha: pedido não processado (${descreverFalhaEmail(erro)}).`))
    .finally(() => pedidosEmAndamento.delete(pedido));
  pedidosEmAndamento.add(pedido);
});

async function processarPedidoRecuperacao(email: string) {
  const [usuario] = await consultar(
    pool,
    "SELECT id_usuario, nome FROM usuarios WHERE email = ? AND status_conta = 'ativa' AND data_exclusao IS NULL",
    [email],
  );
  if (!usuario) return;

  const token = gerarTokenRecuperacao();
  const criado = await emTransacao(async (db) => {
    // Pedidos simultâneos da mesma conta entram em fila: a contagem do limite fica exata.
    await db.execute('SELECT id_usuario FROM usuarios WHERE id_usuario = ? FOR UPDATE', [usuario.id_usuario]);
    const [{ recentes }] = await consultar(
      db,
      `SELECT COUNT(*) AS recentes FROM codigos_recuperacao_senha
        WHERE id_usuario = ? AND data_criacao > UTC_TIMESTAMP(3) - INTERVAL ${JANELA_LIMITE_MINUTOS} MINUTE`,
      [usuario.id_usuario],
    );
    if (Number(recentes) >= LIMITE_PEDIDOS_POR_CONTA) return false;
    // O novo pedido substitui os anteriores: só o mais recente da conta é aceito
    // na redefinição (os antigos ficam no histórico, sem poder ser usados).
    await db.execute(
      `INSERT INTO codigos_recuperacao_senha (id_codigo, id_usuario, hash_codigo, data_expiracao, data_criacao)
       VALUES (?, ?, ?, UTC_TIMESTAMP(3) + INTERVAL ${VALIDADE_TOKEN_MINUTOS} MINUTE, UTC_TIMESTAMP(3))`,
      [uuid(), usuario.id_usuario, hashTokenRecuperacao(token)],
    );
    return true;
  });
  if (!criado) {
    console.warn('Recuperação de senha: limite de pedidos da conta atingido; nenhum e-mail enviado.');
    return;
  }

  const provedor = provedorEmail();
  try {
    await provedor.enviar(emailRecuperacao(email, usuario.nome, token));
    console.log(`Recuperação de senha: e-mail enviado (${provedor.nome}).`);
  } catch (erro) {
    console.error(`Recuperação de senha: e-mail não enviado por ${provedor.nome} (${descreverFalhaEmail(erro)}).`);
  }
}

type EstadoToken = {
  id_codigo: string;
  id_usuario: string;
  usado: number;
  expirado: number;
  substituido: number;
  conta_ativa: number;
};

/** Situação do token. `bloquear` trava o pedido e a conta até o fim da transação. */
async function estadoDoToken(db: Executor, hash: Buffer, bloquear: boolean): Promise<EstadoToken | undefined> {
  const [linha] = await consultar(
    db,
    `SELECT c.id_codigo, c.id_usuario,
            c.data_uso IS NOT NULL AS usado,
            c.data_expiracao <= UTC_TIMESTAMP(3) AS expirado,
            EXISTS (SELECT 1 FROM codigos_recuperacao_senha n
                     WHERE n.id_usuario = c.id_usuario AND n.data_criacao > c.data_criacao) AS substituido,
            (u.status_conta = 'ativa' AND u.data_exclusao IS NULL) AS conta_ativa
       FROM codigos_recuperacao_senha c
       JOIN usuarios u ON u.id_usuario = c.id_usuario
      WHERE c.hash_codigo = ?
      ${bloquear ? 'FOR UPDATE' : ''}`,
    [hash],
  );
  return linha as EstadoToken | undefined;
}

/** Erro para cada situação em que o link não serve. Nada sobre a conta é revelado. */
function exigirTokenUtilizavel(estado: EstadoToken | undefined): asserts estado is EstadoToken {
  if (!estado || !estado.conta_ativa) {
    throw new ApiError(400, 'Link de recuperação inválido. Peça um novo em "Esqueci minha senha".', 'TOKEN_INVALIDO');
  }
  if (estado.usado) {
    throw new ApiError(410, 'Este link já foi usado. Se precisar, peça um novo em "Esqueci minha senha".', 'TOKEN_UTILIZADO');
  }
  if (estado.substituido) {
    throw new ApiError(
      410,
      'Este link foi substituído por um pedido mais recente. Use o último e-mail recebido.',
      'TOKEN_SUBSTITUIDO',
    );
  }
  if (estado.expirado) {
    throw new ApiError(
      410,
      `Este link expirou (vale por ${VALIDADE_TOKEN_MINUTOS} minutos). Peça um novo em "Esqueci minha senha".`,
      'TOKEN_EXPIRADO',
    );
  }
}

/** Mesma regra do cadastro (mínimo de 8), com mensagens próprias. */
function validarNovaSenha(novaSenha: string, confirmacao: string) {
  if (novaSenha.trim().length < SENHA_MINIMA) {
    throw new ApiError(400, `A nova senha precisa ter pelo menos ${SENHA_MINIMA} caracteres.`, 'VALIDATION_ERROR');
  }
  if (Buffer.byteLength(novaSenha, 'utf8') > SENHA_MAXIMA_BYTES) {
    throw new ApiError(400, 'A nova senha é longa demais. Use no máximo 72 caracteres sem acento.', 'VALIDATION_ERROR');
  }
  if (novaSenha !== confirmacao) {
    throw new ApiError(400, 'A confirmação não é igual à nova senha.', 'VALIDATION_ERROR');
  }
}

/**
 * Troca a senha com um token válido. O token é conferido antes (sem trava, para
 * links inválidos não custarem um hash de senha) e de novo dentro da transação,
 * com `FOR UPDATE`: dois envios simultâneos do mesmo link ficam em fila e só o
 * primeiro troca a senha; o segundo encontra o token já usado.
 */
authRouter.post(['/reset-password', '/redefinir-senha'], async (req, res) => {
  const { token, novaSenha, confirmacaoSenha } = redefinirSenhaSchema.parse(req.body);
  if (!FORMATO_TOKEN.test(token)) exigirTokenUtilizavel(undefined);
  const hashToken = hashTokenRecuperacao(token);
  exigirTokenUtilizavel(await estadoDoToken(pool, hashToken, false));
  validarNovaSenha(novaSenha, confirmacaoSenha);

  const hashSenha = await bcrypt.hash(novaSenha, CUSTO_BCRYPT);
  await repetirEmImpasse(() =>
    emTransacao(async (db) => {
      const estado = await estadoDoToken(db, hashToken, true);
      exigirTokenUtilizavel(estado);
      // A nova senha muda a impressão gravada nas sessões: todas as abertas antes caem.
      await db.execute('UPDATE usuarios SET hash_senha = ? WHERE id_usuario = ?', [hashSenha, estado.id_usuario]);
      await db.execute(
        'UPDATE codigos_recuperacao_senha SET data_uso = UTC_TIMESTAMP(3) WHERE id_codigo = ? AND data_uso IS NULL',
        [estado.id_codigo],
      );
    }),
  );
  res.json({ data: { mensagem: 'Senha alterada. Entre com a nova senha.' } });
});
