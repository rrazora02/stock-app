import 'package:flutter/material.dart';
import '../models/top_movers.dart';

class StockDetailScreen extends StatelessWidget {
  final TopMoversStock stock;

  const StockDetailScreen({
    Key? key,
    required this.stock,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isGainer = stock.percentChange >= 0;
    final color = isGainer ? Colors.green : Colors.red;
    final icon = isGainer ? Icons.arrow_upward : Icons.arrow_downward;

    return Scaffold(
      appBar: AppBar(
        title: Text(stock.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(color, icon),
            const SizedBox(height: 24),
            _buildPriceInfo(),
            const SizedBox(height: 24),
            _buildMarketInfo(),
            const SizedBox(height: 24),
            _buildChartPlaceholder(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color color, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stock.symbol,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              stock.name,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${stock.ltp.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  '${stock.percentChange.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Price Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
                'Last Traded Price', '₹${stock.ltp.toStringAsFixed(2)}'),
            _buildInfoRow(
                'Day\'s High', '₹${stock.dayHigh.toStringAsFixed(2)}'),
            _buildInfoRow('Day\'s Low', '₹${stock.dayLow.toStringAsFixed(2)}'),
            _buildInfoRow('Change', '₹${stock.change.toStringAsFixed(2)}'),
            _buildInfoRow(
                'Change %', '${stock.percentChange.toStringAsFixed(2)}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Market Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Volume', _formatNumber(stock.volume)),
            _buildInfoRow('Market Cap', '₹${_formatNumber(stock.marketCap)}'),
            _buildInfoRow('Category', stock.category),
          ],
        ),
      ),
    );
  }

  Widget _buildChartPlaceholder() {
    return Card(
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16.0),
        child: const Center(
          child: Text(
            'Chart will be displayed here',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double number) {
    if (number >= 1000000000) {
      return '${(number / 1000000000).toStringAsFixed(2)}B';
    } else if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(2)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(2)}K';
    } else {
      return number.toStringAsFixed(2);
    }
  }
}
