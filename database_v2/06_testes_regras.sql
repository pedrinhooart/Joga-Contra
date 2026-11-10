-- =============================================================================
-- Joga Contra — banco joga_contra_v2 — MySQL 8.4 LTS
-- 06_testes_regras.sql: testes automatizados das regras de integridade.
--
-- ATENÇÃO: execute SOMENTE em um banco de TESTE (cópia vazia criada com os
-- scripts 01–04). O roteiro insere dados fictícios (e-mails @example.com),
-- chama os procedimentos (que fazem COMMIT) e, no final, remove os dados que
-- ele próprio criou e os procedimentos auxiliares teste_*.
-- Duração: ~10 s (usa SLEEP para simular partidas e anúncios vencidos).
--
-- Resultado: a última consulta lista cada verificação com OK ou FALHOU.
-- =============================================================================

USE joga_contra_v2;
SET NAMES utf8mb4;
SET time_zone = '+00:00';

DROP TEMPORARY TABLE IF EXISTS teste_resultados;
CREATE TEMPORARY TABLE teste_resultados (
  ordem     INT AUTO_INCREMENT PRIMARY KEY,
  descricao VARCHAR(200),
  resultado VARCHAR(10),
  detalhe   VARCHAR(300)
);

DROP PROCEDURE IF EXISTS teste_deve_falhar;
DROP PROCEDURE IF EXISTS teste_verificar;
DROP PROCEDURE IF EXISTS teste_executar;

DELIMITER $$
-- Executa um comando que DEVE ser rejeitado pelo banco.
CREATE PROCEDURE teste_deve_falhar(IN p_descricao VARCHAR(200), IN p_sql TEXT)
BEGIN
  DECLARE v_falhou BOOLEAN DEFAULT FALSE;
  DECLARE v_mensagem VARCHAR(300) DEFAULT NULL;
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1 v_mensagem = MESSAGE_TEXT;
    SET v_falhou = TRUE;
  END;
  SET @teste_sql = p_sql;
  PREPARE comando FROM @teste_sql;
  EXECUTE comando;
  DEALLOCATE PREPARE comando;
  INSERT INTO teste_resultados (descricao, resultado, detalhe)
  VALUES (p_descricao, IF(v_falhou, 'OK', 'FALHOU'), COALESCE(v_mensagem, 'comando foi aceito'));
END$$

-- Executa um comando que DEVE ser aceito.
CREATE PROCEDURE teste_executar(IN p_descricao VARCHAR(200), IN p_sql TEXT)
BEGIN
  DECLARE v_mensagem VARCHAR(300) DEFAULT NULL;
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    GET DIAGNOSTICS CONDITION 1 v_mensagem = MESSAGE_TEXT;
  SET @teste_sql = p_sql;
  PREPARE comando FROM @teste_sql;
  EXECUTE comando;
  DEALLOCATE PREPARE comando;
  INSERT INTO teste_resultados (descricao, resultado, detalhe)
  VALUES (p_descricao, IF(v_mensagem IS NULL, 'OK', 'FALHOU'), v_mensagem);
END$$

-- Registra uma condição esperada.
CREATE PROCEDURE teste_verificar(IN p_descricao VARCHAR(200), IN p_condicao BOOLEAN)
BEGIN
  INSERT INTO teste_resultados (descricao, resultado)
  VALUES (p_descricao, IF(COALESCE(p_condicao, FALSE), 'OK', 'FALHOU'));
END$$
DELIMITER ;

-- -----------------------------------------------------------------------------
-- Dados fictícios
-- -----------------------------------------------------------------------------
SET @hash = '$2b$12$abcdefghijklmnopqrstuvABCDEFGHIJKLMNOPQRSTUVWXYZ01234';
SET @u1 = '11111111-1111-4111-8111-111111111111', @u2 = '22222222-2222-4222-8222-222222222222',
    @u3 = '33333333-3333-4333-8333-333333333333', @u4 = '44444444-4444-4444-8444-444444444444',
    @u5 = '55555555-5555-4555-8555-555555555555';
