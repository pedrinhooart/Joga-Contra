-- =============================================================================
-- Joga Contra — banco joga_contra_v2 — MySQL 8.4 LTS
-- 11_conflito_horario.sql (23/11/2026): ao aceitar um desafio, as outras
-- solicitações PENDENTES do mesmo time desafiante para jogos na mesma data e
-- hora local são encerradas na mesma transação (status 'encerrada', com motivo;
-- nada é apagado), e os capitães afetados são avisados.
--
-- Cria a função fn_inicio_local e recria o procedimento
-- proc_confirmar_solicitacao (DROP/CREATE de rotina: não toca em dados).
-- Para bancos criados antes desta versão; 02_rotinas.sql já traz o resultado.
-- Pode ser executado de novo (remove e recria as duas rotinas).
-- =============================================================================

SET NAMES utf8mb4;
SET time_zone = '+00:00';

DROP FUNCTION IF EXISTS fn_inicio_local;
DROP PROCEDURE IF EXISTS proc_confirmar_solicitacao;

DELIMITER $$

-- Data e hora local de início ('AAAA-MM-DD HH:MM') de uma partida, a partir do
-- instante em UTC e da UF onde ela acontece — o horário que as pessoas
-- escolheram no anúncio. Mesmos fusos de backend/src/services/fuso.ts (o Brasil
-- não tem horário de verão desde 2019; o teste de integração confere os dois).
CREATE FUNCTION fn_inicio_local(
  p_inicio DATETIME(3),
  p_uf     CHAR(2) CHARACTER SET ascii COLLATE ascii_bin)
RETURNS CHAR(16) CHARACTER SET ascii
DETERMINISTIC NO SQL
RETURN DATE_FORMAT(
  DATE_SUB(p_inicio, INTERVAL CASE
    WHEN p_uf = 'AC' THEN 5
    WHEN p_uf IN ('AM', 'MS', 'MT', 'RO', 'RR') THEN 4
    ELSE 3
  END HOUR),
  '%Y-%m-%d %H:%i')$$

-- Confirma a concordância de um dos times. Quando os dois lados confirmam, na
-- mesma transação: confirma a solicitação, cria a partida (cópia dos dados do
-- anúncio), deixa o anúncio indisponível (encerrado), encerra as demais
-- solicitações pendentes e notifica os capitães afetados e os envolvidos.
--
-- Mesmo dia e horário (23/11/2026): o time desafiante não joga duas partidas ao
-- mesmo tempo. Na mesma transação, as OUTRAS solicitações pendentes dele para
-- jogos com a mesma data e hora local de início (fn_inicio_local) são
-- encerradas — nunca a aceita, nunca as de outros times, nunca apagadas — e os
-- donos desses anúncios e o próprio capitão desafiante são avisados.
--
-- Concorrência: 1º o time desafiante é bloqueado (FOR UPDATE), serializando os
-- aceites de desafios do mesmo time — de dois aceites simultâneos para o mesmo
-- horário, o segundo encontra a sua solicitação já encerrada e é recusado — e
-- impedindo que ele crie solicitação nova até o fim (a FK de
-- solicitacoes_confronto lê o time com bloqueio compartilhado). 2º o anúncio,
-- serializando as confirmações do mesmo anúncio; 3º a solicitação. Os índices
-- únicos un_solicitacoes_confronto_confirmada e un_partidas_anuncio impedem uma
-- segunda confirmação mesmo que alguém altere as tabelas sem este procedimento.
-- Qualquer erro desfaz tudo (ROLLBACK no tratador de exceções).
--
-- Retorna uma linha: id_solicitacao, status, data_confirmacao_anunciante,
-- data_confirmacao_solicitante, id_partida (NULL se ainda falta um lado).
CREATE PROCEDURE proc_confirmar_solicitacao(
  IN p_id_solicitacao CHAR(36) CHARACTER SET ascii COLLATE ascii_bin,
  IN p_id_usuario     CHAR(36) CHARACTER SET ascii COLLATE ascii_bin)
