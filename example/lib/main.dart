import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tripos_mobile/tripos_mobile.dart';

import 'stored_transactions_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'triPOS Mobile Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const TriposHomePage(),
    );
  }
}

class TriposHomePage extends StatefulWidget {
  const TriposHomePage({super.key});

  @override
  State<TriposHomePage> createState() => _TriposHomePageState();
}

class _TriposHomePageState extends State<TriposHomePage> {
  final _tripos = TriposMobile();
  final _amountController = TextEditingController(text: '0.01');
  final _transactionIdController = TextEditingController();

  static const applicationMode = ApplicationMode.production;

  // Test credentials
  static const acceptorId = 'xxxx';
  static const accountId = 'xxxx';
  static const token = 'xxxx';

  String _sdkVersion = 'Unknown';
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _isConnecting = false; // 标记是否正在连接设备
  bool _transactionJustCompleted = false; // 标记交易刚完成，防止设备事件覆盖状态
  String _status = 'Not initialized';
  String _lastTransactionId = '';
  List<String> _devices = [];
  String? _selectedDevice;
  String _transactionResult = '';

  // Separated API mode (NEW)
  bool _useSeparatedApi = false; // Toggle between combined and separated API
  bool _isSdkOnlyInitialized =
      false; // SDK initialized but device not connected

  StreamSubscription<VtpStatus>? _statusSubscription;
  StreamSubscription<DeviceEvent>? _deviceEventSubscription;

  // Configuration for scanning - use specific device type as SDK requires it
  TriposConfiguration get _configuration => TriposConfiguration(
    hostConfiguration: const HostConfiguration(
      acceptorId: acceptorId,
      accountId: accountId,
      accountToken: token,
      applicationId: '8414',
      applicationName: 'triPOS Flutter Example',
      applicationVersion: '1.0.0',
    ),
    deviceConfiguration: DeviceConfiguration(
      // SDK requires specific device type for scanning
      deviceType: DeviceType.ingenicoMoby5500,
      identifier: _selectedDevice,
      terminalId: '1234',
      contactlessAllowed: true,
      keyedEntryAllowed: true,
    ),
    applicationConfiguration: const ApplicationConfiguration(
      // applicationMode: ApplicationMode.testCertification,
      applicationMode: applicationMode,
      idlePrompt: 'triPOS Flutter',
    ),
  );

  /// Auto-detect device type based on device name
  DeviceType _detectDeviceType(String? deviceName) {
    if (deviceName == null || deviceName.isEmpty) {
      return DeviceType.ingenicoMoby5500; // Default fallback
    }
    final lower = deviceName.toLowerCase();
    if (lower.contains('mob55') ||
        lower.contains('moby55') ||
        lower.contains('5500')) {
      return DeviceType.ingenicoMoby5500;
    }
    if (lower.contains('mob85') ||
        lower.contains('moby85') ||
        lower.contains('8500')) {
      return DeviceType.ingenicoMoby8500;
    }
    if (lower.contains('lane3') || lower.contains('3000')) {
      return DeviceType.lane3000;
    }
    if (lower.contains('lane5')) {
      return DeviceType.lane5000;
    }
    if (lower.contains('lane7')) {
      return DeviceType.lane7000;
    }
    if (lower.contains('lane8')) {
      return DeviceType.lane8000;
    }
    if (lower.contains('chipper') || lower.contains('bbpos')) {
      return DeviceType.bbposChipper2XBT;
    }
    // Default to Moby5500 if no match
    return DeviceType.ingenicoMoby5500;
  }

  // Configuration for initialization (auto-detects device type from name)
  TriposConfiguration get _initConfiguration => TriposConfiguration(
    hostConfiguration: const HostConfiguration(
      acceptorId: acceptorId,
      accountId: accountId,
      accountToken: token,
      applicationId: '8414',
      applicationName: 'triPOS Flutter Example',
      applicationVersion: '1.0.0',
    ),
    deviceConfiguration: DeviceConfiguration(
      // Auto-detect device type based on selected device name
      deviceType: _detectDeviceType(_selectedDevice),
      identifier: _selectedDevice,
      terminalId: '1234',
      contactlessAllowed: true,
      keyedEntryAllowed: true,
    ),
    applicationConfiguration: const ApplicationConfiguration(
      applicationMode: applicationMode,
      idlePrompt: 'triPOS Flutter',
    ),
    // Re-enable Store-and-Forward for now (SSL/timeout issue prevents online mode)
    storeAndForwardConfiguration: const StoreAndForwardConfiguration(
      storingTransactionsAllowed:
          true, // Allow offline transactions while SSL issue is resolved
      shouldTransactionsBeAutomaticallyForwarded: true,
    ),
  );

