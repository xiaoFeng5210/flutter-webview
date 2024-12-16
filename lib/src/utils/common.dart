import 'dart:async';

Timer startPolling() {
  Duration interval = const Duration(seconds: 2);
  return Timer.periodic(interval, (timer) async {
    print('polling');
  });
}
