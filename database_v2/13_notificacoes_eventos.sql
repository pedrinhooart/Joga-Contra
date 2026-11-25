-- =============================================================================
-- Joga Contra — banco joga_contra_v2 — MySQL 8.4 LTS
-- 13_notificacoes_eventos.sql (25/11/2026): notificações dos eventos, fase 2.
--
-- Muda só textos, chaves e destinatários das notificações; as regras de
-- anúncios, desafios e partidas continuam as mesmas. Cada notificação segue na
-- mesma transação do seu evento: se ele for desfeito, ela também é.
--
--   * tipo novo 'solicitacao_enviada' (registro para o time que enviou o desafio);
--   * fn_quando_texto: '26/11 às 21h' no horário local do jogo;
--   * proc_confirmar_solicitacao: 'Desafio aceito!' ao desafiante (adversário,
--     data, hora, local e chat liberado), 'Partida confirmada' já lida para quem
--     aceitou, 'Solicitação encerrada' aos outros desafiantes do anúncio e
--     'Solicitação encerrada por conflito de horário' só ao time desafiante
--     (os donos dos outros anúncios deixam de ser avisados);
--   * proc_recusar_solicitacao, proc_excluir_anuncio, proc_expirar_anuncios:
--     'Solicitação encerrada' com time, data e hora;
--   * proc_cancelar_partida: 'Jogo cancelado' aos dois lados (já lido para quem
--     cancelou), com data, hora e motivo;
--   * chave_evento em todas: no máximo uma notificação por evento e pessoa.
--
-- Não altera nem apaga dados. Reexecutável (remove e recria as rotinas).
-- Para bancos criados antes desta versão; 01 e 02 já trazem o resultado.
-- =============================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET time_zone = '+00:00';

ALTER TABLE notificacoes
  DROP CHECK vr_notificacoes_tipo,
  ADD CONSTRAINT vr_notificacoes_tipo CHECK (tipo IN (
    'solicitacao_recebida', 'mensagem_recebida', 'partida_confirmada', 'partida_cancelada',
    'solicitacao_encerrada', 'solicitacao_recusada', 'anuncio_expirando', 'avaliacao_pendente',
    'aviso', 'solicitacao_enviada'));

DROP FUNCTION IF EXISTS fn_quando_texto;
DROP PROCEDURE IF EXISTS proc_confirmar_solicitacao;
DROP PROCEDURE IF EXISTS proc_recusar_solicitacao;
DROP PROCEDURE IF EXISTS proc_cancelar_partida;
DROP PROCEDURE IF EXISTS proc_excluir_anuncio;
DROP PROCEDURE IF EXISTS proc_expirar_anuncios;

DELIMITER $$
CREATE FUNCTION fn_quando_texto(
  p_inicio DATETIME(3),
  p_uf     CHAR(2) CHARACTER SET ascii COLLATE ascii_bin)
RETURNS VARCHAR(20) CHARACTER SET utf8mb4
DETERMINISTIC NO SQL
BEGIN
  -- utf8mb4: o texto final tem acento (' às ').
  DECLARE v_local VARCHAR(16) CHARACTER SET utf8mb4 DEFAULT fn_inicio_local(p_inicio, p_uf);
  RETURN CONCAT(SUBSTRING(v_local, 9, 2), '/', SUBSTRING(v_local, 6, 2), ' às ',
                SUBSTRING(v_local, 12, 2), 'h',
                IF(SUBSTRING(v_local, 15, 2) = '00', '', SUBSTRING(v_local, 15, 2)));
