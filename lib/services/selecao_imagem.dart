import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/time.dart';

/// Falha ao escolher a imagem, com mensagem para o usuário.
class ErroImagem implements Exception {
  const ErroImagem(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}

/// Escolha da foto do time na galeria do aparelho.
abstract final class SelecaoDeImagem {
  /// Substituível nos testes. Devolve nulo quando o usuário cancela.
  static Future<ImagemSelecionada?> Function() selecionar = _daGaleria;

  static Future<ImagemSelecionada?> _daGaleria() async {
    final XFile? arquivo;
    try {
      // Reduz no próprio aparelho: envio rápido e dentro do limite da API.
      arquivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
    } on PlatformException {
      throw const ErroImagem('Não foi possível abrir a galeria de fotos.');
    }
    if (arquivo == null) return null;
    return validar(await arquivo.readAsBytes());
  }

  /// Confere formato e tamanho antes de enviar.
  static ImagemSelecionada validar(Uint8List bytes) {
    final tipo = ImagemSelecionada.tipoDe(bytes);
    if (tipo == null) {
      throw const ErroImagem('Escolha uma imagem JPG, PNG ou WebP.');
    }
    if (bytes.length > ImagemSelecionada.limiteBytes) {
      throw const ErroImagem('A imagem passa de 2 MB. Escolha outra.');
    }
    return ImagemSelecionada(bytes, tipo);
  }
}
