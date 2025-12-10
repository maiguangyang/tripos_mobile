import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io'; // For Platform check

import 'package:flutter/services.dart';
import 'package:tripos_mobile/tripos_mobile.dart';
import 'package:tripos_mobile/tripos_mobile_platform_interface.dart';
import 'package:permission_handler/permission_handler.dart';

// Constants for the app
class AppConstants {
  static const double defaultPaymentAmount = 1.31; // 低于 $10 离线限额
  static const String defaultApplicationId = '1001';
  static const String defaultApplicationName = 'FlutterExample';
  static const String defaultApplicationVersion = '1.0.0';
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // ✨ Use the public TriposMobile API (recommended)
  final _triposPlugin = TriposMobile();

  // GlobalKey for ScaffoldMessenger
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

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
  // ✨ 演示：监听 triPOS SDK 发送的实时事件
  void _setupEventListeners() {
    // 使用新的 TriposMobile.events API
    _eventSubscription = _triposPlugin.events.listen(
      (event) {
        _log(
          '${DateTime.now().toIso8601String()} [SDK EVENT] Type: ${event.type} | Msg: ${event.message}',
        );

        setState(() {
          // 根据事件类型更新UI
          switch (event.type) {
            case 'message':
            case 'displayMessage':
              // SDK 要求显示提示 (如 "请插卡", "输入密码")
              _statusMessage = event.message ?? '';
              print("message1111111 ${event.message}");
              break;
            case 'readyForCard':
              _statusMessage =
                  event.message ?? 'Reader ready - please tap/insert/swipe';
              _showSnackBar(_statusMessage, isError: false);
              break;
            case 'connected':
              _statusMessage = 'Device Connected!';
              break;
            case 'disconnected':
              _statusMessage = 'Device Disconnected';
              _connectedDevice = null;
              break;
            case 'error':
              _statusMessage = 'Error: ${event.message}';
              break;
            default:
              _statusMessage = event.message ?? 'Unknown event';
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
    // Check if running on iOS simulator
    if (Platform.isIOS) {
      // iOS simulator doesn't support Bluetooth
      // On real device, permissions will be requested automatically
      _log('ℹ️  Running on iOS - permissions handled by system');
      return true; // Skip permission check on iOS
    }

    final permissionList = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ];
    // Android 13+ needs通知权限以启动前台服务，否则SDK警告并缩短侦测时间
    permissionList.add(Permission.notification);

    Map<Permission, PermissionStatus> statuses = await permissionList.request();

    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted) {
      _log('❌ Bluetooth permissions denied');
      _log('请在系统设置中授予蓝牙和位置权限');

      // Show dialog to guide user
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('需要权限'),
            content: const Text(
              '此应用需要以下权限才能扫描设备：\n'
              '• 蓝牙扫描\n'
              '• 蓝牙连接\n'
              '• 位置信息\n\n'
              '请在系统设置中手动授予这些权限。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings(); // Open app settings
                },
                child: const Text('打开设置'),
              ),
            ],
          ),
        );
      }
    } else {
      _log('✅ Bluetooth permissions granted');
    }

    return allGranted;
  }

  // 2. 初始化 SDK (使用 PDF 文档对应的配置参数)
  Future<void> _initializeSdk() async {
    setState(() => _isLoading = true);
    try {
      // 替换为你的 Worldpay 测试账号信息
      final config = TriposConfiguration(
        acceptorId: '874767787', // 从 Worldpay 门户获取
        accountId: '1091187', // 从 Worldpay 门户获取
        accountToken:
            'D59509CCCA5068F9B5D231EAC735B84348CDE8F861B8D5A8BF82B847749B0EB824175F01', // 从 Worldpay 门户获取
        applicationId: AppConstants.defaultApplicationId,
        applicationName: AppConstants.defaultApplicationName,
        applicationVersion: AppConstants.defaultApplicationVersion,
        // Offline payment configuration
        storeMode: 'Auto', // Auto, Manual, or Disabled
        offlineAmountLimit: 50.00, // $50 limit for offline transactions
        retentionDays: 7, // Keep offline transactions for 7 days
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
    bool permissionsGranted = await _requestBluetoothPermissions();
    if (!permissionsGranted && Platform.isAndroid) {
      // Only block on Android if permissions denied
      // iOS handles permissions automatically
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
      _log('Error: No device connected');
      _showSnackBar('请先连接设备');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Starting Transaction...';
    });

    try {
      // 调用后，SDK 会通过 EventStream 发送 "Please Insert Card"
      // 这里 await 的结果是最终交易结束的结果
      final response = await _triposPlugin.processPayment(
        PaymentRequest(
          amount: AppConstants.defaultPaymentAmount,
          // 可选：配置交易元数据字段
          laneNumber: '1', // 收银通道号
          referenceNumber:
              'REF_${DateTime.now().millisecondsSinceEpoch}', // 参考号
          clerkNumber: '001', // 收银员编号
          shiftID: '1', // 班次ID
        ),
      );

      _log('Transaction Finished.');
      _log('Approved: ${response.isApproved}');
      _log('Auth Code: ${response.authCode ?? "N/A"}');
      _log('Trans ID: ${response.transactionId}');
      _log('Amount: ${response.amount ?? "N/A"}');
      if (response.isOffline) {
        _log(
          '⚠️  OFFLINE: Transaction stored locally and will be forwarded when online',
        );
      }

      setState(() {
        if (response.isOffline) {
          _statusMessage = response.isApproved
              ? '💾 STORED OFFLINE (Will forward when online)'
              : 'PAYMENT DECLINED';
        } else {
          _statusMessage = response.isApproved
              ? 'PAYMENT APPROVED!'
              : 'PAYMENT DECLINED';
        }
      });

      if (response.isApproved) {
        _showSnackBar('✅ 支付成功！金额：\$${response.amount}', isError: false);
      } else {
        _showSnackBar('❌ 支付失败：${response.message}', isError: true);
      }
    } catch (e) {
      _log('Payment Error: $e');
      setState(() => _statusMessage = 'Payment Error Occurred');
      _showSnackBar('支付错误：$e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 6. 断开连接
  Future<void> _disconnect() async {
    setState(() => _isLoading = true);
    try {
      await _triposPlugin.disconnect();
      setState(() {
        _connectedDevice = null;
        _statusMessage = 'Disconnected';
      });
      _log('Device disconnected successfully');
      _showSnackBar('设备已断开', isError: false);
    } catch (e) {
      _log('Disconnect Error: $e');
      _showSnackBar('断开连接失败: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Helper: Show SnackBar
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey, // Add ScaffoldMessengerKey
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
          label: Text('3. Pay \$${AppConstants.defaultPaymentAmount}'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
          ),
          onPressed: _isLoading || _connectedDevice == null
              ? null
              : _processPayment,
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.bluetooth_disabled),
          label: const Text('Disconnect'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
          onPressed: _isLoading || _connectedDevice == null
              ? null
              : _disconnect,
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