END$$

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
  DECLARE v_quando VARCHAR(20);
  DECLARE v_local VARCHAR(200);

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
  SELECT status, data_hora_inicio, sigla_estado, data_exclusao,
         COALESCE(NULLIF(TRIM(nome_local), ''), cidade)
    INTO v_status_anuncio, v_inicio, v_uf, v_exclusao, v_local
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

    SET v_quando = fn_quando_texto(v_inicio, v_uf);

    -- d) alerta aos capitães cujas solicitações serão encerradas
    INSERT INTO notificacoes (id_notificacao, id_usuario_destinatario, tipo, titulo, mensagem,
                              id_solicitacao, chave_evento, data_criacao)
    SELECT UUID(), t.id_capitao, 'solicitacao_encerrada',
           'Solicitação encerrada',
           LEFT(CONCAT('Sua solicitação para jogar contra o time ', v_nome_anunciante,
                       ' foi encerrada: o jogo de ', v_quando, ' foi confirmado com outro time.'), 500),
           s.id_solicitacao, CONCAT('solicitacao_encerrada:', s.id_solicitacao), v_agora
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

      -- Aviso só ao time que teve as solicitações encerradas (uma por
      -- solicitação efetivamente encerrada agora).
      INSERT INTO notificacoes (id_notificacao, id_usuario_destinatario, tipo, titulo, mensagem,
                                id_solicitacao, chave_evento, data_criacao)
      SELECT UUID(), v_capitao_solicitante, 'solicitacao_encerrada',
             'Solicitação encerrada por conflito de horário',
             LEFT(CONCAT('Como seu desafio contra o time ', v_nome_anunciante, ' foi confirmado para ',
                         v_quando, ', sua solicitação para o jogo do time ', ta.nome,
                         ' nesse mesmo horário foi encerrada.'), 500),
             s.id_solicitacao, CONCAT('solicitacao_encerrada:', s.id_solicitacao), v_agora
        FROM solicitacoes_confronto s
        JOIN times ta ON ta.id_time = s.id_time_anunciante
       WHERE s.id_solicitacao MEMBER OF (v_mesmo_horario)
         AND s.status = 'encerrada' AND s.data_resposta = v_agora
         AND s.motivo_encerramento = v_motivo_horario;
    END IF;

    -- f) aviso aos dois capitães envolvidos. O texto já informa que o chat foi
    --    liberado (a conversa abre com a solicitação confirmada), sem aviso à
    --    parte. Quem deu o aceite recebe o seu já lido: registro no histórico,
    --    sem contar como novidade.
    INSERT INTO notificacoes (id_notificacao, id_usuario_destinatario, tipo, titulo, mensagem,
                              id_partida, chave_evento, data_criacao, data_leitura)
    VALUES
      (UUID(), v_capitao_solicitante, 'partida_confirmada', 'Desafio aceito!',
       LEFT(CONCAT('Seu desafio foi aceito! O jogo contra o time ', v_nome_anunciante, ' será em ',
                   v_quando, ', em ', v_local, '. O chat com o outro capitão já está liberado.'), 500),
       v_id_partida, CONCAT('desafio_aceito:', p_id_solicitacao), v_agora,
       IF(p_id_usuario = v_capitao_solicitante, v_agora, NULL)),
      (UUID(), v_capitao_anunciante, 'partida_confirmada', 'Partida confirmada',
       LEFT(CONCAT('Você aceitou o desafio do time ', v_nome_solicitante, '. O jogo será em ',
                   v_quando, ', em ', v_local, '. O chat com o outro capitão já está liberado.'), 500),
       v_id_partida, CONCAT('desafio_aceito:', p_id_solicitacao), v_agora,
       IF(p_id_usuario = v_capitao_anunciante, v_agora, NULL));
  END IF;

  COMMIT;

  SELECT s.id_solicitacao, s.status, s.data_confirmacao_anunciante, s.data_confirmacao_solicitante,
         v_id_partida AS id_partida
    FROM solicitacoes_confronto s WHERE s.id_solicitacao = p_id_solicitacao;
END$$

CREATE PROCEDURE proc_recusar_solicitacao(
  IN p_id_solicitacao CHAR(36) CHARACTER SET ascii COLLATE ascii_bin,
  IN p_id_usuario     CHAR(36) CHARACTER SET ascii COLLATE ascii_bin)
