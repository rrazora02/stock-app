import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/portfolio.dart';
import 'services/stock_service.dart';
import 'services/chat_service.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/settings_screen.dart';
import 'dart:math';
import 'providers/theme_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'widgets/stock_chart.dart';
import 'widgets/trading_view_chart.dart';
import 'screens/option_chain_screen.dart';
import 'package:my_stock_app/models/stock.dart';
import 'services/socket_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'live_price_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
    return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Stock Trading App',
          theme: themeProvider.theme,
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  final SocketService _socketService = SocketService();
  bool _isAuthenticated = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    try {
      await _authService.init();
      final isLoggedIn = await _authService.isLoggedIn();

      if (isLoggedIn) {
        final hasPin = await _authService.hasPin();
        if (!hasPin) {
          // First time login, setup PIN
          final pinSetup = await _authService.setupPin();
          if (pinSetup) {
            setState(() {
              _isAuthenticated = true;
              _isLoading = false;
            });
            _socketService.connect(); // Connect to socket after authentication
            return;
          }
        } else {
          // Already logged in, verify PIN
          final authenticated = await _authService.authenticateWithPin();
          if (authenticated) {
            setState(() {
              _isAuthenticated = true;
              _isLoading = false;
            });
            _socketService.connect(); // Connect to socket after authentication
            return;
          }
        }
      }

      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    } catch (e) {
      print('Error during authentication: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _socketService.disconnect(); // Disconnect socket when widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return _isAuthenticated ? const TradingHomePage() : const LoginScreen();
  }
}

class TradingHomePage extends StatefulWidget {
  const TradingHomePage({super.key});

  @override
  State<TradingHomePage> createState() => _TradingHomePageState();
}

