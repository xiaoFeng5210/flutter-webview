import 'package:flutter/material.dart';

class SampleItemDetailsView extends StatefulWidget {
  const SampleItemDetailsView({super.key});
  static const routeName = '/sample_item';

  @override
  State<SampleItemDetailsView> createState() => _SampleItemDetailsViewState();
}

class _SampleItemDetailsViewState extends State<SampleItemDetailsView> {
  int _counter = 0;

  void _incrementCounter() {
    if (_counter >= 20) {
      return;
    }
    setState(() {
      _counter++;
    });
  }

  // 初始化
  @override
  void initState() {
    print('初始化');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
      ),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Center(
              child: Text(_counter.toString()),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _incrementCounter,
              child: const Text('Increment'),
            ),
          ],
        ),
      ),
    );
  }
}
