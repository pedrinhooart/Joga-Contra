import 'dotenv/config';
import mysql from 'mysql2/promise';

// Somente leitura: confere se o banco configurado tem a estrutura usada pela API.
const conexao = {
  host: process.env.DB_HOST ?? '127.0.0.1',
  port: Number(process.env.DB_PORT ?? 3306),
  user: process.env.DB_USER ?? '',
  password: process.env.DB_PASSWORD ?? '',
  database: process.env.DB_NAME ?? '',
};

const TABELAS = [
  'estados', 'modalidades', 'categorias_etarias', 'niveis_tecnicos', 'mandos_campo', 'criterios_avaliacao',
  'usuarios', 'codigos_recuperacao_senha', 'times', 'times_modalidades', 'anuncios_partidas',
  'solicitacoes_confronto', 'mensagens', 'partidas', 'avaliacoes', 'notas_avaliacao', 'notificacoes',
  'vis_estatisticas_times', 'vis_perfis_times', 'vis_anuncios_disponiveis', 'vis_resumo_solicitacoes',
];
const PROCEDIMENTOS = [
  'proc_confirmar_solicitacao', 'proc_recusar_solicitacao', 'proc_cancelar_solicitacao', 'proc_cancelar_partida',
  'proc_excluir_anuncio', 'proc_expirar_anuncios', 'proc_marcar_partidas_realizadas',
];

async function main() {
  const db = await mysql.createConnection(conexao);
  try {
    await db.query('SET SESSION TRANSACTION READ ONLY');
    const [[info]] = await db.query<any[]>('SELECT VERSION() AS versao, DATABASE() AS banco');
    const [tabelas] = await db.execute<any[]>(
      'SELECT table_name AS nome FROM information_schema.tables WHERE table_schema = ?',
      [conexao.database],
    );
    const [rotinas] = await db.execute<any[]>(
      'SELECT routine_name AS nome FROM information_schema.routines WHERE routine_schema = ?',
      [conexao.database],
    );
    const existentes = new Set([...tabelas, ...rotinas].map((r) => r.nome));
    const faltando = [...TABELAS, ...PROCEDIMENTOS].filter((nome) => !existentes.has(nome));
    const [[referencias]] = await db.query<any[]>(
      `SELECT (SELECT COUNT(*) FROM modalidades) AS modalidades,
              (SELECT COUNT(*) FROM categorias_etarias) AS categorias_etarias,
              (SELECT COUNT(*) FROM niveis_tecnicos) AS niveis_tecnicos,
              (SELECT COUNT(*) FROM estados) AS estados`,
    ).catch(() => [[null]] as any);
    console.log(JSON.stringify({ conectado: true, ...info, faltando, referencias }, null, 2));
    if (faltando.length) process.exitCode = 2;
  } finally {
    await db.end();
  }
}

main().catch((erro) => {
  console.error('Falha na verificação do banco:', erro.code ?? erro.message);
  process.exitCode = 1;
});
