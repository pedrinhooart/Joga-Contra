-- =============================================================================
-- Joga Contra — banco joga_contra_v2 — MySQL 8.4 LTS
-- 04_visoes.sql: visões com os dados calculados que a API devolve ao app.
-- Os agregados NÃO são armazenados em colunas (evita redundância).
-- Execute depois de 01_esquema.sql.
-- =============================================================================

USE joga_contra_v2;

-- Estatísticas do time: Time.totalPartidasRealizadas / mediaAvaliacao / totalAvaliacoes.
CREATE VIEW vis_estatisticas_times AS
SELECT t.id_time,
       COALESCE(pr.total_partidas_realizadas, 0) AS total_partidas_realizadas,
       av.media_avaliacao,
       COALESCE(av.total_avaliacoes, 0) AS total_avaliacoes
  FROM times t
  LEFT JOIN (
        SELECT x.id_time, COUNT(*) AS total_partidas_realizadas
          FROM (SELECT id_time_anunciante AS id_time FROM partidas WHERE status = 'realizada'
                UNION ALL
                SELECT id_time_adversario FROM partidas WHERE status = 'realizada') AS x
         GROUP BY x.id_time) AS pr ON pr.id_time = t.id_time
  LEFT JOIN (
        SELECT a.id_time_avaliado AS id_time,
               COUNT(DISTINCT a.id_avaliacao) AS total_avaliacoes,
               ROUND(AVG(n.nota), 1) AS media_avaliacao
          FROM avaliacoes a
          JOIN notas_avaliacao n ON n.id_avaliacao = a.id_avaliacao
         GROUP BY a.id_time_avaliado) AS av ON av.id_time = t.id_time;

-- Perfil público do time (sem e-mail/telefone pessoal do capitão).
CREATE VIEW vis_perfis_times AS
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

-- Anúncios abertos a solicitações (busca, início, mapa).
-- A API ainda filtra por texto, classificações, data, local e exclui o próprio time.
CREATE VIEW vis_anuncios_disponiveis AS
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

-- Resumo das conversas: última mensagem e não lidas para cada lado.
-- SolicitacaoConfronto.ultimaMensagem / dataUltimaMensagem / mensagensNaoLidas.
CREATE VIEW vis_resumo_solicitacoes AS
SELECT s.id_solicitacao, s.id_anuncio, s.id_time_anunciante, s.id_time_solicitante, s.status,
       ult.texto AS ultima_mensagem,
       ult.data_envio AS data_ultima_mensagem,
       (SELECT COUNT(*) FROM mensagens m
         WHERE m.id_solicitacao = s.id_solicitacao AND m.id_time_remetente = s.id_time_solicitante
           AND m.data_leitura IS NULL) AS nao_lidas_anunciante,
       (SELECT COUNT(*) FROM mensagens m
         WHERE m.id_solicitacao = s.id_solicitacao AND m.id_time_remetente = s.id_time_anunciante
           AND m.data_leitura IS NULL) AS nao_lidas_solicitante,
       s.data_criacao, s.data_atualizacao
  FROM solicitacoes_confronto s
  LEFT JOIN (
        SELECT id_solicitacao, texto, data_envio,
               ROW_NUMBER() OVER (PARTITION BY id_solicitacao ORDER BY data_envio DESC, id_mensagem DESC) AS posicao
          FROM mensagens) AS ult
    ON ult.id_solicitacao = s.id_solicitacao AND ult.posicao = 1;