  @override
  void initState() {
    super.initState();
    _initPlugin();
  }

  Future<void> _initPlugin() async {
    final version = await _tripos.getSdkVersion();
    final initialized = await _tripos.isInitialized();

    setState(() {
      _sdkVersion = version ?? 'Unknown';
      _isInitialized = initialized;
      _status = initialized ? 'Initialized' : 'Not initialized';
    });

    // Listen to status updates (使用 VtpStatus 枚举)
    _statusSubscription = _tripos.statusStream.listen((status) {
      setState(() {
        // 正在连接时，忽略 VtpStatus.none，保持显示 "正在连接设备..."
        if (_isConnecting && status == VtpStatus.none) {
          return;
        }
        _status = _formatVtpStatus(status);
      });
    });

    // Listen to device events (now type-safe with DeviceEvent)
    _deviceEventSubscription = _tripos.deviceEventStream.listen((event) {
      // 交易刚完成后，忽略设备事件，防止覆盖交易结果状态
      if (_transactionJustCompleted) {
        print('Ignoring device event after transaction: ${event.type}');
        return;
      }

      print("deviceEventStream-marlon $event");

      // setState(() {
      //   switch (event.type) {
      //     case DeviceEventType.connecting:
      //       _status = '正在连接设备...';
      //       _showSnackBar('Connecting to device...');
      //     case DeviceEventType.connected:
      //       _status = '设备已连接: ${event.model ?? "未知设备"}';
      //       _showSnackBar('Device connected: ${event.model}');
      //     case DeviceEventType.disconnected:
      //       _status = '设备已断开';
      //       _showSnackBar('Device disconnected');
      //     case DeviceEventType.error:
      //       _status = '设备错误';
      //       _showSnackBar('Device error: ${event.message}', isError: true);
      //     case DeviceEventType.ready:
      //       _status = '设备就绪';
      //       _showSnackBar('Device ready');
      //     case DeviceEventType.unknown:
      //       break;
      //   }
      // });
    });
  }

