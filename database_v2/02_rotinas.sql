-- =============================================================================
-- Joga Contra — banco joga_contra_v2 — MySQL 8.4 LTS
-- 02_rotinas.sql: gatilhos (validação defensiva) e procedimentos (operações
-- transacionais de várias linhas).
--
-- Execute depois de 01_esquema.sql. Requer privilégio CREATE ROUTINE e TRIGGER.
-- Se o servidor usar log binário, pode ser necessário
-- SET GLOBAL log_bin_trust_function_creators = 1 (decisão do administrador).
--
-- Divisão de responsabilidades (detalhada no README):
--   * Restrições (CHECK, UNIQUE, FK) ............ invariantes de cada linha.
--   * Gatilhos ................................... validações que dependem de
--     outras tabelas e transições de status. Nunca alteram outras linhas.
--   * Procedimentos proc_* ....................... operações que mudam várias
--     linhas e precisam ser atômicas (confirmar, recusar, cancelar, excluir,
--     expirar). Cada procedimento abre e fecha a própria transação: a API deve
--     chamá-lo FORA de uma transação aberta (em modo autocommit).
--   * API ........................................ autenticação, autorização
--     por sessão, hash de senha, cadastro de usuário + time numa transação,
--     montagem do JSON, rotinas agendadas.
--
-- Mensagens de erro: SQLSTATE '45000' com texto em português (até 128
-- caracteres). A API converte ER_SIGNAL_EXCEPTION (1644) em HTTP 409.
-- =============================================================================

USE joga_contra_v2;

DELIMITER $$

-- -----------------------------------------------------------------------------
-- Gatilhos: times
-- -----------------------------------------------------------------------------

CREATE TRIGGER gat_times_antes_inserir
BEFORE INSERT ON times FOR EACH ROW
BEGIN
  IF NOT EXISTS (SELECT 1 FROM usuarios
                 WHERE id_usuario = NEW.id_capitao AND status_conta = 'ativa') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O capitão precisa ter uma conta ativa.';
  END IF;
  IF NEW.data_arquivamento IS NOT NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Um time novo não pode nascer arquivado.';
  END IF;
END$$

CREATE TRIGGER gat_times_antes_atualizar
BEFORE UPDATE ON times FOR EACH ROW
BEGIN
  IF NEW.id_capitao <> OLD.id_capitao AND NOT EXISTS (
       SELECT 1 FROM usuarios WHERE id_usuario = NEW.id_capitao AND status_conta = 'ativa') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O novo capitão precisa ter uma conta ativa.';
  END IF;
  IF OLD.data_arquivamento IS NOT NULL AND NEW.data_arquivamento IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Um time arquivado não pode ser reativado por atualização direta.';
  END IF;
END$$

-- -----------------------------------------------------------------------------
-- Gatilhos: anúncios
-- -----------------------------------------------------------------------------

CREATE TRIGGER gat_anuncios_partidas_antes_inserir
BEFORE INSERT ON anuncios_partidas FOR EACH ROW
BEGIN
  IF NEW.status <> 'ativo' OR NEW.data_exclusao IS NOT NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Um anúncio novo deve começar ativo.';
  END IF;
  IF NEW.data_hora_inicio <= UTC_TIMESTAMP(3) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A data e o horário da partida devem ser futuros.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM times t JOIN usuarios u ON u.id_usuario = t.id_capitao
                 WHERE t.id_time = NEW.id_time AND t.data_arquivamento IS NULL
                   AND u.status_conta = 'ativa') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Somente times ativos com capitão ativo podem anunciar.';
  END IF;
END$$

