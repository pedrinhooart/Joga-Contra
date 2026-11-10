/// Usuário autenticado. No Joga Contra todo usuário cadastrado é capitão de um
/// time; os demais integrantes não possuem conta.
/// A senha nunca é armazenada nem devolvida pela API.
class Usuario {
  const Usuario({
    required this.id,
    required this.nome,
    required this.email,
    this.telefone,
    this.urlFoto,
    this.cidade,
    this.siglaEstado,
  });

  final String id;
  final String nome, email;
  final String? telefone, urlFoto, cidade, siglaEstado;

  String get primeiroNome => nome.trim().split(RegExp(r'\s+')).first;
  String get inicial =>
      nome.trim().isEmpty ? '?' : nome.trim()[0].toUpperCase();

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
    id: json['idUsuario'] as String,
    nome: json['nome'] as String,
    email: json['email'] as String,
    telefone: json['telefone'] as String?,
    urlFoto: json['urlFoto'] as String?,
    cidade: json['cidade'] as String?,
    siglaEstado: json['siglaEstado'] as String?,
  );
}

/// Dados enviados em `POST /auth/cadastro`: cria o usuário (capitão) e o time.
/// Modalidade, categoria, nível e quantidade de cada jogo ficam no anúncio.
class CadastroCapitao {
  const CadastroCapitao({
    required this.nome,
    required this.email,
    required this.senha,
    required this.nomeTime,
    required this.cidade,
    required this.siglaEstado,
  });

  final String nome, email, senha;
  final String nomeTime;
  final String cidade, siglaEstado;

  Map<String, dynamic> toJson() => {
    'usuario': {
      'nome': nome,
      'email': email,
      'senha': senha,
      'cidade': cidade,
      'siglaEstado': siglaEstado,
    },
    'time': {'nome': nomeTime, 'cidade': cidade, 'siglaEstado': siglaEstado},
  };
}
