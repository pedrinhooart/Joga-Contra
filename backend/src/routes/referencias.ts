import { Router } from 'express';
import { pool } from '../config/db.js';
import { consultar } from '../services/helpers.js';

export const referenciasRouter = Router();

/** Pública: o formulário de cadastro precisa das listas antes do login. */
referenciasRouter.get('/', async (_req, res) => {
  const lista = (tabela: string, coluna: string) =>
    consultar(pool, `SELECT ${coluna} AS id, codigo, nome, ordem FROM ${tabela} WHERE ativo = TRUE ORDER BY ordem, nome`);

  const [modalidades, categoriasEtarias, niveisTecnicos, mandosCampo, criteriosAvaliacao, estados] = await Promise.all([
    lista('modalidades', 'id_modalidade'),
    lista('categorias_etarias', 'id_categoria_etaria'),
    lista('niveis_tecnicos', 'id_nivel_tecnico'),
    lista('mandos_campo', 'id_mando_campo'),
    lista('criterios_avaliacao', 'id_criterio'),
    consultar(pool, 'SELECT sigla, nome FROM estados WHERE ativo = TRUE ORDER BY sigla'),
  ]);

  res.json({ data: { modalidades, categoriasEtarias, niveisTecnicos, mandosCampo, criteriosAvaliacao, estados } });
});