CREATE TRIGGER gat_anuncios_partidas_antes_atualizar
BEFORE UPDATE ON anuncios_partidas FOR EACH ROW
BEGIN
  IF NEW.id_time <> OLD.id_time THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O time dono do anúncio não pode ser alterado.';
  END IF;
  IF OLD.data_exclusao IS NOT NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Anúncio excluído não pode ser alterado.';
  END IF;

  -- Transições: ativo <-> pausado; ativo|pausado -> encerrado|expirado.
  IF NEW.status <> OLD.status AND NOT (
       (OLD.status = 'ativo'   AND NEW.status IN ('pausado', 'encerrado', 'expirado')) OR
       (OLD.status = 'pausado' AND NEW.status IN ('ativo', 'encerrado', 'expirado'))) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Transição de status do anúncio não permitida.';
  END IF;
  -- "encerrado" (indisponível) somente com a partida já criada.
  IF NEW.status = 'encerrado' AND OLD.status <> 'encerrado'
     AND NOT EXISTS (SELECT 1 FROM partidas WHERE id_anuncio = NEW.id_anuncio) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O anúncio só é encerrado pela confirmação de uma partida.';
  END IF;
  IF NEW.status = 'encerrado' AND NEW.data_exclusao IS NOT NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Anúncio com partida confirmada não pode ser excluído.';
  END IF;

  -- Conteúdo congelado depois de encerrado/expirado.
  IF OLD.status IN ('encerrado', 'expirado') AND (
       NOT (OLD.data_hora_inicio <=> NEW.data_hora_inicio) OR NOT (OLD.nome_local <=> NEW.nome_local)
       OR NOT (OLD.endereco <=> NEW.endereco) OR NOT (OLD.cidade <=> NEW.cidade)
       OR NOT (OLD.sigla_estado <=> NEW.sigla_estado) OR NOT (OLD.id_modalidade <=> NEW.id_modalidade)
       OR NOT (OLD.id_categoria_etaria <=> NEW.id_categoria_etaria)
       OR NOT (OLD.id_nivel_tecnico <=> NEW.id_nivel_tecnico)
       OR NOT (OLD.quantidade_jogadores <=> NEW.quantidade_jogadores)
       OR NOT (OLD.valor_aluguel_por_time <=> NEW.valor_aluguel_por_time)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Anúncio encerrado ou expirado não pode ser editado.';
  END IF;

  IF OLD.status IN ('ativo', 'pausado') AND NEW.status IN ('ativo', 'pausado')
     AND NOT (OLD.data_hora_inicio <=> NEW.data_hora_inicio)
     AND NEW.data_hora_inicio <= UTC_TIMESTAMP(3) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A data e o horário da partida devem ser futuros.';
  END IF;
END$$

-- -----------------------------------------------------------------------------
-- Gatilhos: solicitações de confronto
-- -----------------------------------------------------------------------------

CREATE TRIGGER gat_solicitacoes_confronto_antes_inserir
BEFORE INSERT ON solicitacoes_confronto FOR EACH ROW
BEGIN
  DECLARE v_time CHAR(36) CHARACTER SET ascii COLLATE ascii_bin;
  DECLARE v_status VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin;
  DECLARE v_inicio DATETIME(3);
  DECLARE v_exclusao DATETIME(3);

  -- FOR SHARE: espera uma confirmação em andamento no mesmo anúncio terminar e
  -- lê o status já confirmado (evita nova solicitação em anúncio recém-encerrado).
  SELECT id_time, status, data_hora_inicio, data_exclusao
    INTO v_time, v_status, v_inicio, v_exclusao
    FROM anuncios_partidas WHERE id_anuncio = NEW.id_anuncio
    FOR SHARE;

  IF v_time IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Anúncio não encontrado.';
  END IF;
  IF NEW.id_time_anunciante IS NULL THEN
    SET NEW.id_time_anunciante = v_time;
  ELSEIF NEW.id_time_anunciante <> v_time THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O time anunciante não corresponde ao anúncio.';
  END IF;
  IF v_status <> 'ativo' OR v_exclusao IS NOT NULL OR v_inicio <= UTC_TIMESTAMP(3) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Este anúncio não está disponível para novas solicitações.';
  END IF;
  IF NEW.id_time_solicitante = v_time THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Um time não pode solicitar o próprio anúncio.';
  END IF;
  IF NEW.status <> 'pendente' OR NEW.data_resposta IS NOT NULL
     OR NEW.data_confirmacao_anunciante IS NOT NULL OR NEW.data_confirmacao_solicitante IS NOT NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Uma solicitação nova deve começar pendente e sem confirmações.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM times t JOIN usuarios u ON u.id_usuario = t.id_capitao
                 WHERE t.id_time = NEW.id_time_solicitante AND t.data_arquivamento IS NULL
                   AND u.status_conta = 'ativa') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Somente times ativos com capitão ativo podem solicitar confronto.';
  END IF;