SET @t1 = 'a1111111-1111-4111-8111-111111111111', @t2 = 'a2222222-2222-4222-8222-222222222222',
    @t3 = 'a3333333-3333-4333-8333-333333333333', @t4 = 'a4444444-4444-4444-8444-444444444444';
SET @an1 = 'b1111111-1111-4111-8111-111111111111', @an2 = 'b2222222-2222-4222-8222-222222222222',
    @an3 = 'b3333333-3333-4333-8333-333333333333', @an4 = 'b4444444-4444-4444-8444-444444444444',
    @an5 = 'b5555555-5555-4555-8555-555555555555';
SET @s2 = 'c2222222-2222-4222-8222-222222222222', @s3 = 'c3333333-3333-4333-8333-333333333333',
    @s4 = 'c4444444-4444-4444-8444-444444444444', @s5 = 'c5555555-5555-4555-8555-555555555555',
    @s6 = 'c6666666-6666-4666-8666-666666666666', @s7 = 'c7777777-7777-4777-8777-777777777777',
    @s8 = 'c8888888-8888-4888-8888-888888888888';

INSERT INTO usuarios (id_usuario, nome, email, hash_senha, sigla_estado) VALUES
  (@u1, 'Capitão Teste A', 'teste.a@example.com', @hash, 'SP'),
  (@u2, 'Capitão Teste B', 'teste.b@example.com', @hash, 'SP'),
  (@u3, 'Capitão Teste C', 'teste.c@example.com', @hash, 'SP'),
  (@u4, 'Capitão Teste D', 'teste.d@example.com', @hash, 'SP'),
  (@u5, 'Usuário sem time', 'teste.e@example.com', @hash, 'SP');

INSERT INTO times (id_time, id_capitao, nome, cidade, sigla_estado, quantidade_jogadores, id_categoria_etaria, id_nivel_tecnico) VALUES
  (@t1, @u1, 'Teste A FC', 'São Paulo', 'SP', 14, 4, 2),
  (@t2, @u2, 'Teste B FC', 'São Paulo', 'SP', 12, 4, 2),
  (@t3, @u3, 'Teste C FC', 'São Paulo', 'SP', 10, 4, 1),
  (@t4, @u4, 'Teste D FC', 'São Paulo', 'SP', 11, 4, 3);
INSERT INTO times_modalidades (id_time, id_modalidade) VALUES (@t1, 1), (@t2, 1), (@t3, 1), (@t4, 2);

INSERT INTO anuncios_partidas (id_anuncio, id_time, id_modalidade, id_categoria_etaria, id_nivel_tecnico,
  id_mando_campo, quantidade_jogadores, data_hora_inicio, cidade, sigla_estado, nome_local, valor_aluguel_por_time)
VALUES (@an1, @t1, 1, 4, 2, 1, 7, UTC_TIMESTAMP(3) + INTERVAL 7 DAY, 'São Paulo', 'SP', 'Campo Teste', 120.00);

-- -----------------------------------------------------------------------------
-- Restrições de linha
-- -----------------------------------------------------------------------------
CALL teste_deve_falhar('Senha em texto puro (hash curto) é rejeitada',
  "INSERT INTO usuarios (id_usuario, nome, email, hash_senha) VALUES ('66666666-6666-4666-8666-666666666666', 'X', 'x@example.com', 'senha123')");
CALL teste_deve_falhar('E-mail duplicado (sem diferenciar maiúsculas) é rejeitado',
  CONCAT("INSERT INTO usuarios (id_usuario, nome, email, hash_senha) VALUES ('66666666-6666-4666-8666-666666666666', 'X', 'TESTE.A@example.com', '", @hash, "')"));
CALL teste_deve_falhar('Identificador fora do formato UUID é rejeitado',
  CONCAT("INSERT INTO usuarios (id_usuario, nome, email, hash_senha) VALUES ('abc', 'X', 'y@example.com', '", @hash, "')"));
