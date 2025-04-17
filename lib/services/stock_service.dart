import 'dart:async';
import '../models/stock.dart' as stock_models;
import '../models/market_data.dart' as market_models;
import '../models/top_movers.dart';
import 'socket_service.dart';

class StockService {
  final Map<String, StreamController<stock_models.StockUpdate>> _controllers =
      {};
  final Map<String, StreamController<market_models.MarketUpdate>>
      _marketUpdateControllers = {};
  final Map<String, market_models.MarketUpdate> _lastMarketUpdates = {};
  final SocketService _socketService = SocketService();

  StockService() {
    _initializeServices();
  }

  void _initializeServices() {
    _socketService.connect();
    _startPriceUpdates();
  }

  void _startPriceUpdates() {
    // Listen to WebSocket updates
    _socketService.stockUpdates.listen(
      (update) {
        if (!_controllers.containsKey(update.symbol)) {
          _controllers[update.symbol] =
              StreamController<stock_models.StockUpdate>.broadcast();
        }
        _controllers[update.symbol]?.add(update);
      },
      onError: (error) {
        print('WebSocket error: $error');
      },
    );

    _socketService.marketUpdates.listen(
      (update) {
        if (!_marketUpdateControllers.containsKey(update.symbol)) {
          _marketUpdateControllers[update.symbol] =
              StreamController<market_models.MarketUpdate>.broadcast();
        }
        _lastMarketUpdates[update.symbol] = update;
        _marketUpdateControllers[update.symbol]?.add(update);
      },
      onError: (error) {
        print('WebSocket market update error: $error');
      },
    );
  }

  Map<String, double> getAllPrices() {
    final Map<String, double> prices = {};
    _socketService.lastStockUpdates.forEach((symbol, update) {
      prices[symbol] = update.ltp;
    });
    return prices;
  }

  String getStockName(String symbol) {
    final update = _socketService.getLastStockUpdate(symbol);
    return update?.name ?? symbol;
  }

  Stream<stock_models.StockUpdate> getStockUpdates(String symbol) {
    if (!_controllers.containsKey(symbol)) {
      _controllers[symbol] =
          StreamController<stock_models.StockUpdate>.broadcast();
      final lastUpdate = _socketService.getLastStockUpdate(symbol);
      if (lastUpdate != null) {
        _controllers[symbol]?.add(lastUpdate);
      }
    }
    return _controllers[symbol]!.stream;
  }

  Stream<market_models.MarketUpdate> getMarketUpdates(String index) {
    if (!_marketUpdateControllers.containsKey(index)) {
      _marketUpdateControllers[index] =
          StreamController<market_models.MarketUpdate>.broadcast();
      final lastUpdate = _socketService.getLastMarketUpdate(index);
      if (lastUpdate != null) {
        _marketUpdateControllers[index]?.add(lastUpdate);
      }
    }
    return _marketUpdateControllers[index]!.stream;
  }

  double getCurrentPrice(String symbol) {
    final update = _socketService.getLastStockUpdate(symbol);
    return update?.ltp ?? 0.0;
  }

  void dispose() {
    for (var controller in _controllers.values) {
      controller.close();
    }
    for (var controller in _marketUpdateControllers.values) {
      controller.close();
    }
    _socketService.disconnect();
  }
}
