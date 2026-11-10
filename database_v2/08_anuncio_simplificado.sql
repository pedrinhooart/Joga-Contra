-- =============================================================================
-- Joga Contra — banco joga_contra_v2 — MySQL 8.4 LTS
-- 08_anuncio_simplificado.sql (migração autorizada em 10/11/2026)
--
-- 1. Anúncio sem categoria etária e sem quantidade de jogadores obrigatórias
--    (o formulário não pede mais esses dados; anúncios antigos mantêm os seus).
-- 2. Duração prevista da partida no anúncio, independente do horário de início.
-- 3. Partida aceita quantidade nula (o procedimento de confirmação copia a do anúncio).
-- 4. vis_anuncios_disponiveis com LEFT JOIN em categorias (anúncios sem categoria
--    continuam na busca) e com a duração.
-- 5. Chat só depois do aceite: mensagens apenas em solicitações confirmadas
--    (reforço no banco da regra que a API também aplica).
--
-- Não apaga nem altera dados. Para bancos criados antes desta versão; 01, 02 e
-- 04 já trazem o resultado. Execute uma vez (ADD COLUMN falha se repetir).
-- =============================================================================

ALTER TABLE anuncios_partidas
  MODIFY id_categoria_etaria  TINYINT UNSIGNED NULL,
  MODIFY quantidade_jogadores TINYINT UNSIGNED NULL COMMENT 'Jogadores por equipe na partida (opcional).',
  ADD COLUMN duracao_minutos  SMALLINT UNSIGNED NULL COMMENT 'Duração prevista da partida, em minutos.'
    AFTER data_hora_inicio,
  ADD CONSTRAINT vr_anuncios_partidas_duracao
    CHECK (duracao_minutos IS NULL OR duracao_minutos BETWEEN 15 AND 600);

ALTER TABLE partidas
  MODIFY quantidade_jogadores TINYINT UNSIGNED NULL;

CREATE OR REPLACE VIEW vis_anuncios_disponiveis AS
SELECT a.id_anuncio, a.id_time, t.nome AS nome_time, t.sigla AS sigla_time, t.url_escudo,
       t.cidade AS cidade_time, t.sigla_estado AS sigla_estado_time, u.nome AS nome_capitao,
       a.id_modalidade, m.codigo AS codigo_modalidade, m.nome AS nome_modalidade, m.ordem AS ordem_modalidade,
       a.id_categoria_etaria, c.codigo AS codigo_categoria_etaria, c.nome AS nome_categoria_etaria,
       c.ordem AS ordem_categoria_etaria,
       a.id_nivel_tecnico, n.codigo AS codigo_nivel_tecnico, n.nome AS nome_nivel_tecnico,
       n.ordem AS ordem_nivel_tecnico,
       a.id_mando_campo, mc.codigo AS codigo_mando_campo, mc.nome AS nome_mando_campo,
       mc.ordem AS ordem_mando_campo,
       a.quantidade_jogadores, a.data_hora_inicio, a.duracao_minutos, a.cidade, a.sigla_estado, a.bairro, a.nome_local,
       a.endereco, a.latitude, a.longitude, a.valor_aluguel_por_time, a.descricao, a.status,
       (SELECT COUNT(*) FROM solicitacoes_confronto s
         WHERE s.id_anuncio = a.id_anuncio AND s.status = 'pendente') AS total_solicitacoes,
       a.data_criacao, a.data_atualizacao
  FROM anuncios_partidas a
  JOIN times t ON t.id_time = a.id_time
  JOIN usuarios u ON u.id_usuario = t.id_capitao
  JOIN modalidades m ON m.id_modalidade = a.id_modalidade
  LEFT JOIN categorias_etarias c ON c.id_categoria_etaria = a.id_categoria_etaria
  JOIN niveis_tecnicos n ON n.id_nivel_tecnico = a.id_nivel_tecnico
  LEFT JOIN mandos_campo mc ON mc.id_mando_campo = a.id_mando_campo
 WHERE a.status = 'ativo'
   AND a.data_exclusao IS NULL
   AND a.data_hora_inicio > UTC_TIMESTAMP(3)
   AND t.data_arquivamento IS NULL;

-- Gatilho recriado (o MySQL não tem CREATE OR REPLACE TRIGGER).
DROP TRIGGER IF EXISTS gat_mensagens_antes_inserir;

DELIMITER $$
CREATE TRIGGER gat_mensagens_antes_inserir
BEFORE INSERT ON mensagens FOR EACH ROW
BEGIN
  -- O chat só existe depois que o time anunciante aceita a solicitação.
  IF NOT EXISTS (
       SELECT 1 FROM solicitacoes_confronto s
       JOIN times t ON t.id_time = NEW.id_time_remetente
       WHERE s.id_solicitacao = NEW.id_solicitacao
         AND NEW.id_time_remetente IN (s.id_time_anunciante, s.id_time_solicitante)
         AND t.id_capitao = NEW.id_usuario_remetente
         AND s.status = 'confirmada') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O chat é liberado quando o time anunciante aceita o desafio.';
  END IF;
  IF NEW.data_leitura IS NOT NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Uma mensagem nova não pode estar lida.';
  END IF;
END$$
DELIMITER ;