CALL teste_deve_falhar('Capitão com dois times é rejeitado (um capitão por time e vice-versa)',
  CONCAT("INSERT INTO times (id_time, id_capitao, nome, cidade, sigla_estado, quantidade_jogadores, id_categoria_etaria) VALUES ('a9999999-9999-4999-8999-999999999999', '", @u1, "', 'Outro', 'São Paulo', 'SP', 10, 4)"));
CALL teste_deve_falhar('Time com 4 jogadores é rejeitado',
  CONCAT("INSERT INTO times (id_time, id_capitao, nome, cidade, sigla_estado, quantidade_jogadores, id_categoria_etaria) VALUES ('a9999999-9999-4999-8999-999999999999', '", @u5, "', 'Outro', 'São Paulo', 'SP', 4, 4)"));
CALL teste_deve_falhar('Anúncio sem nível técnico é rejeitado',
  CONCAT("INSERT INTO anuncios_partidas (id_anuncio, id_time, id_modalidade, id_categoria_etaria, quantidade_jogadores, data_hora_inicio, cidade, sigla_estado, nome_local) VALUES ('b9999999-9999-4999-8999-999999999999', '", @t1, "', 1, 4, 7, UTC_TIMESTAMP(3) + INTERVAL 1 DAY, 'São Paulo', 'SP', 'X')"));
CALL teste_deve_falhar('Anúncio com data passada é rejeitado',
  CONCAT("INSERT INTO anuncios_partidas (id_anuncio, id_time, id_modalidade, id_categoria_etaria, id_nivel_tecnico, quantidade_jogadores, data_hora_inicio, cidade, sigla_estado, nome_local) VALUES ('b9999999-9999-4999-8999-999999999999', '", @t1, "', 1, 4, 2, 7, UTC_TIMESTAMP(3) - INTERVAL 1 DAY, 'São Paulo', 'SP', 'X')"));
CALL teste_deve_falhar('Anúncio com 4 jogadores por equipe é rejeitado',
  CONCAT("INSERT INTO anuncios_partidas (id_anuncio, id_time, id_modalidade, id_categoria_etaria, id_nivel_tecnico, quantidade_jogadores, data_hora_inicio, cidade, sigla_estado, nome_local) VALUES ('b9999999-9999-4999-8999-999999999999', '", @t1, "', 1, 4, 2, 4, UTC_TIMESTAMP(3) + INTERVAL 1 DAY, 'São Paulo', 'SP', 'X')"));
CALL teste_deve_falhar('Anúncio com categoria inexistente é rejeitado (FK)',
  CONCAT("INSERT INTO anuncios_partidas (id_anuncio, id_time, id_modalidade, id_categoria_etaria, id_nivel_tecnico, quantidade_jogadores, data_hora_inicio, cidade, sigla_estado, nome_local) VALUES ('b9999999-9999-4999-8999-999999999999', '", @t1, "', 1, 99, 2, 7, UTC_TIMESTAMP(3) + INTERVAL 1 DAY, 'São Paulo', 'SP', 'X')"));
CALL teste_deve_falhar('Anúncio com só latitude (sem longitude) é rejeitado',
  CONCAT("INSERT INTO anuncios_partidas (id_anuncio, id_time, id_modalidade, id_categoria_etaria, id_nivel_tecnico, quantidade_jogadores, data_hora_inicio, cidade, sigla_estado, nome_local, latitude) VALUES ('b9999999-9999-4999-8999-999999999999', '", @t1, "', 1, 4, 2, 7, UTC_TIMESTAMP(3) + INTERVAL 1 DAY, 'São Paulo', 'SP', 'X', -23.5)"));
CALL teste_deve_falhar('Anúncio não pode nascer encerrado',
  CONCAT("INSERT INTO anuncios_partidas (id_anuncio, id_time, id_modalidade, id_categoria_etaria, id_nivel_tecnico, quantidade_jogadores, data_hora_inicio, cidade, sigla_estado, nome_local, status) VALUES ('b9999999-9999-4999-8999-999999999999', '", @t1, "', 1, 4, 2, 7, UTC_TIMESTAMP(3) + INTERVAL 1 DAY, 'São Paulo', 'SP', 'X', 'encerrado')"));

