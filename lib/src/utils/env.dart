import 'dart:io';

enum Environment { dev, prod }

const env = String.fromEnvironment('ENV', defaultValue: 'dev');
const Environment currentEnv =
    env == 'dev' ? Environment.dev : Environment.prod;

const String devUrl = 'http://192.168.4.31:3000/';
const String prodUrl = 'http://192.168.2.103';

String getBaseUrl() {
  if (currentEnv == Environment.dev) {
    return devUrl;
  } else {
    return prodUrl;
  }
}
