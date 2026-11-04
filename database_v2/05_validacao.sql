-- =============================================================================
-- Joga Contra — banco joga_contra_v2 — MySQL 8.4 LTS
-- 05_validacao.sql: SOMENTE leitura (SELECT/EXPLAIN). Seguro em qualquer ambiente.
--   Parte A — confere a estrutura criada pelos scripts 01–04.
--   Parte B — consultas de exemplo das funcionalidades do app (as mesmas que a
--             API deverá executar). Troque os valores das variáveis @ pelos ids
--             reais antes de rodar a parte B.
-- =============================================================================

USE joga_contra_v2;
SET time_zone = '+00:00';

-- =============================================================================
-- PARTE A — Estrutura
-- =============================================================================

-- A1. Versão do servidor (esperado: 8.4.x).
SELECT VERSION() AS versao_mysql, DATABASE() AS banco, @@character_set_database AS charset,
       @@collation_database AS colacao;

-- A2. Objetos esperados: 17 tabelas, 4 visões, 15 gatilhos, 7 procedimentos.
SELECT
  (SELECT COUNT(*) FROM information_schema.tables
    WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE') AS tabelas,
  (SELECT COUNT(*) FROM information_schema.views WHERE table_schema = DATABASE()) AS visoes,
  (SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema = DATABASE()) AS gatilhos,
  (SELECT COUNT(*) FROM information_schema.routines
    WHERE routine_schema = DATABASE() AND routine_type = 'PROCEDURE') AS procedimentos,
  (SELECT COUNT(*) FROM information_schema.referential_constraints
    WHERE constraint_schema = DATABASE()) AS chaves_estrangeiras,
  (SELECT COUNT(*) FROM information_schema.check_constraints
    WHERE constraint_schema = DATABASE()) AS verificacoes;

-- A3. Tabelas esperadas que estejam faltando (esperado: nenhuma linha).
SELECT esperado.nome AS tabela_faltando
  FROM (SELECT 'estados' AS nome UNION ALL SELECT 'modalidades' UNION ALL SELECT 'categorias_etarias'
        UNION ALL SELECT 'niveis_tecnicos' UNION ALL SELECT 'mandos_campo' UNION ALL SELECT 'criterios_avaliacao'
        UNION ALL SELECT 'usuarios' UNION ALL SELECT 'codigos_recuperacao_senha' UNION ALL SELECT 'times'
        UNION ALL SELECT 'times_modalidades' UNION ALL SELECT 'anuncios_partidas'
        UNION ALL SELECT 'solicitacoes_confronto' UNION ALL SELECT 'mensagens' UNION ALL SELECT 'partidas'
        UNION ALL SELECT 'avaliacoes' UNION ALL SELECT 'notas_avaliacao' UNION ALL SELECT 'notificacoes'
        UNION ALL SELECT 'vis_estatisticas_times' UNION ALL SELECT 'vis_perfis_times'
        UNION ALL SELECT 'vis_anuncios_disponiveis' UNION ALL SELECT 'vis_resumo_solicitacoes') AS esperado
  LEFT JOIN information_schema.tables t
    ON t.table_schema = DATABASE() AND t.table_name = esperado.nome
 WHERE t.table_name IS NULL;

-- A4. Dados de referência (esperado: 27, 2, 4, 3, 3, 4).
SELECT (SELECT COUNT(*) FROM estados) AS estados, (SELECT COUNT(*) FROM modalidades) AS modalidades,
       (SELECT COUNT(*) FROM categorias_etarias) AS categorias_etarias,
       (SELECT COUNT(*) FROM niveis_tecnicos) AS niveis_tecnicos,
       (SELECT COUNT(*) FROM mandos_campo) AS mandos_campo,
       (SELECT COUNT(*) FROM criterios_avaliacao) AS criterios_avaliacao;

SELECT 'modalidade' AS tipo, id_modalidade AS id, codigo, nome FROM modalidades
UNION ALL SELECT 'categoria_etaria', id_categoria_etaria, codigo, nome FROM categorias_etarias
UNION ALL SELECT 'nivel_tecnico', id_nivel_tecnico, codigo, nome FROM niveis_tecnicos
ORDER BY tipo, id;

-- A5. Chaves estrangeiras (tabela -> tabela referenciada).
SELECT rc.table_name AS tabela, rc.constraint_name AS restricao, rc.referenced_table_name AS referencia,
       GROUP_CONCAT(k.column_name ORDER BY k.ordinal_position) AS colunas,
       rc.delete_rule AS ao_excluir, rc.update_rule AS ao_atualizar
  FROM information_schema.referential_constraints rc
  JOIN information_schema.key_column_usage k
    ON k.constraint_schema = rc.constraint_schema AND k.constraint_name = rc.constraint_name
   AND k.table_name = rc.table_name
 WHERE rc.constraint_schema = DATABASE()
 GROUP BY rc.table_name, rc.constraint_name, rc.referenced_table_name, rc.delete_rule, rc.update_rule
 ORDER BY rc.table_name, rc.constraint_name;

-- A6. Gatilhos e procedimentos.
SELECT trigger_name AS gatilho, event_object_table AS tabela, action_timing AS momento,
       event_manipulation AS evento
  FROM information_schema.triggers WHERE trigger_schema = DATABASE() ORDER BY tabela, gatilho;
SELECT routine_name AS procedimento FROM information_schema.routines
 WHERE routine_schema = DATABASE() ORDER BY routine_name;

-- A7. Objetos fora da convenção de nomes (esperado: nenhuma linha).
SELECT CONCAT('restrição ', constraint_name) AS fora_do_padrao FROM information_schema.table_constraints
 WHERE table_schema = DATABASE() AND constraint_type <> 'PRIMARY KEY'
   AND constraint_name NOT REGEXP '^(ce|un|vr)_[a-z0-9_]+$'
UNION ALL
SELECT CONCAT('índice ', index_name) FROM information_schema.statistics
 WHERE table_schema = DATABASE() AND index_name <> 'PRIMARY'
   AND index_name NOT REGEXP '^(ce|un|ind)_[a-z0-9_]+$'
UNION ALL
SELECT CONCAT('coluna ', table_name, '.', column_name) FROM information_schema.columns
 WHERE table_schema = DATABASE() AND column_name NOT REGEXP '^[a-z0-9_]+$';

-- =============================================================================
-- PARTE B — Consultas de exemplo (funcionalidades do app)
-- =============================================================================
SET @id_usuario = CONVERT('00000000-0000-4000-8000-000000000000' USING ascii) COLLATE ascii_bin;  -- capitão logado
SET @id_time    = (SELECT id_time FROM times WHERE id_capitao = @id_usuario);
SET @id_anuncio = CONVERT('00000000-0000-4000-8000-000000000000' USING ascii) COLLATE ascii_bin;
SET @id_solicitacao = CONVERT('00000000-0000-4000-8000-000000000000' USING ascii) COLLATE ascii_bin;

-- B1. GET /referencias
SELECT id_modalidade AS id, codigo, nome, ordem FROM modalidades WHERE ativo ORDER BY ordem;
SELECT id_categoria_etaria AS id, codigo, nome, ordem FROM categorias_etarias WHERE ativo ORDER BY ordem;
SELECT id_nivel_tecnico AS id, codigo, nome, ordem FROM niveis_tecnicos WHERE ativo ORDER BY ordem;
SELECT sigla, nome FROM estados WHERE ativo ORDER BY nome;

-- B2. POST /auth/login — a API compara a senha com hash_senha (bcrypt) em memória.
SELECT u.id_usuario, u.nome, u.hash_senha, u.status_conta, t.id_time
  FROM usuarios u LEFT JOIN times t ON t.id_capitao = u.id_usuario
 WHERE u.email = 'capitao@example.com' AND u.data_exclusao IS NULL;

-- B3. GET /times/:id — perfil com estatísticas (sem dados pessoais do capitão).
SELECT * FROM vis_perfis_times WHERE id_time = @id_time;
SELECT m.id_modalidade AS id, m.codigo, m.nome FROM times_modalidades tm
  JOIN modalidades m ON m.id_modalidade = tm.id_modalidade WHERE tm.id_time = @id_time ORDER BY m.ordem;

-- B4. GET /anuncios — busca (filtros opcionais; exclui o próprio time).
SET @uf = 'SP', @cidade = NULL, @id_modalidade = NULL, @id_categoria = NULL, @id_nivel = NULL,
    @data = NULL, @texto = NULL;
SELECT *
  FROM vis_anuncios_disponiveis a
 WHERE a.id_time <> COALESCE(@id_time, '')
   AND (@uf IS NULL OR a.sigla_estado = @uf)
   AND (@cidade IS NULL OR a.cidade = @cidade)
   AND (@id_modalidade IS NULL OR a.id_modalidade = @id_modalidade)
   AND (@id_categoria IS NULL OR a.id_categoria_etaria = @id_categoria)
   AND (@id_nivel IS NULL OR a.id_nivel_tecnico = @id_nivel)
   AND (@data IS NULL OR a.data_hora_inicio >= @data AND a.data_hora_inicio < @data + INTERVAL 1 DAY)
   AND (@texto IS NULL OR CONCAT_WS(' ', a.nome_time, a.cidade, a.bairro, a.nome_local) LIKE CONCAT('%', @texto, '%'))
 ORDER BY a.data_hora_inicio
 LIMIT 20 OFFSET 0;

-- B5. GET /anuncios/meus
SELECT a.*, (SELECT COUNT(*) FROM solicitacoes_confronto s
              WHERE s.id_anuncio = a.id_anuncio AND s.status = 'pendente') AS total_solicitacoes
  FROM anuncios_partidas a
 WHERE a.id_time = @id_time AND a.data_exclusao IS NULL AND a.status IN ('ativo', 'pausado')
 ORDER BY a.data_hora_inicio;

-- B6. GET /solicitacoes/minhas — conversas em andamento do time (enviadas e recebidas).
SELECT s.*, r.ultima_mensagem, r.data_ultima_mensagem,
       IF(s.id_time_anunciante = @id_time, r.nao_lidas_anunciante, r.nao_lidas_solicitante) AS mensagens_nao_lidas
  FROM solicitacoes_confronto s
  JOIN vis_resumo_solicitacoes r ON r.id_solicitacao = s.id_solicitacao
 WHERE (s.id_time_anunciante = @id_time OR s.id_time_solicitante = @id_time)
 ORDER BY COALESCE(r.data_ultima_mensagem, s.data_criacao) DESC;

-- B7. GET /solicitacoes/:id/mensagens e marcação de leitura.
SELECT id_mensagem, id_time_remetente, texto, data_envio, data_leitura
  FROM mensagens WHERE id_solicitacao = @id_solicitacao ORDER BY data_envio, id_mensagem;
-- (escrita, executada pela API) UPDATE mensagens SET data_leitura = UTC_TIMESTAMP(3)
--   WHERE id_solicitacao = ? AND id_time_remetente <> ? AND data_leitura IS NULL;

-- B8. POST /solicitacoes e PATCH /solicitacoes/:id/confirmar (escritas, executadas pela API)
-- INSERT INTO solicitacoes_confronto (id_solicitacao, id_anuncio, id_time_solicitante, mensagem_inicial)
--   VALUES (?, ?, ?, ?);
-- CALL proc_confirmar_solicitacao(?, ?);   -- retorna id_partida quando os dois lados confirmaram

-- B9. GET /partidas/proxima
SELECT p.* FROM partidas p
 WHERE p.status = 'confirmada' AND p.data_hora_inicio > UTC_TIMESTAMP(3)
   AND (p.id_time_anunciante = @id_time OR p.id_time_adversario = @id_time)
 ORDER BY p.data_hora_inicio LIMIT 1;

-- B10. GET /partidas/minhas — com "avaliadaPeloMeuTime".
SELECT p.*, EXISTS (SELECT 1 FROM avaliacoes a
                     WHERE a.id_partida = p.id_partida AND a.id_time_avaliador = @id_time) AS avaliada_pelo_meu_time
  FROM partidas p
 WHERE p.id_time_anunciante = @id_time OR p.id_time_adversario = @id_time
 ORDER BY p.data_hora_inicio DESC;

-- B11. GET /times/:id/avaliacoes — avaliações recebidas com nota média de cada uma.
SELECT a.id_avaliacao, a.comentario, a.data_criacao, a.id_time_avaliador, t.nome AS nome_time_avaliador,
       ROUND(AVG(n.nota), 1) AS nota_media
  FROM avaliacoes a
  JOIN notas_avaliacao n ON n.id_avaliacao = a.id_avaliacao
  JOIN times t ON t.id_time = a.id_time_avaliador
 WHERE a.id_time_avaliado = @id_time
 GROUP BY a.id_avaliacao, a.comentario, a.data_criacao, a.id_time_avaliador, t.nome
 ORDER BY a.data_criacao DESC;

-- B12. GET /notificacoes
SELECT id_notificacao, tipo, titulo, mensagem, id_anuncio, id_solicitacao, id_partida,
       data_leitura IS NOT NULL AS lida, data_criacao
  FROM notificacoes WHERE id_usuario_destinatario = @id_usuario
 ORDER BY data_criacao DESC LIMIT 50;

-- B13. Uso de índices nas consultas mais frequentes.
EXPLAIN SELECT id_anuncio FROM anuncios_partidas
 WHERE status = 'ativo' AND sigla_estado = 'SP' AND cidade = 'São Paulo'
   AND data_hora_inicio > UTC_TIMESTAMP(3) ORDER BY data_hora_inicio;
EXPLAIN SELECT * FROM notificacoes
 WHERE id_usuario_destinatario = @id_usuario AND data_leitura IS NULL ORDER BY data_criacao DESC;
EXPLAIN SELECT * FROM partidas
 WHERE id_time_adversario = @id_time AND status = 'confirmada' ORDER BY data_hora_inicio;
