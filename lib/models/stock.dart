class Stock {
  final String symbol;
  final String name;
  final double ltp;
  final double change;
  final double percentChange;
  final double dayHigh;
  final double dayLow;
  final int volume;
  final double marketCap;

  // Aliases for compatibility
  double get price => ltp;
  double get changePercent => percentChange;

  Stock({
    required this.symbol,
    required this.name,
    required this.ltp,
    required this.change,
    required this.percentChange,
    required this.dayHigh,
    required this.dayLow,
    required this.volume,
    required this.marketCap,
  });
}

class StockUpdate {
  final String symbol;
  final String name;
  final double ltp;
  final double change;
  final double percentChange;
  final double dayHigh;
  final double dayLow;
  final int volume;
  final double marketCap;
  final String lastUpdateTime;

  // Aliases for compatibility
  double get price => ltp;
  double get changePercent => percentChange;

  StockUpdate({
    required this.symbol,
    required this.name,
    required this.ltp,
    required this.change,
    required this.percentChange,
    required this.dayHigh,
    required this.dayLow,
    required this.volume,
    required this.marketCap,
    required this.lastUpdateTime,
  });

  factory StockUpdate.fromJson(Map<String, dynamic> json) {
    return StockUpdate(
      symbol: json['symbol'] as String,
      name: json['name'] as String? ?? json['symbol'] as String,
      ltp: (json['price'] ?? json['ltp'] ?? 0.0).toDouble(),
      change: (json['change'] ?? 0.0).toDouble(),
      percentChange: (json['percentChange'] ?? 0.0).toDouble(),
      dayHigh: (json['high'] ?? json['dayHigh'] ?? 0.0).toDouble(),
      dayLow: (json['low'] ?? json['dayLow'] ?? 0.0).toDouble(),
      volume: (json['volume'] ?? 0).toInt(),
      marketCap: (json['marketCap'] ?? 0.0).toDouble(),
      lastUpdateTime:
          json['time'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}
