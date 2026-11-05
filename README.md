# Joga Contra — Android

Primeira versão mobile em Flutter baseada no protótipo exportado do Figma Make. A análise das telas, navegação, estilo e assets está em [PROTOTYPE_ANALYSIS.md](PROTOTYPE_ANALYSIS.md).

## Executar

```powershell
flutter pub get
flutter run
```

Para gerar o APK de depuração:

```powershell
flutter build apk --debug
```

O arquivo gerado fica em `build/app/outputs/flutter-apk/app-debug.apk`.

### Fonte de dados

| Modo | Como ativar | Uso |
|---|---|---|
| API REST | **padrão** | Dados reais do banco `joga_contra_v2` |
| Demonstração (dados fictícios em memória) | somente com `--dart-define=USE_DEMO_DATA=true` | Ver telas sem API |

A URL da API fica em `config/emulador.json` e `config/celular.json` (se o IP do computador mudar, edite só esse arquivo). A API precisa estar rodando: veja [backend/README.md](backend/README.md). Passo a passo em [docs/HOMOLOGACAO_JOGA_CONTRA.md](docs/HOMOLOGACAO_JOGA_CONTRA.md).

```powershell
flutter run --dart-define-from-file=config/emulador.json
flutter run -d ID_DO_CELULAR --dart-define-from-file=config/celular.json
```

Testes contra uma API rodando (gravam dados fictícios):

```powershell
flutter test test/integracao_api_test.dart test/integracao_telas_test.dart --dart-define=API_TESTE_URL=http://127.0.0.1:3000/api
```

## Estrutura

- `lib/screens/`: telas agrupadas por área do produto (só apresentação).
- `lib/widgets/`: marca, escudo, cartões, chips, botões e estados de carregamento/erro.
- `lib/models/`: modelos de domínio e conversão JSON (usuário, time, anúncio, solicitação, partida, notificação, referências).
- `lib/repositories/contratos.dart`: interfaces de acesso a dados usadas pelas telas.
- `lib/repositories/api/`: implementação via API REST.
- `lib/repositories/demo/`: implementação de demonstração (dados fictícios, só com `USE_DEMO_DATA=true`).
- `lib/services/api_client.dart`: cliente HTTP único.
- `lib/services/armazenamento_sessao.dart`: guarda o token no armazenamento seguro do sistema.
- `lib/state/app_state.dart`: sessão (capitão + time) e cadastros de referência.
- `lib/core/formatters.dart`: formatação pt-BR.
- `lib/theme/`: paleta e tema visual.

A integração entre app, API e banco está em [docs/INTEGRACAO_JOGA_CONTRA_V2.md](docs/INTEGRACAO_JOGA_CONTRA_V2.md). Mensagens em tempo real, mapas, upload de imagens e notificações push dependem de integrações futuras.

## Banco de dados

O banco oficial é `joga_contra_v2`, documentado em [database_v2/README.md](database_v2/README.md). A pasta `database/` guarda o projeto antigo, sem uso pela API.
