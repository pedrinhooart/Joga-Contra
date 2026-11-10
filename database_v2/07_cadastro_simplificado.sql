-- =============================================================================
-- Joga Contra — banco joga_contra_v2 — MySQL 8.4 LTS
-- 07_cadastro_simplificado.sql: categoria etária e quantidade de jogadores do
-- time passam a ser opcionais. O cadastro do capitão não pede esses dados: cada
-- anúncio de partida informa os seus.
--
-- Migração para bancos criados antes desta versão (01_esquema.sql e
-- 04_visoes.sql já trazem o resultado). Não apaga nem altera dados.
-- Pode repetir: MODIFY e CREATE OR REPLACE VIEW são idempotentes.
-- =============================================================================

ALTER TABLE times
  MODIFY id_categoria_etaria  TINYINT UNSIGNED NULL,
  MODIFY quantidade_jogadores TINYINT UNSIGNED NULL COMMENT 'Informada pelo capitão (opcional).';

-- Times sem categoria continuam no perfil público (LEFT JOIN).
CREATE OR REPLACE VIEW vis_perfis_times AS
SELECT t.id_time, t.id_capitao, t.nome, t.sigla, t.url_escudo, t.cidade, t.sigla_estado, t.bairro,
       t.quantidade_jogadores, t.descricao, t.ano_fundacao, t.telefone_contato, t.verificado,
       t.id_categoria_etaria, c.codigo AS codigo_categoria_etaria, c.nome AS nome_categoria_etaria,
       c.ordem AS ordem_categoria_etaria,
       t.id_nivel_tecnico, n.codigo AS codigo_nivel_tecnico, n.nome AS nome_nivel_tecnico,
       n.ordem AS ordem_nivel_tecnico,
       u.nome AS nome_capitao,
       e.total_partidas_realizadas, e.media_avaliacao, e.total_avaliacoes,
       t.data_criacao, t.data_atualizacao
  FROM times t
  JOIN usuarios u ON u.id_usuario = t.id_capitao
  LEFT JOIN categorias_etarias c ON c.id_categoria_etaria = t.id_categoria_etaria
  LEFT JOIN niveis_tecnicos n ON n.id_nivel_tecnico = t.id_nivel_tecnico
  JOIN vis_estatisticas_times e ON e.id_time = t.id_time
 WHERE t.data_arquivamento IS NULL;
