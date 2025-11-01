const express = require("express");
const path = require("path");
const { createProxyMiddleware } = require("http-proxy-middleware");
const { spawn } = require("child_process");

const app = express();
const PORT = process.env.PORT || 8000;

console.log("Starting addon...");

// Spawn the Zaarrg addon process on port 7000
const addon = spawn("node", ["server.js", "--port=7000", "--host=127.0.0.1"], {
  cwd: "/app/addon",
  stdio: "inherit"
});

// Give the addon a few seconds to boot
setTimeout(() => console.log("Ready"), 3000);

// Proxy all /addon requests to the addon service
app.use(
  "/addon",
  createProxyMiddleware({
    target: "http://127.0.0.1:7000",
    changeOrigin: true,
    pathRewrite: { "^/addon": "" },
    logLevel: "silent"
  })
);

// Serve the built Stremio web UI
app.use(
  express.static(path.join(__dirname, "stremio-web/build"), { maxAge: "1d" })
);

// Fallback to index.html for SPA routing
app.get("*", (req, res) =>
  res.sendFile(path.join(__dirname, "stremio-web/build/index.html"))
);

// Start the proxy server
app.listen(PORT, "0.0.0.0", () => console.log(`Running on ${PORT}`));

// Clean shutdown
process.on("SIGTERM", () => {
  addon.kill();
  process.exit(0);
});