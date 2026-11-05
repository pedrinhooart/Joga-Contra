/**
 * Envio do código de recuperação de senha.
 * PENDENTE: nenhum provedor de e-mail foi configurado. Até lá o código é gerado
 * e guardado como hash, mas não chega ao usuário. Nunca registrar o código em log.
 */
export async function enviarCodigoRecuperacao(_email: string, _codigo: string) {
  console.warn('Recuperação de senha solicitada, mas nenhum provedor de e-mail está configurado.');
}