-- -----------------------------------------------------------------------------
-- Solicitações
-- -----------------------------------------------------------------------------
INSERT INTO solicitacoes_confronto (id_solicitacao, id_anuncio, id_time_solicitante, mensagem_inicial)
VALUES (@s2, @an1, @t2, 'Bora jogar?'), (@s3, @an1, @t3, NULL), (@s4, @an1, @t4, NULL);
CALL teste_verificar('Vários times solicitam o mesmo anúncio; time anunciante preenchido pelo gatilho',
  (SELECT COUNT(*) FROM solicitacoes_confronto WHERE id_anuncio = @an1 AND id_time_anunciante = @t1) = 3);
CALL teste_deve_falhar('Time não pode solicitar o próprio anúncio',
  CONCAT("INSERT INTO solicitacoes_confronto (id_solicitacao, id_anuncio, id_time_solicitante) VALUES ('c9999999-9999-4999-8999-999999999999', '", @an1, "', '", @t1, "')"));
CALL teste_deve_falhar('Segunda solicitação pendente do mesmo time no mesmo anúncio é rejeitada',
  CONCAT("INSERT INTO solicitacoes_confronto (id_solicitacao, id_anuncio, id_time_solicitante) VALUES ('c9999999-9999-4999-8999-999999999999', '", @an1, "', '", @t2, "')"));
CALL teste_deve_falhar('Solicitação não pode nascer confirmada',
  CONCAT("INSERT INTO solicitacoes_confronto (id_solicitacao, id_anuncio, id_time_solicitante, status) VALUES ('c9999999-9999-4999-8999-999999999999', '", @an1, "', '", @t2, "', 'confirmada')"));

-- Mensagens
CALL teste_deve_falhar('Mensagem antes do aceite do time anunciante é rejeitada (chat fechado)',
  CONCAT("INSERT INTO mensagens (id_mensagem, id_solicitacao, id_time_remetente, id_usuario_remetente, texto) VALUES ('d1111111-1111-4111-8111-111111111111', '", @s2, "', '", @t2, "', '", @u2, "', 'Sábado às 16h?')"));
CALL teste_deve_falhar('Usuário que não é capitão do time remetente não envia mensagem',
  CONCAT("INSERT INTO mensagens (id_mensagem, id_solicitacao, id_time_remetente, id_usuario_remetente, texto) VALUES ('d2222222-2222-4222-8222-222222222222', '", @s2, "', '", @t2, "', '", @u5, "', 'Oi')"));
CALL teste_deve_falhar('Time fora da solicitação não envia mensagem',
  CONCAT("INSERT INTO mensagens (id_mensagem, id_solicitacao, id_time_remetente, id_usuario_remetente, texto) VALUES ('d2222222-2222-4222-8222-222222222222', '", @s2, "', '", @t3, "', '", @u3, "', 'Oi')"));
CALL teste_verificar('Solicitação pendente não tem conversa',
  (SELECT ultima_mensagem IS NULL AND nao_lidas_anunciante = 0 AND nao_lidas_solicitante = 0
     FROM vis_resumo_solicitacoes WHERE id_solicitacao = @s2));

-- -----------------------------------------------------------------------------
-- Confirmação dupla e encerramento automático
-- -----------------------------------------------------------------------------
CALL teste_deve_falhar('Usuário que não é capitão de nenhum dos dois times não confirma',
  CONCAT("CALL proc_confirmar_solicitacao('", @s2, "', '", @u5, "')"));
CALL teste_deve_falhar('Status confirmada sem a concordância dos dois lados é rejeitado (atualização direta)',
  CONCAT("UPDATE solicitacoes_confronto SET status = 'confirmada', data_resposta = UTC_TIMESTAMP(3), data_confirmacao_anunciante = UTC_TIMESTAMP(3) WHERE id_solicitacao = '", @s2, "'"));

CALL proc_confirmar_solicitacao(@s2, @u1);
CALL teste_verificar('Confirmação de um lado só mantém pendente e não cria partida',
  (SELECT status = 'pendente' AND data_confirmacao_anunciante IS NOT NULL AND data_confirmacao_solicitante IS NULL
     FROM solicitacoes_confronto WHERE id_solicitacao = @s2)
  AND NOT EXISTS (SELECT 1 FROM partidas WHERE id_anuncio = @an1));
