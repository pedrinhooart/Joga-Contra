-- API/backend SQL examples. Every :name is a bound parameter, never string interpolation.
-- Authenticate/authorize the actor in the backend and set the connection to UTC.

-- 1. Discover active listings. Omit predicates whose filters are absent.
SELECT l.listing_id, t.team_id, t.name AS team_name, s.label_pt_br AS sport,
       c.label_pt_br AS category, sl.label_pt_br AS skill_level,
       l.starts_at_utc, l.timezone_name, l.city, l.state_code, l.neighborhood,
       l.venue_name, l.players_per_team, l.rental_fee_per_team,
       CASE WHEN :origin_lat IS NULL OR l.latitude IS NULL THEN NULL
            ELSE ST_Distance_Sphere(POINT(:origin_lon, :origin_lat), POINT(l.longitude, l.latitude)) / 1000 END AS distance_km
FROM game_listings l
JOIN teams t ON t.team_id = l.team_id AND t.archived_at_utc IS NULL
JOIN sports s ON s.sport_id = l.sport_id
JOIN team_categories c ON c.category_id = l.category_id
LEFT JOIN skill_levels sl ON sl.skill_level_id = l.skill_level_id
WHERE l.status_code = 'active'
  AND l.starts_at_utc >= :starts_after_utc
  AND (:sport_id IS NULL OR l.sport_id = :sport_id)
  AND (:category_id IS NULL OR l.category_id = :category_id)
  AND (:skill_level_id IS NULL OR l.skill_level_id = :skill_level_id)
  AND (:state_code IS NULL OR l.state_code = :state_code)
  AND (:city_query IS NULL OR l.city LIKE CONCAT('%', :city_query, '%')
       OR l.neighborhood LIKE CONCAT('%', :city_query, '%') OR l.venue_name LIKE CONCAT('%', :city_query, '%')
       OR t.name LIKE CONCAT('%', :city_query, '%'))
  AND (:radius_km IS NULL OR (:origin_lat IS NOT NULL AND l.latitude IS NOT NULL
       AND ST_Distance_Sphere(POINT(:origin_lon, :origin_lat), POINT(l.longitude, l.latitude)) <= :radius_km * 1000))
ORDER BY l.starts_at_utc ASC, l.listing_id ASC
LIMIT :page_size OFFSET :offset;

-- 2. Listing detail. Contact stays private; return it only after a separately authorized operation.
SELECT l.*, t.name AS team_name, t.crest_asset_id, s.label_pt_br AS sport,
       c.label_pt_br AS category, sl.label_pt_br AS skill_level,
       hp.label_pt_br AS home_preference
FROM game_listings l
JOIN teams t ON t.team_id = l.team_id
JOIN sports s ON s.sport_id = l.sport_id
JOIN team_categories c ON c.category_id = l.category_id
LEFT JOIN skill_levels sl ON sl.skill_level_id = l.skill_level_id
JOIN home_preferences hp ON hp.home_preference_id = l.home_preference_id
WHERE l.listing_id = :listing_id AND l.status_code = 'active' AND t.archived_at_utc IS NULL;

-- 3. Register interest and open the conversation exactly once. The backend checks that
-- actor_user_id is an active member of interested_team_id and that teams differ.
START TRANSACTION;
SELECT team_id, status_code FROM game_listings WHERE listing_id = :listing_id FOR UPDATE;
INSERT INTO game_interests
 (interest_id, listing_id, listing_owner_team_id, interested_team_id, created_by_user_id, status_code, message_to_owner)
VALUES (:interest_id, :listing_id, :listing_owner_team_id, :interested_team_id, :actor_user_id, 'pending', :message);
INSERT INTO conversations
 (conversation_id, interest_id, listing_id, listing_owner_team_id, interested_team_id)
VALUES (:conversation_id, :interest_id, :listing_id, :listing_owner_team_id, :interested_team_id);
INSERT INTO conversation_members (conversation_id, team_id, user_id)
SELECT :conversation_id, tm.team_id, tm.user_id FROM team_members tm
WHERE tm.team_id IN (:listing_owner_team_id, :interested_team_id) AND tm.revoked_at_utc IS NULL;
-- Create one notification per active member of the listing-owner team here.
COMMIT;
-- On duplicate (listing_id, interested_team_id), return the existing interest/conversation or 409.

-- 4. List conversations visible to an active team member; membership and current team role
-- are authorized again by the API. Cursor pagination should use (updated_at_utc, conversation_id).
SELECT c.conversation_id, c.updated_at_utc, i.status_code AS interest_status,
       l.listing_id, owner.name AS listing_owner, interested.name AS interested_team,
       (SELECT m.body_text FROM chat_messages m WHERE m.conversation_id = c.conversation_id
          AND m.deleted_at_utc IS NULL ORDER BY m.created_at_utc DESC, m.message_id DESC LIMIT 1) AS latest_message
FROM conversation_members cm
JOIN conversations c ON c.conversation_id = cm.conversation_id AND c.archived_at_utc IS NULL
JOIN game_interests i ON i.interest_id = c.interest_id
JOIN game_listings l ON l.listing_id = c.listing_id
JOIN teams owner ON owner.team_id = c.listing_owner_team_id
JOIN teams interested ON interested.team_id = c.interested_team_id
WHERE cm.user_id = :actor_user_id AND cm.team_id = :active_team_id AND cm.removed_at_utc IS NULL
ORDER BY c.updated_at_utc DESC, c.conversation_id DESC
LIMIT :page_size;

