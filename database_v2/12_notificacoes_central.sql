-- =============================================================================
-- Joga Contra — banco joga_contra_v2 — MySQL 8.4 LTS
-- 12_notificacoes_central.sql (25/11/2026): central de notificações, fase 1.
--
-- A tabela notificacoes já guarda destinatário, tipo, título, mensagem, a
-- referência ao conteúdo (anúncio, solicitação ou partida), a leitura e a data.
-- Esta migração acrescenta:
--   chave_evento   identifica o evento de origem; com UNIQUE (destinatário,
--                  chave), o mesmo evento nunca gera duas notificações para a
--                  mesma pessoa, mesmo com a API repetindo a tentativa.
--                  NULL = sem chave (as já existentes e as dos procedimentos).
--   índice         (destinatário, data_criacao, id) para a lista paginada.
--   tipo 'aviso'   avisos gerais do Joga Contra (e a notificação de teste).
-- e recria o gatilho de imutabilidade para proteger também a chave.
--
-- Não apaga nem altera notificações: a coluna nova fica vazia nas antigas, e
-- a nova lista de tipos contém todos os anteriores. Os dois ALTER são atômicos.
-- Para bancos criados antes desta versão; 01 e 02 já trazem o resultado.
-- Execute uma vez (ADD COLUMN).
-- =============================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;

ALTER TABLE notificacoes
  ADD COLUMN chave_evento VARCHAR(150) CHARACTER SET ascii COLLATE ascii_bin NULL
    COMMENT 'Evento de origem (ex.: mensagem_recebida:<id>). Garante uma notificação por evento e destinatário.'
    AFTER id_partida,
  ADD CONSTRAINT un_notificacoes_evento UNIQUE (id_usuario_destinatario, chave_evento),
  ADD INDEX ind_notificacoes_lista (id_usuario_destinatario, data_criacao, id_notificacao);

ALTER TABLE notificacoes
  DROP CHECK vr_notificacoes_tipo,
  ADD CONSTRAINT vr_notificacoes_tipo CHECK (tipo IN (
    'solicitacao_recebida', 'mensagem_recebida', 'partida_confirmada', 'partida_cancelada',
    'solicitacao_encerrada', 'solicitacao_recusada', 'anuncio_expirando', 'avaliacao_pendente',
    'aviso'));

DROP TRIGGER IF EXISTS gat_notificacoes_antes_atualizar;

DELIMITER $$
CREATE TRIGGER gat_notificacoes_antes_atualizar
BEFORE UPDATE ON notificacoes FOR EACH ROW
BEGIN
  IF NOT (OLD.id_usuario_destinatario <=> NEW.id_usuario_destinatario) OR NOT (OLD.tipo <=> NEW.tipo)
     OR NOT (OLD.titulo <=> NEW.titulo) OR NOT (OLD.mensagem <=> NEW.mensagem)
     OR NOT (OLD.id_anuncio <=> NEW.id_anuncio) OR NOT (OLD.id_solicitacao <=> NEW.id_solicitacao)
     OR NOT (OLD.id_partida <=> NEW.id_partida) OR NOT (OLD.chave_evento <=> NEW.chave_evento)
     OR (OLD.data_leitura IS NOT NULL AND NOT (OLD.data_leitura <=> NEW.data_leitura)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Notificações são imutáveis; apenas a leitura pode ser registrada.';
  END IF;
END$$
DELIMITER ;