BEGIN
  DECLARE v_id_anuncio CHAR(36) CHARACTER SET ascii COLLATE ascii_bin;
  DECLARE v_anunciante CHAR(36) CHARACTER SET ascii COLLATE ascii_bin;
  DECLARE v_solicitante CHAR(36) CHARACTER SET ascii COLLATE ascii_bin;
  DECLARE v_status_solicitacao VARCHAR(20);
  DECLARE v_status_anuncio VARCHAR(20);
  DECLARE v_inicio DATETIME(3);
  DECLARE v_uf CHAR(2) CHARACTER SET ascii COLLATE ascii_bin;
  DECLARE v_inicio_local CHAR(16) CHARACTER SET ascii;
  DECLARE v_mesmo_horario JSON DEFAULT NULL;
  DECLARE v_motivo_horario VARCHAR(255)
    DEFAULT 'O time desafiante já tem partida confirmada neste dia e horário.';
  DECLARE v_exclusao DATETIME(3);
  DECLARE v_conf_anunciante DATETIME(3);
  DECLARE v_conf_solicitante DATETIME(3);
  DECLARE v_nome_anunciante VARCHAR(120);
  DECLARE v_nome_solicitante VARCHAR(120);
  DECLARE v_capitao_anunciante CHAR(36) CHARACTER SET ascii COLLATE ascii_bin;
  DECLARE v_capitao_solicitante CHAR(36) CHARACTER SET ascii COLLATE ascii_bin;
  DECLARE v_id_partida CHAR(36) CHARACTER SET ascii COLLATE ascii_bin DEFAULT NULL;
  DECLARE v_agora DATETIME(3) DEFAULT UTC_TIMESTAMP(3);

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  -- id_anuncio e o time desafiante são imutáveis: lidos antes da transação,
  -- para que a fotografia de leitura dela só comece depois dos bloqueios.
  SELECT id_anuncio, id_time_solicitante INTO v_id_anuncio, v_solicitante
    FROM solicitacoes_confronto WHERE id_solicitacao = p_id_solicitacao;
  IF v_id_anuncio IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solicitação não encontrada.';
  END IF;

  START TRANSACTION;

  -- 1º bloqueio: time desafiante (ordem fixa time -> anúncio -> solicitações).
  SELECT id_time INTO v_solicitante
    FROM times WHERE id_time = v_solicitante
    FOR UPDATE;

  -- 2º bloqueio: anúncio.
  SELECT status, data_hora_inicio, sigla_estado, data_exclusao
    INTO v_status_anuncio, v_inicio, v_uf, v_exclusao
    FROM anuncios_partidas WHERE id_anuncio = v_id_anuncio
    FOR UPDATE;

  -- 3º bloqueio: a solicitação, relida após obter os bloqueios anteriores.
  SELECT s.status, s.id_time_anunciante, s.id_time_solicitante,
         s.data_confirmacao_anunciante, s.data_confirmacao_solicitante
    INTO v_status_solicitacao, v_anunciante, v_solicitante, v_conf_anunciante, v_conf_solicitante
    FROM solicitacoes_confronto s WHERE s.id_solicitacao = p_id_solicitacao
    FOR UPDATE;

  IF v_status_solicitacao <> 'pendente' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Esta solicitação não está mais em aberto.';
  END IF;
  IF v_status_anuncio <> 'ativo' OR v_exclusao IS NOT NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O anúncio não está mais disponível para confirmação.';
  END IF;
  IF v_inicio <= v_agora THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A data da partida já passou.';
  END IF;

  SELECT t.nome, t.id_capitao INTO v_nome_anunciante, v_capitao_anunciante
    FROM times t WHERE t.id_time = v_anunciante;
  SELECT t.nome, t.id_capitao INTO v_nome_solicitante, v_capitao_solicitante
    FROM times t WHERE t.id_time = v_solicitante;

  IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id_usuario = p_id_usuario AND status_conta = 'ativa') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conta do usuário inativa ou inexistente.';
  END IF;

  -- Registra o lado do usuário (idempotente: repetir não altera a data).
  IF p_id_usuario = v_capitao_anunciante THEN
    SET v_conf_anunciante = COALESCE(v_conf_anunciante, v_agora);
  ELSEIF p_id_usuario = v_capitao_solicitante THEN
    SET v_conf_solicitante = COALESCE(v_conf_solicitante, v_agora);
  ELSE
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Somente os capitães dos dois times podem confirmar a partida.';
  END IF;

  UPDATE solicitacoes_confronto
     SET data_confirmacao_anunciante = v_conf_anunciante,
         data_confirmacao_solicitante = v_conf_solicitante
   WHERE id_solicitacao = p_id_solicitacao;

  IF v_conf_anunciante IS NOT NULL AND v_conf_solicitante IS NOT NULL THEN
    -- a) solicitação confirmada
    UPDATE solicitacoes_confronto
       SET status = 'confirmada', data_resposta = v_agora
     WHERE id_solicitacao = p_id_solicitacao;

    -- b) partida com cópia dos dados combinados
    SET v_id_partida = UUID();
    INSERT INTO partidas (
      id_partida, id_solicitacao, id_anuncio, id_time_anunciante, id_time_adversario,
      id_modalidade, quantidade_jogadores, data_hora_inicio, nome_local, endereco,
      cidade, sigla_estado, latitude, longitude, valor_aluguel_por_time, data_criacao)
    SELECT v_id_partida, p_id_solicitacao, a.id_anuncio, a.id_time, v_solicitante,
           a.id_modalidade, a.quantidade_jogadores, a.data_hora_inicio, a.nome_local, a.endereco,
           a.cidade, a.sigla_estado, a.latitude, a.longitude, a.valor_aluguel_por_time, v_agora
      FROM anuncios_partidas a WHERE a.id_anuncio = v_id_anuncio;

    -- c) anúncio indisponível
    UPDATE anuncios_partidas SET status = 'encerrado' WHERE id_anuncio = v_id_anuncio;

    -- d) alerta aos capitães cujas solicitações serão encerradas
    INSERT INTO notificacoes (id_notificacao, id_usuario_destinatario, tipo, titulo, mensagem,
                              id_solicitacao, data_criacao)
    SELECT UUID(), t.id_capitao, 'solicitacao_encerrada',
           'Esse jogo já tem adversário.',
           LEFT(CONCAT('O anúncio de ', v_nome_anunciante,
                       ' confirmou partida com outro time. Sua solicitação foi encerrada.'), 500),
           s.id_solicitacao, v_agora
      FROM solicitacoes_confronto s
      JOIN times t ON t.id_time = s.id_time_solicitante
     WHERE s.id_anuncio = v_id_anuncio AND s.status = 'pendente'
       AND s.id_solicitacao <> p_id_solicitacao;

    -- e) encerramento automático das demais solicitações
    UPDATE solicitacoes_confronto
       SET status = 'encerrada', data_resposta = v_agora,
           motivo_encerramento = 'Partida confirmada com outro time.'
     WHERE id_anuncio = v_id_anuncio AND status = 'pendente'
       AND id_solicitacao <> p_id_solicitacao;

    -- e2) mesmo dia e horário: as outras solicitações PENDENTES do time
    --     desafiante para jogos com a mesma data e hora local de início.
    --     Leitura sem bloqueio dos anúncios (evita impasse com quem confirma
    --     aqueles anúncios); o time está bloqueado desde o início, então nenhuma
    --     solicitação nova dele aparece até o COMMIT. O UPDATE relê o status
    --     atual com bloqueio: só encerra o que ainda está pendente.
    SET v_inicio_local = fn_inicio_local(v_inicio, v_uf);
    SELECT JSON_ARRAYAGG(s.id_solicitacao) INTO v_mesmo_horario
      FROM solicitacoes_confronto s
      JOIN anuncios_partidas a ON a.id_anuncio = s.id_anuncio
     WHERE s.id_time_solicitante = v_solicitante AND s.status = 'pendente'
       AND s.id_solicitacao <> p_id_solicitacao AND s.id_anuncio <> v_id_anuncio
       AND fn_inicio_local(a.data_hora_inicio, a.sigla_estado) = v_inicio_local;

    IF v_mesmo_horario IS NOT NULL THEN
      UPDATE solicitacoes_confronto
         SET status = 'encerrada', data_resposta = v_agora,
             motivo_encerramento = v_motivo_horario
       WHERE id_time_solicitante = v_solicitante AND status = 'pendente'
         AND id_solicitacao <> p_id_solicitacao
         AND id_solicitacao MEMBER OF (v_mesmo_horario);

      -- Avisos: o dono de cada anúncio perde o desafiante; o capitão
      -- desafiante entende por que os outros pedidos saíram dos pendentes.
      INSERT INTO notificacoes (id_notificacao, id_usuario_destinatario, tipo, titulo, mensagem,
                                id_solicitacao, data_criacao)
      SELECT UUID(), ta.id_capitao, 'solicitacao_encerrada', 'Desafio retirado.',
             LEFT(CONCAT(v_nome_solicitante, ' confirmou outra partida no mesmo dia e horário. ',
                         'A solicitação para o seu jogo foi encerrada.'), 500),
             s.id_solicitacao, v_agora
        FROM solicitacoes_confronto s
        JOIN times ta ON ta.id_time = s.id_time_anunciante
       WHERE s.id_solicitacao MEMBER OF (v_mesmo_horario)
         AND s.status = 'encerrada' AND s.data_resposta = v_agora
         AND s.motivo_encerramento = v_motivo_horario
      UNION ALL
      SELECT UUID(), v_capitao_solicitante, 'solicitacao_encerrada', 'Desafio encerrado.',
             LEFT(CONCAT('Vocês já jogam contra ', v_nome_anunciante, ' nesse dia e horário. ',
                         'O desafio para o jogo de ', ta.nome, ' foi encerrado.'), 500),
             s.id_solicitacao, v_agora
        FROM solicitacoes_confronto s
        JOIN times ta ON ta.id_time = s.id_time_anunciante
       WHERE s.id_solicitacao MEMBER OF (v_mesmo_horario)
         AND s.status = 'encerrada' AND s.data_resposta = v_agora
         AND s.motivo_encerramento = v_motivo_horario;
    END IF;

    -- f) aviso aos dois capitães envolvidos
    INSERT INTO notificacoes (id_notificacao, id_usuario_destinatario, tipo, titulo, mensagem,
                              id_partida, data_criacao)
    VALUES
      (UUID(), v_capitao_anunciante, 'partida_confirmada', 'Pode chamar a equipe.',
       LEFT(CONCAT('Sua partida contra ', v_nome_solicitante, ' foi confirmada.'), 500), v_id_partida, v_agora),
      (UUID(), v_capitao_solicitante, 'partida_confirmada', 'Pode chamar a equipe.',
       LEFT(CONCAT('Sua partida contra ', v_nome_anunciante, ' foi confirmada.'), 500), v_id_partida, v_agora);
  END IF;

  COMMIT;

  SELECT s.id_solicitacao, s.status, s.data_confirmacao_anunciante, s.data_confirmacao_solicitante,
         v_id_partida AS id_partida
    FROM solicitacoes_confronto s WHERE s.id_solicitacao = p_id_solicitacao;
END$$

DELIMITER ;
