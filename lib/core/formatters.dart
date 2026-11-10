/// Formatação pt-BR usada pelas telas. Datas chegam da API em UTC (ISO 8601)
/// e são exibidas no horário local do aparelho.
abstract final class Formatos {
  static const _diasCurtos = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  static const _diasLongos = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];
  static const _mesesCurtos = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun', //
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];
  static const _mesesLongos = [
    'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', //
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
  ];

  static String _dois(int v) => v.toString().padLeft(2, '0');

  /// "Sáb, 18 jul"
  static String dataCurta(DateTime d) {
    final l = d.toLocal();
    return '${_diasCurtos[l.weekday - 1]}, ${l.day} ${_mesesCurtos[l.month - 1]}';
  }

  /// "Sábado, 18 de julho"
  static String dataLonga(DateTime d) {
    final l = d.toLocal();
    final dia = _diasLongos[l.weekday - 1];
    return '${dia.split('-').first}, ${l.day} de ${_mesesLongos[l.month - 1]}';
  }

  /// "Sáb, 18 jul de 2026"
  static String dataComAno(DateTime d) =>
      '${dataCurta(d)} de ${d.toLocal().year}';

  /// "11 jul 2026"
  static String dataHistorico(DateTime d) {
    final l = d.toLocal();
    return '${l.day} ${_mesesCurtos[l.month - 1]} ${l.year}';
  }

  /// "18/07/2026"
  static String dataNumerica(DateTime d) {
    final l = d.toLocal();
    return '${_dois(l.day)}/${_dois(l.month)}/${l.year}';
  }

  /// 90 → "1 h 30 min"; 45 → "45 min"; 120 → "2 h".
  static String duracao(int minutos) {
    final h = minutos ~/ 60, m = minutos % 60;
    if (h == 0) return '$m min';
    return m == 0 ? '$h h' : '$h h $m min';
  }

  /// "16:00"
  static String hora(DateTime d) {
    final l = d.toLocal();
    return '${_dois(l.hour)}:${_dois(l.minute)}';
  }

  /// "R$ 120" / "R$ 120,50"
  static String moeda(num valor) {
    final centavos = (valor * 100).round();
    final reais = centavos ~/ 100, resto = centavos % 100;
    return resto == 0 ? 'R\$ $reais' : 'R\$ $reais,${_dois(resto)}';
  }

  /// "4,9"
  static String decimal(num valor, {int casas = 1}) =>
      valor.toStringAsFixed(casas).replaceAll('.', ',');

  /// "3,2 km"
  static String distancia(double km) => '${decimal(km)} km';

  /// "Há 5 minutos", "Há 1 hora", "Ontem", "18/07"
  static String relativo(DateTime d, {DateTime? agora}) {
    final now = agora ?? DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'Agora';
    if (diff.inMinutes < 60) {
      return 'Há ${diff.inMinutes} minuto${diff.inMinutes == 1 ? '' : 's'}';
    }
    if (diff.inHours < 24) {
      return 'Há ${diff.inHours} hora${diff.inHours == 1 ? '' : 's'}';
    }
    if (diff.inDays == 1) return 'Ontem';
    final l = d.toLocal();
    return '${_dois(l.day)}/${_dois(l.month)}';
  }

  /// Hora da última mensagem na lista de conversas: "14:32" hoje, "Ontem", "18/07".
  static String horaOuDia(DateTime d, {DateTime? agora}) {
    final now = (agora ?? DateTime.now()).toLocal();
    final l = d.toLocal();
    if (l.year == now.year && l.month == now.month && l.day == now.day) {
      return hora(l);
    }
    return relativo(d, agora: agora) == 'Ontem'
        ? 'Ontem'
        : '${_dois(l.day)}/${_dois(l.month)}';
  }

  /// Converte "18/07/2026" + "16:00" em DateTime local. Retorna null se inválido.
  static DateTime? lerDataHora(String data, String hora) {
    final d = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(data.trim());
    final h = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hora.trim());
    if (d == null || h == null) return null;
    final dia = int.parse(d[1]!),
        mes = int.parse(d[2]!),
        ano = int.parse(d[3]!);
    final hh = int.parse(h[1]!), mm = int.parse(h[2]!);
    if (mes < 1 || mes > 12 || hh > 23 || mm > 59) return null;
    final result = DateTime(ano, mes, dia, hh, mm);
    return result.day == dia ? result : null;
  }

  /// Iniciais para escudo sem imagem: "União FC" -> "UFC", "Real Amigos" -> "RA".
  static String sigla(String nome) {
    final partes = nome
        .split(RegExp(r'\s+'))
        .where(
          (p) =>
              p.isNotEmpty &&
              !const {
                'da',
                'de',
                'do',
                'das',
                'dos',
                'e',
              }.contains(p.toLowerCase()),
        )
        .toList();
    if (partes.isEmpty) return '';
    if (partes.length == 1) {
      final p = partes.first;
      return (p.length <= 4 ? p : p.substring(0, 3)).toUpperCase();
    }
    final s = partes
        .map((p) => p.length <= 2 && p == p.toUpperCase() ? p : p[0])
        .join();
    return (s.length > 4 ? s.substring(0, 4) : s).toUpperCase();
  }
}
