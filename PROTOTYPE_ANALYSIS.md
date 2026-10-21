# Análise do protótipo Joga Contra

Referência: ZIP `Joga Contra Mobile App Design(1).zip`, projeto React/Vite exportado pelo Figma Make. A implementação de referência está em `prototype-source/src/App.tsx` e `prototype-source/src/index.css`.

## Telas e navegação identificadas

- **Início**: saudação, banner de destaque, pesquisa, criação de anúncio, próxima partida confirmada, estatísticas e jogos próximos.
- **Buscar adversário**: busca por time/cidade/local, filtros por modalidade, data, distância, categoria e nível, cards de jogos, estado vazio e atalho para o mapa.
- **Detalhes do jogo**: dados do jogo e do time, descrição, verificação e ação “Tenho interesse”.
- **Anunciar jogo**: formulário dividido em “Como vai ser o jogo?” e “Quando e onde?”, publicação e confirmação.
- **Conversas** e **Conversa**: lista de times interessados, mensagens, compartilhamento de localização/imagem e resumo para confirmar a partida.
- **Partida confirmada**: confronto, data, horário, endereço, ações de localização/conversa e cancelamento.
- **Meus jogos**: abas Todos, Aguardando, Negociando, Confirmado, Realizado e Cancelado; ações levam a anúncio, conversa, confirmação ou avaliação.
- **Meus anúncios**: criação, edição, pausar/reativar, interessados e exclusão com confirmação.
- **Perfil do time**: escudo, modalidade/categoria/nível, apresentação, contato, histórico, métricas, avaliação, edição e saída.
- **Notificações**: quatro itens demonstrativos que abrem conversa, partida, conversas ou anúncios.
- **Mapa de jogos**: mapa ilustrativo de São Paulo com marcadores selecionáveis e lista de jogos próximos.
- **Avaliar partida**: quatro critérios de 1 a 5 estrelas, comentário e validação antes do envio.
- **Entrar**, **Criar conta** e **Recuperar acesso**: autenticação de demonstração, cadastro em duas etapas e aviso de recuperação.

Rota principal: Início → Buscar → Detalhes → Interesse → Conversa → Confirmar → Partida confirmada. Rotas paralelas: Início → Anunciar → Meus anúncios; Início → Meus jogos → Avaliar; navegação geral por menu lateral no desktop e barra inferior no celular. O ZIP inicia em Início e não contém onboarding.

## Componentes, estados e comportamento

Componentes repetidos: marca e selo do time; botão primário/contornado/perigo; chips de modalidade/status; cards de jogo; campos rotulados; painéis; avatar/escudo; estado vazio; modal de confirmação; toast; barra de navegação.

Estados do protótipo: filtro ativo e nenhum resultado; anúncio ativo/pausado/vazio; jogo aguardando/negociando/confirmado/realizado/cancelado; chat com mensagens; estrelas selecionadas; cadastro etapa 1/2; loading breve após autenticação; modais de interesse, confirmar, cancelar, apagar e editar perfil.

## Identidade visual observada

- Verde principal `#123D2B`; verde escuro lateral `#103927`; lima `#C3F35A`; verde de ação `#297243`.
- Fundo `#F6F8F6`; texto `#222B26`; secundário `#818982`; borda `#E8ECE8`; alerta `#C64343`.
- Fontes do protótipo: DM Sans; título condensado do banner: Barlow Condensed. Cantos moderados (aprox. 7–13 px), bordas claras e sombras discretas. Barra inferior em telas estreitas; menu lateral de 232 px no desktop.
- Interface em português brasileiro. Ícones SVG lineares; escudos desenhados por CSS.

## Assets e substituições

O ZIP não contém diretório de imagens, fontes, logo ou escudos individuais. Os escudos são CSS com iniciais e ícones. Banner e capa do perfil apontam para fotografia do Unsplash (`photo-1522778119026-d647f0596c20`), mas o arquivo de imagem não acompanha o ZIP e a URL falhou ao validar no ambiente de build. Como solução temporária, banner e capa usam linhas de campo vetoriais no mesmo verde escuro. Ícones e escudos foram reconstruídos com recursos Flutter nativos. DM Sans e Barlow Condensed não vieram no ZIP; Roboto é a substituta temporária.

## Limites do mock

Busca, filtros, seleção do mapa, mensagens, formulários, anúncios, avaliação e confirmação ficam no estado local da sessão. Login, recuperação de senha, Google, envio de notificações, geolocalização/mapas reais, upload, comunicação em tempo real, persistência e dados de times exigiriam backend ou integração de serviços. O cadastro Flutter reúne em uma tela os campos que o protótipo organiza em duas etapas, e a edição de perfil permite atualizar o nome do time. O mapa da referência é ilustrativo. Datas e estatísticas são fixas no protótipo. A revisão visual no emulador ficou limitada por uma janela de “System UI não está respondendo” do próprio Android; os testes Flutter passaram e o processo do app iniciou.
