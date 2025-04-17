import 'package:flutter/material.dart';
import '../models/top_movers.dart';
import '../services/zerodha_service.dart';

class TopMoversScreen extends StatefulWidget {
  const TopMoversScreen({super.key});

  @override
  State<TopMoversScreen> createState() => _TopMoversScreenState();
}

class _TopMoversScreenState extends State<TopMoversScreen> {
  final ZerodhaService _zerodhaService = ZerodhaService();
  TopMoversData? _topMoversData;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _loadTopMoversData();
  }

  Future<void> _loadTopMoversData() async {
    try {
      final data = await _zerodhaService.getTopMovers();
      setState(() {
        _topMoversData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load top movers data';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Movers'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _showAll = !_showAll;
              });
            },
            child: Text(
              _showAll ? 'SHOW TOP' : 'VIEW ALL',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : _buildTopMoversContent(),
    );
  }

  Widget _buildTopMoversContent() {
    if (_showAll) {
      // Show all stocks combined
      final allStocks = [
        ..._topMoversData!.largeCapGainers,
        ..._topMoversData!.largeCapLosers,
        ..._topMoversData!.midCapGainers,
        ..._topMoversData!.midCapLosers,
        ..._topMoversData!.smallCapGainers,
        ..._topMoversData!.smallCapLosers,
      ];

      // Sort by percentage change
      allStocks.sort((a, b) => b.percentChange.compareTo(a.percentChange));

      return ListView.builder(
        itemCount: allStocks.length,
        itemBuilder: (context, index) {
          final stock = allStocks[index];
          final isGainer = stock.percentChange >= 0;
          return _buildStockTile(stock, isGainer);
        },
      );
    } else {
      // Show top gainers and losers separately
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('🔼 Top Gainers'),
            _buildStockList(_topMoversData!.largeCapGainers, true),
            _buildSectionHeader('🔽 Top Losers'),
            _buildStockList(_topMoversData!.largeCapLosers, false),
          ],
        ),
      );
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStockList(List<TopMoversStock> stocks, bool isGainers) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stocks.length,
      itemBuilder: (context, index) {
        final stock = stocks[index];
        return _buildStockTile(stock, isGainers);
      },
    );
  }

  Widget _buildStockTile(TopMoversStock stock, bool isGainers) {
    final color = isGainers ? Colors.green : Colors.red;
    final icon = isGainers ? Icons.arrow_upward : Icons.arrow_downward;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          stock.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(stock.symbol),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${stock.ltp.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              '${stock.percentChange >= 0 ? '+' : ''}${stock.percentChange.toStringAsFixed(2)}%',
              style: TextStyle(
                color: color,
              ),
            ),
          ],
        ),
        onTap: () => _showStockDetails(stock),
      ),
    );
  }

  void _showStockDetails(TopMoversStock stock) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stock.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              stock.symbol,
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('LTP', '₹${stock.ltp.toStringAsFixed(2)}'),
            _buildDetailRow(
              'Change',
              '${stock.change >= 0 ? '+' : ''}₹${stock.change.abs().toStringAsFixed(2)}',
            ),
            _buildDetailRow(
              'Change %',
              '${stock.percentChange >= 0 ? '+' : ''}${stock.percentChange.toStringAsFixed(2)}%',
            ),
            _buildDetailRow('Day High', '₹${stock.dayHigh.toStringAsFixed(2)}'),
            _buildDetailRow('Day Low', '₹${stock.dayLow.toStringAsFixed(2)}'),
            _buildDetailRow('Volume', stock.volume.toString()),
            _buildDetailRow(
              'Market Cap',
              '₹${(stock.marketCap / 10000000).toStringAsFixed(2)} Cr',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
