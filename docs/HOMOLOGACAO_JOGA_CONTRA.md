# Joga Contra — Relatório de preparação para homologação

Data: 05/11/2026 · Branch `refactor/dados-dinamicos`

## Conclusão: PRONTO COM RESSALVAS

Flutter, API e `joga_contra_v2` foram testados juntos no emulador Android, com dados gravados no banco real. As ressalvas:

1. **O celular físico não foi testado**, e a porta 3000 precisa de uma regra de firewall, que exige administrador (seção G.4).
2. A partir de **08/11/2026** as rotinas ficam suspensas para proteger os registros antigos (seção F.2).
3. Recuperação de senha não funciona de ponta a ponta: falta provedor de e-mail e tela para digitar o código.

## A. Ambiente

| Item | Valor |
|---|---|
| Branch | `refactor/dados-dinamicos` (nenhuma branch criada) |
| Ponto de restauração | Commit anterior: `81faa40` |
| Banco | `joga_contra_v2`, MySQL 8.4.13, serviço `MySQL84` (início automático), usuário `root` mantido |
| API | Porta `3000`, escuta em `0.0.0.0` |
| Emulador | `http://10.0.2.2:3000/api` · AVD `Pixel_9_Pro`, Android 17 (emulador) |
| Celular | `http://192.168.100.121:3000/api` (Ethernet, rede Privada, gateway `192.168.100.254`) |
| Trocar de ambiente | `--dart-define-from-file=config/emulador.json` ou `config/celular.json`. No VS Code: "Joga Contra (emulador)" ou "(celular)" |
| Se o IP do computador mudar | Editar só `config/celular.json` |

HTTP sem criptografia só é permitido no build **debug** (`android/app/src/debug/AndroidManifest.xml`). Builds release e profile bloqueiam HTTP, por isso o APK de teste é debug.

## B. Backend

**Conexão:** ativa, `/api/health/db` responde `{ status: "ok", conexaoAtiva: true, banco: "joga_contra_v2", bancoCorreto: true }` por `127.0.0.1` e pelo IP da rede. Não expõe host, usuário ou senha. Com outro banco, responde 503.

**Endpoints verificados:** todos os de [backend/README.md](../backend/README.md), pelos testes de integração e pelo uso real do app.

**Corrigidos ou ajustados:**

| Arquivo | Ajuste |
|---|---|
| `routes/health.ts` | `/health/db` passou a confirmar que o banco é o esperado |
| `app.ts` | Log de cada requisição (método, caminho, status, tempo), sem corpo, query ou cabeçalhos |
| `app.ts` | Limite de login conta só tentativas erradas. Antes, 10 logins certos em 15 minutos bloqueavam quem alterna contas |
| `services/rotinas.ts` | Rotinas não executam se tocariam registros anteriores a `ROTINAS_PRESERVAR_ATE` |

**Testes executados com o código final:**

| Teste | Resultado |
|---|---|
| `tsc --noEmit` e `npm run build` | Sem erros |
| `npm test` (unitários) | 26 de 26 |
| `npm run test:integracao` no banco real | 15 de 15, com 2 cenários novos: redefinição de senha com código válido e matriz de 12 combinações de faixa etária e nível, nas 2 modalidades |
| `npm run verify:db` | Nada faltando |
| Limite de login | 12 logins certos passam; o 11º erro recebe 429 em JSON |
| `npm ls` | Sem dependência faltando |
| `npm audit --omit=dev` | **1 vulnerabilidade alta em `zod`**, sem atualização aplicada (seção F) |

CORS está aberto (`*`), o que não afeta o app. JWT, pool e tratamento de erros foram revisados e exercitados pelos testes; não exigiram mudança.

## C. Flutter

| Item | Situação |
|---|---|
| `flutter analyze` | Sem problemas |
| `flutter test` | 14 de 14 (7 dependem de API e rodam à parte) |
| Repositórios e telas contra a API real | 7 de 7 |
| APK debug | Compilou para os dois ambientes; instalado e aberto no emulador |
| APK do celular | Login feito pelo IP `192.168.100.121`, a partir do emulador. **Valida a configuração, não o firewall** |

