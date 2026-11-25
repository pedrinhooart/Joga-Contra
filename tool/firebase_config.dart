// Gera android/app/src/main/res/values/firebase.xml (fora do Git) a partir do
// google-services.json baixado do Firebase Console:
//
//   dart run tool/firebase_config.dart [caminho/do/google-services.json]
//
// São os mesmos recursos que o plugin com.google.gms.google-services gera no
// build. Com eles, o Firebase nativo inicia junto com o processo do app —
// inclusive quando o Android o acorda para entregar um push com o app fechado.
// Só vai a identificação pública do app Android (a mesma que fica dentro de
// qualquer APK). A conta de serviço é outra coisa e fica só no servidor
// (FIREBASE_CREDENCIAIS no backend/.env).
import 'dart:convert';
import 'dart:io';

const pacote = 'com.jogacontra.joga_contra';
const destino = 'android/app/src/main/res/values/firebase.xml';

void main(List<String> args) {
  final origem = File(
    args.isEmpty ? 'android/app/google-services.json' : args.first,
  );
  if (!origem.existsSync()) {
    stderr.writeln(
      'Não encontrei ${origem.path}. Baixe o google-services.json do app Android '
      '($pacote) no Firebase Console > Configurações do projeto.',
    );
    exit(1);
  }
  final json = jsonDecode(origem.readAsStringSync()) as Map<String, dynamic>;
  final projeto = json['project_info'] as Map<String, dynamic>;
  final clientes = (json['client'] as List).cast<Map<String, dynamic>>();
  final cliente = clientes.firstWhere(
    (c) => c['client_info']?['android_client_info']?['package_name'] == pacote,
    orElse: () {
      stderr.writeln(
        'O google-services.json não tem o app Android "$pacote". '
        'Registre o app com esse nome de pacote no Firebase Console.',
      );
      exit(1);
    },
  );
  final valores = {
    'google_app_id': cliente['client_info']['mobilesdk_app_id'],
    'google_api_key': (cliente['api_key'] as List).first['current_key'],
    'gcm_defaultSenderId': projeto['project_number'],
    'project_id': projeto['project_id'],
    'google_storage_bucket': projeto['storage_bucket'],
  };
  for (final obrigatoria in [
    'google_app_id',
    'google_api_key',
    'gcm_defaultSenderId',
    'project_id',
  ]) {
    if ('${valores[obrigatoria] ?? ''}'.isEmpty) {
      stderr.writeln('google-services.json incompleto ($obrigatoria).');
      exit(1);
    }
  }
  final linhas = [
    for (final e in valores.entries)
      if ('${e.value ?? ''}'.isNotEmpty)
        '    <string name="${e.key}" translatable="false">'
            '${const HtmlEscape().convert('${e.value}')}</string>',
  ];
  File(destino).writeAsStringSync(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<!-- Gerado por tool/firebase_config.dart a partir do google-services.json. Fora do Git. -->\n'
    '<resources>\n${linhas.join('\n')}\n</resources>\n',
  );
  stdout.writeln(
    '$destino gerado para o projeto ${valores['project_id']}. Gere o APK de novo.',
  );
}
