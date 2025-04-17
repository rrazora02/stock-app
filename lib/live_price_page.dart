import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class LivePricePage extends StatefulWidget {
  @override
  _LivePricePageState createState() => _LivePricePageState();
}

class _LivePricePageState extends State<LivePricePage> {
  IO.Socket? socket;
  List<String> tickData = [];

  @override
  void initState() {
    super.initState();

    // Connect to WebSocket server (Replace with your IP or use localhost for emulator)
    socket = IO.io('ws://localhost:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    // Handle connection event
    socket!.onConnect((_) {
      print('Connected to Node.js WebSocket server');
    });

    // Listen to incoming data
    socket!.on("tick_data", (data) {
      setState(() {
        tickData = List<String>.from(data.map((tick) =>
            "Symbol: ${tick['symbol']} | Price: ${tick['price']} | High: ${tick['high']} | Low: ${tick['low']}"));
      });
    });
  }

  @override
  void dispose() {
    socket?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Live Stock Prices")),
      body: ListView.builder(
        itemCount: tickData.length,
        itemBuilder: (context, index) => ListTile(
          title: Text(tickData[index]),
        ),
      ),
    );
  }
}