**Telas usadas no emulador:** Entrar, Criar conta, Esqueci a senha, Início, Buscar, Filtros, Detalhes, Conversa, Conversas, Partida confirmada, Meus jogos, Meus anúncios, Anunciar, Editar anúncio, Mapa, Notificações, Perfil, Avaliação. Conferi visualmente as capturas de Entrar, Buscar, Filtros, Meus anúncios, Conversa, Partida confirmada e Perfil: estão íntegras, mas não comparei lado a lado com o Figma.

**Defeitos encontrados no emulador e corrigidos:**

| Defeito | Causa | Correção |
|---|---|---|
| **Tela vermelha ao aplicar filtros** | Campos de texto descartados enquanto a folha ainda fechava | Controllers passaram a viver com a tela (`discover_screen.dart`). Teste de regressão criado |
| **Mesmo defeito ao salvar o nome do time** | Mesma causa, no diálogo de `app.dart` | Mesma correção e teste de regressão. Ambos falham sem a correção |

Em build release, esse erro não mostraria a tela vermelha, mas o defeito era o mesmo.

## D. Banco de dados

Banco utilizado: somente `joga_contra_v2`. Antes de ligar a API, salvei o hash de cada registro das 17 tabelas e comparei ao final:

**Estrutura, rotinas e gatilhos idênticos. Registros antigos: 0 alterados, 0 removidos.**

| Tabela | Antes | Agora | Novos |
|---|---|---|---|
| usuarios | 71 | 219 | 148 |
| times | 71 | 219 | 148 |
| anuncios_partidas | 31 | 127 | 96 |
| solicitacoes_confronto | 36 | 129 | 93 |
| partidas | 17 | 59 | 42 |
| mensagens | 7 | 15 | 8 |
| avaliacoes | 1 | 5 | 4 |
| notificacoes | 99 | 345 | 246 |

Tabelas de referência sem mudança. Os 148 usuários novos têm e-mail `teste.homologacao.*@example.com`.

**Operações realizadas:** somente inserções e atualizações em registros novos, pela API. Uma chamada direta de `proc_marcar_partidas_realizadas(0)`, feita depois de confirmar que só uma partida `teste.homologacao` seria afetada, para testar a avaliação. Nenhum DROP, TRUNCATE, DELETE em massa ou script de inicialização.

**Problemas:** nenhum depende de alteração estrutural.

## E. Funcionalidades

"Emulador" significa feito pela tela, no app instalado, com API e banco reais. "API" significa teste de integração no banco real.

