import 'package:flutter/material.dart';
import '../models/time.dart';
import '../theme/app_theme.dart';

/// Prévia da nova foto do time. "Salvar foto" envia e mostra o progresso;
/// se o envio falhar, a mensagem aparece aqui e a foto atual continua valendo.
/// Fecha com `true` quando a foto foi salva.
class DialogoFotoTime extends StatefulWidget {
  const DialogoFotoTime({
    super.key,
    required this.imagem,
    required this.enviar,
  });

  final ImagemSelecionada imagem;
  final Future<void> Function() enviar;

  @override
  State<DialogoFotoTime> createState() => _DialogoFotoTimeState();
}

class _DialogoFotoTimeState extends State<DialogoFotoTime> {
  bool _enviando = false;
  String? _erro;

  Future<void> _salvar() async {
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await widget.enviar();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _erro = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nova foto do time'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mesmo formato do escudo exibido no app.
        Container(
          width: 140,
          height: 154,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2E8),
            border: Border.all(color: const Color(0xFFD5E1D4)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Image.memory(
            widget.imagem.bytes,
            fit: BoxFit.cover,
            semanticLabel: 'Prévia da nova foto do time',
            errorBuilder: (context, erro, pilha) => const Center(
              child: Icon(Icons.broken_image_outlined, color: AppColors.muted),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _erro ?? 'É assim que os outros times vão ver o seu escudo.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: _erro == null ? AppColors.muted : const Color(0xFFC62828),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _enviando ? null : () => Navigator.pop(context, false),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _enviando ? null : _salvar,
        child: _enviando
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.muted,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('Enviando…'),
                ],
              )
            : Text(_erro == null ? 'Salvar foto' : 'Tentar de novo'),
      ),
    ],
  );
}
