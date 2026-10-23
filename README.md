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

## Estrutura

- `lib/screens/`: telas agrupadas por área do produto.
- `lib/widgets/`: marca, escudo, cartões, chips e botões reutilizáveis.
- `lib/models/`: modelos locais.
- `lib/repositories/`: dados mockados que podem ser substituídos por um repositório remoto.
- `lib/theme/`: paleta e tema visual.

As interações são demonstrativas e os dados ficam apenas em memória durante a sessão. Autenticação, persistência, mensagens em tempo real, mapas e envio de notificações dependem de integrações futuras.

## Banco de dados

O modelo MySQL para um backend/API compartilhado com Android e iOS está documentado em [database/DATABASE_DESIGN.md](database/DATABASE_DESIGN.md). O schema, catálogos iniciais e consultas de referência ficam em `database/`.