  /// 将 VtpStatus 枚举转换为可读的中文状态文本
  String _formatVtpStatus(VtpStatus status) {
    return switch (status) {
      // 基础状态
      VtpStatus.none => '无',
      VtpStatus.initializing => '正在初始化...',
      VtpStatus.deinitializing => '正在反初始化...',
      VtpStatus.done => '完成',
      VtpStatus.unknown => '未知状态',

      // 运行状态 - 交易类型
      VtpStatus.runningHealthCheck => '正在健康检查...',
      VtpStatus.runningSale => '正在执行销售...',
      VtpStatus.runningRefund => '正在执行退款...',
      VtpStatus.runningAuthorization => '正在执行授权...',
      VtpStatus.runningAuthorizationWithToken => '正在执行令牌授权...',
      VtpStatus.runningVoid => '正在执行作废...',
      VtpStatus.runningReturn => '正在执行退货...',
      VtpStatus.runningSaleWithToken => '正在执行令牌销售...',
      VtpStatus.runningRefundWithToken => '正在执行令牌退款...',
      VtpStatus.runningReversal => '正在执行撤销...',
      VtpStatus.runningCreditCardAdjustment => '正在调整信用卡...',
      VtpStatus.runningAuthorizationCompletion => '正在完成授权...',
      VtpStatus.runningIncrementalAuthorization => '正在增量授权...',
      VtpStatus.runningManuallyForward => '正在手动转发...',
      VtpStatus.runningHostedPaymentSale => '正在托管支付销售...',
      VtpStatus.runningHostedPaymentAuthorization => '正在托管支付授权...',

      // 礼品卡相关
      VtpStatus.runningGiftCardActivate => '正在激活礼品卡...',
      VtpStatus.runningGiftCardBalanceInquiry => '正在查询礼品卡余额...',
      VtpStatus.runningGiftCardReload => '正在充值礼品卡...',
      VtpStatus.runningGiftCardClose => '正在关闭礼品卡...',
      VtpStatus.runningGiftCardBalanceTransferRequest => '正在转账礼品卡...',
      VtpStatus.runningGiftCardUnloadRequest => '正在卸载礼品卡...',
      VtpStatus.runningGiftCardBalanceTransfer => '正在礼品卡余额转账...',

      // Token 相关
      VtpStatus.runningCreateToken => '正在创建令牌...',
      VtpStatus.runningCreateTokenWithTransactionId => '正在创建交易令牌...',

      // EBT 相关
      VtpStatus.runningEbtBalanceInquiry => '正在查询 EBT 余额...',
      VtpStatus.runningEbtVoucher => '正在处理 EBT 凭证...',

      // 获取输入状态
      VtpStatus.gettingCardInput => '请刷卡/插卡...',
      VtpStatus.gettingCardInputTapInsertSwipe => '请刷卡/插卡/NFC...',
      VtpStatus.gettingCardInputInsertSwipe => '请插卡/刷卡...',
      VtpStatus.gettingCardInputTapSwipe => '请NFC/刷卡...',
      VtpStatus.gettingCardInputSwipe => '请刷卡...',
      VtpStatus.gettingPaymentType => '请选择支付方式...',
      VtpStatus.gettingEbtType => '请选择 EBT 类型...',
      VtpStatus.gettingConvenienceFeeAmountConfirmation => '请确认手续费...',
      VtpStatus.gettingWantTip => '是否添加小费?',
      VtpStatus.gettingTipSelection => '请选择小费金额...',
      VtpStatus.gettingTipEntry => '请输入小费...',
      VtpStatus.gettingSurchargeFeeAmountConfirmation => '请确认附加费...',
      VtpStatus.gettingWantCashback => '是否需要现金返还?',
      VtpStatus.gettingCashbackSelection => '请选择现金返还金额...',
      VtpStatus.gettingCashbackEntry => '请输入现金返还金额...',
      VtpStatus.gettingPostalCode => '请输入邮编...',
      VtpStatus.gettingTotalAmountConfirmation => '请确认总金额...',
      VtpStatus.gettingPin => '请输入 PIN 码...',
      VtpStatus.gettingContinuingEmvTransaction => '继续 EMV 交易...',
      VtpStatus.gettingFinalizingEmvTransaction => '正在完成 EMV 交易...',

      // 处理状态
      VtpStatus.processingCardInput => '正在处理卡片...',
      VtpStatus.sendingToHost => '正在发送到主机...',
      VtpStatus.transactionProcessing => '交易处理中...',
      VtpStatus.finalizing => '正在最终处理...',

      // 卡片读取失败
      VtpStatus.chipReadFailed => '芯片读取失败',
      VtpStatus.swipeReadFailed => '刷卡读取失败',
      VtpStatus.chipCardSwipedReadFailed => '芯片卡刷卡读取失败',
      VtpStatus.failedToRetrieveCardData => '无法获取卡片数据',
      VtpStatus.cardDataRetrievalTimeOut => '卡片数据读取超时',
      VtpStatus.enableCardKeyedOnlyInput => '请手动输入卡号',

      // PIN 状态
      VtpStatus.pinOK => 'PIN 码正确',
      VtpStatus.reEnterPin => '请重新输入 PIN 码',
      VtpStatus.lastPinTry => '最后一次 PIN 码尝试',
      VtpStatus.pinEnteredSuccessfully => 'PIN 码输入成功',
      VtpStatus.pinEntryCancelled => 'PIN 码输入已取消',

      // 卡片状态
      VtpStatus.removeCard => '请移除卡片',
      VtpStatus.cardRemoved => '卡片已移除',

      // 交易结果状态
      VtpStatus.transactionCancelled => '交易已取消',

      // 选择状态
      VtpStatus.selectApplication => '请选择应用程序',

      // 非接触式状态
      VtpStatus.contactlessReadNotSupportedByCard => '卡片不支持非接触式读取',
      VtpStatus.contactlessAmountMaxLimitExceeded => '金额超过非接触式限额',
      VtpStatus.multipleCardsTappedError => '检测到多张卡片',
      VtpStatus.contactlessReadFailed => '非接触式读取失败',
      VtpStatus.contactlessTapsMaxNumberExceeded => '非接触式刷卡次数超限',
      VtpStatus.contactlessCardNotSupportedNoMatchingAID => '卡片不支持',
      VtpStatus.contactlessCardRequestsInterfaceSwitch => '请更换读卡方式',

      // 显示状态
      VtpStatus.showingDccInfo => '显示 DCC 信息',
      VtpStatus.pleaseSeePhone => '请查看手机',

      // 确认状态
      VtpStatus.amountConfirmed => '金额已确认',
      VtpStatus.surchargeFeeAmountConfirmed => '附加费已确认',
      VtpStatus.surchargeFeeAmountDeclined => '附加费已拒绝',
      VtpStatus.surchargeFeeAmountTimedOut => '附加费确认超时',
      VtpStatus.cashbackUnsupportedCard => '卡片不支持现金返还',
    };
  }

