import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Busca dados assíncronos e exibe os estados de carregamento, erro e conteúdo.
/// O estado "sem dados" é responsabilidade do `builder`, que usa `EmptyState`
/// com a mensagem própria de cada tela.
class Carregador<T> extends StatefulWidget {
  const Carregador({
    super.key,
    required this.carregar,
    required this.builder,
    this.padding = const EdgeInsets.fromLTRB(18, 22, 18, 26),
  });

  final Future<T> Function() carregar;
  final Widget Function(BuildContext context, T dados, VoidCallback recarregar)
  builder;
  final EdgeInsets padding;

  @override
  State<Carregador<T>> createState() => _CarregadorState<T>();
}

class _CarregadorState<T> extends State<Carregador<T>> {
  late Future<T> _future = widget.carregar();

  void _recarregar() => setState(() => _future = widget.carregar());

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(color: AppColors.green),
          ),
        );
      }
      if (snap.hasError) {
        return ListView(
          padding: widget.padding,
          children: [
            ErroCarregamento(mensagem: '${snap.error}', onTentar: _recarregar),
          ],
        );
      }
      return widget.builder(context, snap.data as T, _recarregar);
    },
  );
}

class ErroCarregamento extends StatelessWidget {
  const ErroCarregamento({super.key, required this.mensagem, this.onTentar});
  final String mensagem;
  final VoidCallback? onTentar;
  @override
  Widget build(BuildContext context) => EmptyState(
    title: 'A bola não chegou.',
    message: mensagem,
    action: onTentar == null
        ? null
        : TextButton(
            onPressed: onTentar,
            child: const Text('Tentar novamente'),
          ),
  );
}
