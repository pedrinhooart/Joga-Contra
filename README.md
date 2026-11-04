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
| Demonstração (dados fictícios em memória) | padrão em debug e nos testes; `--dart-define=USE_DEMO_DATA=true` | Desenvolvimento de telas sem API |
| API REST | padrão em release; `--dart-define=USE_DEMO_DATA=false` | Dados reais |

URL da API: `--dart-define=API_BASE_URL=http://192.168.0.10:3000/api` (padrão `http://10.0.2.2:3000/api`, emulador Android).

```powershell
flutter run --dart-define=USE_DEMO_DATA=false --dart-define=API_BASE_URL=http://localhost:3000/api
```

## Estrutura

- `lib/screens/`: telas agrupadas por área do produto (só apresentação).
- `lib/widgets/`: marca, escudo, cartões, chips, botões e estados de carregamento/erro.
- `lib/models/`: modelos de domínio e conversão JSON (usuário, time, anúncio, solicitação, partida, notificação, referências).
- `lib/repositories/contratos.dart`: interfaces de acesso a dados usadas pelas telas.
- `lib/repositories/api/`: implementação via API REST.
- `lib/repositories/demo/`: implementação de demonstração (dados fictícios, nunca usada em release por padrão).
- `lib/services/api_client.dart`: cliente HTTP único.
- `lib/state/app_state.dart`: sessão (capitão + time) e cadastros de referência.
- `lib/core/formatters.dart`: formatação pt-BR.
- `lib/theme/`: paleta e tema visual.

A auditoria de dados variáveis, o inventário de entidades e o contrato da API estão em [docs/AUDITORIA_DADOS_DINAMICOS.md](docs/AUDITORIA_DADOS_DINAMICOS.md). A API Express ainda usa o banco antigo; os repositórios de API seguem o contrato planejado para o novo banco. Mensagens em tempo real, mapas, upload de imagens e notificações push dependem de integrações futuras.

## Banco de dados

O modelo MySQL para um backend/API compartilhado com Android e iOS está documentado em [database/DATABASE_DESIGN.md](database/DATABASE_DESIGN.md). O schema, catálogos iniciais e consultas de referência ficam em `database/`.
