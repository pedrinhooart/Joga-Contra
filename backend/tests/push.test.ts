import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { describe, expect, it, vi } from 'vitest';

vi.mock('../src/config/env.js', () => ({ env: { NODE_ENV: 'test', PUSH_INTERVALO_MS: 3000 } }));
vi.mock('../src/config/db.js', () => ({ pool: { execute: vi.fn() } }));

const enviado = vi.hoisted(() => ({ multicast: [] as any[], resposta: null as any }));
vi.mock('firebase-admin/app', () => ({
  getApps: () => [],
  cert: (conta: any) => ({ conta }),
  initializeApp: (opcoes: any, nome: string) => ({ opcoes, nome }),
}));
vi.mock('firebase-admin/messaging', () => ({
  getMessaging: () => ({
    sendEachForMulticast: async (m: any) => {
      enviado.multicast.push(m);
      return enviado.resposta;
    },
  }),
}));

import { CANAL_ANDROID, EnviadorFirebase, etiquetaAndroid, mensagemDaNotificacao } from '../src/services/push.js';

describe('push: adaptador do Firebase', () => {
  const credenciais = path.join(mkdtempSync(path.join(tmpdir(), 'fcm-')), 'conta.json');
  writeFileSync(credenciais, JSON.stringify({ project_id: 'teste', client_email: 'x@teste.iam', private_key: 'k' }));

  it('mensagem com título, texto e só identificadores', () => {
    const m = mensagemDaNotificacao({
      id_notificacao: 'n1', tipo: 'partida_confirmada', titulo: 'Desafio aceito!', mensagem: 'Seu desafio foi aceito!',
      id_solicitacao: null, id_partida: 'p1', id_anuncio: null, id_usuario_destinatario: 'u1',
    });
    expect(m).toEqual({
      titulo: 'Desafio aceito!',
      corpo: 'Seu desafio foi aceito!',
      dados: { idNotificacao: 'n1', tipo: 'partida_confirmada', referenciaTipo: 'partida', referenciaId: 'p1' },
    });
    expect(JSON.stringify(m)).not.toContain('u1'); // sem dados da conta
  });

  it('envia pelo Admin SDK no canal do app e interpreta cada token', async () => {
    enviado.resposta = {
      responses: [
        { success: true },
        { success: false, error: { code: 'messaging/installation-id-not-registered' } },
        { success: false, error: { code: 'messaging/unavailable' } },
      ],
    };
    const r = await new EnviadorFirebase(credenciais).enviar(['a', 'b', 'c'], {
      titulo: 'T', corpo: 'C', dados: { idNotificacao: 'n1', tipo: 'aviso', referenciaTipo: '', referenciaId: '' },
    });
    expect(r).toEqual([
      { token: 'a', ok: true, tokenInvalido: false, erro: undefined },
      { token: 'b', ok: false, tokenInvalido: true, erro: 'messaging/installation-id-not-registered' },
      { token: 'c', ok: false, tokenInvalido: false, erro: 'messaging/unavailable' },
    ]);
    const [m] = enviado.multicast;
    expect(m).toMatchObject({
      fids: ['a', 'b', 'c'],
      notification: { title: 'T', body: 'C' },
      data: { idNotificacao: 'n1', tipo: 'aviso' },
      android: { priority: 'high', notification: { channelId: CANAL_ANDROID, icon: 'ic_notificacao', tag: 'n1' } },
    });
  });

  it('mensagens da mesma conversa se substituem no aparelho; os demais avisos não', () => {
    const m = (tipo: string, id: string, ref: string) => ({
      titulo: 'T', corpo: 'C', dados: { idNotificacao: id, tipo, referenciaTipo: 'solicitacao' as const, referenciaId: ref },
    });
    expect(etiquetaAndroid(m('mensagem_recebida', 'n1', 's1'))).toBe('chat-s1');
    expect(etiquetaAndroid(m('mensagem_recebida', 'n2', 's1'))).toBe('chat-s1');
    expect(etiquetaAndroid(m('solicitacao_recebida', 'n3', 's1'))).toBe('n3');
  });

  it('mais de 500 aparelhos: envia em lotes de 500, um resultado por aparelho', async () => {
    const tokens = Array.from({ length: 1203 }, (_, i) => 'fid-' + i);
    const enviador = new EnviadorFirebase(credenciais);
    const espiao = vi.spyOn(enviador as any, 'enviarLote').mockImplementation(async (lote: any) =>
      lote.map((token: string) => ({ token, ok: true })),
    );
    const r = await enviador.enviar(tokens, { titulo: 'T', corpo: 'C', dados: { idNotificacao: 'n', tipo: 'aviso', referenciaTipo: '', referenciaId: '' } });
    expect(espiao.mock.calls.map((c: any) => c[0].length)).toEqual([500, 500, 203]);
    expect(r).toHaveLength(1203);
    expect(r.at(-1)).toEqual({ token: 'fid-1202', ok: true });
  });
});