  /// 将 TransactionStatus 转换为可读的中文状态文本
  String _formatTransactionStatus(TransactionStatus status) {
    return switch (status) {
      TransactionStatus.approved => '✅ 交易已批准',
      TransactionStatus.partiallyApproved => '⚠️ 部分批准',
      TransactionStatus.approvedExceptCashback => '✅ 已批准（现金返还除外）',
      TransactionStatus.approvedByMerchant => '📦 离线交易待转发',
      TransactionStatus.callIssuer => '📞 需联系发卡行',
      TransactionStatus.declined => '❌ 交易被拒绝',
      TransactionStatus.needsToBeReversed => '🔄 需要撤销',
      TransactionStatus.dccRequested => '💱 DCC 请求',
      TransactionStatus.error => '❌ 交易错误',
      TransactionStatus.unknown => '❓ 未知状态',
    };
  }

  @override
  void dispose() {
    _amountController.dispose();
    _transactionIdController.dispose();
    _statusSubscription?.cancel();
    _deviceEventSubscription?.cancel();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  /// Request all necessary permissions for Bluetooth scanning
  Future<bool> _requestPermissions() async {
    setState(() {
      _status = 'Requesting permissions...';
    });

    // Request Bluetooth permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    // Check if all permissions are granted
    bool allGranted = true;
    List<String> deniedPermissions = [];

    if (statuses[Permission.bluetoothScan]?.isDenied == true) {
      deniedPermissions.add('Bluetooth Scan');
      allGranted = false;
    }
    if (statuses[Permission.bluetoothConnect]?.isDenied == true) {
      deniedPermissions.add('Bluetooth Connect');
      allGranted = false;
    }
    if (statuses[Permission.location]?.isDenied == true) {
      deniedPermissions.add('Location');
      allGranted = false;
    }

    if (!allGranted) {
      _showSnackBar(
        'Missing permissions: ${deniedPermissions.join(", ")}. Please enable in Settings.',
        isError: true,
      );

      // Show dialog to open settings
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permissions Required'),
            content: Text(
              'The following permissions are required:\n\n'
              '• Bluetooth Scan\n'
              '• Bluetooth Connect\n'
              '• Location\n\n'
              'Please enable them in Settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
      return false;
    }

    return true;
  }

  Future<void> _scanDevices() async {
    setState(() {
      _isLoading = true;
      _status = 'Checking permissions...';
    });

    // Request permissions first
    final hasPermissions = await _requestPermissions();
    if (!hasPermissions) {
      setState(() {
        _isLoading = false;
        _status = 'Permissions denied';
      });
      return;
    }

    setState(() {
      _status = 'Scanning for devices...';
    });

    try {
      // Devices are already filtered and sorted at native level (payment devices first)
      final devices = await _tripos.scanBluetoothDevices(_configuration);

      // Count payment devices (for display purposes)

      final paymentCount = devices.length;

      setState(() {
        _devices = devices;
        _status = 'Found ${devices.length} device(s) ($paymentCount payment)';

        // Auto-select first device if available (payment devices are at front)
        if (devices.isNotEmpty && _selectedDevice == null) {
          _selectedDevice = devices.first;
        }
      });

      if (devices.isEmpty) {
        _showSnackBar('No devices found. Make sure your device is powered on.');
      } else if (paymentCount > 0) {
        _showSnackBar('Found $paymentCount payment device(s)');
      }
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('permission') || errorMsg.contains('Permission')) {
        _showSnackBar(
          'Missing permissions. Please enable in Settings.',
          isError: true,
        );
      } else {
        _showSnackBar('Scan error: $e', isError: true);
      }
      setState(() {
        _status = 'Scan failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _initialize() async {
    if (_selectedDevice == null) {
      _showSnackBar('Please select a device first');
      return;
    }

    setState(() {
      _isLoading = true;
      _isConnecting = true; // 标记开始连接
      // _status = '正在连接设备...';
    });

    try {
      // Use initConfiguration with specific device type for initialization
      final success = await _tripos.initialize(_initConfiguration);
      setState(() {
        _isInitialized = success;
        _isConnecting = false; // 连接结束
        _status = success ? '设备已连接' : '连接失败';
      });

      if (success) {
        _showSnackBar('SDK initialized successfully');
      } else {
        _showSnackBar('Failed to initialize SDK', isError: true);
      }
    } catch (e) {
      _showSnackBar('Init error: $e', isError: true);
      setState(() {
        _isConnecting = false; // 连接结束
        _status = '连接失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Connect to a specific device
  Future<void> _connectToDevice(String device) async {
    setState(() {
      _selectedDevice = device;
    });
    await _initialize();
  }

  Future<void> _deinitialize() async {
    setState(() {
      _isLoading = true;
      _status = 'Deinitializing...';
    });

    try {
      await _tripos.deinitialize();
      setState(() {
        _isInitialized = false;
        _status = 'Not initialized';
      });
      _showSnackBar('SDK deinitialized');
    } catch (e) {
      _showSnackBar('Deinit error: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ============= Separated API Methods (NEW) =============

  /// Initialize SDK only (without connecting to device)
  /// This is the first step in the separated API flow
  Future<void> _initSdkOnly() async {
    setState(() {
      _isLoading = true;
      _status = '正在初始化 SDK...';
    });

    try {
      final result = await _tripos.initializeSdk(_configuration);
      final success = result['success'] == true;

      setState(() {
        _isSdkOnlyInitialized = success;
        _status = success ? 'SDK 已初始化 (设备未连接)' : 'SDK 初始化失败';
      });

      if (success) {
        _showSnackBar('SDK initialized (device not connected)');
      } else {
        _showSnackBar(
          'Failed to initialize SDK: ${result['message']}',
          isError: true,
        );
      }
    } catch (e) {
      print("_initSdkOnly-marlon ${e.toString()}");
      _showSnackBar('SDK init error: $e', isError: true);
      setState(() {
        _status = 'SDK 初始化失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Connect to device only (after SDK is initialized)
  /// This is the second step in the separated API flow
  Future<void> _connectDeviceOnly(String device) async {
    if (!_isSdkOnlyInitialized) {
      _showSnackBar('Please initialize SDK first');
      return;
    }

    setState(() {
      _selectedDevice = device;
      _isLoading = true;
      _isConnecting = true;
      // _status = '正在连接设备...';
    });

    try {
      final deviceType = _detectDeviceType(device);
      final result = await _tripos.connectDevice(
        device,
        deviceType: deviceType,
      );
      final success = result['success'] == true;

      setState(() {
        _isInitialized = success;
        _isConnecting = false;
        _status = success ? '设备已连接: ${result['model'] ?? device}' : '设备连接失败';
      });

      print("_connectDeviceOnly-marlon $result");

      if (success) {
        _showSnackBar('Device connected: ${result['model']}');
      } else {
        _showSnackBar('Connection failed: ${result['message']}', isError: true);
      }
    } catch (e) {
      print("object-marlon ${e.toString()}");
      _showSnackBar('Connection error: $e', isError: true);
      setState(() {
        _isConnecting = false;
        _status = '连接失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Disconnect device only (keep SDK initialized)
  Future<void> _disconnectDeviceOnly() async {
    setState(() {
      _isLoading = true;
      _status = '正在断开设备...';
    });

    try {
      final result = await _tripos.disconnectDevice();
      final success = result['success'] == true;

      setState(() {
        _isInitialized = false;
        _status = success ? 'SDK 已初始化 (设备未连接)' : '断开失败';
      });

      if (success) {
        _showSnackBar('Device disconnected (SDK still initialized)');
      }
    } catch (e) {
      print("_disconnectDeviceOnly-marlon ${e.toString()}");
      _showSnackBar('Disconnect error: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ============= End Separated API Methods =============

  Future<void> _processSale() async {
    if (!_isInitialized) {
      _showSnackBar('Please initialize SDK first');
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      _showSnackBar('Please enter a valid amount');
      return;
    }

    setState(() {
      _isLoading = true;
      _transactionResult = '';
    });

    try {
      final response = await _tripos.processSale(
        SaleRequest(
          transactionAmount: amount,
          referenceNumber: DateTime.now().millisecondsSinceEpoch.toString(),
        ),
      );

      setState(() {
        _transactionResult = _formatTransactionResult(
          'Sale',
          response.isApproved,
          response.transactionStatus.name,
          response.approvedAmount,
          response.host?.transactionId,
          response.host?.authCode,
          response.card?.maskedCardNumber,
          response.errorMessage,
          expressResponseCode: response.host?.expressResponseCode,
          expressResponseMessage: response.host?.expressResponseMessage,
          hostResponseCode: response.host?.hostResponseCode,
          hostResponseMessage: response.host?.hostResponseMessage,
        );

        if (response.isApproved && response.host?.transactionId != null) {
          _lastTransactionId = response.host!.transactionId!;
          _transactionIdController.text = _lastTransactionId;
        }
      });

      // 设置标志防止设备事件立即覆盖状态
      _transactionJustCompleted = true;

      // 短暂显示交易结果状态，然后恢复到设备状态
      setState(() {
        _status = _formatTransactionStatus(response.transactionStatus);
      });

      // 2秒后恢复到设备状态
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _transactionJustCompleted = false;
            // 恢复到设备就绪状态（因为交易完成说明设备是正常的）
            _status = '设备就绪';
          });
        }
      });

      if (response.isApproved) {
        _showSnackBar('Sale approved!');
      } else {
        _showSnackBar(
          'Sale declined: ${response.errorMessage ?? response.transactionStatus.name}',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Sale error: $e', isError: true);
      _transactionJustCompleted = false;
      setState(() {
        _transactionResult = 'Error: $e';
        _status = '交易错误';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _processRefund() async {
    if (!_isInitialized) {
      _showSnackBar('Please initialize SDK first');
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      _showSnackBar('Please enter a valid amount');
      return;
    }

    setState(() {
      _isLoading = true;
      _transactionResult = '';
    });

    try {
      final response = await _tripos.processRefund(
        RefundRequest(
          transactionAmount: amount,
          referenceNumber: DateTime.now().millisecondsSinceEpoch.toString(),
        ),
      );

      setState(() {
        _transactionResult = _formatTransactionResult(
          'Refund',
          response.isApproved,
          response.transactionStatus.name,
          response.approvedAmount,
          response.host?.transactionId,
          response.host?.authCode,
          response.card?.maskedCardNumber,
          response.errorMessage,
        );
      });

      if (response.isApproved) {
        _showSnackBar('Refund approved!');
      } else {
        _showSnackBar('Refund declined', isError: true);
      }
    } catch (e) {
      _showSnackBar('Refund error: $e', isError: true);
      setState(() {
        _transactionResult = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Linked refund using original transaction ID (no card required)
  Future<void> _processLinkedRefund() async {
    if (!_isInitialized) {
      _showSnackBar('Please initialize SDK first');
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      _showSnackBar('Please enter a valid amount');
      return;
    }

    final transactionId = _transactionIdController.text.trim();
    if (transactionId.isEmpty) {
      _showSnackBar('Please enter a Transaction ID for linked refund');
      return;
    }

    setState(() {
      _isLoading = true;
      _transactionResult = '';
    });

    try {
      final response = await _tripos.processLinkedRefund(
        LinkedRefundRequest(
          transactionId: transactionId,
          transactionAmount: amount,
          referenceNumber: DateTime.now().millisecondsSinceEpoch.toString(),
        ),
      );

      setState(() {
        _transactionResult = _formatTransactionResult(
          'Linked Refund',
          response.isApproved,
          response.transactionStatus.name,
          response.approvedAmount,
          response.host?.transactionId,
          response.host?.authCode,
          response.card?.maskedCardNumber,
          response.errorMessage,
        );
      });

      if (response.isApproved) {
        _showSnackBar('Linked refund approved!');
      } else {
        _showSnackBar(
          'Linked refund declined: ${response.errorMessage ?? response.transactionStatus.name}',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Linked refund error: $e', isError: true);
      setState(() {
        _transactionResult = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _processVoid() async {
    if (!_isInitialized) {
      _showSnackBar('Please initialize SDK first');
      return;
    }

    final transactionId = _transactionIdController.text.trim();
    if (transactionId.isEmpty) {
      _showSnackBar('Please enter a transaction ID to void');
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;

    setState(() {
      _isLoading = true;
      _transactionResult = '';
    });

    try {
      final response = await _tripos.processVoid(
        VoidRequest(
          transactionId: transactionId,
          transactionAmount: amount,
          referenceNumber: DateTime.now().millisecondsSinceEpoch.toString(),
        ),
      );

      setState(() {
        _transactionResult = _formatTransactionResult(
          'Void',
          response.isApproved,
          response.transactionStatus.name,
          response.approvedAmount,
          response.host?.transactionId,
          response.host?.authCode,
          null,
          response.errorMessage,
        );
      });

      if (response.isApproved) {
        _showSnackBar('Void approved!');
      } else {
        _showSnackBar('Void declined', isError: true);
      }
    } catch (e) {
      _showSnackBar('Void error: $e', isError: true);
      setState(() {
        _transactionResult = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelTransaction() async {
    try {
      await _tripos.cancelTransaction();
      _showSnackBar('Transaction cancelled');
    } catch (e) {
      _showSnackBar('Cancel error: $e', isError: true);
    }
  }

  String _formatTransactionResult(
    String type,
    bool isApproved,
    String status,
    double? amount,
    String? transactionId,
    String? authCode,
    String? maskedCard,
    String? errorMessage, {
    String? expressResponseCode,
    String? expressResponseMessage,
    String? hostResponseCode,
    String? hostResponseMessage,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('=== $type Result ===');
    buffer.writeln('Status: ${isApproved ? "APPROVED" : "DECLINED"}');
    buffer.writeln('Transaction Status: $status');
    if (amount != null)
      buffer.writeln('Amount: \$${amount.toStringAsFixed(2)}');
    if (transactionId != null) buffer.writeln('Transaction ID: $transactionId');
    if (authCode != null) buffer.writeln('Auth Code: $authCode');
    if (maskedCard != null) buffer.writeln('Card: $maskedCard');

    // Show detailed error info for declined transactions
    if (!isApproved) {
      if (expressResponseCode != null)
        buffer.writeln('Express Code: $expressResponseCode');
      if (expressResponseMessage != null)
        buffer.writeln('Express Message: $expressResponseMessage');
      if (hostResponseCode != null)
        buffer.writeln('Host Code: $hostResponseCode');
      if (hostResponseMessage != null)
        buffer.writeln('Host Message: $hostResponseMessage');
    }

    if (errorMessage != null) buffer.writeln('Error: $errorMessage');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('triPOS Mobile Example'),
        actions: [
          if (_isInitialized) ...[
            IconButton(
              icon: const Icon(Icons.storage),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        StoredTransactionsPage(tripos: _tripos),
                  ),
                );
              },
              tooltip: '离线交易',
            ),
            IconButton(
              icon: const Icon(Icons.power_settings_new),
              onPressed: _isLoading ? null : _deinitialize,
              tooltip: 'Deinitialize',
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('SDK Status', style: theme.textTheme.titleMedium),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _isInitialized
                                ? Colors.green.withOpacity(0.2)
                                : Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _isInitialized ? 'Connected' : 'Disconnected',
                            style: TextStyle(
                              color: _isInitialized
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('SDK Version: $_sdkVersion'),
                    const SizedBox(height: 4),
                    Text('Status: $_status'),
                    if (_lastTransactionId.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Last Transaction: $_lastTransactionId'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Device Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Device Connection',
                          style: theme.textTheme.titleMedium,
                        ),
                        // Connection status indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _isInitialized
                                ? Colors.green.withOpacity(0.2)
                                : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isInitialized
                                    ? Icons.bluetooth_connected
                                    : Icons.bluetooth_disabled,
                                size: 16,
                                color: _isInitialized
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isInitialized
                                    ? 'Connected: ${_selectedDevice ?? "Device"}'
                                    : 'Disconnected',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _isInitialized
                                      ? Colors.green
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // API Mode Switch (NEW)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _useSeparatedApi
                            ? Colors.purple.withAlpha(25)
                            : Colors.blue.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _useSeparatedApi
                              ? Colors.purple.withAlpha(75)
                              : Colors.blue.withAlpha(75),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _useSeparatedApi ? Icons.call_split : Icons.merge,
                            color: _useSeparatedApi
                                ? Colors.purple
                                : Colors.blue,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _useSeparatedApi ? '分离 API 模式' : '组合 API 模式',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _useSeparatedApi
                                        ? Colors.purple
                                        : Colors.blue,
                                  ),
                                ),
                                Text(
                                  _useSeparatedApi
                                      ? 'initializeSdk → connectDevice'
                                      : 'initialize (一步完成)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _useSeparatedApi,
                            onChanged:
                                _isLoading ||
                                    _isInitialized ||
                                    _isSdkOnlyInitialized
                                ? null
                                : (value) {
                                    setState(() {
                                      _useSeparatedApi = value;
                                    });
                                  },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Separated API: Initialize SDK button (NEW)
                    if (_useSeparatedApi) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isLoading ||
                                      _isSdkOnlyInitialized ||
                                      _isInitialized
                                  ? null
                                  : _initSdkOnly,
                              icon: _isLoading && !_isSdkOnlyInitialized
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      _isSdkOnlyInitialized
                                          ? Icons.check_circle
                                          : Icons.play_arrow,
                                    ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                              ),
                              label: Text(
                                _isSdkOnlyInitialized
                                    ? 'SDK 已初始化'
                                    : 'Step 1: 初始化 SDK',
                              ),
                            ),
                          ),
                          // Reset button (when SDK initialized but device not connected)
                          if (_isSdkOnlyInitialized && !_isInitialized) ...[
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        _isSdkOnlyInitialized = false;
                                        _status = 'SDK 已重置';
                                      });
                                      _showSnackBar(
                                        'SDK reset - can switch mode now',
                                      );
                                    },
                              icon: const Icon(Icons.refresh),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange,
                                side: const BorderSide(color: Colors.orange),
                              ),
                              label: const Text('重置'),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Scan button
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _scanDevices,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.bluetooth_searching),
                      label: Text(
                        _useSeparatedApi ? 'Step 2: 扫描设备' : 'Scan for Devices',
                      ),
                    ),

                    // Device List
                    if (_devices.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _devices.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: theme.colorScheme.outline.withOpacity(0.2),
                          ),
                          itemBuilder: (context, index) {
                            final device = _devices[index];
                            final isConnected =
                                _isInitialized && _selectedDevice == device;
                            final isConnecting =
                                _isLoading && _selectedDevice == device;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: Icon(
                                isConnected
                                    ? Icons.bluetooth_connected
                                    : Icons.bluetooth,
                                color: isConnected ? Colors.green : Colors.blue,
                              ),
                              title: Text(
                                device,
                                style: TextStyle(
                                  fontWeight: isConnected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isConnected
                                      ? Colors.green.shade700
                                      : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: isConnected
                                  ? const Text(
                                      'Connected',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                      ),
                                    )
                                  : null,
                              trailing: isConnected
                                  ? OutlinedButton(
                                      onPressed: _isLoading
                                          ? null
                                          : (_useSeparatedApi
                                                ? _disconnectDeviceOnly
                                                : _deinitialize),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(
                                          color: Colors.red,
                                        ),
                                      ),
                                      child: const Text('Disconnect'),
                                    )
                                  : ElevatedButton(
                                      onPressed:
                                          _isLoading ||
                                              _isInitialized ||
                                              (_useSeparatedApi &&
                                                  !_isSdkOnlyInitialized)
                                          ? null
                                          : () => _useSeparatedApi
                                                ? _connectDeviceOnly(device)
                                                : _connectToDevice(device),
                                      style: _useSeparatedApi
                                          ? ElevatedButton.styleFrom(
                                              backgroundColor: Colors.purple,
                                              foregroundColor: Colors.white,
                                            )
                                          : null,
                                      child: isConnecting
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              _useSeparatedApi
                                                  ? 'Step 3: 连接'
                                                  : 'Connect',
                                            ),
                                    ),
                            );
                          },
                        ),
                      ),
                    ],

                    // Initialize SDK button (separate)
                    if (_isInitialized) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'SDK Initialized',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Text(
                                    'Connected to: ${_selectedDevice ?? "Unknown"}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Transaction Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Transaction', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount (\$)',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _transactionIdController,
                      decoration: const InputDecoration(
                        labelText: 'Transaction ID (for void)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading || !_isInitialized
                                ? null
                                : _processSale,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('SALE'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading || !_isInitialized
                                ? null
                                : _processRefund,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('REFUND'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading || !_isInitialized
                                ? null
                                : _processVoid,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('VOID'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Linked refund button (uses Transaction ID, no card required)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading || !_isInitialized
                            ? null
                            : _processLinkedRefund,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.link),
                        label: const Text('LINKED REFUND (by Transaction ID)'),
                      ),
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 8),
                            Text(_status),
                            TextButton(
                              onPressed: _cancelTransaction,
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Result Section
            if (_transactionResult.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Transaction Result',
                            style: theme.textTheme.titleMedium,
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _transactionResult = '';
                              });
                            },
                          ),
                        ],
                      ),
                      const Divider(),
                      SelectableText(
                        _transactionResult,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Test Credentials Info
            const SizedBox(height: 16),
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Test Credentials',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Acceptor ID: $acceptorId\n'
                      'Account ID: $accountId\n'
                      'Mode: ${applicationMode.name}',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
