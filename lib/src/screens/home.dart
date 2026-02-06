import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webview/src/api/cloud.dart';
import 'package:flutter_webview/src/store/home_notifier.dart';
import 'dart:convert';
import 'package:flutter_webview/src/utils/url_config.dart';
import 'package:flutter_webview/src/screens/webview.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends ConsumerState<HomeScreen> {
  final CloudApi _cloudApi = CloudApi();
  List<Device> _deviceList = [];
  int _currentPage = 1; // 当前页码，从1开始
  int _total = 0; // 总记录数
  static const int _pageSize = 20; // 每页大小

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDeviceList();
  }

  @override
  void dispose() {
    super.dispose();
    usernameController.dispose();
    passwordController.dispose();
  }

  /// 分段打印长字符串，避免 debugPrint 截断
  void _printLongString(String message) {
    const int chunkSize = 800;
    for (int i = 0; i < message.length; i += chunkSize) {
      final end = (i + chunkSize < message.length) ? i + chunkSize : message.length;
      debugPrint(message.substring(i, end));
    }
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
        pn: _currentPage,
        ps: _pageSize,
      ));
      if (response.code == 0) {
        final jsonStr = jsonEncode(response.data.list.map((device) => device.toJson()).toList());
        _printLongString('Device list: $jsonStr');
        setState(() {
          _deviceList = response.data.list;
          _total = response.data.total;
        });
      }
    } catch (e) {
      // 需要登陆
      debugPrint('Error fetching device list: $e');
      _showLoginDialog();
    }
    
  }

  /// 计算总页数
  int get _totalPages {
    if (_total == 0) return 1;
    return (_total / _pageSize).ceil();
  }

  /// 上一页
  void _previousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
      });
      _fetchDeviceList();
    }
  }

  /// 下一页
  void _nextPage() {
    if (_currentPage < _totalPages) {
      setState(() {
        _currentPage++;
      });
      _fetchDeviceList();
    }
  }



  Future<void> _showLoginDialog() async {
    

    final homeNotifier = ref.read(homeProvider.notifier);
    usernameController.text = homeNotifier.state.username;
    passwordController.text = homeNotifier.state.password;
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
                              }   isLoading = true;
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
  /// 显示进入App的确认对话框
  Future<void> _showConfirmDialog(Device device) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(32),
            width: MediaQuery.of(context).size.width * 0.5,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '确认进入',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Text(
                  '设备ID: ${device.id}',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 12),
                Text(
                  '门店名称: ${device.dealerName}',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 12),
                Text(
                  '请确认设备是否开机并且联网, 还需确认该设备管理员是否配置过nginx代理',
                  style: TextStyle(fontSize: 20, color: Colors.amber[700]),
                ),
                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                      child: const Text(
                        '取消',
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 24),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        try {
                          final response = await _cloudApi.getFrpcMachine(FrpcMachineRequest(deviceid: device.id));
                          if (response.code == 0) {
                            final webviewUrl = '${response.data}/lebaiapp/';
                            debugPrint('webviewUrl: $webviewUrl');
                            UrlConfig.webviewUrl = webviewUrl;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => WebViewScreen()),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('获取FRPC机器信息失败: $e', style: TextStyle(fontSize: 20, color: Colors.white)),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 5),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        '确认进入',
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 截取字符串，如果超过指定长度则截取并添加省略号
  String _truncateString(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("云迹煮面远程访问应用App工具🔧",
        style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blue)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _currentPage = 1; // 重置到第一页
                    });
                    _fetchDeviceList();
                  },
                  child: const Text('获取设备列表', style: TextStyle(fontSize: 22)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 分页控件
            if (_total > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _currentPage > 1 ? _previousPage : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('上一页', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 24),
                    Text(
                      '第 $_currentPage / $_totalPages 页 (共 $_total 条)',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 24),
                    ElevatedButton(
                      onPressed: _currentPage < _totalPages ? _nextPage : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('下一页', style: TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: _deviceList.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无设备数据',
                        style: TextStyle(fontSize: 20, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _deviceList.length,
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      itemBuilder: (context, index) {
                        final device = _deviceList[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '设备ID: ${device.id}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Text(
                                      '门店名称: ',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _truncateString(device.dealerName, 30),
                                        style: const TextStyle(fontSize: 18),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Text(
                                      '状态: ',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: device.online
                                            ? Colors.green
                                            : Colors.grey,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        device.online ? '在线' : '离线',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: ElevatedButton(
                              onPressed: () {
                                _showConfirmDialog(device);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('进入App',
                                style: TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
