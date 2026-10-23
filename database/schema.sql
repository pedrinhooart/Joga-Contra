-- Joga Contra relational schema for MySQL 8.0.16+ (CHECK constraints enforced).
-- Run against an empty database. All timestamps ending in *_utc are UTC.
-- API/backend connections should execute: SET time_zone = '+00:00';
CREATE DATABASE IF NOT EXISTS joga_contra
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE joga_contra;

CREATE TABLE account_statuses (
  status_code VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
  label_pt_br VARCHAR(40) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE team_roles (
  role_code VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
  label_pt_br VARCHAR(40) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE brazilian_states (
  state_code CHAR(2) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
  state_name VARCHAR(40) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE sports (
  sport_id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL UNIQUE,
  label_pt_br VARCHAR(60) NOT NULL,
  sort_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

CREATE TABLE team_categories (
  category_id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL UNIQUE,
  label_pt_br VARCHAR(60) NOT NULL,
  sort_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

CREATE TABLE skill_levels (
  skill_level_id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL UNIQUE,
  label_pt_br VARCHAR(60) NOT NULL,
  sort_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

CREATE TABLE home_preferences (
  home_preference_id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL UNIQUE,
  label_pt_br VARCHAR(60) NOT NULL,
  sort_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

CREATE TABLE listing_statuses (
  status_code VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
  label_pt_br VARCHAR(40) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE listing_status_transitions (
  from_status_code VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  to_status_code VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  PRIMARY KEY (from_status_code, to_status_code),
  CONSTRAINT fk_listing_transition_from FOREIGN KEY (from_status_code) REFERENCES listing_statuses(status_code),
  CONSTRAINT fk_listing_transition_to FOREIGN KEY (to_status_code) REFERENCES listing_statuses(status_code),
  CONSTRAINT chk_listing_transition_distinct CHECK (from_status_code <> to_status_code)
) ENGINE=InnoDB;

CREATE TABLE interest_statuses (
  status_code VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
  label_pt_br VARCHAR(40) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE interest_status_transitions (
  from_status_code VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  to_status_code VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  PRIMARY KEY (from_status_code, to_status_code),
  CONSTRAINT fk_interest_transition_from FOREIGN KEY (from_status_code) REFERENCES interest_statuses(status_code),
  CONSTRAINT fk_interest_transition_to FOREIGN KEY (to_status_code) REFERENCES interest_statuses(status_code),
  CONSTRAINT chk_interest_transition_distinct CHECK (from_status_code <> to_status_code)
) ENGINE=InnoDB;

CREATE TABLE match_statuses (
  status_code VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
  label_pt_br VARCHAR(40) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE match_status_transitions (
  from_status_code VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  to_status_code VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  PRIMARY KEY (from_status_code, to_status_code),
  CONSTRAINT fk_match_transition_from FOREIGN KEY (from_status_code) REFERENCES match_statuses(status_code),
  CONSTRAINT fk_match_transition_to FOREIGN KEY (to_status_code) REFERENCES match_statuses(status_code),
  CONSTRAINT chk_match_transition_distinct CHECK (from_status_code <> to_status_code)
) ENGINE=InnoDB;

CREATE TABLE message_types (
  type_code VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
  label_pt_br VARCHAR(40) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE notification_types (
  type_code VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY,
  label_pt_br VARCHAR(80) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE review_criteria (
  criterion_id SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NOT NULL UNIQUE,
  label_pt_br VARCHAR(80) NOT NULL,
  sort_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

-- UUID v4 values are generated by the backend and serialized as canonical strings.
-- Password hashes, if used, must be produced by a current password-hashing algorithm
-- (e.g. Argon2id); never place a password or reusable token in this table.
CREATE TABLE users (
  user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
  email VARCHAR(254) NOT NULL,
  display_name VARCHAR(120) NOT NULL,
  phone_e164 VARCHAR(20) NULL,
  password_hash VARCHAR(255) NULL,
  account_status_code VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'pending',
  email_verified_at_utc DATETIME(6) NULL,
  phone_verified_at_utc DATETIME(6) NULL,
  created_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at_utc DATETIME(6) NULL,
  CONSTRAINT uq_users_email UNIQUE (email),
  CONSTRAINT fk_users_account_status FOREIGN KEY (account_status_code) REFERENCES account_statuses(status_code),
  CONSTRAINT chk_users_email_nonempty CHECK (CHAR_LENGTH(TRIM(email)) > 3),
  CONSTRAINT chk_users_name_nonempty CHECK (CHAR_LENGTH(TRIM(display_name)) > 0),
  CONSTRAINT chk_users_password_hash CHECK (password_hash IS NULL OR CHAR_LENGTH(password_hash) >= 20)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Optional identities for an external auth provider. provider_subject is provider-issued,
-- unique only within provider_code; provider tokens/secrets are never stored here.
CREATE TABLE user_auth_identities (
  identity_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
  user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  provider_code VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  provider_subject VARCHAR(255) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  created_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_auth_provider_subject UNIQUE (provider_code, provider_subject),
  CONSTRAINT fk_auth_identity_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Optional opaque refresh-session registry. Store only a cryptographic hash of
-- each high-entropy refresh token; access tokens are short-lived and not stored.
CREATE TABLE user_sessions (
  session_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
  user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  refresh_token_hash BINARY(32) NOT NULL,
  device_label VARCHAR(100) NULL,
  created_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  last_used_at_utc DATETIME(6) NULL,
  expires_at_utc DATETIME(6) NOT NULL,
  revoked_at_utc DATETIME(6) NULL,
  CONSTRAINT uq_user_session_refresh_hash UNIQUE (refresh_token_hash),
  CONSTRAINT fk_user_session_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE RESTRICT,
  CONSTRAINT chk_user_session_expiry CHECK (expires_at_utc > created_at_utc),
  KEY ix_user_sessions_user_active (user_id, revoked_at_utc, expires_at_utc)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE media_assets (
  asset_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
  owner_user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  object_key VARCHAR(512) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  media_type VARCHAR(100) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  byte_size BIGINT UNSIGNED NOT NULL,
  sha256 BINARY(32) NULL,
  created_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  deleted_at_utc DATETIME(6) NULL,
  CONSTRAINT uq_media_object_key UNIQUE (object_key),
  CONSTRAINT fk_media_owner FOREIGN KEY (owner_user_id) REFERENCES users(user_id) ON DELETE RESTRICT,
  CONSTRAINT chk_media_size CHECK (byte_size > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE teams (
  team_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
  created_by_user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  name VARCHAR(120) NOT NULL,
  crest_asset_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  sport_id SMALLINT UNSIGNED NOT NULL,
  category_id SMALLINT UNSIGNED NOT NULL,
  skill_level_id SMALLINT UNSIGNED NULL,
  description TEXT NULL,
  city VARCHAR(100) NOT NULL,
  state_code CHAR(2) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  neighborhood VARCHAR(100) NULL,
  contact_phone_e164 VARCHAR(20) NULL,
  contact_phone_public BOOLEAN NOT NULL DEFAULT FALSE,
  latitude DECIMAL(9,6) NULL,
  longitude DECIMAL(9,6) NULL,
  location_consent_at_utc DATETIME(6) NULL,
  created_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  archived_at_utc DATETIME(6) NULL,
  CONSTRAINT fk_teams_creator FOREIGN KEY (created_by_user_id) REFERENCES users(user_id) ON DELETE RESTRICT,
  CONSTRAINT fk_teams_crest FOREIGN KEY (crest_asset_id) REFERENCES media_assets(asset_id) ON DELETE RESTRICT,
  CONSTRAINT fk_teams_sport FOREIGN KEY (sport_id) REFERENCES sports(sport_id) ON DELETE RESTRICT,
  CONSTRAINT fk_teams_category FOREIGN KEY (category_id) REFERENCES team_categories(category_id) ON DELETE RESTRICT,
  CONSTRAINT fk_teams_skill FOREIGN KEY (skill_level_id) REFERENCES skill_levels(skill_level_id) ON DELETE RESTRICT,
  CONSTRAINT fk_teams_state FOREIGN KEY (state_code) REFERENCES brazilian_states(state_code) ON DELETE RESTRICT,
  CONSTRAINT chk_teams_name CHECK (CHAR_LENGTH(TRIM(name)) > 0),
  CONSTRAINT chk_teams_city CHECK (CHAR_LENGTH(TRIM(city)) > 0),
  CONSTRAINT chk_teams_lat CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
  CONSTRAINT chk_teams_lon CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
  CONSTRAINT chk_teams_coordinates_pair CHECK ((latitude IS NULL) = (longitude IS NULL)),
  CONSTRAINT chk_teams_location_consent CHECK (latitude IS NULL OR location_consent_at_utc IS NOT NULL),
  KEY ix_teams_search (state_code, city, sport_id, category_id, skill_level_id, archived_at_utc)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE team_members (
  team_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  role_code VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  joined_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  revoked_at_utc DATETIME(6) NULL,
  PRIMARY KEY (team_id, user_id),
  CONSTRAINT fk_team_member_team FOREIGN KEY (team_id) REFERENCES teams(team_id) ON DELETE RESTRICT,
  CONSTRAINT fk_team_member_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE RESTRICT,
  CONSTRAINT fk_team_member_role FOREIGN KEY (role_code) REFERENCES team_roles(role_code) ON DELETE RESTRICT,
  KEY ix_team_members_user (user_id, revoked_at_utc, team_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE game_listings (
  listing_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
  team_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  created_by_user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  sport_id SMALLINT UNSIGNED NOT NULL,
  category_id SMALLINT UNSIGNED NOT NULL,
  skill_level_id SMALLINT UNSIGNED NULL,
  home_preference_id SMALLINT UNSIGNED NOT NULL,
  status_code VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'active',
  players_per_team TINYINT UNSIGNED NOT NULL,
  starts_at_utc DATETIME(6) NOT NULL,
  timezone_name VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  city VARCHAR(100) NOT NULL,
  state_code CHAR(2) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  neighborhood VARCHAR(100) NULL,
  venue_name VARCHAR(160) NOT NULL,
  venue_address VARCHAR(255) NULL,
  latitude DECIMAL(9,6) NULL,
  longitude DECIMAL(9,6) NULL,
  location_consent_at_utc DATETIME(6) NULL,
  rental_fee_per_team DECIMAL(10,2) NULL,
  notes TEXT NULL,
  created_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  removed_at_utc DATETIME(6) NULL,
  CONSTRAINT uq_listing_team_pair UNIQUE (listing_id, team_id),
  CONSTRAINT fk_listings_team FOREIGN KEY (team_id) REFERENCES teams(team_id) ON DELETE RESTRICT,
  CONSTRAINT fk_listings_creator_member FOREIGN KEY (team_id, created_by_user_id) REFERENCES team_members(team_id, user_id) ON DELETE RESTRICT,
  CONSTRAINT fk_listings_sport FOREIGN KEY (sport_id) REFERENCES sports(sport_id) ON DELETE RESTRICT,
  CONSTRAINT fk_listings_category FOREIGN KEY (category_id) REFERENCES team_categories(category_id) ON DELETE RESTRICT,
  CONSTRAINT fk_listings_skill FOREIGN KEY (skill_level_id) REFERENCES skill_levels(skill_level_id) ON DELETE RESTRICT,
  CONSTRAINT fk_listings_home FOREIGN KEY (home_preference_id) REFERENCES home_preferences(home_preference_id) ON DELETE RESTRICT,
  CONSTRAINT fk_listings_status FOREIGN KEY (status_code) REFERENCES listing_statuses(status_code) ON DELETE RESTRICT,
  CONSTRAINT fk_listings_state FOREIGN KEY (state_code) REFERENCES brazilian_states(state_code) ON DELETE RESTRICT,
  CONSTRAINT chk_listing_players CHECK (players_per_team BETWEEN 5 AND 30),
  CONSTRAINT chk_listing_fee CHECK (rental_fee_per_team IS NULL OR rental_fee_per_team >= 0),
  CONSTRAINT chk_listing_lat CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
  CONSTRAINT chk_listing_lon CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
  CONSTRAINT chk_listing_coordinates_pair CHECK ((latitude IS NULL) = (longitude IS NULL)),
  CONSTRAINT chk_listing_location_consent CHECK (latitude IS NULL OR location_consent_at_utc IS NOT NULL),
  CONSTRAINT chk_listing_city CHECK (CHAR_LENGTH(TRIM(city)) > 0),
  CONSTRAINT chk_listing_venue CHECK (CHAR_LENGTH(TRIM(venue_name)) > 0),
  CONSTRAINT chk_listing_timezone CHECK (CHAR_LENGTH(TRIM(timezone_name)) > 0),
  KEY ix_listing_discovery (status_code, sport_id, category_id, skill_level_id, starts_at_utc, state_code, city),
  KEY ix_listing_team_status (team_id, status_code, starts_at_utc)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE game_interests (
  interest_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
  listing_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  listing_owner_team_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  interested_team_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  created_by_user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  status_code VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'pending',
  message_to_owner VARCHAR(1000) NULL,
  created_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  responded_at_utc DATETIME(6) NULL,
  CONSTRAINT uq_listing_interested_team UNIQUE (listing_id, interested_team_id),
  CONSTRAINT uq_interest_listing_pair UNIQUE (interest_id, listing_id, listing_owner_team_id, interested_team_id),
  CONSTRAINT fk_interest_listing_owner FOREIGN KEY (listing_id, listing_owner_team_id) REFERENCES game_listings(listing_id, team_id) ON DELETE RESTRICT,
  CONSTRAINT fk_interest_interested_team FOREIGN KEY (interested_team_id) REFERENCES teams(team_id) ON DELETE RESTRICT,
  CONSTRAINT fk_interest_creator_member FOREIGN KEY (interested_team_id, created_by_user_id) REFERENCES team_members(team_id, user_id) ON DELETE RESTRICT,
  CONSTRAINT fk_interest_status FOREIGN KEY (status_code) REFERENCES interest_statuses(status_code) ON DELETE RESTRICT,
  CONSTRAINT chk_interest_teams_distinct CHECK (listing_owner_team_id <> interested_team_id),
  KEY ix_interest_team_status (interested_team_id, status_code, created_at_utc),
  KEY ix_interest_owner_status (listing_owner_team_id, status_code, created_at_utc)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE conversations (
  conversation_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
  interest_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  listing_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  listing_owner_team_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  interested_team_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  created_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  archived_at_utc DATETIME(6) NULL,
  CONSTRAINT uq_conversation_interest UNIQUE (interest_id),
  CONSTRAINT fk_conversation_interest_context FOREIGN KEY (interest_id, listing_id, listing_owner_team_id, interested_team_id)
    REFERENCES game_interests(interest_id, listing_id, listing_owner_team_id, interested_team_id) ON DELETE RESTRICT,
  KEY ix_conversation_owner (listing_owner_team_id, updated_at_utc),
  KEY ix_conversation_interested (interested_team_id, updated_at_utc)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE conversation_members (
  conversation_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  team_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  joined_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  last_read_at_utc DATETIME(6) NULL,
  removed_at_utc DATETIME(6) NULL,
  PRIMARY KEY (conversation_id, team_id, user_id),
  CONSTRAINT fk_conversation_member_conversation FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE RESTRICT,
  CONSTRAINT fk_conversation_member_team_user FOREIGN KEY (team_id, user_id) REFERENCES team_members(team_id, user_id) ON DELETE RESTRICT,
  KEY ix_conversation_member_user (user_id, removed_at_utc, conversation_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE chat_messages (
  message_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
  conversation_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  sender_team_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  sender_user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  message_type_code VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  body_text TEXT NULL,
  asset_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  latitude DECIMAL(9,6) NULL,
  longitude DECIMAL(9,6) NULL,
  location_consent_at_utc DATETIME(6) NULL,
  created_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  edited_at_utc DATETIME(6) NULL,
  deleted_at_utc DATETIME(6) NULL,
  CONSTRAINT fk_message_conversation FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE RESTRICT,
  CONSTRAINT fk_message_sender_membership FOREIGN KEY (sender_team_id, sender_user_id) REFERENCES team_members(team_id, user_id) ON DELETE RESTRICT,
  CONSTRAINT fk_message_type FOREIGN KEY (message_type_code) REFERENCES message_types(type_code) ON DELETE RESTRICT,
  CONSTRAINT fk_message_asset FOREIGN KEY (asset_id) REFERENCES media_assets(asset_id) ON DELETE RESTRICT,
  CONSTRAINT chk_message_payload CHECK (
    (message_type_code = 'text' AND body_text IS NOT NULL AND asset_id IS NULL AND latitude IS NULL AND longitude IS NULL)
    OR (message_type_code = 'image' AND asset_id IS NOT NULL AND latitude IS NULL AND longitude IS NULL)
    OR (message_type_code = 'location' AND latitude IS NOT NULL AND longitude IS NOT NULL AND location_consent_at_utc IS NOT NULL AND asset_id IS NULL)
    OR (message_type_code = 'system' AND (body_text IS NOT NULL OR asset_id IS NOT NULL OR latitude IS NOT NULL))
  ),
  CONSTRAINT chk_message_lat CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
  CONSTRAINT chk_message_lon CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
  CONSTRAINT chk_message_coordinates_pair CHECK ((latitude IS NULL) = (longitude IS NULL)),
  KEY ix_messages_conversation_time (conversation_id, created_at_utc, message_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- A match copies the agreed details so later listing edits/removal cannot rewrite history.
-- Result/score columns are intentionally omitted until a product flow is approved.
CREATE TABLE matches (
  match_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
  listing_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  interest_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  host_team_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  opponent_team_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  status_code VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'proposed',
  host_team_name_snapshot VARCHAR(120) NOT NULL,
  opponent_team_name_snapshot VARCHAR(120) NOT NULL,
  sport_code_snapshot VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  category_label_snapshot VARCHAR(60) NOT NULL,
  skill_level_label_snapshot VARCHAR(60) NULL,
  home_preference_label_snapshot VARCHAR(60) NOT NULL,
  players_per_team_snapshot TINYINT UNSIGNED NOT NULL,
  starts_at_utc DATETIME(6) NOT NULL,
  timezone_name VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  city VARCHAR(100) NOT NULL,
  state_code CHAR(2) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  neighborhood VARCHAR(100) NULL,
  venue_name VARCHAR(160) NOT NULL,
  venue_address VARCHAR(255) NULL,
  latitude DECIMAL(9,6) NULL,
  longitude DECIMAL(9,6) NULL,
  location_consent_at_utc DATETIME(6) NULL,
  rental_fee_per_team DECIMAL(10,2) NULL,
  notes_snapshot TEXT NULL,
  host_confirmed_at_utc DATETIME(6) NULL,
  opponent_confirmed_at_utc DATETIME(6) NULL,
  confirmed_at_utc DATETIME(6) NULL,
  cancelled_by_team_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  cancellation_reason VARCHAR(1000) NULL,
  cancelled_at_utc DATETIME(6) NULL,
  completed_at_utc DATETIME(6) NULL,
  created_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_match_interest UNIQUE (interest_id),
  CONSTRAINT fk_match_interest_context FOREIGN KEY (interest_id, listing_id, host_team_id, opponent_team_id)
    REFERENCES game_interests(interest_id, listing_id, listing_owner_team_id, interested_team_id) ON DELETE RESTRICT,
  CONSTRAINT fk_match_host_team FOREIGN KEY (host_team_id) REFERENCES teams(team_id) ON DELETE RESTRICT,
  CONSTRAINT fk_match_opponent_team FOREIGN KEY (opponent_team_id) REFERENCES teams(team_id) ON DELETE RESTRICT,
  CONSTRAINT fk_match_status FOREIGN KEY (status_code) REFERENCES match_statuses(status_code) ON DELETE RESTRICT,
  CONSTRAINT fk_match_cancelled_by FOREIGN KEY (cancelled_by_team_id) REFERENCES teams(team_id) ON DELETE RESTRICT,
  CONSTRAINT fk_match_state FOREIGN KEY (state_code) REFERENCES brazilian_states(state_code) ON DELETE RESTRICT,
  CONSTRAINT chk_match_teams_distinct CHECK (host_team_id <> opponent_team_id),
  CONSTRAINT chk_match_players CHECK (players_per_team_snapshot BETWEEN 5 AND 30),
  CONSTRAINT chk_match_fee CHECK (rental_fee_per_team IS NULL OR rental_fee_per_team >= 0),
  CONSTRAINT chk_match_lat CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
  CONSTRAINT chk_match_lon CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
  CONSTRAINT chk_match_coordinates_pair CHECK ((latitude IS NULL) = (longitude IS NULL)),
  CONSTRAINT chk_match_location_consent CHECK (latitude IS NULL OR location_consent_at_utc IS NOT NULL),
  CONSTRAINT chk_match_confirmed_timestamps CHECK (
    status_code <> 'confirmed' OR
    (host_confirmed_at_utc IS NOT NULL AND opponent_confirmed_at_utc IS NOT NULL AND confirmed_at_utc IS NOT NULL)
  ),
  CONSTRAINT chk_match_cancelled_timestamps CHECK (
    status_code <> 'cancelled' OR (cancelled_at_utc IS NOT NULL AND cancelled_by_team_id IS NOT NULL)
  ),
  CONSTRAINT chk_match_completed_timestamp CHECK (status_code <> 'completed' OR completed_at_utc IS NOT NULL),
  KEY ix_match_host_status_date (host_team_id, status_code, starts_at_utc),
  KEY ix_match_opponent_status_date (opponent_team_id, status_code, starts_at_utc)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE review_records (
  review_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
  match_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  reviewer_team_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  reviewed_team_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  created_by_user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  comment_text TEXT NULL,
  created_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at_utc DATETIME(6) NULL,
  CONSTRAINT uq_review_per_direction UNIQUE (match_id, reviewer_team_id, reviewed_team_id),
  CONSTRAINT fk_review_match FOREIGN KEY (match_id) REFERENCES matches(match_id) ON DELETE RESTRICT,
  CONSTRAINT fk_review_reviewer FOREIGN KEY (reviewer_team_id, created_by_user_id) REFERENCES team_members(team_id, user_id) ON DELETE RESTRICT,
  CONSTRAINT fk_review_reviewed_team FOREIGN KEY (reviewed_team_id) REFERENCES teams(team_id) ON DELETE RESTRICT,
  CONSTRAINT chk_review_teams_different CHECK (reviewer_team_id <> reviewed_team_id),
  KEY ix_review_team_date (reviewed_team_id, created_at_utc)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE review_scores (
  review_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  criterion_id SMALLINT UNSIGNED NOT NULL,
  score TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (review_id, criterion_id),
  CONSTRAINT fk_review_score_review FOREIGN KEY (review_id) REFERENCES review_records(review_id) ON DELETE RESTRICT,
  CONSTRAINT fk_review_score_criterion FOREIGN KEY (criterion_id) REFERENCES review_criteria(criterion_id) ON DELETE RESTRICT,
  CONSTRAINT chk_review_score CHECK (score BETWEEN 1 AND 5)
) ENGINE=InnoDB;

CREATE TABLE notifications (
  notification_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
  recipient_user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  team_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  type_code VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  title VARCHAR(160) NOT NULL,
  body_text VARCHAR(1000) NOT NULL,
  listing_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  interest_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  conversation_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  match_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  created_at_utc DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  read_at_utc DATETIME(6) NULL,
  CONSTRAINT fk_notification_recipient FOREIGN KEY (recipient_user_id) REFERENCES users(user_id) ON DELETE RESTRICT,
  CONSTRAINT fk_notification_team_member FOREIGN KEY (team_id, recipient_user_id) REFERENCES team_members(team_id, user_id) ON DELETE RESTRICT,
  CONSTRAINT fk_notification_type FOREIGN KEY (type_code) REFERENCES notification_types(type_code) ON DELETE RESTRICT,
  CONSTRAINT fk_notification_listing FOREIGN KEY (listing_id) REFERENCES game_listings(listing_id) ON DELETE RESTRICT,
  CONSTRAINT fk_notification_interest FOREIGN KEY (interest_id) REFERENCES game_interests(interest_id) ON DELETE RESTRICT,
  CONSTRAINT fk_notification_conversation FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id) ON DELETE RESTRICT,
  CONSTRAINT fk_notification_match FOREIGN KEY (match_id) REFERENCES matches(match_id) ON DELETE RESTRICT,
  CONSTRAINT chk_notification_single_target CHECK (
    (listing_id IS NOT NULL) + (interest_id IS NOT NULL) + (conversation_id IS NOT NULL) + (match_id IS NOT NULL) <= 1
  ),
  KEY ix_notifications_unread (recipient_user_id, read_at_utc, created_at_utc, notification_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- State-change guards: callers still need server-side authorization; these triggers
-- prevent bypassing the declared transition graph through ordinary SQL updates.
DELIMITER $$
CREATE TRIGGER bi_game_listings_initial_status
BEFORE INSERT ON game_listings FOR EACH ROW
BEGIN
  IF NEW.status_code <> 'active' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A new listing must start active';
  END IF;
END$$

CREATE TRIGGER bi_game_interests_no_self_interest
BEFORE INSERT ON game_interests FOR EACH ROW
BEGIN
  DECLARE listing_team CHAR(36);
  DECLARE current_listing_status VARCHAR(24);
  SELECT team_id, status_code INTO listing_team, current_listing_status
  FROM game_listings WHERE listing_id = NEW.listing_id;
  IF listing_team IS NULL OR listing_team <> NEW.listing_owner_team_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Interest listing owner does not match listing';
  END IF;
  IF current_listing_status <> 'active' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Interest requires an active listing';
  END IF;
  IF listing_team = NEW.interested_team_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A team cannot express interest in its own listing';
  END IF;
  IF NEW.status_code <> 'pending' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A new interest must start pending';
  END IF;
END$$

CREATE TRIGGER bu_game_listings_status_guard
BEFORE UPDATE ON game_listings FOR EACH ROW
BEGIN
  IF OLD.status_code <> NEW.status_code AND NOT EXISTS (
    SELECT 1 FROM listing_status_transitions
    WHERE from_status_code = OLD.status_code AND to_status_code = NEW.status_code
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid listing status transition';
  END IF;
END$$

CREATE TRIGGER bu_game_interests_status_guard
BEFORE UPDATE ON game_interests FOR EACH ROW
BEGIN
  IF OLD.status_code <> NEW.status_code AND NOT EXISTS (
    SELECT 1 FROM interest_status_transitions
    WHERE from_status_code = OLD.status_code AND to_status_code = NEW.status_code
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid interest status transition';
  END IF;
END$$

CREATE TRIGGER bi_conversations_context_guard
BEFORE INSERT ON conversations FOR EACH ROW
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM game_interests i
    WHERE i.interest_id = NEW.interest_id AND i.listing_id = NEW.listing_id
      AND i.listing_owner_team_id = NEW.listing_owner_team_id
      AND i.interested_team_id = NEW.interested_team_id
      AND i.status_code IN ('pending', 'accepted')
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conversation must match a valid active interest';
  END IF;
END$$

CREATE TRIGGER bi_conversation_members_context_guard
BEFORE INSERT ON conversation_members FOR EACH ROW
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM conversations c
    WHERE c.conversation_id = NEW.conversation_id
      AND NEW.team_id IN (c.listing_owner_team_id, c.interested_team_id)
  ) OR NOT EXISTS (
    SELECT 1 FROM team_members tm
    WHERE tm.team_id = NEW.team_id AND tm.user_id = NEW.user_id AND tm.revoked_at_utc IS NULL
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Conversation member must be an active member of a participating team';
  END IF;
END$$

CREATE TRIGGER bi_chat_messages_participant_guard
BEFORE INSERT ON chat_messages FOR EACH ROW
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM conversation_members cm
    WHERE cm.conversation_id = NEW.conversation_id AND cm.team_id = NEW.sender_team_id
      AND cm.user_id = NEW.sender_user_id AND cm.removed_at_utc IS NULL
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Message sender is not an active conversation member';
  END IF;
END$$

CREATE TRIGGER bi_matches_context_guard
BEFORE INSERT ON matches FOR EACH ROW
BEGIN
  IF NEW.status_code <> 'proposed' OR NOT EXISTS (
    SELECT 1 FROM game_interests i
    WHERE i.interest_id = NEW.interest_id AND i.listing_id = NEW.listing_id
      AND i.listing_owner_team_id = NEW.host_team_id
      AND i.interested_team_id = NEW.opponent_team_id
      AND i.status_code = 'accepted'
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Match requires an accepted interest and proposed initial status';
  END IF;
END$$

CREATE TRIGGER bu_matches_status_guard
BEFORE UPDATE ON matches FOR EACH ROW
BEGIN
  IF OLD.status_code <> NEW.status_code AND NOT EXISTS (
    SELECT 1 FROM match_status_transitions
    WHERE from_status_code = OLD.status_code AND to_status_code = NEW.status_code
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid match status transition';
  END IF;
  IF OLD.status_code = 'proposed' AND NEW.status_code = 'confirmed'
     AND (NEW.host_confirmed_at_utc IS NULL OR NEW.opponent_confirmed_at_utc IS NULL) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Both teams must confirm before match confirmation';
  END IF;
  IF OLD.status_code IN ('confirmed', 'completed', 'cancelled') AND (
       NOT (OLD.starts_at_utc <=> NEW.starts_at_utc)
       OR NOT (OLD.timezone_name <=> NEW.timezone_name)
       OR NOT (OLD.city <=> NEW.city)
       OR NOT (OLD.state_code <=> NEW.state_code)
       OR NOT (OLD.neighborhood <=> NEW.neighborhood)
       OR NOT (OLD.venue_name <=> NEW.venue_name)
       OR NOT (OLD.venue_address <=> NEW.venue_address)
       OR NOT (OLD.latitude <=> NEW.latitude)
       OR NOT (OLD.longitude <=> NEW.longitude)
       OR NOT (OLD.location_consent_at_utc <=> NEW.location_consent_at_utc)
       OR NOT (OLD.rental_fee_per_team <=> NEW.rental_fee_per_team)
       OR NOT (OLD.notes_snapshot <=> NEW.notes_snapshot)
       OR NOT (OLD.host_team_name_snapshot <=> NEW.host_team_name_snapshot)
       OR NOT (OLD.opponent_team_name_snapshot <=> NEW.opponent_team_name_snapshot)
       OR NOT (OLD.sport_code_snapshot <=> NEW.sport_code_snapshot)
       OR NOT (OLD.category_label_snapshot <=> NEW.category_label_snapshot)
       OR NOT (OLD.skill_level_label_snapshot <=> NEW.skill_level_label_snapshot)
       OR NOT (OLD.home_preference_label_snapshot <=> NEW.home_preference_label_snapshot)
       OR NOT (OLD.players_per_team_snapshot <=> NEW.players_per_team_snapshot)
     ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Agreed match snapshot is immutable after confirmation';
  END IF;
END$$

CREATE TRIGGER bi_review_requires_completed_match
BEFORE INSERT ON review_records FOR EACH ROW
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM matches m
    WHERE m.match_id = NEW.match_id AND m.status_code = 'completed'
      AND ((m.host_team_id = NEW.reviewer_team_id AND m.opponent_team_id = NEW.reviewed_team_id)
        OR (m.opponent_team_id = NEW.reviewer_team_id AND m.host_team_id = NEW.reviewed_team_id))
  ) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Review requires a completed match between these teams';
  END IF;
END$$
DELIMITER ;
