-- =============================================================================
-- Joga Contra — banco joga_contra_v2 — MySQL 8.4 LTS
-- 03_dados_referencia.sql: SOMENTE cadastros de referência.
-- Não há usuários, times, anúncios, partidas ou mensagens fictícias.
--
-- Idempotente: pode ser executado mais de uma vez. Registros existentes são
-- atualizados pelo identificador (nome e ordem), nunca duplicados ou apagados.
-- Os identificadores são fixos para serem iguais em todos os ambientes.
-- Execute depois de 01_esquema.sql.
-- =============================================================================

USE joga_contra_v2;
SET NAMES utf8mb4;
SET time_zone = '+00:00';

INSERT INTO estados (sigla, nome) VALUES
  ('AC', 'Acre'), ('AL', 'Alagoas'), ('AP', 'Amapá'), ('AM', 'Amazonas'),
  ('BA', 'Bahia'), ('CE', 'Ceará'), ('DF', 'Distrito Federal'), ('ES', 'Espírito Santo'),
  ('GO', 'Goiás'), ('MA', 'Maranhão'), ('MT', 'Mato Grosso'), ('MS', 'Mato Grosso do Sul'),
  ('MG', 'Minas Gerais'), ('PA', 'Pará'), ('PB', 'Paraíba'), ('PR', 'Paraná'),
  ('PE', 'Pernambuco'), ('PI', 'Piauí'), ('RJ', 'Rio de Janeiro'), ('RN', 'Rio Grande do Norte'),
  ('RS', 'Rio Grande do Sul'), ('RO', 'Rondônia'), ('RR', 'Roraima'), ('SC', 'Santa Catarina'),
  ('SP', 'São Paulo'), ('SE', 'Sergipe'), ('TO', 'Tocantins')
AS novo
ON DUPLICATE KEY UPDATE nome = novo.nome;

INSERT INTO modalidades (id_modalidade, codigo, nome, ordem) VALUES
  (1, 'society', 'Futebol society/sintético', 10),
  (2, 'quadra',  'Futebol de quadra',         20)
AS novo
ON DUPLICATE KEY UPDATE nome = novo.nome, ordem = novo.ordem;

INSERT INTO categorias_etarias (id_categoria_etaria, codigo, nome, idade_maxima, ordem) VALUES
  (1, 'sub_15', 'Sub-15', 15,   10),
  (2, 'sub_17', 'Sub-17', 17,   20),
  (3, 'sub_19', 'Sub-19', 19,   30),
  (4, 'livre',  'Livre',  NULL, 40)
AS novo
ON DUPLICATE KEY UPDATE nome = novo.nome, idade_maxima = novo.idade_maxima, ordem = novo.ordem;

INSERT INTO niveis_tecnicos (id_nivel_tecnico, codigo, nome, ordem) VALUES
  (1, 'iniciante',     'Iniciante',     10),
  (2, 'intermediario', 'Intermediário', 20),
  (3, 'avancado',      'Avançado',      30)
AS novo
ON DUPLICATE KEY UPDATE nome = novo.nome, ordem = novo.ordem;

INSERT INTO mandos_campo (id_mando_campo, codigo, nome, ordem) VALUES
  (1, 'casa',        'Jogo em casa', 10),
  (2, 'fora',        'Jogo fora',    20),
  (3, 'indiferente', 'Indiferente',  30)
AS novo
ON DUPLICATE KEY UPDATE nome = novo.nome, ordem = novo.ordem;

INSERT INTO criterios_avaliacao (id_criterio, codigo, nome, ordem) VALUES
  (1, 'pontualidade',    'Pontualidade',       10),
  (2, 'organizacao',     'Organização',        20),
  (3, 'respeito',        'Respeito',           30),
  (4, 'estrutura_local', 'Estrutura do local', 40)
AS novo
ON DUPLICATE KEY UPDATE nome = novo.nome, ordem = novo.ordem;
