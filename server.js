const express = require("express");
const http = require("http");
const socketIo = require("socket.io");
const fs = require("fs");
const csv = require("csv-parser");
const { KiteTicker } = require("kiteconnect");
const path = require("path");

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*", // Flutter-friendly
  },
});

// Zerodha Credentials (Replace these with ENV in production)
const apiKey = "g33tntd1ecmoddy2";
const accessToken = "IbxfJXtIgAUX7e19lS0nCaRXilEtuhr3";

// Path to CSV file
const instrumentsFilePath = path.join(__dirname, "instruments.csv");

// Data storage
let top200Tokens = [];
const tokenMap = {}; // instrument_token -> symbol

const ticker = new KiteTicker({ api_key: apiKey, access_token: accessToken });

// Step 1: Load and Filter Top 200 NSE EQ tokens (based on alphabetical order or customize)
function loadTopNSEEquityTokens(limit = 200) {
  return new Promise((resolve, reject) => {
    const tempList = [];

    fs.createReadStream(instrumentsFilePath)
      .pipe(csv())
      .on("data", (row) => {
        if (row.exchange === "NSE" && row.instrument_type === "EQ") {
          const token = parseInt(row.instrument_token);
          const symbol = row.tradingsymbol;
          tempList.push({ token, symbol });
        }
      })
      .on("end", () => {
        // Optional: Sort alphabetically or by market cap if you have extra data
        tempList.sort((a, b) => a.symbol.localeCompare(b.symbol));

        top200Tokens = tempList.slice(0, limit).map((item) => item.token);
        tempList.slice(0, limit).forEach((item) => {
          tokenMap[item.token] = item.symbol;
        });

        console.log(`✅ Loaded top ${top200Tokens.length} NSE EQ tokens`);
        resolve();
      })
      .on("error", reject);
  });
}

// Step 2: WebSocket & Ticker setup
function startServer() {
  io.on("connection", (socket) => {
    console.log("🟢 Client connected via WebSocket");

    socket.on("disconnect", () => {
      console.log("🔴 Client disconnected");
    });
  });

  ticker.connect();

  ticker.on("connect", () => {
    console.log("🟢 Connected to Zerodha WebSocket");

    const batch = top200Tokens;
    ticker.subscribe(batch);
    ticker.setMode(ticker.modeFull, batch);

    console.log(`✅ Subscribed to ${batch.length} tokens`);
  });

  ticker.on("ticks", (ticks) => {
    const enrichedTicks = ticks.map((tick) => ({
      token: tick.instrument_token,
      symbol: tokenMap[tick.instrument_token] || "UNKNOWN",
      lastPrice: tick.last_price,
      volume: tick.volume,
      change: tick.change,
      timestamp: tick.timestamp,
    }));

    io.emit("tick", enrichedTicks);
  });

  ticker.on("error", (err) => {
    console.error("❌ Zerodha WebSocket error:", err);
  });

  ticker.on("close", () => {
    console.log("🔒 Zerodha WebSocket closed");
  });

  server.listen(3000, () => {
    console.log("🚀 Server running at http://localhost:3000");
  });
}

// Step 3: Run all
(async () => {
  try {
    await loadTopNSEEquityTokens(200); // you can change this to 50, 100, etc.
    startServer();
  } catch (err) {
    console.error("❌ Initialization failed:", err);
  }
})();
