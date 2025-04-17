import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

class ChatService {
  static const String _apiKey = 'g33tntd1ecmoddy2';
  static const String _baseUrl = 'https://api.marketdata.com/v1';

  // Cache for stock prices to reduce API calls
  final Map<String, _CachedStockPrice> _priceCache = {};
  static const Duration _cacheDuration = Duration(minutes: 5);

  Future<String> getBotResponse(
      String message, Map<String, dynamic> context) async {
    try {
      message = message.trim();
      if (message.isEmpty) {
        return 'Please enter a valid message.';
      }

      // First, try to handle specific stock-related queries
      if (message.toLowerCase().contains('price') ||
          message.toLowerCase().contains('value')) {
        final stockSymbol = _extractStockSymbol(message);
        if (stockSymbol != null) {
          return await _getStockPrice(stockSymbol);
        }
      }

      // If no specific stock query, use the general market chat API
      final response = await http
          .post(
        Uri.parse('$_baseUrl/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'message': message,
          'context': context,
        }),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'];
      } else if (response.statusCode == 401) {
        return 'Sorry, there was an authentication error. Please try again later.';
      } else if (response.statusCode == 429) {
        return 'The service is currently busy. Please try again in a few moments.';
      } else {
        return _getFallbackResponse(message);
      }
    } on TimeoutException {
      return 'The request took too long. Please try again.';
    } catch (e) {
      return _getFallbackResponse(message);
    }
  }

  String? _extractStockSymbol(String message) {
    // Enhanced regex to extract stock symbols (uppercase letters)
    final regex = RegExp(r'[A-Z]{2,10}(?:\.[A-Z]{2,3})?');
    final matches = regex.allMatches(message);
    if (matches.isNotEmpty) {
      return matches.first.group(0);
    }
    return null;
  }

  Future<String> _getStockPrice(String symbol) async {
    try {
      // Check cache first
      final cachedPrice = _priceCache[symbol];
      if (cachedPrice != null &&
          DateTime.now().difference(cachedPrice.timestamp) < _cacheDuration) {
        return 'The current price of $symbol is ₹${cachedPrice.price} (${cachedPrice.change}%)';
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/stocks/$symbol'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Price fetch timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final price = data['price'].toStringAsFixed(2);
        final change = data['change'].toStringAsFixed(2);

        // Update cache
        _priceCache[symbol] = _CachedStockPrice(
          price: price,
          change: change,
          timestamp: DateTime.now(),
        );

        return 'The current price of $symbol is ₹$price ($change%)';
      } else {
        return 'Sorry, I couldn\'t fetch the price for $symbol at the moment.';
      }
    } on TimeoutException {
      return 'The price request took too long. Please try again.';
    } catch (e) {
      return 'Sorry, I encountered an error while fetching the price for $symbol.';
    }
  }

  String _getFallbackResponse(String message) {
    message = message.toLowerCase();

    // Handle empty or very short messages
    if (message.length < 2) {
      return 'Please enter a more detailed question about stocks or the market.';
    }

    if (message.contains('hello') || message.contains('hi')) {
      return 'Hello! I\'m your market assistant. How can I help you with stocks today?';
    } else if (message.contains('help')) {
      return 'I can help you with:\n'
          '• Stock prices and trends\n'
          '• Market analysis\n'
          '• Portfolio suggestions\n'
          '• Trading strategies\n'
          'Just ask me anything about the market!';
    } else if (message.contains('market') || message.contains('trend')) {
      return 'The market is showing positive momentum today. Would you like to know about specific sectors or stocks?';
    } else if (message.contains('portfolio') || message.contains('holdings')) {
      return 'I can help you analyze your portfolio. Would you like to:\n'
          '1. Check your current holdings\n'
          '2. Get portfolio recommendations\n'
          '3. Calculate returns';
    } else if (message.contains('buy') || message.contains('sell')) {
      return 'I can help you with trading decisions. Please specify:\n'
          '1. The stock you\'re interested in\n'
          '2. Whether you want to buy or sell\n'
          '3. Your investment horizon';
    } else {
      return 'I\'m here to help with market-related questions. You can ask me about:\n'
          '• Stock prices\n'
          '• Market trends\n'
          '• Trading strategies\n'
          '• Portfolio management\n'
          'What would you like to know?';
    }
  }
}

class _CachedStockPrice {
  final String price;
  final String change;
  final DateTime timestamp;

  _CachedStockPrice({
    required this.price,
    required this.change,
    required this.timestamp,
  });
}
