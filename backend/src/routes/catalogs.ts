import { Router } from 'express';
import { pool } from '../config/db.js';
import { asyncHandler } from '../middlewares/error-handler.js';
import { toJsonList } from '../services/helpers.js';

export const catalogsRouter = Router();
catalogsRouter.get('/', asyncHandler(async (_req, res) => {
  const [categories, levels, homes, states] = await Promise.all([
    pool.execute<any[]>('SELECT category_id AS categoryId, code, label_pt_br AS labelPtBr, sort_order AS sortOrder FROM team_categories WHERE is_active=TRUE ORDER BY sort_order, label_pt_br'),
    pool.execute<any[]>('SELECT skill_level_id AS skillLevelId, code, label_pt_br AS labelPtBr, sort_order AS sortOrder FROM skill_levels WHERE is_active=TRUE ORDER BY sort_order, label_pt_br'),
    pool.execute<any[]>('SELECT home_preference_id AS homePreferenceId, code, label_pt_br AS labelPtBr, sort_order AS sortOrder FROM home_preferences WHERE is_active=TRUE ORDER BY sort_order, label_pt_br'),
    pool.execute<any[]>('SELECT state_code AS stateCode, state_name AS stateName FROM brazilian_states WHERE is_active=TRUE ORDER BY state_name'),
  ]);
  res.json({ data: { categories: toJsonList(categories[0]), skillLevels: toJsonList(levels[0]), homePreferences: toJsonList(homes[0]), states: toJsonList(states[0]) } });
}));
