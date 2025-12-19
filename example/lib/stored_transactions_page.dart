import 'package:flutter/material.dart';
import 'package:tripos_mobile/tripos_mobile.dart';

/// 离线交易管理页面 - Store-and-Forward
class StoredTransactionsPage extends StatefulWidget {
  final TriposMobile tripos;

  const StoredTransactionsPage({super.key, required this.tripos});

  @override
  State<StoredTransactionsPage> createState() => _StoredTransactionsPageState();
}

class _StoredTransactionsPageState extends State<StoredTransactionsPage> {
  List<StoredTransactionRecord> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final transactions = await widget.tripos.getStoredTransactions();
      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadByState(StoredTransactionState state) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final transactions = await widget.tripos.getStoredTransactionsByState(
        state,
      );
      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _forwardTransaction(StoredTransactionRecord record) async {
    if (record.tpId == null) {
      _showSnackBar('交易 ID 为空', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await widget.tripos.forwardTransaction(
        ForwardTransactionRequest(tpId: record.tpId!),
      );

      if (response.isApproved) {
        _showSnackBar('交易转发成功！ID: ${response.transactionId}');
        _loadTransactions(); // 刷新列表
      } else {
        _showSnackBar('转发失败: ${response.errorMessage}', isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackBar('转发错误: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTransaction(StoredTransactionRecord record) async {
    if (record.tpId == null) {
      _showSnackBar('交易 ID 为空', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除交易 ${record.tpId} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final success = await widget.tripos.deleteStoredTransaction(record.tpId!);

      if (success) {
        _showSnackBar('交易已删除');
        _loadTransactions(); // 刷新列表
      } else {
        _showSnackBar('删除失败', isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackBar('删除错误: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String _formatState(StoredTransactionState state) {
    switch (state) {
      case StoredTransactionState.stored:
        return '待转发';
      case StoredTransactionState.storedPendingGenac2:
        return '待 EMV 确认';
      case StoredTransactionState.processing:
        return '处理中';
      case StoredTransactionState.processed:
        return '已处理';
      case StoredTransactionState.deleted:
        return '已删除';
    }
  }

  Color _getStateColor(StoredTransactionState state) {
    switch (state) {
      case StoredTransactionState.stored:
        return Colors.orange;
      case StoredTransactionState.storedPendingGenac2:
        return Colors.amber;
      case StoredTransactionState.processing:
        return Colors.blue;
      case StoredTransactionState.processed:
        return Colors.green;
      case StoredTransactionState.deleted:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('离线交易管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadTransactions,
            tooltip: '刷新',
          ),
          PopupMenuButton<StoredTransactionState>(
            icon: const Icon(Icons.filter_list),
            tooltip: '按状态筛选',
            onSelected: _loadByState,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: StoredTransactionState.stored,
                child: Text('待转发'),
              ),
              const PopupMenuItem(
                value: StoredTransactionState.processing,
                child: Text('处理中'),
              ),
              const PopupMenuItem(
                value: StoredTransactionState.processed,
                child: Text('已处理'),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('加载失败: $_errorMessage'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadTransactions,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无离线交易',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text('离线模式下进行的交易将显示在这里', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _transactions.length,
        itemBuilder: (context, index) {
          final tx = _transactions[index];
          return _buildTransactionCard(tx);
        },
      ),
    );
  }

  Widget _buildTransactionCard(StoredTransactionRecord tx) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 状态和金额行
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStateColor(tx.state).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatState(tx.state),
                    style: TextStyle(
                      color: _getStateColor(tx.state),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                if (tx.totalAmount != null)
                  Text(
                    '\$${tx.totalAmount!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // 卡片信息行
            if (tx.lastFourDigits != null || tx.cardLogo != null) ...[
              Row(
                children: [
                  Icon(Icons.credit_card, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  if (tx.cardLogo != null) ...[
                    Text(
                      tx.cardLogo!,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (tx.lastFourDigits != null)
                    Text(
                      '•••• ${tx.lastFourDigits}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.grey[700],
                      ),
                    ),
                  if (tx.entryMode != null) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatEntryMode(tx.entryMode!),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
            ],

            // 持卡人姓名
            if (tx.cardHolderName != null && tx.cardHolderName!.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    tx.cardHolderName!,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // 设备信息
            if (tx.deviceSerialNumber != null) ...[
              Row(
                children: [
                  Icon(Icons.devices, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    '设备: ${tx.deviceSerialNumber}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // 操作员/终端信息
            if (tx.clerkId != null ||
                tx.terminalId != null ||
                tx.laneId != null) ...[
              Row(
                children: [
                  Icon(Icons.badge_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (tx.clerkId != null)
                          Text(
                            '操作员: ${tx.clerkId}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        if (tx.terminalId != null)
                          Text(
                            '终端: ${tx.terminalId}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        if (tx.laneId != null)
                          Text(
                            '通道: ${tx.laneId}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // 交易追踪信息
            if (tx.invoiceNumber != null || tx.referenceNumber != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (tx.invoiceNumber != null)
                          Text(
                            '发票号: ${tx.invoiceNumber}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        if (tx.referenceNumber != null)
                          Text(
                            '参考号: ${tx.referenceNumber}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // 交易类型和 Transaction ID
            Row(
              children: [
                if (tx.transactionType != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tx.transactionType!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.purple,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (tx.transactionId != null)
                  Text(
                    'Txn: ${tx.transactionId}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),

            // 本地交易 ID
            Text(
              'ID: ${tx.tpId ?? "N/A"}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),

            // 创建时间
            if (tx.createdOn != null) ...[
              const SizedBox(height: 4),
              Text(
                '创建时间: ${tx.createdOn}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
            const SizedBox(height: 12),

            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 显示转发按钮：stored 或 storedPendingGenac2 状态
                if (tx.state == StoredTransactionState.stored ||
                    tx.state == StoredTransactionState.storedPendingGenac2) ...[
                  TextButton.icon(
                    onPressed: () => _forwardTransaction(tx),
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('转发'),
                  ),
                  const SizedBox(width: 8),
                ],
                // 显示删除按钮：除了 processed 和 deleted 以外的状态
                if (tx.state != StoredTransactionState.processed &&
                    tx.state != StoredTransactionState.deleted)
                  TextButton.icon(
                    onPressed: () => _deleteTransaction(tx),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('删除'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatEntryMode(String entryMode) {
    switch (entryMode.toLowerCase()) {
      case 'swipe':
        return '刷卡';
      case 'chip':
      case 'contact':
        return '插卡';
      case 'contactless':
      case 'tap':
        return '感应';
      case 'keyed':
      case 'manual':
        return '手输';
      default:
        return entryMode;
    }
  }
}
