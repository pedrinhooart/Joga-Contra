import '../models/game.dart';

class MockRepository {
  static const games = <Game>[
    Game(
      id: 1,
      name: 'Real Amigos FC',
      crest: 'RA',
      sport: 'Futebol',
      category: 'Livre',
      city: 'São Paulo, SP',
      date: 'Sáb, 18 jul',
      time: '16:00',
      place: 'Campo do Ibirapuera',
      level: 'Intermediário',
      distance: '3,2 km',
      home: 'Jogo em casa',
    ),
    Game(
      id: 2,
      name: 'Vila Nova Futsal',
      crest: 'VILA',
      sport: 'Futsal',
      category: 'Livre',
      city: 'São Paulo, SP',
      date: 'Dom, 19 jul',
      time: '10:00',
      place: 'Quadra Vila Mariana',
      level: 'Intermediário',
      distance: '4,8 km',
      home: 'Casa ou fora',
    ),
    Game(
      id: 3,
      name: 'Atlético da Zona Sul',
      crest: 'AC',
      sport: 'Futebol',
      category: 'Sub-20',
      city: 'São Paulo, SP',
      date: 'Sáb, 18 jul',
      time: '09:00',
      place: 'Campo Santo Amaro',
      level: 'Avançado',
      distance: '6,1 km',
      home: 'Jogo fora',
    ),
    Game(
      id: 4,
      name: 'Resenha Esporte Clube',
      crest: 'EC',
      sport: 'Futebol',
      category: 'Veterano',
      city: 'São Paulo, SP',
      date: 'Dom, 19 jul',
      time: '08:30',
      place: 'Arena da Saúde',
      level: 'Recreativo',
      distance: '7,5 km',
      home: 'Casa ou fora',
    ),
  ];

  static const notifications = [
    (
      'Tem rival querendo jogo!',
      'O time Real Amigos demonstrou interesse no seu anúncio.',
      'Há 5 minutos',
      'chat',
    ),
    (
      'Pode chamar a equipe.',
      'Sua partida contra o Real Amigos FC foi confirmada.',
      'Há 30 minutos',
      'confirmed',
    ),
    (
      'A conversa tá rolando.',
      'Você recebeu uma nova mensagem de Vila Nova Futsal.',
      'Há 1 hora',
      'conversations',
    ),
    (
      'Seu anúncio está próximo de expirar.',
      'Atualize a disponibilidade para continuar encontrando adversários.',
      'Ontem',
      'ads',
    ),
  ];
}
