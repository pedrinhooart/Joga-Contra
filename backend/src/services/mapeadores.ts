import { dataIso, type Linha } from './helpers.js';

/** Converte linhas do banco (snake_case) no JSON lido pelos modelos do Flutter. */

const referencia = (id: unknown, codigo: unknown, nome: unknown, ordem: unknown) =>
  id == null ? null : { id, codigo, nome, ordem };

export const mapearUsuario = (r: Linha) => ({
  idUsuario: r.id_usuario,
  nome: r.nome,
  email: r.email,
  telefone: r.telefone,
  urlFoto: r.url_foto,
  cidade: r.cidade,
  siglaEstado: r.sigla_estado,
});

/** Time a partir de vis_perfis_times. */
export const mapearTime = (r: Linha, modalidades: Linha[], incluirContato: boolean) => ({
  idTime: r.id_time,
  idCapitao: r.id_capitao,
  nome: r.nome,
  sigla: r.sigla,
  urlEscudo: r.url_escudo,
  cidade: r.cidade,
  siglaEstado: r.sigla_estado,
  bairro: r.bairro,
  quantidadeJogadores: r.quantidade_jogadores,
  modalidades,
  categoriaEtaria: referencia(r.id_categoria_etaria, r.codigo_categoria_etaria, r.nome_categoria_etaria, r.ordem_categoria_etaria),
  nivelTecnico: referencia(r.id_nivel_tecnico, r.codigo_nivel_tecnico, r.nome_nivel_tecnico, r.ordem_nivel_tecnico),
  descricao: r.descricao,
  anoFundacao: r.ano_fundacao,
  nomeCapitao: r.nome_capitao,
  telefoneContato: incluirContato ? r.telefone_contato : null,
  totalPartidasRealizadas: r.total_partidas_realizadas,
  mediaAvaliacao: r.media_avaliacao,
  totalAvaliacoes: r.total_avaliacoes,
  verificado: Boolean(r.verificado),
});

/** ResumoTime a partir de colunas com prefixo (ex.: `anunciante_nome`). */
export const mapearResumoTime = (r: Linha, prefixo: string) => ({
  idTime: r[`${prefixo}_id`],
  nome: r[`${prefixo}_nome`],
  sigla: r[`${prefixo}_sigla`],
  urlEscudo: r[`${prefixo}_url_escudo`],
  cidade: r[`${prefixo}_cidade`],
  siglaEstado: r[`${prefixo}_sigla_estado`],
  nomeCapitao: r[`${prefixo}_nome_capitao`],
});

/** Colunas de ResumoTime para um alias de `times` e outro de `usuarios`. */
export const colunasResumoTime = (prefixo: string, time: string, capitao: string) => `
  ${time}.id_time AS ${prefixo}_id, ${time}.nome AS ${prefixo}_nome, ${time}.sigla AS ${prefixo}_sigla,
  ${time}.url_escudo AS ${prefixo}_url_escudo, ${time}.cidade AS ${prefixo}_cidade,
  ${time}.sigla_estado AS ${prefixo}_sigla_estado, ${capitao}.nome AS ${prefixo}_nome_capitao`;

/** AnuncioPartida a partir de vis_anuncios_disponiveis ou de SELECT_ANUNCIO. */
export const mapearAnuncio = (r: Linha) => ({
  idAnuncio: r.id_anuncio,
  time: {
    idTime: r.id_time,
    nome: r.nome_time,
    sigla: r.sigla_time,
    urlEscudo: r.url_escudo,
    cidade: r.cidade_time,
    siglaEstado: r.sigla_estado_time,
    nomeCapitao: r.nome_capitao,
  },
  modalidade: referencia(r.id_modalidade, r.codigo_modalidade, r.nome_modalidade, r.ordem_modalidade),
  categoriaEtaria: referencia(r.id_categoria_etaria, r.codigo_categoria_etaria, r.nome_categoria_etaria, r.ordem_categoria_etaria),
  nivelTecnico: referencia(r.id_nivel_tecnico, r.codigo_nivel_tecnico, r.nome_nivel_tecnico, r.ordem_nivel_tecnico),
  mandoCampo: referencia(r.id_mando_campo, r.codigo_mando_campo, r.nome_mando_campo, r.ordem_mando_campo),
  quantidadeJogadores: r.quantidade_jogadores,
  dataHoraInicio: dataIso(r.data_hora_inicio),
  duracaoMinutos: r.duracao_minutos ?? null,
  cidade: r.cidade,
  siglaEstado: r.sigla_estado,
  bairro: r.bairro,
  nomeLocal: r.nome_local,
  endereco: r.endereco,
  latitude: r.latitude ?? null,
  longitude: r.longitude ?? null,
  valorAluguelPorTime: r.valor_aluguel_por_time,
  descricao: r.descricao,
  status: r.status,
  totalSolicitacoes: r.total_solicitacoes,
});

export const mapearMensagem = (r: Linha) => ({
  idMensagem: r.id_mensagem,
  idSolicitacao: r.id_solicitacao,
  idTimeRemetente: r.id_time_remetente,
  texto: r.texto,
  dataEnvio: dataIso(r.data_envio),
});

export const mapearNotificacao = (r: Linha) => ({
  idNotificacao: r.id_notificacao,
  tipo: r.tipo,
  titulo: r.titulo,
  mensagem: r.mensagem,
  dataCriacao: dataIso(r.data_criacao),
  lida: r.data_leitura != null,
  idAnuncio: r.id_anuncio,
  idSolicitacao: r.id_solicitacao,
  idPartida: r.id_partida,
});
