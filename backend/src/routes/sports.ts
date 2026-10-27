import { Router } from 'express'; import { pool } from '../config/db.js'; import { asyncHandler } from '../middlewares/error-handler.js'; import { toJsonList } from '../services/helpers.js';
export const sportsRouter = Router();
sportsRouter.get('/', asyncHandler(async (_req, res) => { const [rows] = await pool.execute<any[]>('SELECT sport_id AS sportId, code, label_pt_br AS labelPtBr, sort_order AS sortOrder FROM sports WHERE is_active=TRUE ORDER BY sort_order, label_pt_br'); res.json({ data: toJsonList(rows) }); }));
