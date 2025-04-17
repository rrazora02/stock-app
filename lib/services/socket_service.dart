import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/stock.dart';
import '../models/market_data.dart';
import '../models/top_movers.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  late IO.Socket socket;
  final Map<String, StockUpdate> _stockUpdates = {};
  final Map<String, MarketUpdate> _marketUpdates = {};
  final List<Function(Map<String, StockUpdate>)> _stockListeners = [];
  final List<Function(Map<String, MarketUpdate>)> _marketListeners = [];
  final _topMoversController = StreamController<TopMoversData>.broadcast();
  final _stockController = StreamController<StockUpdate>.broadcast();
  final _marketController = StreamController<MarketUpdate>.broadcast();
  bool _isConnected = false;

  Map<String, StockUpdate> get lastStockUpdates => _stockUpdates;
  Map<String, MarketUpdate> get lastMarketUpdates => _marketUpdates;
  Stream<TopMoversData> get topMoversUpdates => _topMoversController.stream;
  Stream<StockUpdate> get stockUpdates => _stockController.stream;
  Stream<MarketUpdate> get marketUpdates => _marketController.stream;

  StockUpdate? getLastStockUpdate(String symbol) {
    return _stockUpdates[symbol];
  }

  MarketUpdate? getLastMarketUpdate(String symbol) {
    return _marketUpdates[symbol];
  }

  void connect() {
    if (_isConnected) {
      print('🟡 Already connected to server');
      return;
    }

    try {
      print(
          '🟡 Attempting to connect to server at http://192.168.29.123:3000...');
      socket = IO.io(
        'http://192.168.29.123:3000',
        <String, dynamic>{
          'transports': ['websocket'],
          'autoConnect': true,
          'reconnection': true,
          'reconnectionAttempts': 5,
          'reconnectionDelay': 1000,
          'forceNew': true,
          'timeout': 10000,
        },
      );

      socket.clearListeners();

      socket.onConnect((_) {
        print('🟢 Connected to Node.js server at 192.168.29.123:3000');
        _isConnected = true;
        _requestInitialData();
      });

      // Handle raw data events
      socket.on('data', (data) {
        print('📊 Received raw data event: $data');
        _handleRawData(data);
      });

      // Handle tick data events
      socket.on('tick_data', (data) {
        print('📊 Received tick_data event: $data');
        _handleRawData(data);
      });

      socket.on('ticks', (data) {
        print('📊 Received ticks event: $data');
        _handleRawData(data);
      });

      socket.onDisconnect((_) {
        print('🔴 Disconnected from server');
        _isConnected = false;
      });

      socket.onError((error) {
        print('❌ Socket error: $error');
        _isConnected = false;
      });

      socket.onConnectError((error) {
        print('❌ Connection error: $error');
        _isConnected = false;
      });

      // Add ping/pong handlers
      socket.on('ping', (_) => print('🏓 Received ping from server'));
      socket.on('pong', (_) => print('🏓 Sent pong to server'));
    } catch (e) {
      print('❌ Error initializing socket: $e');
      _isConnected = false;
    }
  }

  void _handleRawData(dynamic data) {
    try {
      print('🔄 Processing raw data: $data');

      if (data is List) {
        // Handle array of ticks
        for (var tick in data) {
          _processTick(tick);
        }
      } else if (data is Map) {
        // Handle single tick or market update
        if (data['type'] == 'stock' || data['symbol'] != null) {
          _processTick(data);
        } else if (data['type'] == 'market') {
          _processMarketUpdate(data);
        }
      }
    } catch (e) {
      print('❌ Error processing raw data: $e');
      print('❌ Raw data that caused error: $data');
    }
  }

  void _processTick(dynamic tick) {
    try {
      print('📊 Processing tick: $tick');

      final symbol = tick['symbol'] as String;
      final price = (tick['price'] ?? tick['ltp'] ?? 0.0) as num;
      final volume = (tick['volume'] ?? 0) as num;
      final high = (tick['high'] ?? tick['dayHigh'] ?? 0.0) as num;
      final low = (tick['low'] ?? tick['dayLow'] ?? 0.0) as num;
      final time = tick['time'] as String? ?? DateTime.now().toIso8601String();

      print('📈 Creating update for $symbol:');
      print('   - Price: $price');
      print('   - Volume: $volume');
      print('   - High: $high');
      print('   - Low: $low');
      print('   - Time: $time');

      final update = StockUpdate(
        symbol: symbol,
        name: symbol,
        ltp: price.toDouble(),
        change: 0.0,
        percentChange: 0.0,
        dayHigh: high.toDouble(),
        dayLow: low.toDouble(),
        volume: volume.toInt(),
        marketCap: 0.0,
        lastUpdateTime: time,
      );

      _stockUpdates[symbol] = update;
      _stockController.add(update);
      _notifyStockListeners();
    } catch (e) {
      print('❌ Error processing tick: $e');
      print('❌ Tick data that caused error: $tick');
    }
  }

  void _processMarketUpdate(dynamic data) {
    try {
      print('📊 Processing market update: $data');

      final symbol = data['symbol'] as String;
      final price = (data['price'] ?? 0.0) as num;
      final change = (data['change'] ?? 0.0) as num;
      final changePercent = (data['changePercent'] ?? 0.0) as num;

      final update = MarketUpdate(
        symbol: symbol,
        price: price.toDouble(),
        change: change.toDouble(),
        changePercent: changePercent.toDouble(),
      );

      _marketUpdates[symbol] = update;
      _marketController.add(update);
      _notifyMarketListeners();
    } catch (e) {
      print('❌ Error processing market update: $e');
      print('❌ Market data that caused error: $data');
    }
  }

  void _requestInitialData() {
    print('🔄 Requesting initial data from server...');
    socket.emit('getInitialData');
  }

  void addStockListener(Function(Map<String, StockUpdate>) listener) {
    _stockListeners.add(listener);
  }

  void addMarketListener(Function(Map<String, MarketUpdate>) listener) {
    _marketListeners.add(listener);
  }

  void removeStockListener(Function(Map<String, StockUpdate>) listener) {
    _stockListeners.remove(listener);
  }

  void removeMarketListener(Function(Map<String, MarketUpdate>) listener) {
    _marketListeners.remove(listener);
  }

  void _notifyStockListeners() {
    for (var listener in _stockListeners) {
      listener(_stockUpdates);
    }
  }

  void _notifyMarketListeners() {
    for (var listener in _marketListeners) {
      listener(_marketUpdates);
    }
  }

  void disconnect() {
    print('🔌 Disconnecting from server...');
    socket.disconnect();
    _topMoversController.close();
    _stockController.close();
    _marketController.close();
  }
}
