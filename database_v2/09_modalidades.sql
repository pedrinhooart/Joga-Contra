-- =============================================================================
-- Joga Contra — banco joga_contra_v2 — MySQL 8.4 LTS
-- 09_modalidades.sql (23/11/2026): modalidades do anúncio.
--
--   1 Society/Futebol Sintético   (antes "Futebol society/sintético")
--   2 Futsal                      (antes "Futebol de quadra", código 'quadra')
--   3 Futebol de Campo            (nova)
--   4 Futebol de Campo Reduzido   (nova; não é o mesmo que Society)
--
-- Segura e idempotente: só cadastro de referência. Nenhum anúncio, partida ou
-- time é alterado: os registros continuam apontando para o mesmo id (os antigos
-- de "Futebol de quadra" passam a aparecer como Futsal). Nada é convertido de
-- Society para Campo Reduzido.
-- =============================================================================

SET NAMES utf8mb4;

INSERT INTO modalidades (id_modalidade, codigo, nome, ordem) VALUES
  (1, 'society',        'Society/Futebol Sintético',  10),
  (2, 'futsal',         'Futsal',                     20),
  (3, 'campo',          'Futebol de Campo',           30),
  (4, 'campo_reduzido', 'Futebol de Campo Reduzido',  40)
AS novo
ON DUPLICATE KEY UPDATE codigo = novo.codigo, nome = novo.nome, ordem = novo.ordem;