| Funcionalidade | Situação | Teste realizado | Observação |
|---|---|---|---|
| Cadastro de usuário e equipe | APROVADO | Emulador, API | Formulário completo; validações de cadastro inválido pela API |
| Login e validação de credenciais | APROVADO | Emulador, API | "E-mail ou senha inválidos." exibido |
| Persistência da sessão | APROVADO | Emulador | Sobreviveu a encerramento forçado, com armazenamento seguro real |
| Logout | APROVADO | Emulador | Reabrir volta ao login |
| Limite de tentativas | APROVADO | Instância local | 429 no 11º erro |
| Recuperação: pedido | APROVADO COM RESSALVAS | Emulador, API | Grava o código, mas a tela promete um link que não chega |
| Recuperação: redefinir com código | APROVADO COM RESSALVAS | API | Funciona e é de uso único, mas o app não tem tela para isso |
| Envio de e-mail | NÃO IMPLEMENTADO | Código | Falta provedor |
| Login com Google | NÃO IMPLEMENTADO | Emulador | Botão só exibe aviso |
| Associação ao capitão, um time por capitão | APROVADO | Emulador, API | |
| Quantidade de jogadores | APROVADO | Emulador, API | |
| Consulta do perfil | APROVADO | Emulador, API | |
| Edição do time | APROVADO COM RESSALVAS | Emulador, API | App edita só o nome |
| Permissões entre equipes | APROVADO | API | |
| Criar anúncio | APROVADO | Emulador, API | |
| Validação do anúncio | APROVADO | Emulador, API | Poucos jogadores e data passada rejeitados na tela |
| Listar e detalhar anúncios | APROVADO | Emulador, API | Oculta o próprio time |
| Editar, pausar, reativar | APROVADO | Emulador, API | |
| Excluir anúncio | APROVADO | Emulador, API | Encerrou a solicitação e avisou o adversário |
| Associação à equipe | APROVADO | API | Time vem do token, não do cliente |
| Estado do anúncio | APROVADO COM RESSALVAS | Código | Sem campo no formulário: usa sempre o estado do time |
| Criar solicitação | APROVADO | Emulador, API | |
| Consultar solicitações, Interessados | APROVADO | Emulador, API | |
| Aceitar de um lado | APROVADO | Emulador, API | Mostra "Aguardando o adversário" |
| Recusar solicitação | APROVADO COM RESSALVAS | API | Sem botão no app |
| Impedir duplicadas | APROVADO | API | |
| Impedir em anúncio encerrado | APROVADO | API | |
| Confirmação pelas duas equipes | APROVADO | Emulador, telas, API | No emulador, o segundo lado foi confirmado pela API |
| Encerrar demais solicitações | APROVADO | API | |
| Anúncio indisponível após confirmar | APROVADO | API | |
| Confirmações simultâneas | APROVADO | API | 10 rodadas paralelas: uma só partida |
| Notificar capitães não selecionados | APROVADO | API | |
| Filtros Sub-15, Sub-17, Sub-19, Livre | APROVADO | API; Sub-15 no emulador | Cada um isolado e combinado |
| Filtros Iniciante, Intermediário, Avançado | APROVADO | API; Avançado no emulador | Independentes da faixa etária |
| Filtros society e quadra | APROVADO COM RESSALVAS | Emulador, API | "Quadra" fica oculto até rolar a linha para o lado |
| Filtros cidade, data, horário | APROVADO | Emulador, API | Combinados: 1 resultado correto |
| Filtro de distância | NÃO IMPLEMENTADO | Código | Campo aparece, mas a API ignora |
| Conversa | APROVADO COM RESSALVAS | Emulador, API | Mensagens persistem, sem tempo real |
| Notificações | APROVADO | Emulador, API | Abrir leva à partida |
| Início com próxima partida | APROVADO | Emulador | |
| Meus jogos e abas | APROVADO | Emulador | Aguardando, Confirmado, Realizado |
| Avaliação | APROVADO | Emulador, API | Critérios vêm do banco |
| Partida realizada, expiração | APROVADO COM RESSALVAS | API, com registros próprios | Suspensas a partir de 08/11 para preservar registros antigos |
| Cancelar partida | APROVADO COM RESSALVAS | API | Botão visível, não acionado no emulador |
| Mapa | APROVADO COM RESSALVAS | Emulador | Ilustrativo |
| Abrir localização | NÃO IMPLEMENTADO | Emulador | Só exibe aviso |
| Placar | NÃO IMPLEMENTADO | Código | |
| Upload de escudo | NÃO IMPLEMENTADO | Código | |
| Execução em celular físico | NÃO TESTADO | — | Depende do firewall e do aparelho |
| Acesso pela rede a partir de outro aparelho | NÃO TESTADO | — | Só testado no próprio computador |

### Pendências do relatório anterior

| Item | Classificação | Estado | Impacto na homologação |
|---|---|---|---|
| E-mail de recuperação | Bloqueada por dependência externa | Código gerado e redefinição prontos na API; faltam provedor e tela do código | Quem esquecer a senha não recupera o acesso. Use contas com senha conhecida |
| Filtro de distância | Não implementada | Banco tem latitude e longitude; API e app não usam | O campo não muda o resultado: não homologar |
| Edição completa do perfil | Parcialmente implementada | API completa; app só edita o nome | Descrição, quantidade e demais campos não testáveis pela tela |
| Registro de placar | Não implementada | Colunas existem; sem rota nem tela | Histórico sem resultado |
| Upload de escudo | Não implementada | Coluna `url_escudo` existe; sem envio | Times usam a sigla |
| Chat em tempo real | Parcialmente implementada | Conversa funcional, sem atualização automática | Para ver mensagem nova, reabra a conversa |

