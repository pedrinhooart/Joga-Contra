import { mkdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { env } from '../config/env.js';

/** Formatos de imagem aceitos, com a extensão usada no arquivo salvo. */
export const TIPOS_IMAGEM = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp' } as const;
export type TipoImagem = keyof typeof TIPOS_IMAGEM;

/** Tamanho máximo de uma imagem enviada. */
export const LIMITE_IMAGEM_BYTES = 2 * 1024 * 1024;

/**
 * Formato real da imagem pelos primeiros bytes (não confia no Content-Type).
 * Nulo se não for JPEG, PNG ou WebP.
 */
export function tipoDaImagem(bytes: Buffer): TipoImagem | null {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'image/jpeg';
  if (bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
    return 'image/png';
  }
  if (bytes.length >= 12 && bytes.toString('ascii', 0, 4) === 'RIFF' && bytes.toString('ascii', 8, 12) === 'WEBP') {
    return 'image/webp';
  }
  return null;
}

/**
 * Onde os arquivos ficam. Hoje: pasta no servidor. Na implantação na AWS, uma
 * implementação com S3 (credenciais só no servidor) substitui esta sem mudar
 * as rotas. O banco guarda apenas o endereço público devolvido por `salvar`.
 */
export interface Armazenamento {
  /** Grava e devolve o endereço público do arquivo. */
  salvar(pasta: string, nome: string, bytes: Buffer): Promise<string>;
  /** Remove um arquivo salvo por este armazenamento. Ignora endereços de fora. */
  remover(endereco: string): Promise<void>;
}

/** Arquivos em `ARQUIVOS_DIR`, servidos pela própria API em `/api/arquivos`. */
export class ArmazenamentoLocal implements Armazenamento {
  constructor(
    readonly raiz: string,
    readonly prefixoUrl = '/api/arquivos',
  ) {}

  async salvar(pasta: string, nome: string, bytes: Buffer) {
    const destino = path.join(this.raiz, pasta);
    await mkdir(destino, { recursive: true });
    await writeFile(path.join(destino, nome), bytes, { flag: 'wx' }); // nunca sobrescreve
    return `${this.prefixoUrl}/${pasta}/${nome}`;
  }

  async remover(endereco: string) {
    if (!endereco.startsWith(`${this.prefixoUrl}/`)) return;
    const relativo = endereco.slice(this.prefixoUrl.length + 1);
    const arquivo = path.resolve(this.raiz, relativo);
    // Só apaga dentro da pasta de arquivos (sem "..").
    if (!arquivo.startsWith(path.resolve(this.raiz) + path.sep)) return;
    await rm(arquivo, { force: true });
  }
}

export const armazenamento = new ArmazenamentoLocal(path.resolve(env.ARQUIVOS_DIR ?? 'arquivos'));