CALL teste_deve_falhar('Confirmação registrada não pode ser desfeita',
  CONCAT("UPDATE solicitacoes_confronto SET data_confirmacao_anunciante = NULL WHERE id_solicitacao = '", @s2, "'"));

CALL proc_confirmar_solicitacao(@s2, @u2);
CALL teste_verificar('Segundo lado confirma: solicitação confirmada e partida criada',
  (SELECT status = 'confirmada' FROM solicitacoes_confronto WHERE id_solicitacao = @s2)
  AND (SELECT COUNT(*) FROM partidas WHERE id_anuncio = @an1 AND id_solicitacao = @s2
         AND id_time_anunciante = @t1 AND id_time_adversario = @t2 AND status = 'confirmada'
         AND nome_local = 'Campo Teste' AND valor_aluguel_por_time = 120.00) = 1);
CALL teste_verificar('Anúncio fica indisponível (encerrado) e sai da busca',
  (SELECT status = 'encerrado' FROM anuncios_partidas WHERE id_anuncio = @an1)
  AND NOT EXISTS (SELECT 1 FROM vis_anuncios_disponiveis WHERE id_anuncio = @an1));
CALL teste_verificar('Demais solicitações do anúncio encerradas automaticamente',
  (SELECT COUNT(*) FROM solicitacoes_confronto
    WHERE id_anuncio = @an1 AND status = 'encerrada' AND motivo_encerramento IS NOT NULL) = 2);
CALL teste_verificar('Capitães dos times não selecionados (C e D) notificados do encerramento',
  (SELECT COUNT(*) FROM notificacoes WHERE tipo = 'solicitacao_encerrada'
    AND id_usuario_destinatario IN (@u3, @u4) AND id_solicitacao IN (@s3, @s4)) = 2
  AND NOT EXISTS (SELECT 1 FROM notificacoes WHERE tipo = 'solicitacao_encerrada' AND id_usuario_destinatario IN (@u1, @u2)));
CALL teste_verificar('Os dois capitães envolvidos recebem "partida confirmada"',
  (SELECT COUNT(DISTINCT id_usuario_destinatario) FROM notificacoes
    WHERE tipo = 'partida_confirmada' AND id_usuario_destinatario IN (@u1, @u2)) = 2);
CALL teste_deve_falhar('Outra solicitação do mesmo anúncio não pode mais ser confirmada (procedimento)',
  CONCAT("CALL proc_confirmar_solicitacao('", @s3, "', '", @u1, "')"));
CALL teste_deve_falhar('Outra solicitação do mesmo anúncio não pode mais ser confirmada (atualização direta)',
  CONCAT("UPDATE solicitacoes_confronto SET status = 'confirmada', data_confirmacao_anunciante = UTC_TIMESTAMP(3), data_confirmacao_solicitante = UTC_TIMESTAMP(3) WHERE id_solicitacao = '", @s3, "'"));
CALL teste_deve_falhar('Nova solicitação em anúncio encerrado é rejeitada',
  CONCAT("INSERT INTO solicitacoes_confronto (id_solicitacao, id_anuncio, id_time_solicitante) VALUES ('c9999999-9999-4999-8999-999999999999', '", @an1, "', '", @t3, "')"));
CALL teste_deve_falhar('Anúncio encerrado não volta a ficar ativo',
  CONCAT("UPDATE anuncios_partidas SET status = 'ativo' WHERE id_anuncio = '", @an1, "'"));
CALL teste_deve_falhar('Anúncio encerrado não pode ser excluído',
  CONCAT("CALL proc_excluir_anuncio('", @an1, "', '", @u1, "')"));
CALL teste_deve_falhar('Dados combinados da partida são imutáveis',
  CONCAT("UPDATE partidas SET nome_local = 'Outro campo' WHERE id_anuncio = '", @an1, "'"));
