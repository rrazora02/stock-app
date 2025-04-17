import 'package:flutter/material.dart';
import '../models/top_movers.dart';

class TopMoversTab extends StatelessWidget {
  final List<TopMoversStock> gainers;
  final List<TopMoversStock> losers;
  final Function(TopMoversStock) onStockTap;

  const TopMoversTab({
    Key? key,
    required this.gainers,
    required this.losers,
    required this.onStockTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Top Gainers'),
              Tab(text: 'Top Losers'),
            ],
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildStockList(gainers, true),
                _buildStockList(losers, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockList(List<TopMoversStock> stocks, bool isGainers) {
    if (stocks.isEmpty) {
      return const Center(
        child: Text('No data available'),
      );
    }

    return ListView.builder(
      itemCount: stocks.length,
      itemBuilder: (context, index) {
        final stock = stocks[index];
        return _buildStockCard(stock, isGainers);
      },
    );
  }

  Widget _buildStockCard(TopMoversStock stock, bool isGainers) {
    final color = isGainers ? Colors.green : Colors.red;
    final icon = isGainers ? Icons.arrow_upward : Icons.arrow_downward;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () => onStockTap(stock),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stock.symbol,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${stock.ltp.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        icon,
                        color: color,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${stock.percentChange.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
