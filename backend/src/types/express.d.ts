declare global {
  namespace Express {
    interface Request {
      auth?: { idUsuario: string; idTime: string | null };
    }
  }
}
export {};
