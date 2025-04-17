class MarketData {
  final MarketIndex nifty;
  final MarketIndex sensex;

  MarketData({
    required this.nifty,
    required this.sensex,
  });
}

class MarketIndex {
  final String name;
  final double value;
  final double change;
  final double percentChange;

  MarketIndex({
    required this.name,
    required this.value,
    required this.change,
    required this.percentChange,
  });
}

class MarketUpdate {
  final String symbol;
  final double price;
  final double change;
  final double changePercent;

  MarketUpdate({
    required this.symbol,
    required this.price,
    required this.change,
    required this.changePercent,
  });

  factory MarketUpdate.fromJson(Map<String, dynamic> json) {
    return MarketUpdate(
      symbol: json['symbol'] as String,
      price: (json['price'] ?? 0.0).toDouble(),
      change: (json['change'] ?? 0.0).toDouble(),
      changePercent: (json['changePercent'] ?? 0.0).toDouble(),
    );
  }
}
