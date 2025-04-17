const { KiteTicker } = require("kiteconnect");
const fs = require("fs");
const csv = require("csv-parser");
const path = require("path");

// Zerodha credentials (same as in server.js)
const apiKey = "g33tntd1ecmoddy2";
const accessToken = "IbxfJXtIgAUX7e19lS0nCaRXilEtuhr3";

// Instruments file path
const instrumentsFilePath = path.join(__dirname, "instruments.csv");

// Store tokens and mapping
const tokens = [];
const tokenMap = {};

function getTopNSETokens(limit = 200) {
  return new Promise((resolve, reject) => {
    const temp = [];

    fs.createReadStream(instrumentsFilePath)
      .pipe(csv())
      .on("data", (row) => {
        if (row.exchange === "NSE" && row.instrument_type === "EQ") {
          temp.push({
            token: parseInt(row.instrument_token),
            symbol: row.tradingsymbol,
          });
        }
      })
      .on("end", () => {
        temp.sort((a, b) => a.symbol.localeCompare(b.symbol));
        const top = temp.slice(0, limit);

        top.forEach((item) => {
          tokens.push(item.token);
          tokenMap[item.token] = item.symbol;
        });

        console.log(`✅ Loaded ${tokens.length} tokens`);
        resolve();
      })
      .on("error", reject);
  });
}

function connectWebSocket() {
  const ticker = new KiteTicker({
    api_key: apiKey,
    access_token: accessToken,
  });

  ticker.on("connect", () => {
    console.log("🟢 Connected to WebSocket");

    ticker.subscribe(tokens);
    ticker.setMode(ticker.modeFull, tokens);
  });

  ticker.on("ticks", (ticks) => {
    const data = ticks.map((tick) => ({
      token: tick.instrument_token,
      symbol: tokenMap[tick.instrument_token] || "UNKNOWN",
      lastPrice: tick.last_price,
      volume: tick.volume,
      change: tick.change,
      timestamp: tick.timestamp,
    }));

    console.log("📈 Tick Data:", data);
  });

  ticker.on("error", (err) => {
    console.error("❌ WebSocket Error:", err);
  });

  ticker.on("close", () => {
    console.warn("🔒 WebSocket Closed");
  });

  ticker.connect();
}

// Run it
(async () => {
  try {
    await getTopNSETokens(200);
    connectWebSocket();
  } catch (err) {
    console.error("❌ Error:", err);
  }
})();
