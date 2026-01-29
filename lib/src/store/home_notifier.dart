import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeProvider = NotifierProvider<HomeNotifier, Home>(HomeNotifier.new);


class Home {
  final String username;
  final String password;

  Home({
    required this.username,
    required this.password,
  });
}

class HomeNotifier extends Notifier<Home> {
  @override
  Home build() {
    return Home(
      username: '',
      password: '',
    );
  }
}