class _TradingHomePageState extends State<TradingHomePage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late StockService _stockService;
  late SocketService _socketService;
  late final ChatService _chatService;
  late final Portfolio _portfolio;
  final Map<String, Stock> _stocks = {};
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _showGainers = true;
  String _selectedCap = 'Large Cap';
  final List<ChatMessage> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  final bool _isTyping = false;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _stockService = StockService();
    _socketService = SocketService();
    _chatService = ChatService();
    _portfolio = Portfolio();
    _initializeStocks();
    _tabController = TabController(length: 5, vsync: this);
    _pages = []; // Initialize empty pages list
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializePages();
  }

  void _initializePages() {
    _pages = [
      _buildMarketTabView(),
      _buildWatchlistView(),
      _buildPortfolioView(),
      _buildChatView(),
      _buildOrdersView(),
    ];
  }

  void _initializeStocks() {
    final indianStocks = {
      'RELIANCE': 'Reliance Industries',
      'TCS': 'Tata Consultancy Services',
      'HDFCBANK': 'HDFC Bank',
      'INFY': 'Infosys',
      'HINDUNILVR': 'Hindustan Unilever',
      'ICICIBANK': 'ICICI Bank',
      'SBIN': 'State Bank of India',
      'BHARTIARTL': 'Bharti Airtel',
      'KOTAKBANK': 'Kotak Mahindra Bank',
      'BAJFINANCE': 'Bajaj Finance',
      'HDFC': 'HDFC Ltd',
      'WIPRO': 'Wipro',
      'ONGC': 'Oil & Natural Gas Corp',
      'ITC': 'ITC Ltd',
      'LT': 'Larsen & Toubro',
      'ASIANPAINT': 'Asian Paints',
      'MARUTI': 'Maruti Suzuki',
      'NTPC': 'NTPC Ltd',
      'POWERGRID': 'Power Grid Corp',
      'SUNPHARMA': 'Sun Pharmaceutical',
    };

    indianStocks.forEach((symbol, name) {
      _stocks[symbol] = Stock(
        symbol: symbol,
        name: name,
        ltp: _stockService.getCurrentPrice(symbol),
        change: 0.0,
        percentChange: 0.0,
        dayHigh: 0.0,
        dayLow: 0.0,
        volume: 0,
        marketCap: 0.0,
      );
      _stockService.getStockUpdates(symbol).listen((update) {
        setState(() {
          _stocks[symbol] = Stock(
            symbol: update.symbol,
            name: update.name,
            ltp: update.price,
            change: update.change,
            percentChange: update.changePercent,
            dayHigh: update.dayHigh,
            dayLow: update.dayLow,
            volume: update.volume,
            marketCap: update.marketCap,
          );
        });
      });
    });
  }

  @override
  void dispose() {
    _stockService.dispose();
    _tabController.dispose();
    _searchController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.account_circle_outlined),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            );
          },
        ),
        title: const Text('Market Yog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Show notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () {
              _showPortfolioDialog(context);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Market'),
              Tab(text: 'Watchlist'),
              Tab(text: 'Portfolio'),
                  Tab(text: 'Chat'),
                  Tab(text: 'Orders'),
            ],
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),
              SizedBox(
                height: MediaQuery.of(context).size.height - 200,
            child: TabBarView(
              controller: _tabController,
                  children: _pages,
                ),
              ),
              _buildTopMoversSection(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
            _tabController.animateTo(index);
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'HOME',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_outline),
            label: 'WATCHLIST',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance),
            label: 'PORTFOLIO',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'CHAT',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'ORDERS',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showQuickTradeDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMarketTabView() {
    return SingleChildScrollView(
      child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search stocks...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (value) {
                setState(() {});
            },
          ),
        ),
          _buildMarketsToday(),
        Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  top: 16.0,
                  right: 16.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Top Movers',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TopMoversPage(
                              stockService: _stockService,
                              showGainers: _showGainers,
                              selectedCap: _selectedCap,
                            ),
                          ),
                        );
                      },
                      child: const Text('VIEW ALL'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _showGainers = true;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                              color: _showGainers
                                  ? Colors.blue
                                  : Colors.transparent,
                            border: Border.all(
                              color: _showGainers
                                  ? Colors.blue
                                  : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Gainers',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: _showGainers
                                    ? Colors.white
                                    : Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _showGainers = false;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: !_showGainers
                                ? Colors.blue
                                : Colors.transparent,
                            border: Border.all(
                              color: !_showGainers
                                  ? Colors.blue
                                  : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Losers',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: !_showGainers
                                    ? Colors.white
                                    : Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    _buildCapButton('Large Cap', _selectedCap == 'Large Cap'),
                    const SizedBox(width: 8),
                    _buildCapButton('Mid Cap', _selectedCap == 'Mid Cap'),
                    const SizedBox(width: 8),
                    _buildCapButton('Small Cap', _selectedCap == 'Small Cap'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 140,
                  child:
                      _showGainers ? _buildGainersList() : _buildLosersList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
          SizedBox(
            height: MediaQuery.of(context).size.height - 400,
          child: _buildMarketView(),
        ),
      ],
      ),
    );
  }

  Widget _buildMarketsToday() {
    return Container(
      height: 135,
      color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
          const Padding(
            padding: EdgeInsets.only(left: 16.0, top: 8.0),
            child: Text(
              'Markets Today',
              style: TextStyle(
                color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
              ),
                        ),
                      ),
                      const SizedBox(height: 4),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              children: [
                _buildMarketCard(
                  'NIFTY 50',
                  '₹22876.70',
                  '+₹477.55',
                  '+2.13%',
                  'Expiry Thu',
                ),
                _buildMarketCard(
                  'NIFTY BANK',
                  '₹44556.30',
                  '+₹890.25',
                  '+2.45%',
                  'Expiry Wed',
                ),
                _buildMarketCard(
                  'SENSEX',
                  '₹75320.74',
                  '+₹1473.59',
                  '+2.00%',
                  'Expiry Tue',
                ),
                _buildMarketCard(
                  'NIFTY IT',
                  '₹35678.90',
                  '+₹678.45',
                  '+1.95%',
                  'Expiry Fri',
                ),
                _buildMarketCard(
                  'NIFTY AUTO',
                  '₹12345.67',
                  '+₹234.56',
                  '+1.90%',
                  'Expiry Mon',
                ),
              ],
                  ),
                ),
              ],
            ),
          );
        }

  Widget _buildMarketCard(
    String title,
    String value,
    String change,
    String percentChange,
    String expiry,
  ) {
    final isPositive = change.startsWith('+');
    final color = isPositive ? Colors.green : Colors.red;

          return InkWell(
            onTap: () {
        final stock = Stock(
          symbol: title,
          name: title,
          ltp: double.parse(value.replaceAll('₹', '')),
          change: double.parse(change.replaceAll('+', '').replaceAll('%', '')),
          percentChange: double.parse(
              percentChange.replaceAll('+', '').replaceAll('%', '')),
          dayHigh: 0.0,
          dayLow: 0.0,
          volume: 0,
          marketCap: 0.0,
        );
        _showDetailedStockView(context, stock);
            },
            child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
                    child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                title,
                          style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                          ),
                        ),
              const SizedBox(height: 2),
                        Text(
                value,
                        style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                        ),
                      ),
              const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                    isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                    color: color,
                    size: 12,
                  ),
                  const SizedBox(width: 2),
                          Text(
                    change,
                            style: TextStyle(
                      color: color,
                              fontWeight: FontWeight.w500,
                      fontSize: 11,
                            ),
                          ),
                        ],
                      ),
              const SizedBox(height: 2),
              Text(
                percentChange,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                expiry,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
              ),
            ),
          );
        }

  Widget _buildGainersList() {
    final stocks = _stocks.values.toList();
    stocks.sort((a, b) => b.percentChange.compareTo(a.percentChange));
    final gainers = stocks.take(5).toList();

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: gainers.length,
      itemBuilder: (context, index) {
        final stock = gainers[index];
        return _buildTopMoverCard(
          stock.symbol,
          '₹${stock.ltp.toStringAsFixed(2)}',
          stock.percentChange >= 0
              ? '+₹${(stock.ltp * stock.percentChange / 100).toStringAsFixed(2)}'
              : '-₹${(stock.ltp * stock.percentChange.abs() / 100).toStringAsFixed(2)}',
          '${stock.percentChange >= 0 ? '+' : ''}${stock.percentChange.toStringAsFixed(2)}%',
          '${Random().nextInt(100) + 50} recent buys',
          true,
        );
      },
    );
  }

  Widget _buildLosersList() {
    final stocks = _stocks.values.toList();
    stocks.sort((a, b) => a.percentChange.compareTo(b.percentChange));
    final losers = stocks.take(5).toList();

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: losers.length,
      itemBuilder: (context, index) {
        final stock = losers[index];
        return _buildTopMoverCard(
          stock.symbol,
          '₹${stock.ltp.toStringAsFixed(2)}',
          stock.percentChange >= 0
              ? '+₹${(stock.ltp * stock.percentChange / 100).toStringAsFixed(2)}'
              : '-₹${(stock.ltp * stock.percentChange.abs() / 100).toStringAsFixed(2)}',
          '${stock.percentChange >= 0 ? '+' : ''}${stock.percentChange.toStringAsFixed(2)}%',
          '${Random().nextInt(100) + 50} recent buys',
          false,
        );
      },
    );
  }

  Widget _buildMarketView() {
    final searchQuery = _searchController.text.toLowerCase().trim();
    final filteredStocks = _stocks.entries.where((entry) {
      final stock = entry.value;
      return stock.symbol.toLowerCase().contains(searchQuery) ||
          stock.name.toLowerCase().contains(searchQuery);
    }).toList();

    if (filteredStocks.isEmpty && searchQuery.isNotEmpty) {
      return Center(
                child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
                  children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
                    Text(
              'No stocks found',
              style: TextStyle(
                        fontSize: 16,
                color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            const SizedBox(height: 8),
                    Text(
              'Try searching with a different symbol or company name',
                      style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                      ),
              textAlign: TextAlign.center,
                    ),
                  ],
                ),
      );
    }

    return ListView.builder(
      itemCount: filteredStocks.length,
      itemBuilder: (context, index) {
        final stock = filteredStocks[index].value;
        return StockListTile(
          stock: stock,
          onTap: (stock) => _showDetailedStockView(context, stock),
          onTrade: (stock, isBuy) {
            try {
              if (isBuy) {
                _portfolio.buyStock(
                  stock.symbol,
                  stock.name,
                  stock.ltp,
                  1,
                );
              } else {
                _portfolio.sellStock(stock.symbol, stock.ltp, 1);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Successfully ${isBuy ? 'bought' : 'sold'} 1 share of ${stock.symbol}',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(e.toString()),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildWatchlistView() {
    return ListView.builder(
      itemCount: _stocks.length,
      itemBuilder: (context, index) {
        final stock = _stocks.values.elementAt(index);
        return _buildWatchlistStockTile(stock);
      },
    );
  }

  Widget _buildWatchlistStockTile(Stock stock) {
    return StreamBuilder<StockUpdate>(
      stream: _stockService.getStockUpdates(stock.symbol),
      initialData: StockUpdate(
        symbol: stock.symbol,
        name: stock.name,
        ltp: stock.ltp,
        change: stock.change,
        percentChange: stock.percentChange,
        dayHigh: stock.dayHigh,
        dayLow: stock.dayLow,
        volume: stock.volume,
        marketCap: stock.marketCap,
        lastUpdateTime: DateTime.now().toIso8601String(),
      ),
      builder: (context, AsyncSnapshot<StockUpdate> snapshot) {
        final StockUpdate currentStock = snapshot.data ??
            StockUpdate(
              symbol: stock.symbol,
              name: stock.name,
              ltp: stock.ltp,
              change: stock.change,
              percentChange: stock.percentChange,
              dayHigh: stock.dayHigh,
              dayLow: stock.dayLow,
              volume: stock.volume,
              marketCap: stock.marketCap,
              lastUpdateTime: DateTime.now().toIso8601String(),
            );

        return InkWell(
          onTap: () {
            final stockData = Stock(
              symbol: currentStock.symbol,
              name: currentStock.name,
              ltp: currentStock.ltp,
              change: currentStock.change,
              percentChange: currentStock.percentChange,
              dayHigh: currentStock.dayHigh,
              dayLow: currentStock.dayLow,
              volume: currentStock.volume,
              marketCap: currentStock.marketCap,
            );
            _showDetailedStockView(context, stockData);
          },
          child: ListTile(
            title: Text(_stockService.getStockName(currentStock.symbol)),
            subtitle: Text(currentStock.symbol),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
              Text(
                  '₹${currentStock.ltp.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${currentStock.percentChange >= 0 ? '+' : ''}${currentStock.percentChange.toStringAsFixed(2)}%',
                style: TextStyle(
                    color: currentStock.percentChange >= 0
                        ? Colors.green
                        : Colors.red,
                ),
              ),
            ],
            ),
          ),
        );
      },
    );
  }

  void _showDetailedStockView(BuildContext context, Stock stock) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
          children: [
            // Header with stock info
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        stock.symbol,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.star_border, color: Colors.white),
                        onPressed: () {
                          // Add to watchlist functionality
                        },
                      ),
                    ],
                  ),
                      Text(
                        stock.name,
                        style: TextStyle(
                          fontSize: 14,
                      color: Colors.grey[400],
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                        '₹${stock.ltp.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                          color: Colors.white,
                    ),
                  ),
                      const SizedBox(width: 8),
                  Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                    decoration: BoxDecoration(
                          color: stock.percentChange >= 0
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${stock.percentChange >= 0 ? '+' : ''}${stock.percentChange.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: stock.percentChange >= 0
                                ? Colors.green
                                : Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(16.0),
                    child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                  _buildActionButton(
                    icon: Icons.show_chart,
                    label: 'Chart',
                    onTap: () => _showChart(context, stock),
                  ),
                  _buildActionButton(
                    icon: Icons.analytics,
                    label: 'Option Chain',
                    onTap: () => _showOptionChain(context, stock),
                  ),
                  _buildActionButton(
                    icon: Icons.info_outline,
                    label: 'Stock Details',
                    onTap: () {
                      // Show stock details
                    },
                        ),
                      ],
                    ),
                  ),

            const SizedBox(height: 16),

            // Price info table
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildPriceRow('OPEN', '${stock.ltp - 10.25}'),
                  _buildPriceRow('HIGH', '${stock.ltp + 172.40}'),
                  _buildPriceRow('LOW', '${stock.ltp - 180.35}'),
                  _buildPriceRow('PREV. CLOSE', '${stock.ltp - 15.60}'),
                ],
              ),
            ),

            const Spacer(),

            // Buy and Sell buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleTrade(stock, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'BUY',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleTrade(stock, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'SELL',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              ),
            ],
          ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          Text(
            '₹$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapButton(String text, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCap = text;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.blue : Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTopMoversSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Top Movers',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 5, // Show 5 top movers
            itemBuilder: (context, index) {
              return Container(
                width: 200,
                margin: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Card(
          child: Padding(
                    padding: const EdgeInsets.all(8.0),
            child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                          'Stock ${index + 1}',
                          style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                        Text(
                          'Price: ₹1000',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Change: +5%',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.green,
                                  ),
                    ),
                  ],
                ),
                  ),
                ),
              );
            },
                ),
              ),
            ],
    );
  }

  void _showPortfolioDialog(BuildContext context) {
    // Implementation will be added if needed
  }

  Widget _buildPortfolioView() {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                    const Text(
                      'Portfolio Value',
                      style: TextStyle(
                        fontSize: 18,
                                  fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                              ),
                            ],
                          ),
                const SizedBox(height: 16),
                              Text(
                  '₹${_portfolio.totalValue.toStringAsFixed(2)}',
                                style: const TextStyle(
                    fontSize: 32,
                                  fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _portfolio.totalChange >= 0
                            ? Colors.green[100]
                            : Colors.red[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_portfolio.totalChange >= 0 ? '+' : ''}${_portfolio.totalChange.toStringAsFixed(2)}%',
                                style: TextStyle(
                          color: _portfolio.totalChange >= 0
                              ? Colors.green[700]
                              : Colors.red[700],
                                  fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Today',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _portfolio.holdings.length,
            itemBuilder: (context, index) {
              final holding = _portfolio.holdings.values.elementAt(index);
              return ListTile(
                title: Text(holding.symbol),
                subtitle: Text(holding.name),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                      '₹${holding.getCurrentValue(holding.currentPrice).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                          ),
                          ),
                          Text(
                      '${holding.shares} shares',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      ),
                    ],
                  ),
                onTap: () {
                  final stock = Stock(
                    symbol: holding.symbol,
                    name: holding.name,
                    ltp: holding.currentPrice,
                    change: holding.changePercent,
                    percentChange: holding.changePercent,
                    dayHigh: 0.0,
                    dayLow: 0.0,
                    volume: 0,
                    marketCap: 0.0,
                  );
                  _showDetailedStockView(context, stock);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChatView() {
    // Implementation will be added if needed
    return Container();
  }

  Widget _buildOrdersView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              const Text(
                'Order History',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 16),
              // No orders placeholder
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Pending Orders',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please place a new order',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        _showQuickTradeDialog(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text('VIEW ORDER HISTORY'),
                    ),
                    const SizedBox(height: 12),
          TextButton(
                      onPressed: () {
                        _tabController.animateTo(0); // Switch to Market tab
                      },
                      child: const Text('VIEW TRADING IDEAS'),
          ),
        ],
      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showQuickTradeDialog(BuildContext context) {
    // Implementation will be added if needed
  }

  void _showChart(BuildContext context, Stock stock) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: const Color(0xFF1C1C1E),
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                Text(stock.symbol),
                Text(
                  'NSE',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1C1C1E),
          ),
          body: Column(
            children: [
              Expanded(
                child: TradingViewChart(symbol: stock.symbol),
              ),
              Container(
                padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                        onPressed: () => _handleTrade(stock, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'BUY',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                        onPressed: () => _handleTrade(stock, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'SELL',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  void _showOptionChain(BuildContext context, Stock stock) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OptionChainScreen(
          stock: stock,
        ),
      ),
    );
  }

  void _handleTrade(Stock stock, bool isBuy) {
    bool showAdvancedOptions = false;
    String selectedOrderType = 'DELIVERY';
    int maxQty = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                      stock.symbol,
                          style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'NSE',
                  style: TextStyle(
                    color: Colors.grey[400],
                            fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      '₹${stock.ltp.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                          ),
                          decoration: BoxDecoration(
                        color: stock.percentChange >= 0
                            ? Colors.green.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                        '${stock.percentChange >= 0 ? '+' : ''}${stock.percentChange.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: stock.percentChange >= 0
                              ? Colors.green
                              : Colors.red,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Order type selection
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildOrderTypeButton(
                          'DELIVERY',
                          selectedOrderType == 'DELIVERY',
                          () => setState(() => selectedOrderType = 'DELIVERY'),
                        ),
                      ),
                      Expanded(
                        child: _buildOrderTypeButton(
                          'INTRADAY\nBuy 5x',
                          selectedOrderType == 'INTRADAY',
                          () => setState(() => selectedOrderType = 'INTRADAY'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Number of shares
                Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                        const Text(
                          'No. of shares',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      Text(
                          'Max Qty $maxQty',
                          style: TextStyle(
                            color: Colors.grey[400],
                          fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                        decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const TextField(
                        style: TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                // Limit Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Limit Price',
                      style: TextStyle(
                        color: Colors.white,
                      fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.remove, color: Colors.teal),
                            onPressed: () {},
                          ),
                        ),
                        Expanded(
      child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            color: Colors.grey[800],
                            child: TextField(
                              style: const TextStyle(color: Colors.black),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              controller: TextEditingController(
                                text: stock.ltp.toStringAsFixed(2),
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                              ),
          ),
        ),
      ),
                        Container(
      decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add, color: Colors.teal),
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Stop Loss Price
                Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                    const Text(
                      'Stop Loss Price',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.remove, color: Colors.teal),
                            onPressed: () {},
                          ),
                        ),
              Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            color: Colors.grey[800],
                            child: TextField(
                              style: const TextStyle(color: Colors.black),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              controller: TextEditingController(
                                text: (stock.ltp * 0.95).toStringAsFixed(2),
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add, color: Colors.teal),
                            onPressed: () {},
                ),
              ),
            ],
          ),
                  ],
                ),
                const SizedBox(height: 24),
                // Trigger Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trigger Price',
            style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
            ),
          ),
                    const SizedBox(height: 8),
          Row(
            children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.remove, color: Colors.teal),
                            onPressed: () {},
                          ),
                        ),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            color: Colors.grey[800],
                            child: TextField(
                              style: const TextStyle(color: Colors.black),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              controller: TextEditingController(
                                text: (stock.ltp * 1.05).toStringAsFixed(2),
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add, color: Colors.teal),
                            onPressed: () {},
                          ),
              ),
            ],
          ),
        ],
      ),
                const SizedBox(height: 24),
                // Available Funds Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                            'Available Funds',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.grey,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                    Text(
                                'Margin x1',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                    ),
                  ],
                ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '₹10,000.00',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                    Text(
                              'Required Margin',
                      style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                            const Text(
                              '₹0.00',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                        ),
                ),
              ],
            ),
                ),
                const SizedBox(height: 24),
                // Place Order Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isBuy
                                ? 'Successfully bought ${stock.symbol}'
                                : 'Successfully sold ${stock.symbol}',
                          ),
                          backgroundColor: isBuy ? Colors.green : Colors.red,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'PLACE BUY ORDER',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderTypeButton(
      String text, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTopMoverCard(
    String symbol,
    String price,
    String change,
    String percentChange,
    String recentBuys,
    bool isGainer,
  ) {
    return Container(
      width: 200,
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                symbol,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                price,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                change,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isGainer ? Colors.green : Colors.red,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                percentChange,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isGainer ? Colors.green : Colors.red,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                recentBuys,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StockListTile extends StatelessWidget {
  final Stock stock;
  final Function(Stock) onTap;
  final Function(Stock, bool) onTrade;

  const StockListTile({
    Key? key,
    required this.stock,
    required this.onTap,
    required this.onTrade,
  }) : super(key: key);

  void _showChart(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('${stock.symbol} Chart'),
          ),
          body: TradingViewChart(symbol: stock.symbol),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(stock.symbol),
      subtitle: Text(stock.name),
      trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
          Text(
            '₹${stock.ltp.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:
                  stock.percentChange >= 0 ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${stock.percentChange >= 0 ? '+' : ''}${stock.percentChange.toStringAsFixed(2)}%',
              style: TextStyle(
                color: stock.percentChange >= 0 ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.show_chart),
            onPressed: () => _showChart(context),
            tooltip: 'View Chart',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => onTrade(stock, true),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => onTrade(stock, false),
          ),
        ],
      ),
      onTap: () => onTap(stock),
    );
  }
}