BEGIN
  DECLARE v_status VARCHAR(20);
  DECLARE v_capitao_anunciante CHAR(36) CHARACTER SET ascii COLLATE ascii_bin;
  DECLARE v_capitao_solicitante CHAR(36) CHARACTER SET ascii COLLATE ascii_bin;
  DECLARE v_nome_anunciante VARCHAR(120);
  DECLARE v_quando VARCHAR(20);
  DECLARE v_agora DATETIME(3) DEFAULT UTC_TIMESTAMP(3);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  START TRANSACTION;
  SELECT s.status, ta.id_capitao, ts.id_capitao, ta.nome,
         fn_quando_texto(a.data_hora_inicio, a.sigla_estado)
    INTO v_status, v_capitao_anunciante, v_capitao_solicitante, v_nome_anunciante, v_quando
    FROM solicitacoes_confronto s
    JOIN times ta ON ta.id_time = s.id_time_anunciante
    JOIN times ts ON ts.id_time = s.id_time_solicitante
    JOIN anuncios_partidas a ON a.id_anuncio = s.id_anuncio
   WHERE s.id_solicitacao = p_id_solicitacao
   FOR UPDATE OF s;

  IF v_status IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solicitação não encontrada.';
  END IF;
  IF NOT (p_id_usuario <=> v_capitao_anunciante) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Somente o capitão do time anunciante pode recusar.';
  END IF;
  IF v_status <> 'pendente' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Esta solicitação não está mais em aberto.';
  END IF;

  UPDATE solicitacoes_confronto SET status = 'recusada', data_resposta = v_agora
   WHERE id_solicitacao = p_id_solicitacao;
  INSERT INTO notificacoes (id_notificacao, id_usuario_destinatario, tipo, titulo, mensagem,
                            id_solicitacao, chave_evento, data_criacao)
  VALUES (UUID(), v_capitao_solicitante, 'solicitacao_recusada', 'Solicitação encerrada',
          LEFT(CONCAT('Sua solicitação para jogar contra o time ', v_nome_anunciante, ' em ',
                      v_quando, ' foi recusada.'), 500),
          p_id_solicitacao, CONCAT('solicitacao_encerrada:', p_id_solicitacao), v_agora);
  COMMIT;
END$$

CREATE PROCEDURE proc_cancelar_partida(
  IN p_id_partida CHAR(36) CHARACTER SET ascii COLLATE ascii_bin,
  IN p_id_usuario CHAR(36) CHARACTER SET ascii COLLATE ascii_bin,
  IN p_motivo     VARCHAR(500))