CALL teste_deve_falhar('Placar em partida ainda não realizada é rejeitado',
  CONCAT("UPDATE partidas SET gols_anunciante = 1, gols_adversario = 0 WHERE id_anuncio = '", @an1, "'"));
SET @p1 = (SELECT id_partida FROM partidas WHERE id_anuncio = @an1);
CALL teste_deve_falhar('Avaliação antes da partida realizada é rejeitada',
  CONCAT("INSERT INTO avaliacoes (id_avaliacao, id_partida, id_time_avaliador, id_time_avaliado) VALUES ('e1111111-1111-4111-8111-111111111111', '", @p1, "', '", @t1, "', '", @t2, "')"));

-- Cancelamento da partida
CALL teste_deve_falhar('Usuário de fora não cancela a partida',
  CONCAT("CALL proc_cancelar_partida('", @p1, "', '", @u3, "', 'x')"));
CALL proc_cancelar_partida(@p1, @u2, 'Chuva forte');
CALL teste_verificar('Partida cancelada pelo capitão B; capitão A notificado; anúncio continua encerrado',
  (SELECT status = 'cancelada' AND id_time_cancelou = @t2 FROM partidas WHERE id_partida = @p1)
  AND EXISTS (SELECT 1 FROM notificacoes WHERE tipo = 'partida_cancelada' AND id_usuario_destinatario = @u1 AND id_partida = @p1)
  AND (SELECT status = 'encerrado' FROM anuncios_partidas WHERE id_anuncio = @an1));
CALL teste_deve_falhar('Partida cancelada não volta a confirmada',
  CONCAT("UPDATE partidas SET status = 'confirmada', id_time_cancelou = NULL, data_cancelamento = NULL WHERE id_partida = '", @p1, "'"));

-- -----------------------------------------------------------------------------
-- Recusa, desistência e exclusão de anúncio
-- -----------------------------------------------------------------------------
INSERT INTO anuncios_partidas (id_anuncio, id_time, id_modalidade, id_categoria_etaria, id_nivel_tecnico,
  quantidade_jogadores, data_hora_inicio, cidade, sigla_estado, nome_local)
VALUES (@an2, @t1, 1, 4, 2, 7, UTC_TIMESTAMP(3) + INTERVAL 3 DAY, 'São Paulo', 'SP', 'Campo 2'),
       (@an5, @t1, 1, 4, 2, 7, UTC_TIMESTAMP(3) + INTERVAL 4 DAY, 'São Paulo', 'SP', 'Campo 5');
INSERT INTO solicitacoes_confronto (id_solicitacao, id_anuncio, id_time_solicitante)
VALUES (@s5, @an2, @t3), (@s6, @an2, @t4), (@s8, @an5, @t2);
CALL teste_deve_falhar('Anúncio só fica encerrado quando existe partida (atualização direta)',
  CONCAT("UPDATE anuncios_partidas SET status = 'encerrado' WHERE id_anuncio = '", @an2, "'"));
CALL teste_deve_falhar('Somente o capitão anunciante recusa',
  CONCAT("CALL proc_recusar_solicitacao('", @s5, "', '", @u3, "')"));
CALL proc_recusar_solicitacao(@s5, @u1);
CALL teste_verificar('Recusa registrada e capitão solicitante notificado',
  (SELECT status = 'recusada' FROM solicitacoes_confronto WHERE id_solicitacao = @s5)
  AND EXISTS (SELECT 1 FROM notificacoes WHERE tipo = 'solicitacao_recusada' AND id_usuario_destinatario = @u3));
CALL teste_executar('Após recusa, o mesmo time pode solicitar de novo',
  CONCAT("INSERT INTO solicitacoes_confronto (id_solicitacao, id_anuncio, id_time_solicitante) VALUES ('c9999999-9999-4999-8999-999999999999', '", @an2, "', '", @t3, "')"));
CALL proc_cancelar_solicitacao(@s6, @u4);
CALL teste_verificar('Solicitante desiste (cancelada)',
  (SELECT status = 'cancelada' FROM solicitacoes_confronto WHERE id_solicitacao = @s6));