END$$

CREATE TRIGGER gat_solicitacoes_confronto_antes_atualizar
BEFORE UPDATE ON solicitacoes_confronto FOR EACH ROW
BEGIN
  IF NEW.id_anuncio <> OLD.id_anuncio OR NEW.id_time_anunciante <> OLD.id_time_anunciante
     OR NEW.id_time_solicitante <> OLD.id_time_solicitante THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Anúncio e times de uma solicitação não podem ser alterados.';
  END IF;
  -- Somente pendente muda de status; os demais são finais.
  IF NEW.status <> OLD.status AND OLD.status <> 'pendente' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A solicitação já foi finalizada.';
  END IF;
  -- Confirmações só são registradas enquanto pendente e nunca são desfeitas.
  IF (OLD.data_confirmacao_anunciante IS NOT NULL
        AND NOT (OLD.data_confirmacao_anunciante <=> NEW.data_confirmacao_anunciante))
     OR (OLD.data_confirmacao_solicitante IS NOT NULL
        AND NOT (OLD.data_confirmacao_solicitante <=> NEW.data_confirmacao_solicitante)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Uma confirmação registrada não pode ser desfeita.';
  END IF;
  IF OLD.status <> 'pendente' AND (
       NOT (OLD.data_confirmacao_anunciante <=> NEW.data_confirmacao_anunciante)
       OR NOT (OLD.data_confirmacao_solicitante <=> NEW.data_confirmacao_solicitante)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A solicitação já foi finalizada.';
  END IF;
  -- Confirmar exige anúncio ainda ativo e futuro.
  IF NEW.status = 'confirmada' AND OLD.status = 'pendente' AND NOT EXISTS (
       SELECT 1 FROM anuncios_partidas
       WHERE id_anuncio = NEW.id_anuncio AND status = 'ativo' AND data_exclusao IS NULL
         AND data_hora_inicio > UTC_TIMESTAMP(3)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'O anúncio não está mais disponível para confirmação.';
  END IF;
END$$

-- -----------------------------------------------------------------------------
-- Gatilhos: mensagens
-- -----------------------------------------------------------------------------

CREATE TRIGGER gat_mensagens_antes_inserir
BEFORE INSERT ON mensagens FOR EACH ROW
-- O chat só existe depois que o time anunciante aceita a solicitação.
BEGIN
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

CREATE TRIGGER gat_mensagens_antes_atualizar
BEFORE UPDATE ON mensagens FOR EACH ROW
BEGIN
  IF NOT (OLD.texto <=> NEW.texto) OR NOT (OLD.id_solicitacao <=> NEW.id_solicitacao)
     OR NOT (OLD.id_time_remetente <=> NEW.id_time_remetente)
     OR NOT (OLD.id_usuario_remetente <=> NEW.id_usuario_remetente)
     OR NOT (OLD.data_envio <=> NEW.data_envio)
     OR (OLD.data_leitura IS NOT NULL AND NOT (OLD.data_leitura <=> NEW.data_leitura)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Mensagens são imutáveis; apenas a leitura pode ser registrada.';
  END IF;
END$$

-- -----------------------------------------------------------------------------
-- Gatilhos: partidas
-- -----------------------------------------------------------------------------

CREATE TRIGGER gat_partidas_antes_inserir
BEFORE INSERT ON partidas FOR EACH ROW
BEGIN
  IF NEW.status <> 'confirmada' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Uma partida nova deve começar confirmada.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM solicitacoes_confronto
                 WHERE id_solicitacao = NEW.id_solicitacao AND status = 'confirmada') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A partida exige uma solicitação confirmada pelas duas equipes.';
  END IF;
END$$

CREATE TRIGGER gat_partidas_antes_atualizar
BEFORE UPDATE ON partidas FOR EACH ROW
BEGIN
  IF NEW.status <> OLD.status AND NOT (OLD.status = 'confirmada' AND NEW.status IN ('realizada', 'cancelada')) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Transição de status da partida não permitida.';
  END IF;
  -- Dados combinados são imutáveis.
  IF NOT (OLD.id_solicitacao <=> NEW.id_solicitacao) OR NOT (OLD.id_anuncio <=> NEW.id_anuncio)
     OR NOT (OLD.id_time_anunciante <=> NEW.id_time_anunciante)
     OR NOT (OLD.id_time_adversario <=> NEW.id_time_adversario)
     OR NOT (OLD.id_modalidade <=> NEW.id_modalidade)
     OR NOT (OLD.quantidade_jogadores <=> NEW.quantidade_jogadores)
     OR NOT (OLD.data_hora_inicio <=> NEW.data_hora_inicio)
     OR NOT (OLD.nome_local <=> NEW.nome_local) OR NOT (OLD.endereco <=> NEW.endereco)
     OR NOT (OLD.cidade <=> NEW.cidade) OR NOT (OLD.sigla_estado <=> NEW.sigla_estado)
     OR NOT (OLD.latitude <=> NEW.latitude) OR NOT (OLD.longitude <=> NEW.longitude)
     OR NOT (OLD.valor_aluguel_por_time <=> NEW.valor_aluguel_por_time) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Os dados combinados da partida não podem ser alterados.';
  END IF;
  IF OLD.status = 'cancelada' AND (
       NOT (OLD.gols_anunciante <=> NEW.gols_anunciante) OR NOT (OLD.gols_adversario <=> NEW.gols_adversario)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Partida cancelada não recebe placar.';
  END IF;
END$$

-- -----------------------------------------------------------------------------
-- Gatilhos: avaliações e notas (imutáveis)
-- -----------------------------------------------------------------------------

CREATE TRIGGER gat_avaliacoes_antes_inserir
BEFORE INSERT ON avaliacoes FOR EACH ROW
BEGIN
  IF NOT EXISTS (
       SELECT 1 FROM partidas p
       WHERE p.id_partida = NEW.id_partida AND p.status = 'realizada'
         AND ((p.id_time_anunciante = NEW.id_time_avaliador AND p.id_time_adversario = NEW.id_time_avaliado)
           OR (p.id_time_adversario = NEW.id_time_avaliador AND p.id_time_anunciante = NEW.id_time_avaliado))) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A avaliação exige uma partida realizada entre os dois times.';
  END IF;
END$$

CREATE TRIGGER gat_avaliacoes_antes_atualizar
BEFORE UPDATE ON avaliacoes FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Avaliações não podem ser alteradas.';
END$$

CREATE TRIGGER gat_notas_avaliacao_antes_inserir
BEFORE INSERT ON notas_avaliacao FOR EACH ROW
BEGIN
  IF NOT EXISTS (SELECT 1 FROM criterios_avaliacao WHERE id_criterio = NEW.id_criterio AND ativo) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Critério de avaliação inativo ou inexistente.';
  END IF;
END$$

CREATE TRIGGER gat_notas_avaliacao_antes_atualizar
BEFORE UPDATE ON notas_avaliacao FOR EACH ROW
BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Notas de avaliação não podem ser alteradas.';
END$$

-- -----------------------------------------------------------------------------
-- Gatilhos: notificações
-- -----------------------------------------------------------------------------

CREATE TRIGGER gat_notificacoes_antes_atualizar
BEFORE UPDATE ON notificacoes FOR EACH ROW
BEGIN
  IF NOT (OLD.id_usuario_destinatario <=> NEW.id_usuario_destinatario) OR NOT (OLD.tipo <=> NEW.tipo)
     OR NOT (OLD.titulo <=> NEW.titulo) OR NOT (OLD.mensagem <=> NEW.mensagem)
     OR NOT (OLD.id_anuncio <=> NEW.id_anuncio) OR NOT (OLD.id_solicitacao <=> NEW.id_solicitacao)
     OR NOT (OLD.id_partida <=> NEW.id_partida)
     OR (OLD.data_leitura IS NOT NULL AND NOT (OLD.data_leitura <=> NEW.data_leitura)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Notificações são imutáveis; apenas a leitura pode ser registrada.';
  END IF;
END$$

-- =============================================================================
-- Procedimentos transacionais
-- =============================================================================

-- Confirma a concordância de um dos times. Quando os dois lados confirmam, na
-- mesma transação: confirma a solicitação, cria a partida (cópia dos dados do
-- anúncio), deixa o anúncio indisponível (encerrado), encerra as demais
-- solicitações pendentes e notifica os capitães afetados e os envolvidos.
--
-- Concorrência: o anúncio é bloqueado com FOR UPDATE antes de qualquer
-- verificação, serializando todas as confirmações do mesmo anúncio. Os índices
-- únicos un_solicitacoes_confronto_confirmada e un_partidas_anuncio impedem uma
-- segunda confirmação mesmo que alguém altere as tabelas sem este procedimento.
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

  START TRANSACTION;

  -- id_anuncio é imutável: pode ser lido sem bloqueio.
  SELECT id_anuncio INTO v_id_anuncio
    FROM solicitacoes_confronto WHERE id_solicitacao = p_id_solicitacao;
  IF v_id_anuncio IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solicitação não encontrada.';
  END IF;

  -- 1º bloqueio: anúncio (ordem fixa anúncio -> solicitações evita impasses).
  SELECT status, data_hora_inicio, data_exclusao
    INTO v_status_anuncio, v_inicio, v_exclusao
    FROM anuncios_partidas WHERE id_anuncio = v_id_anuncio
    FOR UPDATE;

  -- 2º bloqueio: a solicitação, relida após obter o bloqueio do anúncio.
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

-- Recusa pelo capitão anunciante. Notifica o capitão solicitante.
CREATE PROCEDURE proc_recusar_solicitacao(
  IN p_id_solicitacao CHAR(36) CHARACTER SET ascii COLLATE ascii_bin,
  IN p_id_usuario     CHAR(36) CHARACTER SET ascii COLLATE ascii_bin)
BEGIN
  DECLARE v_status VARCHAR(20);
  DECLARE v_capitao_anunciante CHAR(36) CHARACTER SET ascii COLLATE ascii_bin;
  DECLARE v_capitao_solicitante CHAR(36) CHARACTER SET ascii COLLATE ascii_bin;
  DECLARE v_nome_anunciante VARCHAR(120);
  DECLARE v_agora DATETIME(3) DEFAULT UTC_TIMESTAMP(3);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  START TRANSACTION;
  SELECT s.status, ta.id_capitao, ts.id_capitao, ta.nome
    INTO v_status, v_capitao_anunciante, v_capitao_solicitante, v_nome_anunciante
    FROM solicitacoes_confronto s
    JOIN times ta ON ta.id_time = s.id_time_anunciante
    JOIN times ts ON ts.id_time = s.id_time_solicitante
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
                            id_solicitacao, data_criacao)
  VALUES (UUID(), v_capitao_solicitante, 'solicitacao_recusada', 'Não foi dessa vez.',
          LEFT(CONCAT(v_nome_anunciante, ' recusou sua solicitação de confronto.'), 500),
          p_id_solicitacao, v_agora);
  COMMIT;
END$$

-- Desistência pelo capitão solicitante.
CREATE PROCEDURE proc_cancelar_solicitacao(
  IN p_id_solicitacao CHAR(36) CHARACTER SET ascii COLLATE ascii_bin,
  IN p_id_usuario     CHAR(36) CHARACTER SET ascii COLLATE ascii_bin)
BEGIN
  DECLARE v_status VARCHAR(20);
  DECLARE v_capitao_solicitante CHAR(36) CHARACTER SET ascii COLLATE ascii_bin;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  START TRANSACTION;
  SELECT s.status, t.id_capitao INTO v_status, v_capitao_solicitante
    FROM solicitacoes_confronto s JOIN times t ON t.id_time = s.id_time_solicitante
   WHERE s.id_solicitacao = p_id_solicitacao
   FOR UPDATE OF s;

  IF v_status IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Solicitação não encontrada.';
  END IF;
  IF NOT (p_id_usuario <=> v_capitao_solicitante) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Somente o capitão do time solicitante pode cancelar.';
  END IF;
  IF v_status <> 'pendente' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Esta solicitação não está mais em aberto.';
  END IF;

  UPDATE solicitacoes_confronto SET status = 'cancelada', data_resposta = UTC_TIMESTAMP(3)
   WHERE id_solicitacao = p_id_solicitacao;
  COMMIT;
END$$

-- Cancelamento de partida confirmada por um dos capitães. O anúncio permanece
-- encerrado (decisão aprovada). Notifica o capitão do outro time.
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
  DECLARE v_agora DATETIME(3) DEFAULT UTC_TIMESTAMP(3);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  START TRANSACTION;
  SELECT p.status, p.data_hora_inicio, p.id_time_anunciante, p.id_time_adversario,
         ta.id_capitao, tv.id_capitao, ta.nome, tv.nome
    INTO v_status, v_inicio, v_time_anunciante, v_time_adversario,
         v_capitao_anunciante, v_capitao_adversario, v_nome_anunciante, v_nome_adversario
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
    SET v_time_cancelou = v_time_anunciante, v_avisar = v_capitao_adversario, v_nome_cancelou = v_nome_anunciante;
  ELSEIF p_id_usuario = v_capitao_adversario THEN
    SET v_time_cancelou = v_time_adversario, v_avisar = v_capitao_anunciante, v_nome_cancelou = v_nome_adversario;
  ELSE
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Somente os capitães dos dois times podem cancelar a partida.';
  END IF;

  UPDATE partidas
     SET status = 'cancelada', id_time_cancelou = v_time_cancelou,
         motivo_cancelamento = NULLIF(TRIM(p_motivo), ''), data_cancelamento = v_agora
   WHERE id_partida = p_id_partida;
  INSERT INTO notificacoes (id_notificacao, id_usuario_destinatario, tipo, titulo, mensagem,
                            id_partida, data_criacao)
  VALUES (UUID(), v_avisar, 'partida_cancelada', 'Partida cancelada.',
          LEFT(CONCAT(v_nome_cancelou, ' cancelou a partida.'), 500), p_id_partida, v_agora);
  COMMIT;
END$$

-- Exclusão lógica de anúncio pelo capitão dono. Solicitações pendentes são
-- encerradas e os capitães solicitantes notificados.
CREATE PROCEDURE proc_excluir_anuncio(
  IN p_id_anuncio CHAR(36) CHARACTER SET ascii COLLATE ascii_bin,
  IN p_id_usuario CHAR(36) CHARACTER SET ascii COLLATE ascii_bin)
BEGIN
  DECLARE v_status VARCHAR(20);
  DECLARE v_exclusao DATETIME(3);
  DECLARE v_capitao CHAR(36) CHARACTER SET ascii COLLATE ascii_bin;
  DECLARE v_nome_time VARCHAR(120);
  DECLARE v_agora DATETIME(3) DEFAULT UTC_TIMESTAMP(3);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  START TRANSACTION;
  SELECT a.status, a.data_exclusao, t.id_capitao, t.nome
    INTO v_status, v_exclusao, v_capitao, v_nome_time
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
                            id_solicitacao, data_criacao)
  SELECT UUID(), t.id_capitao, 'solicitacao_encerrada', 'Anúncio removido.',
         LEFT(CONCAT(v_nome_time, ' removeu o anúncio. Sua solicitação foi encerrada.'), 500),
         s.id_solicitacao, v_agora
    FROM solicitacoes_confronto s JOIN times t ON t.id_time = s.id_time_solicitante
   WHERE s.id_anuncio = p_id_anuncio AND s.status = 'pendente';
  UPDATE solicitacoes_confronto
     SET status = 'encerrada', data_resposta = v_agora, motivo_encerramento = 'Anúncio removido pelo time.'
   WHERE id_anuncio = p_id_anuncio AND status = 'pendente';
  UPDATE anuncios_partidas SET data_exclusao = v_agora WHERE id_anuncio = p_id_anuncio;
  COMMIT;
END$$

-- Rotina agendada: anúncios ativos/pausados com data vencida passam a expirado
-- e suas solicitações pendentes são encerradas (com notificação).
-- Retorna a quantidade de anúncios expirados.
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
                            id_solicitacao, data_criacao)
  SELECT UUID(), t.id_capitao, 'solicitacao_encerrada', 'Esse jogo não aconteceu.',
         'O anúncio expirou sem partida confirmada. Sua solicitação foi encerrada.',
         s.id_solicitacao, v_agora
    FROM solicitacoes_confronto s
    JOIN tmp_anuncios_expirados x ON x.id_anuncio = s.id_anuncio
    JOIN times t ON t.id_time = s.id_time_solicitante
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

-- Rotina agendada: partidas confirmadas cujo início passou há p_horas viram
-- realizadas; os dois capitães recebem o convite para avaliar.
-- Retorna a quantidade de partidas atualizadas.
CREATE PROCEDURE proc_marcar_partidas_realizadas(IN p_horas_apos_inicio SMALLINT UNSIGNED)
BEGIN
  DECLARE v_agora DATETIME(3) DEFAULT UTC_TIMESTAMP(3);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;

  START TRANSACTION;
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_partidas_realizadas (
    id_partida CHAR(36) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY
  ) ENGINE = InnoDB;
  DELETE FROM tmp_partidas_realizadas;

  INSERT INTO tmp_partidas_realizadas (id_partida)
  SELECT id_partida FROM partidas
   WHERE status = 'confirmada'
     AND data_hora_inicio <= v_agora - INTERVAL COALESCE(p_horas_apos_inicio, 3) HOUR
   FOR UPDATE;

  UPDATE partidas p JOIN tmp_partidas_realizadas x ON x.id_partida = p.id_partida
     SET p.status = 'realizada', p.data_realizacao = v_agora;

  INSERT INTO notificacoes (id_notificacao, id_usuario_destinatario, tipo, titulo, mensagem,
                            id_partida, data_criacao)
  SELECT UUID(), t.id_capitao, 'avaliacao_pendente', 'Como foi o jogo?',
         'Avalie o adversário e ajude a comunidade a encontrar bons jogos.', p.id_partida, v_agora
    FROM tmp_partidas_realizadas x
    JOIN partidas p ON p.id_partida = x.id_partida
    JOIN times t ON t.id_time IN (p.id_time_anunciante, p.id_time_adversario);

  SELECT COUNT(*) AS partidas_realizadas FROM tmp_partidas_realizadas;
  DROP TEMPORARY TABLE tmp_partidas_realizadas;
  COMMIT;
END$$

DELIMITER ;

-- -----------------------------------------------------------------------------
-- Evento opcional (DESATIVADO). A recomendação é a API agendar as rotinas.
-- Para usar o agendador do MySQL: SET GLOBAL event_scheduler = ON; e então
-- remova os comentários abaixo.
-- -----------------------------------------------------------------------------
-- DELIMITER $$
-- CREATE EVENT evento_rotinas_horarias
--   ON SCHEDULE EVERY 1 HOUR
--   DO BEGIN
--     CALL proc_expirar_anuncios();
--     CALL proc_marcar_partidas_realizadas(3);
--   END$$
-- DELIMITER ;