class TopMoversPage extends StatefulWidget {
  final StockService stockService;
  final bool showGainers;
  final String selectedCap;

  const TopMoversPage({
    Key? key,
    required this.stockService,
    required this.showGainers,
    required this.selectedCap,
  }) : super(key: key);

  @override
  State<TopMoversPage> createState() => _TopMoversPageState();
}

class _TopMoversPageState extends State<TopMoversPage> {
  late bool _showGainers;
  late String _selectedCap;
  final Map<String, Stock> _stocks = {};
  final Portfolio _portfolio = Portfolio();

  @override
  void initState() {
    super.initState();
    _showGainers = widget.showGainers;
    _selectedCap = widget.selectedCap;
    _initializeStocks();
  }

  void _initializeStocks() {
    final prices = widget.stockService.getAllPrices();
    prices.forEach((symbol, price) {
      _stocks[symbol] = Stock(
        symbol: symbol,
        name: widget.stockService.getStockName(symbol),
        ltp: price,
        change: 0.0,
        percentChange: 0.0,
        dayHigh: 0.0,
        dayLow: 0.0,
        volume: 0,
        marketCap: 0.0,
      );
      widget.stockService.getStockUpdates(symbol).listen((update) {
        setState(() {
          _stocks[symbol] = Stock(
            symbol: update.symbol,
            name: update.name,
            ltp: update.price,
            change: update.change,
            percentChange: update.changePercent,
            dayHigh: update.dayHigh,
            dayLow: update.dayLow,
            volume: update.volume,
            marketCap: update.marketCap,
          );
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final stocks = _stocks.values.toList();
    if (_showGainers) {
      stocks.sort((a, b) => b.percentChange.compareTo(a.percentChange));
    } else {
      stocks.sort((a, b) => a.percentChange.compareTo(b.percentChange));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_showGainers ? 'Top Gainers' : 'Top Losers'),
        backgroundColor: const Color(0xFF1C1C1E),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _showGainers = true;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _showGainers ? Colors.teal : Colors.transparent,
                        border: Border.all(
                          color:
                              _showGainers ? Colors.teal : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Gainers',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _showGainers ? Colors.white : Colors.grey[400],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _showGainers = false;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: !_showGainers ? Colors.teal : Colors.transparent,
                        border: Border.all(
                          color: !_showGainers
                              ? Colors.teal
                              : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Losers',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color:
                              !_showGainers ? Colors.white : Colors.grey[400],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: stocks.length,
              itemBuilder: (context, index) {
                final stock = stocks[index];
                return ListTile(
                  title: Text(
                    stock.symbol,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    stock.name,
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${stock.ltp.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: stock.percentChange >= 0
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
                          '${stock.percentChange >= 0 ? '+' : ''}${stock.percentChange.toStringAsFixed(2)}%',
          style: TextStyle(
                            color: stock.percentChange >= 0
                                ? Colors.green
                                : Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _handleTrade(stock, true),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _handleTrade(Stock stock, bool isBuy) {
    bool showAdvancedOptions = false;
    String selectedOrderType = 'DELIVERY';
    int maxQty = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    stock.symbol,
                    style: const TextStyle(
                      color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                  Text(
                  'NSE',
                    style: TextStyle(
                    color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                children: [
                  Text(
                      '₹${stock.ltp.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: stock.percentChange >= 0
                            ? Colors.green.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${stock.percentChange >= 0 ? '+' : ''}${stock.percentChange.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: stock.percentChange >= 0
                              ? Colors.green
                              : Colors.red,
                          fontSize: 14,
                        ),
                      ),
                  ),
                ],
              ),
                const SizedBox(height: 24),
                // Order type selection
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildOrderTypeButton(
                          'DELIVERY',
                          selectedOrderType == 'DELIVERY',
                          () => setState(() => selectedOrderType = 'DELIVERY'),
                        ),
                      ),
                      Expanded(
                        child: _buildOrderTypeButton(
                          'INTRADAY\nBuy 5x',
                          selectedOrderType == 'INTRADAY',
                          () => setState(() => selectedOrderType = 'INTRADAY'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Number of shares
                Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                        const Text(
                          'No. of shares',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      Text(
                          'Max Qty $maxQty',
                        style: TextStyle(
                            color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const TextField(
                        style: TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                  ),
                ],
              ),
                const SizedBox(height: 24),
                // Limit Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Limit Price',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.remove, color: Colors.teal),
                            onPressed: () {},
                          ),
                        ),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            color: Colors.grey[800],
                            child: TextField(
                              style: const TextStyle(color: Colors.black),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              controller: TextEditingController(
                                text: stock.ltp.toStringAsFixed(2),
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                              ),
                            ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add, color: Colors.teal),
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Stop Loss Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stop Loss Price',
                          style: TextStyle(
                        color: Colors.white,
                            fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.remove, color: Colors.teal),
                            onPressed: () {},
                          ),
                        ),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            color: Colors.grey[800],
                            child: TextField(
                              style: const TextStyle(color: Colors.black),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              controller: TextEditingController(
                                text: (stock.ltp * 0.95).toStringAsFixed(2),
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add, color: Colors.teal),
                            onPressed: () {},
                          ),
                        ),
                      ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
                // Trigger Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              const Text(
                      'Trigger Price',
                style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
              Row(
                children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.remove, color: Colors.teal),
                            onPressed: () {},
                          ),
                        ),
                  Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            color: Colors.grey[800],
                            child: TextField(
                              style: const TextStyle(color: Colors.black),
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              controller: TextEditingController(
                                text: (stock.ltp * 1.05).toStringAsFixed(2),
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add, color: Colors.teal),
                            onPressed: () {},
                    ),
                  ),
                ],
              ),
            ],
          ),
                const SizedBox(height: 24),
                // Available Funds Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
                            'Available Funds',
            style: TextStyle(
                              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.grey,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
          Text(
                                'Margin x1',
                                style: TextStyle(
                                  color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '₹10,000.00',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                            Text(
                              'Required Margin',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                            const Text(
                              '₹0.00',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Place Order Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                  onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isBuy
                                ? 'Successfully bought ${stock.symbol}'
                                : 'Successfully sold ${stock.symbol}',
                          ),
                          backgroundColor: isBuy ? Colors.green : Colors.red,
                        ),
                      );
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'PLACE BUY ORDER',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            ),
          ],
        ),
          );
        },
      ),
    );
  }

  Widget _buildOrderTypeButton(
      String text, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}