CALL teste_executar('Pausar anúncio ativo', CONCAT("UPDATE anuncios_partidas SET status = 'pausado' WHERE id_anuncio = '", @an2, "'"));
CALL teste_deve_falhar('Anúncio pausado não recebe solicitação',
  CONCAT("INSERT INTO solicitacoes_confronto (id_solicitacao, id_anuncio, id_time_solicitante) VALUES ('c8888888-0000-4888-8888-888888888888', '", @an2, "', '", @t2, "')"));
CALL proc_excluir_anuncio(@an5, @u1);
CALL teste_verificar('Exclusão lógica do anúncio encerra pendentes e notifica',
  (SELECT data_exclusao IS NOT NULL FROM anuncios_partidas WHERE id_anuncio = @an5)
  AND (SELECT status = 'encerrada' FROM solicitacoes_confronto WHERE id_solicitacao = @s8)
  AND EXISTS (SELECT 1 FROM notificacoes WHERE id_solicitacao = @s8 AND id_usuario_destinatario = @u2));

-- -----------------------------------------------------------------------------
-- Partida realizada, avaliação e expiração (usa SLEEP)
-- -----------------------------------------------------------------------------
INSERT INTO anuncios_partidas (id_anuncio, id_time, id_modalidade, id_categoria_etaria, id_nivel_tecnico,
  quantidade_jogadores, data_hora_inicio, cidade, sigla_estado, nome_local)
VALUES (@an3, @t1, 2, 4, 2, 5, UTC_TIMESTAMP(3) + INTERVAL 3 SECOND, 'São Paulo', 'SP', 'Quadra 3'),
       (@an4, @t3, 1, 4, 1, 7, UTC_TIMESTAMP(3) + INTERVAL 3 SECOND, 'São Paulo', 'SP', 'Campo 4');
INSERT INTO solicitacoes_confronto (id_solicitacao, id_anuncio, id_time_solicitante)
VALUES (@s7, @an3, @t4), ('c7777777-0000-4777-8777-777777777777', @an4, @t2);
CALL proc_confirmar_solicitacao(@s7, @u4);
CALL proc_confirmar_solicitacao(@s7, @u1);
SET @p2 = (SELECT id_partida FROM partidas WHERE id_anuncio = @an3);
DO SLEEP(4);

CALL proc_marcar_partidas_realizadas(0);
CALL teste_verificar('Rotina marca partida vencida como realizada e convida os dois capitães a avaliar',
  (SELECT status = 'realizada' AND data_realizacao IS NOT NULL FROM partidas WHERE id_partida = @p2)
  AND (SELECT COUNT(*) FROM notificacoes WHERE tipo = 'avaliacao_pendente' AND id_partida = @p2) = 2);
CALL teste_executar('Placar registrado após a partida realizada',
  CONCAT("UPDATE partidas SET gols_anunciante = 3, gols_adversario = 2 WHERE id_partida = '", @p2, "'"));

CALL proc_expirar_anuncios();
CALL teste_verificar('Rotina expira anúncio vencido e encerra solicitação pendente',
  (SELECT status = 'expirado' FROM anuncios_partidas WHERE id_anuncio = @an4)
  AND (SELECT status = 'encerrada' FROM solicitacoes_confronto WHERE id_solicitacao = 'c7777777-0000-4777-8777-777777777777'));

INSERT INTO avaliacoes (id_avaliacao, id_partida, id_time_avaliador, id_time_avaliado, comentario)
VALUES ('e2222222-2222-4222-8222-222222222222', @p2, @t1, @t4, 'Time pontual.');
INSERT INTO notas_avaliacao (id_avaliacao, id_criterio, nota) VALUES
  ('e2222222-2222-4222-8222-222222222222', 1, 5), ('e2222222-2222-4222-8222-222222222222', 2, 4),
  ('e2222222-2222-4222-8222-222222222222', 3, 5), ('e2222222-2222-4222-8222-222222222222', 4, 4);
CALL teste_deve_falhar('Nota 6 é rejeitada',
  "INSERT INTO notas_avaliacao (id_avaliacao, id_criterio, nota) VALUES ('e2222222-2222-4222-8222-222222222222', 1, 6)");