Nenhuma delas exige mudar a estrutura do banco. Nenhuma foi implementada nesta etapa.

## F. Pendências

**Impedem ou limitam a homologação**

1. **Celular físico:** criar a regra de firewall e testar (G.4). Sem regra de entrada para a porta 3000, a conexão deve ser bloqueada.
2. **Rotinas suspensas a partir de 08/11/2026.** Registros criados até `ROTINAS_PRESERVAR_ATE` (`2026-11-05T14:00:00.000Z`, no `.env`) não são alterados: antes de cada rotina, a API verifica se ela tocaria algum deles e, nesse caso, não a executa e registra um aviso no log. Como `proc_expirar_anuncios` e `proc_marcar_partidas_realizadas` são globais, a suspensão vale também para os registros novos. Simulação só de leitura: 0 afetados hoje; 7 anúncios e 3 partidas em 09/11; 10 e 13 em 20/11. **Solução definitiva, que depende de autorização por mudar o banco:** um parâmetro de data de corte nos dois procedimentos.
3. **Cenário de rotinas nos testes:** usa só registros próprios `teste.homologacao`. A partir de 08/11 ele aparece como ignorado (skipped), porque as rotinas estarão suspensas. Sem `ROTINAS_PRESERVAR_ATE`, os testes de integração se recusam a rodar no banco real.
4. **Recuperação de senha** sem saída para o usuário.

**Ressalvas**

5. Primeira abertura depois de instalar, com o emulador recém-ligado: a thread principal travou 38 s e o app mostrou "Não foi possível conectar ao servidor". "Tentar novamente" resolveu, e não se repetiu em 3 aberturas seguintes (4 a 5 s). Observe se ocorre no celular.
6. `zod` com vulnerabilidade alta no `npm audit`. Não atualizei porque a correção muda de versão principal.
7. API com `root`, mantido por decisão sua. Trocar antes de produção.
8. A API aceita qualquer dispositivo da rede local; não exponha a porta 3000 no roteador.
9. Texto: "1 jogos disponíveis", e a recuperação fala em "link", mas o sistema gera código.

## G. Instruções para execução

Comandos em PowerShell. O Flutter não está no PATH, por isso o caminho completo.

**1. MySQL** (início automático; só se estiver parado, em PowerShell de administrador):

```powershell
Get-Service MySQL84
Start-Service MySQL84
```

**2. API:**

```powershell
cd "D:\Joga Contra\Joga-Contra\backend"
npm run dev
```

Confira em `http://localhost:3000/api/health/db`.

**3. Emulador** (segundo terminal):

```powershell
cd "D:\Joga Contra\Joga-Contra"
D:\flutter\bin\flutter emulators --launch Pixel_9_Pro
D:\flutter\bin\flutter run --dart-define-from-file=config/emulador.json
```

**4. Celular físico**

Uma vez, em PowerShell de **administrador**. A regra vale só para rede Privada e sub-rede local:

```powershell
New-NetFirewallRule -DisplayName "Joga Contra API (rede local)" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 3000 -Profile Private -RemoteAddress LocalSubnet
```

Conecte o celular à mesma rede. No navegador dele, abra `http://192.168.100.121:3000/api/health/db`: precisa aparecer `joga_contra_v2`. Ative a Depuração USB, conecte o cabo e rode:

```powershell
cd "D:\Joga Contra\Joga-Contra"
D:\flutter\bin\flutter devices
D:\flutter\bin\flutter run -d ID_DO_CELULAR --dart-define-from-file=config/celular.json
```

**5. APK para instalação manual:**

```powershell
cd "D:\Joga Contra\Joga-Contra"
D:\flutter\bin\flutter build apk --debug --dart-define-from-file=config/celular.json
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" install -r build\app\outputs\flutter-apk\app-debug.apk
```

O arquivo fica em `build\app\outputs\flutter-apk\app-debug.apk` (cerca de 190 MB) e pode ser copiado para o celular. O que está lá agora já é a versão do celular.

