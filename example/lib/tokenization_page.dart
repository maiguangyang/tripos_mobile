import 'package:flutter/material.dart';
import 'package:tripos_mobile/tripos_mobile.dart';

class TokenizationPage extends StatefulWidget {
  const TokenizationPage({super.key});

  @override
  State<TokenizationPage> createState() => _TokenizationPageState();
}

class _TokenizationPageState extends State<TokenizationPage> {
  final _tripos = TriposMobile();
  final _amountController = TextEditingController(text: '1.00');

  bool _isLoading = false;
  String _status = '';
  String? _currentTokenId;

  // Mock Blacklist (simulated)
  final List<String> _blacklistedBins = [
    '411111',
    '400000',
  ]; // Example blacklisted BINs
  bool _isBlacklisted = false;

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  Future<void> _createToken() async {
    setState(() {
      _isLoading = true;
      _status = 'Creating token... Please swipe/insert card.';
      _currentTokenId = null;
      _isBlacklisted = false;
    });

    try {
      // 1. Create Token
      final response = await _tripos.createToken(const CreateTokenRequest());

      // Check if widget is mounted before using context
      if (!mounted) return;

      if (response.tokenId != null) {
        setState(() {
          _currentTokenId = response.tokenId;
          _status =
              'Token Created!\nID: ${_shorten(response.tokenId!)}\nBIN: ${response.bin ?? "Unknown"}';
        });

        _checkBlacklist(response.bin);
      } else {
        setState(() {
          _status =
              'Token creation failed: ${response.errorMessage ?? "Unknown error"}';
        });
        _showSnackBar('Token creation failed', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Error: $e';
      });
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _checkBlacklist(String? bin) {
    if (bin == null) {
      setState(() {
        _status += '\n\n⚠️ No BIN returned, cannot check blacklist.';
      });
      return;
    }

    // Simulate blacklist check
    final isBlacklisted = _blacklistedBins.contains(bin);
    setState(() {
      _isBlacklisted = isBlacklisted;
      if (isBlacklisted) {
        _status += '\n\n❌ CARD BLACKLISTED (BIN: $bin). Sale blocked.';
      } else {
        _status += '\n\n✅ Card Safe (BIN: $bin). Ready for Sale.';
      }
    });
  }

  Future<void> _processSaleWithToken() async {
    if (_currentTokenId == null) {
      _showSnackBar('No token available. Create token first.', isError: true);
      return;
    }

    if (_isBlacklisted) {
      _showSnackBar('Card is blacklisted! Cannot process sale.', isError: true);
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      _showSnackBar('Invalid amount');
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Processing Sale with Token...';
    });

    try {
      final response = await _tripos.processSaleWithToken(
        SaleWithTokenRequest(
          tokenId: _currentTokenId!,
          transactionAmount: amount,
          referenceNumber: DateTime.now().millisecondsSinceEpoch.toString(),
        ),
      );

      if (!mounted) return;

      setState(() {
        if (response.isApproved) {
          _status =
              '💰 Sale APPROVED!\nAmount: ${response.approvedAmount}\nTrans ID: ${response.host?.transactionId}';
        } else {
          _status = 'Sale DECLINED: ${response.errorMessage ?? "Unknown"}';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Sale Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _shorten(String s) {
    if (s.length > 10) {
      return '${s.substring(0, 5)}...${s.substring(s.length - 5)}';
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tokenization Test')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test Flow: Tokenize -> Check Blacklist -> Sale',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Amount
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Sale Amount',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 20),

            // Step 1: Create Token
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _createToken,
              icon: const Icon(Icons.credit_card),
              label: const Text('STEP 1: Create Token (Scan Card)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 20),

            // Status Display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _status.isEmpty ? 'Ready...' : _status,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),

            const SizedBox(height: 20),

            // Step 2: Sale (only if token exists and not blacklisted)
            ElevatedButton.icon(
              onPressed:
                  (_isLoading || _currentTokenId == null || _isBlacklisted)
                  ? null
                  : _processSaleWithToken,
              icon: const Icon(Icons.attach_money),
              label: const Text('STEP 2: Process Sale with Token'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),

            if (_isBlacklisted)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  '🚫 Action Blocked: Card is in blacklist.',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
