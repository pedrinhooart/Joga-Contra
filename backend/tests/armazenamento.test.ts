import { mkdtempSync, existsSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { ArmazenamentoLocal, tipoDaImagem } from '../src/services/armazenamento.js';
import { PNG_1X1 } from './dados-teste.js';


describe('formato da imagem pelos bytes', () => {
  it('reconhece JPEG, PNG e WebP', () => {
    expect(tipoDaImagem(Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0, 0]))).toBe('image/jpeg');
    expect(tipoDaImagem(PNG_1X1)).toBe('image/png');
    expect(tipoDaImagem(Buffer.from('RIFF\x00\x00\x00\x00WEBPVP8 ', 'latin1'))).toBe('image/webp');
  });

  it('recusa o que não é imagem, mesmo com nome ou cabeçalho de imagem', () => {
    expect(tipoDaImagem(Buffer.from('<svg xmlns="http://www.w3.org/2000/svg"/>'))).toBeNull();
    expect(tipoDaImagem(Buffer.from('GIF89a......'))).toBeNull();
    expect(tipoDaImagem(Buffer.alloc(0))).toBeNull();
  });
});

describe('armazenamento local', () => {
  const raiz = mkdtempSync(path.join(tmpdir(), 'joga-arquivos-'));
  const arm = new ArmazenamentoLocal(raiz);

  it('salva, devolve o endereço público e remove', async () => {
    const endereco = await arm.salvar('escudos', 'a.png', PNG_1X1);
    expect(endereco).toBe('/api/arquivos/escudos/a.png');
    const arquivo = path.join(raiz, 'escudos', 'a.png');
    expect(readFileSync(arquivo)).toEqual(PNG_1X1);
    await arm.remover(endereco);
    expect(existsSync(arquivo)).toBe(false);
  });

  it('nunca sobrescreve um arquivo existente', async () => {
    await arm.salvar('escudos', 'b.png', PNG_1X1);
    await expect(arm.salvar('escudos', 'b.png', PNG_1X1)).rejects.toThrow();
  });

  it('não apaga nada fora da pasta de arquivos', async () => {
    const fora = path.join(path.dirname(raiz), `fora-${path.basename(raiz)}.txt`);
    writeFileSync(fora, 'x');
    await arm.remover(`/api/arquivos/../${path.basename(fora)}`);
    await arm.remover('https://exemplo.com/escudo.png');
    expect(existsSync(fora)).toBe(true);
  });
});
