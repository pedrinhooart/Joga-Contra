-- Initial catalog values only. These are editable/admin-controlled reference data,
-- not immutable enum values. Do not seed accounts, teams, ads, matches or messages.
USE joga_contra;

INSERT INTO account_statuses (status_code, label_pt_br) VALUES
  ('pending', 'Pendente'), ('active', 'Ativa'), ('suspended', 'Suspensa'), ('deleted', 'Encerrada');

INSERT INTO team_roles (role_code, label_pt_br) VALUES
  ('owner', 'Responsável'), ('manager', 'Gestor'), ('member', 'Membro');

INSERT INTO brazilian_states (state_code, state_name) VALUES
  ('AC', 'Acre'), ('AL', 'Alagoas'), ('AP', 'Amapá'), ('AM', 'Amazonas'),
  ('BA', 'Bahia'), ('CE', 'Ceará'), ('DF', 'Distrito Federal'), ('ES', 'Espírito Santo'),
  ('GO', 'Goiás'), ('MA', 'Maranhão'), ('MT', 'Mato Grosso'), ('MS', 'Mato Grosso do Sul'),
  ('MG', 'Minas Gerais'), ('PA', 'Pará'), ('PB', 'Paraíba'), ('PR', 'Paraná'),
  ('PE', 'Pernambuco'), ('PI', 'Piauí'), ('RJ', 'Rio de Janeiro'), ('RN', 'Rio Grande do Norte'),
  ('RS', 'Rio Grande do Sul'), ('RO', 'Rondônia'), ('RR', 'Roraima'), ('SC', 'Santa Catarina'),
  ('SP', 'São Paulo'), ('SE', 'Sergipe'), ('TO', 'Tocantins');

INSERT INTO sports (code, label_pt_br, sort_order) VALUES
  ('football', 'Futebol', 10), ('futsal', 'Futsal', 20);

INSERT INTO team_categories (code, label_pt_br, sort_order) VALUES
  ('open', 'Livre', 10), ('u15', 'Sub-15', 20), ('u17', 'Sub-17', 30),
  ('u20', 'Sub-20', 40), ('veteran', 'Veterano', 50);

INSERT INTO skill_levels (code, label_pt_br, sort_order) VALUES
  ('recreational', 'Recreativo', 10), ('intermediate', 'Intermediário', 20), ('advanced', 'Avançado', 30);

INSERT INTO home_preferences (code, label_pt_br, sort_order) VALUES
  ('home', 'Jogo em casa', 10), ('away', 'Jogo fora', 20), ('indifferent', 'Indiferente', 30);

INSERT INTO listing_statuses (status_code, label_pt_br) VALUES
  ('active', 'Ativo'), ('paused', 'Pausado'), ('closed', 'Encerrado'), ('expired', 'Expirado');
INSERT INTO listing_status_transitions (from_status_code, to_status_code) VALUES
  ('active', 'paused'), ('active', 'closed'), ('active', 'expired'),
  ('paused', 'active'), ('paused', 'closed'), ('paused', 'expired');

INSERT INTO interest_statuses (status_code, label_pt_br) VALUES
  ('pending', 'Aguardando resposta'), ('accepted', 'Aceito'), ('declined', 'Recusado'), ('withdrawn', 'Retirado');
INSERT INTO interest_status_transitions (from_status_code, to_status_code) VALUES
  ('pending', 'accepted'), ('pending', 'declined'), ('pending', 'withdrawn');

INSERT INTO match_statuses (status_code, label_pt_br) VALUES
  ('proposed', 'Em negociação'), ('confirmed', 'Confirmado'), ('completed', 'Realizado'), ('cancelled', 'Cancelado');
INSERT INTO match_status_transitions (from_status_code, to_status_code) VALUES
  ('proposed', 'confirmed'), ('proposed', 'cancelled'), ('confirmed', 'completed'), ('confirmed', 'cancelled');

INSERT INTO message_types (type_code, label_pt_br) VALUES
  ('text', 'Texto'), ('image', 'Imagem'), ('location', 'Localização'), ('system', 'Evento do sistema');

INSERT INTO notification_types (type_code, label_pt_br) VALUES
  ('interest_received', 'Novo interesse'), ('interest_accepted', 'Interesse aceito'),
  ('message_received', 'Nova mensagem'), ('match_confirmed', 'Partida confirmada'),
  ('match_cancelled', 'Partida cancelada'), ('listing_expiring', 'Anúncio próximo de expirar');

INSERT INTO review_criteria (code, label_pt_br, sort_order) VALUES
  ('punctuality', 'Pontualidade', 10), ('organization', 'Organização', 20),
  ('respect', 'Respeito', 30), ('venue_facilities', 'Estrutura do local', 40);
