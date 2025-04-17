class TopMoversStock {
  final String symbol;
  final String name;
  final double ltp;
  final double change;
  final double percentChange;
  final double dayHigh;
  final double dayLow;
  final double volume;
  final double marketCap;
  final String category;

  TopMoversStock({
    required this.symbol,
    required this.name,
    required this.ltp,
    required this.change,
    required this.percentChange,
    required this.dayHigh,
    required this.dayLow,
    required this.volume,
    required this.marketCap,
    required this.category,
  });

  factory TopMoversStock.fromJson(Map<String, dynamic> json) {
    return TopMoversStock(
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      ltp: (json['ltp'] as num).toDouble(),
      change: (json['change'] as num).toDouble(),
      percentChange: (json['percentChange'] as num).toDouble(),
      dayHigh: (json['dayHigh'] as num).toDouble(),
      dayLow: (json['dayLow'] as num).toDouble(),
      volume: (json['volume'] as num).toDouble(),
      marketCap: (json['marketCap'] as num).toDouble(),
      category: json['category'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'name': name,
      'ltp': ltp,
      'change': change,
      'percentChange': percentChange,
      'dayHigh': dayHigh,
      'dayLow': dayLow,
      'volume': volume,
      'marketCap': marketCap,
      'category': category,
    };
  }
}

class TopMoversData {
  final List<TopMoversStock> gainers;
  final List<TopMoversStock> losers;

  TopMoversData({
    required this.gainers,
    required this.losers,
  });

  factory TopMoversData.fromJson(Map<String, dynamic> json) {
    return TopMoversData(
      gainers: (json['gainers'] as List)
          .map((e) => TopMoversStock.fromJson(e))
          .toList(),
      losers: (json['losers'] as List)
          .map((e) => TopMoversStock.fromJson(e))
          .toList(),
    );
  }
}