-- 5. Messages use a stable cursor and exclude soft-deleted content. Update last_read_at_utc
-- for the authenticated conversation member after the client acknowledges the page.
SELECT message_id, sender_team_id, sender_user_id, message_type_code, body_text,
       asset_id, latitude, longitude, created_at_utc, edited_at_utc
FROM chat_messages
WHERE conversation_id = :conversation_id AND deleted_at_utc IS NULL
  AND (created_at_utc, message_id) < (:before_created_at_utc, :before_message_id)
ORDER BY created_at_utc DESC, message_id DESC
LIMIT :page_size;

-- 6. Owner accepts an interest, creates a proposed match with an immutable snapshot,
-- then the two teams confirm separately. Perform the accept/create operations atomically.
START TRANSACTION;
SELECT i.*, l.* FROM game_interests i
JOIN game_listings l ON l.listing_id = i.listing_id
WHERE i.interest_id = :interest_id FOR UPDATE;
UPDATE game_interests SET status_code = 'accepted', responded_at_utc = UTC_TIMESTAMP(6)
WHERE interest_id = :interest_id AND status_code = 'pending';
-- INSERT matches (...) SELECT current agreed listing data and both team name snapshots ...
-- Initial match status must be 'proposed'. Commit only if exactly one row was updated/created.
COMMIT;

-- Either side's approval. Set only its own timestamp after membership/role validation.
START TRANSACTION;
SELECT status_code, host_team_id, opponent_team_id, host_confirmed_at_utc,
       opponent_confirmed_at_utc
FROM matches WHERE match_id = :match_id FOR UPDATE;
-- For a host actor:
UPDATE matches
SET host_confirmed_at_utc = COALESCE(host_confirmed_at_utc, UTC_TIMESTAMP(6)),
    status_code = IF(opponent_confirmed_at_utc IS NOT NULL, 'confirmed', status_code),
    confirmed_at_utc = IF(opponent_confirmed_at_utc IS NOT NULL, UTC_TIMESTAMP(6), confirmed_at_utc)
WHERE match_id = :match_id AND status_code = 'proposed' AND host_team_id = :active_team_id;
-- For an opponent actor, swap host/opponent fields. The status trigger requires both acknowledgements.
COMMIT;

-- 7. Cancel by either authorized participating team. Transition trigger rejects any other state.
START TRANSACTION;
UPDATE matches
SET status_code = 'cancelled', cancelled_by_team_id = :active_team_id,
    cancellation_reason = :reason, cancelled_at_utc = UTC_TIMESTAMP(6)
WHERE match_id = :match_id AND status_code IN ('proposed', 'confirmed')
  AND :active_team_id IN (host_team_id, opponent_team_id);
-- Require ROW_COUNT() = 1, enqueue notification(s) for the other team's active members.
COMMIT;

-- 8. List matches in app-facing groups. "Aguardando" and "Negociando" are derived from
-- active listings/interests; the persisted match statuses are proposed/confirmed/completed/cancelled.
SELECT m.* FROM matches m
WHERE :active_team_id IN (m.host_team_id, m.opponent_team_id)
  AND m.status_code = :status_code
ORDER BY m.starts_at_utc DESC, m.match_id DESC
LIMIT :page_size;

-- 9. Submit one review with the complete configured set of scores in one transaction.
-- Backend validates exactly one score for every required active criterion before commit.
START TRANSACTION;
INSERT INTO review_records
 (review_id, match_id, reviewer_team_id, reviewed_team_id, created_by_user_id, comment_text)
VALUES (:review_id, :match_id, :reviewer_team_id, :reviewed_team_id, :actor_user_id, :comment_text);
INSERT INTO review_scores (review_id, criterion_id, score) VALUES
  (:review_id, :punctuality_criterion_id, :punctuality_score),
  (:review_id, :organization_criterion_id, :organization_score),
  (:review_id, :respect_criterion_id, :respect_score),
  (:review_id, :venue_criterion_id, :venue_score);
COMMIT;

-- 10. Calculate profile aggregate on demand; do not store this as primary truth.
SELECT AVG(rs.score) AS average_score, COUNT(DISTINCT r.review_id) AS review_count
FROM review_records r JOIN review_scores rs ON rs.review_id = r.review_id
WHERE r.reviewed_team_id = :team_id AND r.deleted_at_utc IS NULL;

-- 11. Unread notifications for the authenticated account.
SELECT notification_id, type_code, title, body_text, listing_id, interest_id,
       conversation_id, match_id, created_at_utc
FROM notifications
WHERE recipient_user_id = :actor_user_id AND read_at_utc IS NULL
ORDER BY created_at_utc DESC, notification_id DESC
LIMIT :page_size;
UPDATE notifications SET read_at_utc = UTC_TIMESTAMP(6)
WHERE notification_id = :notification_id AND recipient_user_id = :actor_user_id AND read_at_utc IS NULL;