BEGIN
  DECLARE v_status VARCHAR(20);
  DECLARE v_inicio DATETIME(3);
  DECLARE v_time_anunciante CHAR(36) CHARACTER SET ascii COLLATE ascii_bin;
  DECLARE v_time_adversario CHAR(36) CHARACTER SET ascii COLLATE ascii_bin;
  DECLARE v_capitao_anunciante CHAR(36) CHARACTER SET ascii COLLATE ascii_bin;
  DECLARE v_capitao_adversario CHAR(36) CHARACTER SET ascii COLLATE ascii_bin;
  DECLARE v_nome_anunciante VARCHAR(120);
  DECLARE v_nome_adversario VARCHAR(120);
  DECLARE v_time_cancelou CHAR(36) CHARACTER SET ascii COLLATE ascii_bin;
  DECLARE v_avisar CHAR(36) CHARACTER SET ascii COLLATE ascii_bin;
  DECLARE v_nome_cancelou VARCHAR(120);
  DECLARE v_nome_outro VARCHAR(120);
  DECLARE v_quando VARCHAR(20);
  DECLARE v_motivo VARCHAR(500);
  DECLARE v_agora DATETIME(3) DEFAULT UTC_TIMESTAMP(3);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  START TRANSACTION;
  SELECT p.status, p.data_hora_inicio, p.id_time_anunciante, p.id_time_adversario,
         ta.id_capitao, tv.id_capitao, ta.nome, tv.nome,
         fn_quando_texto(p.data_hora_inicio, p.sigla_estado)
    INTO v_status, v_inicio, v_time_anunciante, v_time_adversario,
         v_capitao_anunciante, v_capitao_adversario, v_nome_anunciante, v_nome_adversario,
         v_quando
    FROM partidas p
    JOIN times ta ON ta.id_time = p.id_time_anunciante
    JOIN times tv ON tv.id_time = p.id_time_adversario
   WHERE p.id_partida = p_id_partida
   FOR UPDATE OF p;

  IF v_status IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Partida não encontrada.';
  END IF;
  IF v_status <> 'confirmada' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Somente partidas confirmadas podem ser canceladas.';
  END IF;
  IF p_id_usuario = v_capitao_anunciante THEN
    SET v_time_cancelou = v_time_anunciante, v_avisar = v_capitao_adversario,
        v_nome_cancelou = v_nome_anunciante, v_nome_outro = v_nome_adversario;
  ELSEIF p_id_usuario = v_capitao_adversario THEN
    SET v_time_cancelou = v_time_adversario, v_avisar = v_capitao_anunciante,
        v_nome_cancelou = v_nome_adversario, v_nome_outro = v_nome_anunciante;
  ELSE
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Somente os capitães dos dois times podem cancelar a partida.';
  END IF;

  SET v_motivo = NULLIF(TRIM(p_motivo), '');
  UPDATE partidas
     SET status = 'cancelada', id_time_cancelou = v_time_cancelou,
         motivo_cancelamento = v_motivo, data_cancelamento = v_agora
   WHERE id_partida = p_id_partida;
  INSERT INTO notificacoes (id_notificacao, id_usuario_destinatario, tipo, titulo, mensagem,
                            id_partida, chave_evento, data_criacao, data_leitura)
  VALUES
    (UUID(), v_avisar, 'partida_cancelada', 'Jogo cancelado',
     LEFT(CONCAT('O jogo contra o time ', v_nome_cancelou, ', previsto para ', v_quando,
                 ', foi cancelado.', IF(v_motivo IS NULL, '', CONCAT(' Motivo: ', v_motivo))), 500),
     p_id_partida, CONCAT('partida_cancelada:', p_id_partida), v_agora, NULL),
    (UUID(), p_id_usuario, 'partida_cancelada', 'Jogo cancelado',
     LEFT(CONCAT('Você cancelou o jogo contra o time ', v_nome_outro, ', previsto para ', v_quando,
                 '. O outro capitão foi avisado.'), 500),
     p_id_partida, CONCAT('partida_cancelada:', p_id_partida), v_agora, v_agora);
  COMMIT;
END$$

CREATE PROCEDURE proc_excluir_anuncio(
  IN p_id_anuncio CHAR(36) CHARACTER SET ascii COLLATE ascii_bin,
  IN p_id_usuario CHAR(36) CHARACTER SET ascii COLLATE ascii_bin)
