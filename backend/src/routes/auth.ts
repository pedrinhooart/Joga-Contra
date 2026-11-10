import bcrypt from 'bcryptjs';
import { Router } from 'express';
import jwt from 'jsonwebtoken';
import { createHash, randomBytes } from 'node:crypto';
import { pool } from '../config/db.js';
import { env } from '../config/env.js';
import { requireAuth } from '../middlewares/auth.js';
import { ApiError } from '../middlewares/error-handler.js';
import { cadastroSchema, loginSchema, recuperarSenhaSchema, redefinirSenhaSchema } from '../schemas/api.js';
import { obterTime } from '../services/consultas.js';
import { enviarCodigoRecuperacao } from '../services/email.js';
import { consultar, dataSql, emTransacao, uuid, type Executor } from '../services/helpers.js';
import { mapearUsuario } from '../services/mapeadores.js';

export const authRouter = Router();

const CUSTO_BCRYPT = 12;
/** Comparado quando o e-mail não existe, para o tempo de resposta não revelar isso. */
const HASH_INEXISTENTE = '$2b$12$C6UzMDM.H6dfI/f/IKcEeO7ZzCqmfWkCjD6Jv3c0Fh1VqMFnCwQ5K';
const VALIDADE_CODIGO_MS = 60 * 60_000;

const gerarToken = (idUsuario: string) =>
  jwt.sign({}, env.JWT_SECRET, {
    subject: idUsuario,
    algorithm: 'HS256',
    expiresIn: env.JWT_EXPIRES_IN as jwt.SignOptions['expiresIn'],
  });

const hashCodigo = (codigo: string) => createHash('sha256').update(codigo).digest();

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

  res.status(201).json({ data: { token: gerarToken(idUsuario), ...(await sessao(pool, idUsuario)) } });
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
  res.json({ data: { token: gerarToken(usuario.id_usuario), ...(await sessao(pool, usuario.id_usuario)) } });
});

authRouter.get('/eu', requireAuth, async (req, res) => {
  res.json({ data: await sessao(pool, req.auth!.idUsuario) });
});

// Responde sempre 202, para não revelar quais e-mails estão cadastrados.
authRouter.post('/recuperar-senha', async (req, res) => {
  const { email } = recuperarSenhaSchema.parse(req.body);
  const [usuario] = await consultar(
    pool,
    "SELECT id_usuario FROM usuarios WHERE email = ? AND status_conta = 'ativa'",
    [email],
  );
  if (usuario) {
    const codigo = randomBytes(32).toString('hex');
    await pool.execute(
      `INSERT INTO codigos_recuperacao_senha (id_codigo, id_usuario, hash_codigo, data_expiracao)
       VALUES (?, ?, ?, ?)`,
      [uuid(), usuario.id_usuario, hashCodigo(codigo), dataSql(new Date(Date.now() + VALIDADE_CODIGO_MS))],
    );
    await enviarCodigoRecuperacao(email, codigo);
  }
  res.status(202).end();
});

authRouter.post('/redefinir-senha', async (req, res) => {
  const { codigo, novaSenha } = redefinirSenhaSchema.parse(req.body);
  const hashSenha = await bcrypt.hash(novaSenha, CUSTO_BCRYPT);
  await emTransacao(async (db) => {
    const [registro] = await consultar(
      db,
      `SELECT id_codigo, id_usuario FROM codigos_recuperacao_senha
        WHERE hash_codigo = ? AND data_uso IS NULL AND data_expiracao > UTC_TIMESTAMP(3)
        FOR UPDATE`,
      [hashCodigo(codigo)],
    );
    if (!registro) throw new ApiError(400, 'Código inválido ou expirado.', 'VALIDATION_ERROR');
    await db.execute('UPDATE usuarios SET hash_senha = ? WHERE id_usuario = ?', [hashSenha, registro.id_usuario]);
    await db.execute(
      `UPDATE codigos_recuperacao_senha SET data_uso = UTC_TIMESTAMP(3) WHERE id_usuario = ? AND data_uso IS NULL`,
      [registro.id_usuario],
    );
  });
  res.status(204).end();
});

