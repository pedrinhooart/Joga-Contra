-- =============================================================================
-- Joga Contra — banco joga_contra_v2 — MySQL 8.4 LTS
-- 10_mensagens_entrega.sql (23/11/2026): estados do chat como no WhatsApp.
--
--   enviada      data_envio preenchida (já existia)
--   entregue     data_entrega: o app do destinatário recebeu a mensagem (nova)
--   visualizada  data_leitura: o destinatário abriu a conversa (já existia)
--
-- Não apaga nem altera mensagens: a coluna nova fica vazia nas antigas (as já
-- lidas continuam aparecendo como visualizadas). Para bancos criados antes desta
-- versão; 01 e 02 já trazem o resultado. Execute uma vez (ADD COLUMN).
-- =============================================================================

ALTER TABLE mensagens
  ADD COLUMN data_entrega DATETIME(3) NULL COMMENT 'Recebida pelo app do capitão do outro time.'
    AFTER data_envio,
  ADD CONSTRAINT vr_mensagens_entrega CHECK (data_entrega IS NULL OR data_entrega >= data_envio);

-- Gatilho recriado: entrega e leitura são registradas uma única vez.
DROP TRIGGER IF EXISTS gat_mensagens_antes_atualizar;

DELIMITER $$
CREATE TRIGGER gat_mensagens_antes_atualizar
BEFORE UPDATE ON mensagens FOR EACH ROW
BEGIN
  IF NOT (OLD.texto <=> NEW.texto) OR NOT (OLD.id_solicitacao <=> NEW.id_solicitacao)
     OR NOT (OLD.id_time_remetente <=> NEW.id_time_remetente)
     OR NOT (OLD.id_usuario_remetente <=> NEW.id_usuario_remetente)
     OR NOT (OLD.data_envio <=> NEW.data_envio)
     OR (OLD.data_entrega IS NOT NULL AND NOT (OLD.data_entrega <=> NEW.data_entrega))
     OR (OLD.data_leitura IS NOT NULL AND NOT (OLD.data_leitura <=> NEW.data_leitura)) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Mensagens são imutáveis; apenas a entrega e a leitura podem ser registradas.';
  END IF;
END$$
DELIMITER ;
