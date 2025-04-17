const { KiteConnect } = require("kiteconnect");

const kc = new KiteConnect({
  api_key: "g33tntd1ecmoddy2",
});

kc.generateSession("Jt2a8UAVod5S0ad078649mFwzrZ8ldHM", {
  api_secret: "1hlh2t9xbisuui38sl525720xg0824x6",
})
  .then(function (response) {
    console.log("✅ Login successful!");
    console.log("access_token:", response.access_token);
  })
  .catch(function (err) {
    console.error("❌ Error generating access_token", err);
  });