enum Environment { dev, prod }

const env = String.fromEnvironment('ENV', defaultValue: 'dev');
const Environment currentEnv = env == 'dev'
    ? Environment.dev
    : Environment.prod;

// const String devUrl =
//     'https://virtual-man.xfyun.cn/interact_web/common/wxh5/185638559309500416#%20%20%20%E5%8F%91%E5%B8%83%E6%97%A5%E6%9C%9F:%20%202025-05-27%2014:42:08%20%20%20%E5%8F%91%E5%B8%83%E6%9C%89%E6%95%88%E6%9C%9F:%20%20%E6%B0%B8%E4%B9%85%E6%9C%89%E6%95%88';

const String devUrl = 'https://man.lebai.ltd/static/MiniLive_new.html';
const String prodUrl = 'http://192.168.22.103:8092/';

String getBaseUrl() {
  if (currentEnv == Environment.dev) {
    return devUrl;
  } else {
    return devUrl;
  }
}
