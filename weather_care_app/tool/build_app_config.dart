import 'dart:convert';
import 'dart:io';

Map<String, dynamic> buildAppConfig(
  Map<String, dynamic> config, {
  required String? buildMode,
}) {
  if (buildMode != 'debug') {
    return {'SERVER_URL': 'https://weather-api.codesoha.com'};
  }
  return config;
}

void main(List<String> arguments) {
  final input = arguments.singleWhere((arg) => arg.startsWith('--input='));
  final output = arguments.singleWhere((arg) => arg.startsWith('--output='));
  final config = jsonDecode(
    File(input.substring('--input='.length)).readAsStringSync(encoding: utf8),
  ) as Map<String, dynamic>;
  final result = buildAppConfig(
    config,
    buildMode: Platform.environment['FLUTTER_BUILD_MODE'],
  );
  File(output.substring('--output='.length)).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(result)}\n',
    encoding: utf8,
  );
}
