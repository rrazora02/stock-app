import 'package:flutter/material.dart';
import '../models/stock.dart';

class OptionChainScreen extends StatefulWidget {
  final Stock stock;

  const OptionChainScreen({Key? key, required this.stock}) : super(key: key);

  @override
  _OptionChainScreenState createState() => _OptionChainScreenState();
}

class _OptionChainScreenState extends State<OptionChainScreen> {
  List<Map<String, dynamic>> _callOptions = [];
  List<Map<String, dynamic>> _putOptions = [];

  @override
  void initState() {
    super.initState();
    _loadOptionChain();
  }

  Future<void> _loadOptionChain() async {
    setState(() {
      _callOptions = [
        {
          'strike': 100,
          'price': 5.0,
          'change': 0.5,
          'openInterest': '1000',
          'impliedVolatility': '20%'
        },
        {
          'strike': 105,
          'price': 3.0,
          'change': -0.2,
          'openInterest': '800',
          'impliedVolatility': '18%'
        },
        {
          'strike': 110,
          'price': 1.5,
          'change': 0.1,
          'openInterest': '600',
          'impliedVolatility': '15%'
        },
      ];
      _putOptions = [
        {
          'strike': 100,
          'price': 2.0,
          'change': -0.3,
          'openInterest': '900',
          'impliedVolatility': '19%'
        },
        {
          'strike': 95,
          'price': 4.0,
          'change': 0.4,
          'openInterest': '700',
          'impliedVolatility': '17%'
        },
        {
          'strike': 90,
          'price': 6.0,
          'change': -0.1,
          'openInterest': '500',
          'impliedVolatility': '16%'
        },
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Row(
          children: [
            Text(
              widget.stock.symbol,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '₹${widget.stock.ltp}',
              style: TextStyle(
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadOptionChain,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildFilters(),
          Expanded(
            child: _callOptions.isEmpty && _putOptions.isEmpty
                ? const Center(child: Text('No data available'))
                : _buildOptionChainTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _callOptions.isNotEmpty
                      ? _callOptions.first['strike'].toString()
                      : '',
                  isExpanded: true,
                  dropdownColor: Colors.grey[900],
                  style: const TextStyle(color: Colors.white),
                  hint: const Text(
                    'Select Strike',
                    style: TextStyle(color: Colors.white),
                  ),
                  items: _callOptions.map((option) {
                    return DropdownMenuItem<String>(
                      value: option['strike'].toString(),
                      child: Text(option['strike'].toString()),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _callOptions = _callOptions
                          .where((option) =>
                              option['strike'].toString() == newValue)
                          .toList();
                    });
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              _buildFilterChip('All'),
              const SizedBox(width: 8),
              _buildFilterChip('OI'),
              const SizedBox(width: 8),
              _buildFilterChip('IV'),
            ],
          ),
          const SizedBox(height: 16),
          RangeSlider(
            values: const RangeValues(0, 100000),
            min: 0,
            max: 100000,
            divisions: 20,
            labels: RangeLabels(
              '0',
              '100000',
            ),
            onChanged: (RangeValues values) {
              setState(() {
                // Update the call and put options based on the selected range
                _callOptions = _callOptions
                    .where((option) =>
                        option['strike'] >= values.start &&
                        option['strike'] <= values.end)
                    .toList();
                _putOptions = _putOptions
                    .where((option) =>
                        option['strike'] >= values.start &&
                        option['strike'] <= values.end)
                    .toList();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    return FilterChip(
      selected: true, // Always selected as we're not filtering
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
        ),
      ),
      backgroundColor: Colors.grey[900],
      selectedColor: Colors.blue,
      onSelected: (bool selected) {
        // This method is called when the chip is selected, but we don't need to do anything
      },
    );
  }

  Widget _buildOptionChainTable() {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey[900]),
          dataRowColor: WidgetStateProperty.all(Colors.transparent),
          columns: const [
            DataColumn(
              label: Text('CALLS', style: TextStyle(color: Colors.green)),
            ),
            DataColumn(
              label: Text('OI', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('IV', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('Strike', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('IV', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('OI', style: TextStyle(color: Colors.white)),
            ),
            DataColumn(
              label: Text('PUTS', style: TextStyle(color: Colors.red)),
            ),
          ],
          rows: _callOptions.map<DataRow>((call) {
                final strike = call['strike'] as double;
                final isITM = strike < widget.stock.ltp;

                return DataRow(
                  cells: [
                    DataCell(
                        _buildPriceCell(call['price'], call['change'], !isITM)),
                    DataCell(Text(call['openInterest'],
                        style: const TextStyle(color: Colors.white))),
                    DataCell(Text(call['impliedVolatility'],
                        style: const TextStyle(color: Colors.white))),
                    DataCell(
                      Text(
                        strike.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataCell(Text(call['impliedVolatility'],
                        style: const TextStyle(color: Colors.white))),
                    DataCell(Text(call['openInterest'],
                        style: const TextStyle(color: Colors.white))),
                    DataCell(
                      _buildPriceCell(call['price'], call['change'], isITM),
                    ),
                  ],
                );
              }).toList() +
              _putOptions.map<DataRow>((put) {
                final strike = put['strike'] as double;
                final isITM = strike < widget.stock.ltp;

                return DataRow(
                  cells: [
                    DataCell(
                        _buildPriceCell(put['price'], put['change'], !isITM)),
                    DataCell(Text(put['openInterest'],
                        style: const TextStyle(color: Colors.white))),
                    DataCell(Text(put['impliedVolatility'],
                        style: const TextStyle(color: Colors.white))),
                    DataCell(
                      Text(
                        strike.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataCell(Text(put['impliedVolatility'],
                        style: const TextStyle(color: Colors.white))),
                    DataCell(Text(put['openInterest'],
                        style: const TextStyle(color: Colors.white))),
                    DataCell(
                      _buildPriceCell(put['price'], put['change'], isITM),
                    ),
                  ],
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildPriceCell(double price, double change, bool isPositive) {
    final changeValue = change.abs();
    final color = changeValue >= 0 ? Colors.green : Colors.red;
    final backgroundColor =
        isPositive ? Colors.transparent : Colors.blue.withOpacity(0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '₹${price.toStringAsFixed(2)}',
            style: TextStyle(
              color: isPositive ? Colors.white : Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${changeValue >= 0 ? '+' : ''}$change%',
            style: TextStyle(
              color: color,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
