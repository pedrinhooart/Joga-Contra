import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:joga_contra/core/formatters.dart';
import 'package:joga_contra/models/anuncio_partida.dart';
import 'package:joga_contra/models/solicitacao_confronto.dart';
import 'package:joga_contra/repositories/api/api_repositories.dart';
import 'package:joga_contra/repositories/demo/demo_repositories.dart';
import 'package:joga_contra/services/api_client.dart';

void main() {
  group('Regras de solicitação (repositório de demonstração)', () {
    test(
      'confirmar cria partida, encerra o anúncio e as demais solicitações',
      () async {
        final repos = criarRepositoriosDemo();
        // a-uniao (anúncio do meu time) já tem a solicitação pendente s-vila.
        final s = await repos.solicitacoes.confirmar('s-vila');
        expect(s.status, StatusSolicitacao.confirmada);
        expect(s.idPartida, isNotNull);

        final anuncio = await repos.anuncios.obter('a-uniao');
        expect(anuncio.status, StatusAnuncio.encerrado);
        expect(anuncio.aceitaSolicitacoes, isFalse);

        final partida = await repos.partidas.obter(s.idPartida!);
        expect(partida.idSolicitacao, 's-vila');
        expect(partida.timeAnunciante.id, 't-uniao');
      },
    );

    test(
      'não aceita solicitação para anúncio encerrado ou do próprio time',
      () async {
        final repos = criarRepositoriosDemo();
        expect(
          repos.solicitacoes.solicitar('a-uniao-antigo'),
          throwsStateError,
        );
        expect(repos.solicitacoes.solicitar('a-uniao'), throwsStateError);
      },
    );

    test('busca não lista anúncios do próprio time nem encerrados', () async {
      final repos = criarRepositoriosDemo();
      final lista = await repos.anuncios.buscar(const FiltroAnuncios());
      expect(lista.where((a) => a.time.id == 't-uniao'), isEmpty);
      expect(lista.every((a) => a.aceitaSolicitacoes), isTrue);
    });
  });

  group('ApiClient + repositórios da API', () {
    test('desembrulha "data", envia token e query', () async {
      late http.Request recebida;
      final api = ApiClient(
        baseUrl: 'http://api.test/api',
        client: MockClient((req) async {
          recebida = req;
          return http.Response(
            jsonEncode({
              'data': [_anuncioJson],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      )..setToken('abc');
      final lista = await ApiAnuncioRepository(
        api,
      ).buscar(const FiltroAnuncios(idModalidade: 2, texto: 'vila'));
      expect(recebida.url.path, '/api/anuncios');
      expect(recebida.url.queryParameters, {
        'idModalidade': '2',
        'texto': 'vila',
      });
      expect(recebida.headers['Authorization'], 'Bearer abc');
      expect(lista.single.time.nome, 'Vila Nova Futsal');
      expect(lista.single.modalidade.codigo, 'quadra');
      expect(lista.single.valorAluguelPorTime, 120.5);
    });

    test('converte envelope de erro em ApiException', () async {
      var expirou = false;
      final api = ApiClient(
        baseUrl: 'http://api.test/api',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'code': 'UNAUTHORIZED', 'message': 'Token expirado.'},
            }),
            401,
          ),
        ),
      )..onUnauthorized = () => expirou = true;
      await expectLater(
        api.get('/auth/eu'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'Token expirado.')
              .having((e) => e.isUnauthorized, 'isUnauthorized', isTrue),
        ),
      );
      expect(expirou, isTrue);
    });

    test('falha de rede vira ApiException offline', () async {
      final api = ApiClient(
        baseUrl: 'http://api.test/api',
        client: MockClient((_) => throw http.ClientException('sem rede')),
      );
      await expectLater(
        api.get('/referencias'),
        throwsA(
          isA<ApiException>().having((e) => e.isOffline, 'offline', isTrue),
        ),
      );
    });
  });

  group('Formatos', () {
    test('datas, horas e moeda em pt-BR', () {
      final d = DateTime(2026, 7, 18, 16, 5);
      expect(Formatos.dataCurta(d), 'Sáb, 18 jul');
      expect(Formatos.dataLonga(d), 'Sábado, 18 de julho');
      expect(Formatos.hora(d), '16:05');
      expect(Formatos.moeda(120), 'R\$ 120');
      expect(Formatos.moeda(120.5), 'R\$ 120,50');
      expect(Formatos.decimal(4.9), '4,9');
    });

    test('lê data e hora digitadas', () {
      expect(
        Formatos.lerDataHora('18/07/2026', '16:00'),
        DateTime(2026, 7, 18, 16),
      );
      expect(Formatos.lerDataHora('31/02/2026', '16:00'), isNull);
      expect(Formatos.lerDataHora('18-07-2026', '16:00'), isNull);
      expect(Formatos.lerDataHora('18/07/2026', '25:00'), isNull);
    });

    test('sigla do escudo', () {
      expect(Formatos.sigla('União FC'), 'UFC');
      expect(Formatos.sigla('Atlético da Zona Sul'), 'AZS');
    });
  });
}

const _anuncioJson = {
  'idAnuncio': '7d0f6f5e-0000-4000-8000-000000000001',
  'time': {
    'idTime': '7d0f6f5e-0000-4000-8000-000000000002',
    'nome': 'Vila Nova Futsal',
    'cidade': 'São Paulo',
    'siglaEstado': 'SP',
  },
  'modalidade': {'id': 2, 'codigo': 'quadra', 'nome': 'Futebol de quadra'},
  'categoriaEtaria': {'id': 4, 'codigo': 'livre', 'nome': 'Livre'},
  'nivelTecnico': {'id': 2, 'codigo': 'intermediario', 'nome': 'Intermediário'},
  'quantidadeJogadores': 5,
  'dataHoraInicio': '2026-11-08T13:00:00.000Z',
  'cidade': 'São Paulo',
  'siglaEstado': 'SP',
  'nomeLocal': 'Quadra Vila Mariana',
  'valorAluguelPorTime': '120.50',
  'status': 'ativo',
  'totalSolicitacoes': 1,
};
