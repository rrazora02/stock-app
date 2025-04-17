class Portfolio {
  final Map<String, StockHolding> holdings = {};
  double cash = 10000.0; // Starting with $10,000
  double _totalValue = 10000.0;
  double _totalChange = 0.0;

  double get totalValue => _totalValue;
  double get totalChange => _totalChange;

  void buyStock(String symbol, String name, double price, int quantity) {
    if (cash < price * quantity) {
      throw Exception('Insufficient funds');
    }

    cash -= price * quantity;

    if (holdings.containsKey(symbol)) {
      holdings[symbol]!.addShares(quantity, price);
    } else {
      holdings[symbol] = StockHolding(
        symbol: symbol,
        name: name,
        shares: quantity,
        averagePrice: price,
      );
    }
    _updateTotalValue();
  }

  void sellStock(String symbol, double price, int quantity) {
    if (!holdings.containsKey(symbol)) {
      throw Exception('No holdings for this stock');
    }

    final holding = holdings[symbol]!;
    if (holding.shares < quantity) {
      throw Exception('Insufficient shares');
    }

    cash += price * quantity;
    holding.removeShares(quantity);

    if (holding.shares == 0) {
      holdings.remove(symbol);
    }
    _updateTotalValue();
  }

  void _updateTotalValue() {
    double stocksValue = holdings.values
        .map((holding) => holding.getCurrentValue(holding.averagePrice))
        .fold(0.0, (a, b) => a + b);
    _totalValue = stocksValue + cash;
    _totalChange = ((_totalValue - 10000.0) / 10000.0) * 100;
  }

  double getTotalValue(Map<String, double> currentPrices) {
    double stocksValue = holdings.entries
        .map((entry) => entry.value.shares * (currentPrices[entry.key] ?? 0.0))
        .fold(0.0, (a, b) => a + b);
    return stocksValue + cash;
  }
}

class StockHolding {
  final String symbol;
  final String name;
  int shares;
  double averagePrice;
  double currentPrice;
  double changePercent;

  StockHolding({
    required this.symbol,
    required this.name,
    required this.shares,
    required this.averagePrice,
    this.currentPrice = 0.0,
    this.changePercent = 0.0,
  });

  void addShares(int quantity, double price) {
    double totalValue = shares * averagePrice + quantity * price;
    shares += quantity;
    averagePrice = totalValue / shares;
  }

  void removeShares(int quantity) {
    shares -= quantity;
  }

  double getCurrentValue(double currentPrice) {
    this.currentPrice = currentPrice;
    return shares * currentPrice;
  }

  double getProfitLoss(double currentPrice) {
    return (currentPrice - averagePrice) * shares;
  }
}
