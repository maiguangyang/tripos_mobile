import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tripos_mobile/tripos_mobile.dart';

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
  final _amountController = TextEditingController(text: '1.00');
  final _transactionIdController = TextEditingController();

  // Test credentials
  static const _testAcceptorId = '874767787';
  static const _testAccountId = '1091187';
  static const _testToken =
      'D59509CCCA5068F9B5D231EAC735B84348CDE8F861B8D5A8BF82B847749B0EB824175F01';

  String _sdkVersion = 'Unknown';
  bool _isInitialized = false;
  bool _isLoading = false;
  String _status = 'Not initialized';
  String _lastTransactionId = '';
  List<String> _devices = [];
  String? _selectedDevice;
  String _transactionResult = '';

  StreamSubscription<String>? _statusSubscription;
  StreamSubscription<Map<String, dynamic>>? _deviceEventSubscription;

  TriposConfiguration get _configuration => TriposConfiguration(
    hostConfiguration: const HostConfiguration(
      acceptorId: _testAcceptorId,
      accountId: _testAccountId,
      accountToken: _testToken,
      applicationId: '8414',
      applicationName: 'triPOS Flutter Example',
      applicationVersion: '1.0.0',
    ),
    deviceConfiguration: DeviceConfiguration(
      deviceType: DeviceType.ingenicoMoby5500,
      identifier: _selectedDevice,
      terminalId: '1234',
      contactlessAllowed: true,
      keyedEntryAllowed: true,
    ),
    applicationConfiguration: const ApplicationConfiguration(
      applicationMode: ApplicationMode.testCertification,
      idlePrompt: 'triPOS Flutter',
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

    // Listen to status updates
    _statusSubscription = _tripos.statusStream.listen((status) {
      setState(() {
        _status = status;
      });
    });

    // Listen to device events
    _deviceEventSubscription = _tripos.deviceEventStream.listen((event) {
      final eventType = event['event'] as String?;
      if (eventType == 'connected') {
        _showSnackBar('Device connected: ${event['model']}');
      } else if (eventType == 'disconnected') {
        _showSnackBar('Device disconnected');
      } else if (eventType == 'error') {
        _showSnackBar('Device error: ${event['message']}', isError: true);
      }
    });
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

  Future<void> _scanDevices() async {
    setState(() {
      _isLoading = true;
      _status = 'Scanning for devices...';
    });

    try {
      final devices = await _tripos.scanBluetoothDevices(_configuration);
      setState(() {
        _devices = devices;
        _status = 'Found ${devices.length} device(s)';
      });

      if (devices.isEmpty) {
        _showSnackBar('No devices found. Make sure your device is powered on.');
      }
    } catch (e) {
      _showSnackBar('Scan error: $e', isError: true);
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
      _status = 'Initializing SDK...';
    });

    try {
      final success = await _tripos.initialize(_configuration);
      setState(() {
        _isInitialized = success;
        _status = success ? 'Initialized' : 'Initialization failed';
      });

      if (success) {
        _showSnackBar('SDK initialized successfully');
      } else {
        _showSnackBar('Failed to initialize SDK', isError: true);
      }
    } catch (e) {
      _showSnackBar('Init error: $e', isError: true);
      setState(() {
        _status = 'Init failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
        );

        if (response.isApproved && response.host?.transactionId != null) {
          _lastTransactionId = response.host!.transactionId!;
          _transactionIdController.text = _lastTransactionId;
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
      setState(() {
        _transactionResult = 'Error: $e';
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
    String? errorMessage,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('=== $type Result ===');
    buffer.writeln('Status: ${isApproved ? "APPROVED" : "DECLINED"}');
    buffer.writeln('Transaction Status: $status');
    if (amount != null)
      buffer.writeln('Amount: \$${amount.toStringAsFixed(2)}');
    if (transactionId != null) buffer.writeln('Transaction ID: $transactionId');
    if (authCode != null) buffer.writeln('Auth Code: $authCode');
    if (maskedCard != null) buffer.writeln('Card: $maskedCard');
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
          if (_isInitialized)
            IconButton(
              icon: const Icon(Icons.power_settings_new),
              onPressed: _isLoading ? null : _deinitialize,
              tooltip: 'Deinitialize',
            ),
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
                    Text(
                      'Device Connection',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _scanDevices,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.bluetooth_searching),
                      label: const Text('Scan for Devices'),
                    ),
                    if (_devices.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedDevice,
                        decoration: const InputDecoration(
                          labelText: 'Select Device',
                          border: OutlineInputBorder(),
                        ),
                        items: _devices
                            .map(
                              (device) => DropdownMenuItem(
                                value: device,
                                child: Text(device),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedDevice = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isLoading || _selectedDevice == null
                            ? null
                            : _initialize,
                        icon: const Icon(Icons.power),
                        label: const Text('Initialize SDK'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
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
                      'Acceptor ID: $_testAcceptorId\n'
                      'Account ID: $_testAccountId\n'
                      'Mode: TestCertification',
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
