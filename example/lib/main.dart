import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:tripos_mobile/tripos_mobile_platform_interface.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // 插件实例
  // 假设你在 lib/tripos_mobile.dart 中暴露了 platform interface
  // 或者你可以直接使用 TriposMobilePlatform.instance
  final _triposPlugin = TriposMobilePlatform.instance;

  String _platformVersion = 'Unknown';
  bool _isInitialized = false;
  bool _isLoading = false;

  // 设备列表与连接状态
  List<TriposDevice> _devices = [];
  TriposDevice? _connectedDevice;

  // 实时日志与 UI 提示
  String _logs = '';
  String _statusMessage = 'Ready'; // 用于显示 "请插卡" 等 SDK 提示

  // 事件流订阅
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    _setupEventListeners();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  // 1. 设置事件监听 (核心：接收 SDK 的 UI 交互请求)
  void _setupEventListeners() {
    _eventSubscription = _triposPlugin.events.listen(
      (event) {
        _log('[SDK EVENT] Type: ${event.type} | Msg: ${event.message}');

        setState(() {
          if (event.type == 'message' || event.type == 'displayMessage') {
            // SDK 要求显示提示 (如 "请插卡", "输入密码")
            _statusMessage = event.message ?? '';
          } else if (event.type == 'connected') {
            _statusMessage = 'Device Connected!';
          } else if (event.type == 'error') {
            _statusMessage = 'Error: ${event.message}';
          }
        });
      },
      onError: (error) {
        _log('Event Stream Error: $error');
      },
    );
  }

  Future<void> initPlatformState() async {
    String platformVersion;
    try {
      platformVersion = await _triposPlugin.getPlatformVersion() ?? 'Unknown';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }
    if (!mounted) return;
    setState(() {
      _platformVersion = platformVersion;
    });
  }

  void _log(String message) {
    debugPrint(message);
    setState(() {
      _logs = '${DateTime.now().toString().split('.').last}: $message\n$_logs';
    });
  }

  // Request Bluetooth permissions for Android 12+
  Future<bool> _requestBluetoothPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted) {
      _log('Bluetooth permissions denied');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('需要蓝牙权限才能扫描设备。请在设置中授予权限。'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }

    return allGranted;
  }

  // 2. 初始化 SDK (使用 PDF 文档对应的配置参数)
  Future<void> _initializeSdk() async {
    setState(() => _isLoading = true);
    try {
      // 替换为你的 Worldpay 测试账号信息
      final config = TriposConfiguration(
        acceptorId: 'YOUR_ACCEPTOR_ID', // 从 Worldpay 门户获取
        accountId: 'YOUR_ACCOUNT_ID', // 从 Worldpay 门户获取
        accountToken: 'YOUR_ACCOUNT_TOKEN', // 从 Worldpay 门户获取
        applicationId: '1001',
        applicationName: 'FlutterExample',
        applicationVersion: '1.0.0',
      );

      await _triposPlugin.initialize(config);

      setState(() => _isInitialized = true);
      _log('SDK Initialized successfully');
      _statusMessage = 'SDK Initialized. Ready to scan.';
    } catch (e) {
      _log('Error initializing SDK: $e');
      _statusMessage = 'Initialization Failed';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 3. 扫描设备
  Future<void> _scanDevices() async {
    // Request permissions first
    final hasPermission = await _requestBluetoothPermissions();
    if (!hasPermission) {
      _log('Bluetooth permissions not granted');
      return;
    }

    setState(() {
      _isLoading = true;
      _devices = [];
      _statusMessage = 'Scanning for Bluetooth devices...';
    });

    try {
      final devices = await _triposPlugin.scanDevices();
      setState(() => _devices = devices);
      _log('Found ${devices.length} devices');
      _statusMessage = 'Found ${devices.length} devices.';
    } catch (e) {
      _log('Scan Error: $e');
      _statusMessage = 'Scan Failed. Check Permissions.';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 4. 连接设备
  Future<void> _connectDevice(TriposDevice device) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to ${device.name}...';
    });

    try {
      final success = await _triposPlugin.connectDevice(device);
      if (success) {
        // 注意：实际连接成功通常由 EventStream 中的 'connected' 事件确认
        setState(() => _connectedDevice = device);
        _log('Connect command sent to ${device.name}');
      } else {
        _log('Connect command failed');
        _statusMessage = 'Connection Failed';
      }
    } catch (e) {
      _log('Connection Error: $e');
      _statusMessage = 'Connection Error';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 5. 发起交易
  Future<void> _processPayment() async {
    if (_connectedDevice == null) {
      _log('No device connected');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Starting Transaction...';
    });

    try {
      final request = PaymentRequest(amount: 1.00, currencyCode: 'USD');

      // 调用后，SDK 会通过 EventStream 发送 "Please Insert Card"
      // 这里 await 的结果是最终交易结束的结果
      final response = await _triposPlugin.processPayment(request);

      _log('Transaction Finished.');
      _log('Approved: ${response.isApproved}');
      _log('Auth Code: ${response.authCode}');
      _log('Trans ID: ${response.transactionId}');

      setState(() {
        _statusMessage = response.isApproved
            ? 'PAYMENT APPROVED!'
            : 'PAYMENT DECLINED';
      });
    } catch (e) {
      _log('Payment Error: $e');
      setState(() => _statusMessage = 'Payment Error Occurred');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        appBar: AppBar(title: const Text('triPOS Mobile v4.4 Demo')),
        body: Column(
          children: [
            // 状态栏面板
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              color: Colors.blueGrey.shade100,
              child: Column(
                children: [
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  Text('System: $_platformVersion | Init: $_isInitialized'),
                ],
              ),
            ),
            const Divider(height: 1),

            // 操作按钮区
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildControls(),
            ),
            const Divider(),

            // 设备列表区
            Expanded(
              flex: 2,
              child: _devices.isEmpty
                  ? const Center(child: Text("No devices. Init SDK -> Scan."))
                  : _buildDeviceList(),
            ),
            const Divider(),

            // 日志区
            Container(
              height: 150,
              width: double.infinity,
              color: Colors.black87,
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                child: Text(
                  _logs,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: 'Courier',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Wrap(
      spacing: 10.0,
      runSpacing: 10.0,
      alignment: WrapAlignment.center,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.settings),
          label: const Text('1. Init SDK'),
          onPressed: _isLoading || _isInitialized ? null : _initializeSdk,
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.bluetooth),
          label: const Text('2. Scan'),
          onPressed: _isLoading || !_isInitialized ? null : _scanDevices,
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.payment),
          label: const Text('3. Pay \$1.00'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
          ),
          onPressed: _isLoading || _connectedDevice == null
              ? null
              : _processPayment,
        ),
      ],
    );
  }

  Widget _buildDeviceList() {
    return ListView.builder(
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        final isConnected = _connectedDevice?.identifier == device.identifier;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: Icon(
              Icons.point_of_sale,
              color: isConnected ? Colors.green : Colors.grey,
            ),
            title: Text(device.name),
            subtitle: Text(device.identifier),
            trailing: isConnected
                ? const Chip(
                    label: Text("Connected"),
                    backgroundColor: Colors.greenAccent,
                  )
                : OutlinedButton(
                    onPressed: _isLoading ? null : () => _connectDevice(device),
                    child: const Text('Connect'),
                  ),
          ),
        );
      },
    );
  }
}