BEGIN
  DECLARE v_status VARCHAR(20);
  DECLARE v_exclusao DATETIME(3);
  DECLARE v_capitao CHAR(36) CHARACTER SET ascii COLLATE ascii_bin;
  DECLARE v_nome_time VARCHAR(120);
  DECLARE v_quando VARCHAR(20);
  DECLARE v_agora DATETIME(3) DEFAULT UTC_TIMESTAMP(3);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  START TRANSACTION;
  SELECT a.status, a.data_exclusao, t.id_capitao, t.nome,
         fn_quando_texto(a.data_hora_inicio, a.sigla_estado)
    INTO v_status, v_exclusao, v_capitao, v_nome_time, v_quando
    FROM anuncios_partidas a JOIN times t ON t.id_time = a.id_time
   WHERE a.id_anuncio = p_id_anuncio
   FOR UPDATE OF a;

  IF v_status IS NULL OR v_exclusao IS NOT NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Anúncio não encontrado.';
  END IF;
  IF NOT (p_id_usuario <=> v_capitao) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Somente o capitão do time pode excluir o anúncio.';
  END IF;
  IF v_status = 'encerrado' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Anúncio com partida confirmada não pode ser excluído.';
  END IF;

  INSERT INTO notificacoes (id_notificacao, id_usuario_destinatario, tipo, titulo, mensagem,
                            id_solicitacao, chave_evento, data_criacao)
  SELECT UUID(), t.id_capitao, 'solicitacao_encerrada', 'Solicitação encerrada',
         LEFT(CONCAT('Sua solicitação para jogar contra o time ', v_nome_time,
                     ' foi encerrada: o anúncio do jogo de ', v_quando, ' foi removido.'), 500),
         s.id_solicitacao, CONCAT('solicitacao_encerrada:', s.id_solicitacao), v_agora
    FROM solicitacoes_confronto s JOIN times t ON t.id_time = s.id_time_solicitante
   WHERE s.id_anuncio = p_id_anuncio AND s.status = 'pendente';
  UPDATE solicitacoes_confronto
     SET status = 'encerrada', data_resposta = v_agora, motivo_encerramento = 'Anúncio removido pelo time.'
   WHERE id_anuncio = p_id_anuncio AND status = 'pendente';
  UPDATE anuncios_partidas SET data_exclusao = v_agora WHERE id_anuncio = p_id_anuncio;
  COMMIT;
END$$

CREATE PROCEDURE proc_expirar_anuncios()
BEGIN
  DECLARE v_agora DATETIME(3) DEFAULT UTC_TIMESTAMP(3);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  START TRANSACTION;
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_anuncios_expirados (
    id_anuncio CHAR(36) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY
  ) ENGINE = InnoDB;
  DELETE FROM tmp_anuncios_expirados;

  INSERT INTO tmp_anuncios_expirados (id_anuncio)
  SELECT id_anuncio FROM anuncios_partidas
   WHERE status IN ('ativo', 'pausado') AND data_exclusao IS NULL AND data_hora_inicio <= v_agora
   FOR UPDATE;

  INSERT INTO notificacoes (id_notificacao, id_usuario_destinatario, tipo, titulo, mensagem,
                            id_solicitacao, chave_evento, data_criacao)
  SELECT UUID(), t.id_capitao, 'solicitacao_encerrada', 'Solicitação encerrada',
         LEFT(CONCAT('Sua solicitação para jogar contra o time ', ta.nome, ' foi encerrada: o jogo de ',
                     fn_quando_texto(a.data_hora_inicio, a.sigla_estado),
                     ' expirou sem partida confirmada.'), 500),
         s.id_solicitacao, CONCAT('solicitacao_encerrada:', s.id_solicitacao), v_agora
    FROM solicitacoes_confronto s
    JOIN tmp_anuncios_expirados x ON x.id_anuncio = s.id_anuncio
    JOIN anuncios_partidas a ON a.id_anuncio = s.id_anuncio
    JOIN times t ON t.id_time = s.id_time_solicitante
    JOIN times ta ON ta.id_time = a.id_time
   WHERE s.status = 'pendente';

  UPDATE solicitacoes_confronto s
    JOIN tmp_anuncios_expirados x ON x.id_anuncio = s.id_anuncio
     SET s.status = 'encerrada', s.data_resposta = v_agora, s.motivo_encerramento = 'Anúncio expirado.'
   WHERE s.status = 'pendente';

  UPDATE anuncios_partidas a
    JOIN tmp_anuncios_expirados x ON x.id_anuncio = a.id_anuncio
     SET a.status = 'expirado';

  SELECT COUNT(*) AS anuncios_expirados FROM tmp_anuncios_expirados;
  DROP TEMPORARY TABLE tmp_anuncios_expirados;
  COMMIT;
END$$

DELIMITER ;
