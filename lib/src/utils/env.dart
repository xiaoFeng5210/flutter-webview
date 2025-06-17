enum Environment { dev, prod }

const env = String.fromEnvironment('ENV', defaultValue: 'dev');
const Environment currentEnv = env == 'dev'
    ? Environment.dev
    : Environment.prod;

const String devUrl = 'http://192.168.22.103:8092/';
const String prodUrl = 'http://192.168.22.103:8092/';

String getBaseUrl() {
  if (currentEnv == Environment.dev) {
    return devUrl;
  } else {
    return prodUrl;
  }
}
