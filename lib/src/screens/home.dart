import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webview/src/api/cloud.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends ConsumerState<HomeScreen> {
  final CloudApi _cloudApi = CloudApi();

  @override
  void initState() {
    super.initState();
    _fetchDeviceList();
  }

  Future<void> _fetchDeviceList() async {
    try {
      final response = await _cloudApi.getDeviceList(DeviceListParams(
        integrator: '',
        dealer: '',
        startTime: 0,
        endTime: 0,
        keyword: '',
        sn: '',
        pn: 1,
        ps: 20,
      ));
    debugPrint('Device list: ${response.data.list}');
    } catch (e) {
      // 需要登陆
      debugPrint('Error fetching device list: $e');
      _showLoginDialog();
    }
    
  }



  Future<void> _showLoginDialog() async {
    final TextEditingController usernameController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      // 不允许点击其他地方关闭
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              child: Container(
                padding: const EdgeInsets.all(32),
                width: MediaQuery.of(context).size.width * 0.65,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('登录', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: '用户名',
                        labelStyle: TextStyle(fontSize: 24),
                        hintText: '请输入云平台账号用户名',
                      ),
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: '密码',
                        labelStyle: TextStyle(fontSize: 24),
                        hintText: '请输入云平台账号密码',
                      ),
                      controller: passwordController,
                      obscureText: true,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isLoading)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          )
                        else
                          ElevatedButton(
                            onPressed: () async {
                              final username = usernameController.text.trim();
                              final password = passwordController.text.trim();

                              if (username.isEmpty || password.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('请输入用户名和密码')),
                                );
                                return;
                              }

                              setState(() {
                                isLoading = true;
                              });

                              try {
                                final response = await _cloudApi.signIn(
                                  SignInRequest(
                                    username: username,
                                    password: password,
                                  ),
                                );

                                if (response.isSuccess) {
                                  // 登录成功，关闭对话框并重新获取设备列表
                                  
                                  Navigator.of(dialogContext).pop();
                                  _fetchDeviceList();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(response.message ?? '登录失败'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('登录失败: $e'),
                                  ),
                                );
                              } finally {
                                setState(() {
                                  isLoading = false;
                                });
                              }
                            },
                            child: const Text('登录', style: TextStyle(fontSize: 24)),
                          ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  

  

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("远程访问应用App工具🔧",
        style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blue)),
      ),
      body: SafeArea(child: Column(children: [
      ],))

    );
  }
}