CALL teste_deve_falhar('Nota 0 é rejeitada',
  "UPDATE notas_avaliacao SET nota = 0 WHERE id_avaliacao = 'e2222222-2222-4222-8222-222222222222' AND id_criterio = 1");
CALL teste_deve_falhar('Segunda avaliação do mesmo time na mesma partida é rejeitada',
  CONCAT("INSERT INTO avaliacoes (id_avaliacao, id_partida, id_time_avaliador, id_time_avaliado) VALUES ('e3333333-3333-4333-8333-333333333333', '", @p2, "', '", @t1, "', '", @t4, "')"));
CALL teste_deve_falhar('Time que não jogou a partida não avalia',
  CONCAT("INSERT INTO avaliacoes (id_avaliacao, id_partida, id_time_avaliador, id_time_avaliado) VALUES ('e3333333-3333-4333-8333-333333333333', '", @p2, "', '", @t2, "', '", @t4, "')"));
CALL teste_deve_falhar('Avaliação é imutável',
  "UPDATE avaliacoes SET comentario = 'editado' WHERE id_avaliacao = 'e2222222-2222-4222-8222-222222222222'");
CALL teste_verificar('Estatísticas do time avaliado: 1 partida, média 4,5, 1 avaliação',
  (SELECT total_partidas_realizadas = 1 AND media_avaliacao = 4.5 AND total_avaliacoes = 1
     FROM vis_estatisticas_times WHERE id_time = @t4));
CALL teste_verificar('Perfil público do time traz nome do capitão e estatísticas',
  (SELECT nome_capitao = 'Capitão Teste A' AND total_partidas_realizadas = 1 FROM vis_perfis_times WHERE id_time = @t1));

-- Notificações
CALL teste_executar('Marcar notificação como lida',
  CONCAT("UPDATE notificacoes SET data_leitura = UTC_TIMESTAMP(3) WHERE id_usuario_destinatario = '", @u1, "'"));
CALL teste_deve_falhar('Texto da notificação é imutável',
  CONCAT("UPDATE notificacoes SET titulo = 'x' WHERE id_usuario_destinatario = '", @u1, "'"));

-- -----------------------------------------------------------------------------
-- Resultado
-- -----------------------------------------------------------------------------
SELECT ordem, resultado, descricao, detalhe FROM teste_resultados ORDER BY ordem;
SELECT SUM(resultado = 'OK') AS aprovados, SUM(resultado <> 'OK') AS reprovados FROM teste_resultados;

-- -----------------------------------------------------------------------------
-- Limpeza dos dados criados por este roteiro (somente os ids de teste)
-- -----------------------------------------------------------------------------
DELETE FROM notas_avaliacao WHERE id_avaliacao IN (SELECT id_avaliacao FROM avaliacoes WHERE id_time_avaliador IN (@t1, @t2, @t3, @t4));
DELETE FROM avaliacoes WHERE id_time_avaliador IN (@t1, @t2, @t3, @t4);
DELETE FROM notificacoes WHERE id_usuario_destinatario IN (@u1, @u2, @u3, @u4, @u5);
DELETE FROM mensagens WHERE id_time_remetente IN (@t1, @t2, @t3, @t4);
DELETE FROM partidas WHERE id_time_anunciante IN (@t1, @t2, @t3, @t4);
DELETE FROM solicitacoes_confronto WHERE id_time_solicitante IN (@t1, @t2, @t3, @t4);
DELETE FROM anuncios_partidas WHERE id_time IN (@t1, @t2, @t3, @t4);
DELETE FROM times_modalidades WHERE id_time IN (@t1, @t2, @t3, @t4);
DELETE FROM times WHERE id_time IN (@t1, @t2, @t3, @t4);
DELETE FROM usuarios WHERE id_usuario IN (@u1, @u2, @u3, @u4, @u5);
DROP PROCEDURE teste_deve_falhar;
DROP PROCEDURE teste_executar;
DROP PROCEDURE teste_verificar;
DROP TEMPORARY TABLE teste_resultados;
