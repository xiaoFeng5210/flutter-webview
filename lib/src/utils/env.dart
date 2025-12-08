import 'url_config.dart';

enum Environment { dev, prod }

const env = String.fromEnvironment('ENV', defaultValue: 'dev');
const Environment currentEnv = env == 'dev'
    ? Environment.dev
    : Environment.prod;

Future<String> getBaseUrl() async {
  final url = await UrlConfig.getUrl();
  // 确保 URL 尾部有斜杠
  return url.endsWith('/') ? url : '$url/';
}
