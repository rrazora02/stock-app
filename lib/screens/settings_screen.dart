import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  double _totalInvested = 0.0;
  double _totalReturns = 0.0;
  List<Transaction> _transactions = [];
  bool _hasPin = false;
  double _availableFunds = 10000.00; // Initial funds
  final TextEditingController _fundsController = TextEditingController();
  static const String _fundKey = 'available_funds';

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _checkPinStatus();
    _loadAvailableFunds();
  }

  Future<void> _loadAvailableFunds() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _availableFunds = prefs.getDouble(_fundKey) ?? 10000.00;
    });
  }

  Future<void> _saveAvailableFunds(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fundKey, amount);
  }

  Future<void> _loadTransactions() async {
    // TODO: Load transactions from storage
    setState(() {
      _transactions = [
        Transaction(
          type: TransactionType.buy,
          stockSymbol: 'AAPL',
          shares: 10,
          pricePerShare: 150.0,
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
        ),
        Transaction(
          type: TransactionType.sell,
          stockSymbol: 'GOOGL',
          shares: 5,
          pricePerShare: 2800.0,
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ];
      _calculateTotals();
    });
  }

  Future<void> _checkPinStatus() async {
    await _authService.init();
    final hasPin = await _authService.hasPin();
    setState(() {
      _hasPin = hasPin;
    });
  }

  Future<void> _handleSetupPin() async {
    final success = await _authService.setupPin();
    if (success && mounted) {
      setState(() {
        _hasPin = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN setup successful')),
      );
    }
  }

  void _calculateTotals() {
    _totalInvested = 0.0;
    _totalReturns = 0.0;

    for (var transaction in _transactions) {
      if (transaction.type == TransactionType.buy) {
        _totalInvested += transaction.shares * transaction.pricePerShare;
      } else {
        _totalReturns += transaction.shares * transaction.pricePerShare;
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      await _authService.logout();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddFundsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Add Funds',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _fundsController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter amount',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixText: '₹ ',
                prefixStyle: const TextStyle(color: Colors.white),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[800]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.teal),
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Min: ₹1,000 | Max: ₹10,00,000',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(_fundsController.text) ?? 0;
              if (amount >= 1000 && amount <= 1000000) {
                await _saveAvailableFunds(amount);
                setState(() {
                  _availableFunds = amount;
                });
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Funds updated to ₹${amount.toStringAsFixed(2)}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                _fundsController.clear();
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Please enter an amount between ₹1,000 and ₹10,00,000'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
            ),
            child: const Text('ADD FUNDS'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fundsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF1C1C1E),
      ),
      body: ListView(
        children: [
          // Available Funds Section
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  title: const Text(
                    'Available Funds',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    '₹${_availableFunds.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.teal,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: ElevatedButton(
                    onPressed: _showAddFundsDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('ADD FUNDS'),
                  ),
                ),
                const Divider(color: Colors.grey),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available Margin',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${(_availableFunds * 0.8).toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Used Margin',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '₹0.00',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Other settings items...
          const ListTile(
            title: Text(
              'Account',
              style: TextStyle(color: Colors.white),
            ),
            leading: Icon(Icons.person_outline, color: Colors.white),
            trailing: Icon(Icons.chevron_right, color: Colors.grey),
          ),
          const ListTile(
            title: Text(
              'Bank Accounts',
              style: TextStyle(color: Colors.white),
            ),
            leading: Icon(Icons.account_balance_outlined, color: Colors.white),
            trailing: Icon(Icons.chevron_right, color: Colors.grey),
          ),
          const ListTile(
            title: Text(
              'Security',
              style: TextStyle(color: Colors.white),
            ),
            leading: Icon(Icons.security_outlined, color: Colors.white),
            trailing: Icon(Icons.chevron_right, color: Colors.grey),
          ),
          const ListTile(
            title: Text(
              'Notifications',
              style: TextStyle(color: Colors.white),
            ),
            leading: Icon(Icons.notifications_outlined, color: Colors.white),
            trailing: Icon(Icons.chevron_right, color: Colors.grey),
          ),
          const ListTile(
            title: Text(
              'Help & Support',
              style: TextStyle(color: Colors.white),
            ),
            leading: Icon(Icons.help_outline, color: Colors.white),
            trailing: Icon(Icons.chevron_right, color: Colors.grey),
          ),
          const ListTile(
            title: Text(
              'About',
              style: TextStyle(color: Colors.white),
            ),
            leading: Icon(Icons.info_outline, color: Colors.white),
            trailing: Icon(Icons.chevron_right, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: _handleLogout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'LOGOUT',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showTransactionHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            AppBar(
              title: const Text('Transaction History'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  final transaction = _transactions[index];
                  return ListTile(
                    leading: Icon(
                      transaction.type == TransactionType.buy
                          ? Icons.add_circle
                          : Icons.remove_circle,
                      color: transaction.type == TransactionType.buy
                          ? Colors.green
                          : Colors.red,
                    ),
                    title: Text(transaction.stockSymbol),
                    subtitle: Text(
                      '${transaction.shares} shares @ \$${transaction.pricePerShare.toStringAsFixed(2)}',
                    ),
                    trailing: Text(
                      '\$${(transaction.shares * transaction.pricePerShare).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
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

enum TransactionType { buy, sell }

class Transaction {
  final TransactionType type;
  final String stockSymbol;
  final int shares;
  final double pricePerShare;
  final DateTime timestamp;

  Transaction({
    required this.type,
    required this.stockSymbol,
    required this.shares,
    required this.pricePerShare,
    required this.timestamp,
  });
}
