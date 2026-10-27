import 'dotenv/config';
import mysql from 'mysql2/promise';
const dbEnv = { host: process.env.DB_HOST ?? '127.0.0.1', port: Number(process.env.DB_PORT ?? 3306), user: process.env.DB_USER ?? '', password: process.env.DB_PASSWORD ?? '', database: process.env.DB_NAME ?? '' };

const required: Record<string, string[]> = {
  users: ['user_id', 'email', 'display_name', 'phone_e164', 'password_hash', 'account_status_code', 'deleted_at_utc'],
  sports: ['sport_id', 'code', 'label_pt_br', 'sort_order', 'is_active'],
  teams: ['team_id', 'created_by_user_id', 'name', 'sport_id', 'category_id', 'skill_level_id', 'city', 'state_code', 'archived_at_utc'],
  team_members: ['team_id', 'user_id', 'role_code', 'revoked_at_utc'],
  game_listings: ['listing_id', 'team_id', 'created_by_user_id', 'sport_id', 'category_id', 'home_preference_id', 'status_code', 'starts_at_utc', 'removed_at_utc'],
  game_interests: ['interest_id', 'listing_id', 'listing_owner_team_id', 'interested_team_id', 'created_by_user_id', 'status_code'],
  team_categories: ['category_id', 'code', 'label_pt_br', 'is_active'], skill_levels: ['skill_level_id', 'code', 'label_pt_br', 'is_active'],
  home_preferences: ['home_preference_id', 'code', 'label_pt_br', 'is_active'], brazilian_states: ['state_code', 'state_name', 'is_active'],
  account_statuses: ['status_code'], team_roles: ['role_code'], listing_status_transitions: ['from_status_code', 'to_status_code'], interest_status_transitions: ['from_status_code', 'to_status_code'],
};

async function main() {
const db = await mysql.createConnection(dbEnv);
try {
  await db.query("SET time_zone = '+00:00'");
  const [version] = await db.query<any[]>('SELECT VERSION() AS version, DATABASE() AS database_name');
  const [columns] = await db.execute<any[]>(`SELECT table_name AS tableName, column_name AS columnName FROM information_schema.columns WHERE table_schema=?`, [dbEnv.database]);
  const available = new Map<string, Set<string>>();
  for (const row of columns) (available.get(row.tableName) ?? available.set(row.tableName, new Set()).get(row.tableName)!).add(row.columnName);
  const missing = Object.entries(required).flatMap(([table, names]) => !available.has(table) ? [`tabela ${table}`] : names.filter(n => !available.get(table)!.has(n)).map(n => `${table}.${n}`));
  const [catalog] = await db.query<any[]>(`SELECT
    (SELECT COUNT(*) FROM sports) AS sports, (SELECT COUNT(*) FROM team_categories) AS categories,
    (SELECT COUNT(*) FROM skill_levels) AS skill_levels, (SELECT COUNT(*) FROM home_preferences) AS home_preferences,
    (SELECT COUNT(*) FROM brazilian_states) AS states, (SELECT COUNT(*) FROM account_statuses) AS account_statuses,
    (SELECT COUNT(*) FROM team_roles) AS team_roles`);
  console.log(JSON.stringify({ connected: true, mysqlVersion: version[0].version, database: version[0].database_name, tables: available.size, missing, catalog: catalog[0] }, null, 2));
  if (missing.length) process.exitCode = 2;
} finally { await db.end(); }
}
main().catch(error => { console.error('Falha na verificação do banco:', error.code ?? error.message); process.exitCode = 1; });
