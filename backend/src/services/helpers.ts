import type { PoolConnection } from 'mysql2/promise';
import { randomUUID } from 'node:crypto';
import { ApiError } from '../middlewares/error-handler.js';
export const uuid = () => randomUUID();
export async function requireActiveMembership(db: PoolConnection, teamId: string, userId: string, managerOnly = false) {
  const [rows] = await db.execute<any[]>('SELECT role_code FROM team_members WHERE team_id=? AND user_id=? AND revoked_at_utc IS NULL', [teamId, userId]);
  if (!rows.length || (managerOnly && !['owner', 'manager'].includes(rows[0].role_code))) throw new ApiError(403, 'Você não tem permissão para administrar este time.');
}
export const paging = (page: number, limit: number) => ({ offset: (page - 1) * limit, page, limit });
export const toJson = (row: any) => row && Object.fromEntries(Object.entries(row).map(([k, v]) => [k, v instanceof Date ? v.toISOString() : v]));
export const toJsonList = (rows: any[]) => rows.map(toJson);
