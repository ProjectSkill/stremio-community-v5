FROM node:20-slim

WORKDIR /app

# Install tools

RUN apt-get update && apt-get install -y git wget curl && rm -rf /var/lib/apt/lists/*

# Download Stremio Web pre-built release from GitHub

RUN wget -O stremio-web.tar.gz https://github.com/Stremio/stremio-web/releases/download/v4.4.168/stremio-web-v4.4.168.tar.gz &&   
tar -xzf stremio-web.tar.gz &&   
rm stremio-web.tar.gz &&   
mv build /app/stremio-web

# Build community addon

RUN git clone –depth 1 https://github.com/ProjectSkill/stremio-community-v5 /app/addon &&   
cd /app/addon &&   
npm install &&   
npm run build

# Download Glass Theme CSS

RUN wget -O /app/stremio-web/glass-theme.css   
https://raw.githubusercontent.com/Fxy6969/Stremio-Glass-Theme/cover/StremioGlass.css

# Inject Glass Theme into index.html

RUN find /app/stremio-web -name “index.html” -exec sed -i ‘s|</head>|<link rel="stylesheet" href="/glass-theme.css"><style>body{background:#0a0a0a;}</style></head>|g’ {} ;

# Create server.js in /app (not inside stremio-web)

RUN cat > /app/server.js << ‘EOF’
const express = require(“express”);
const path = require(“path”);
const { createProxyMiddleware } = require(“http-proxy-middleware”);
const { spawn } = require(“child_process”);
const https = require(“https”);

const app = express();
const PORT = process.env.PORT || 10000;
const RENDER_URL = process.env.RENDER_EXTERNAL_URL;

console.log(“Starting Community Addon backend…”);

const addon = spawn(“node”, [“server.js”, “–port=7000”, “–host=127.0.0.1”], {
cwd: “/app/addon”,
stdio: “inherit”
});

addon.on(“error”, (err) => console.error(“Addon error:”, err));

// Keep-alive for Render
if (RENDER_URL) {
setInterval(() => {
https.get(RENDER_URL, (res) => {
console.log(`Keep-alive ping: ${res.statusCode}`);
}).on(“error”, (e) => {
console.error(`Keep-alive error: ${e.message}`);
});
}, 14 * 60 * 1000);
}

// Health check
app.get(”/health”, (req, res) => {
res.json({ status: “healthy”, timestamp: Date.now() });
});

// Proxy addon requests
app.use(”/addon”, createProxyMiddleware({
target: “http://127.0.0.1:7000”,
changeOrigin: true,
pathRewrite: { “^/addon”: “” },
logLevel: “silent”
}));

// Serve Stremio Web static files
app.use(express.static(path.join(__dirname, “stremio-web”)));

// SPA fallback
app.get(”*”, (req, res) => {
res.sendFile(path.join(__dirname, “stremio-web”, “index.html”));
});

// Start server
app.listen(PORT, “0.0.0.0”, () => {
console.log(`Glass Theme running on port ${PORT}`);
if (RENDER_URL) console.log(`URL: ${RENDER_URL}`);
});

// Graceful shutdown
process.on(“SIGTERM”, () => {
addon.kill();
process.exit(0);
});
EOF

# Install server dependencies

RUN npm init -y && npm install express http-proxy-middleware

ENV NODE_ENV=production

EXPOSE 10000

CMD [“node”, “/app/server.js”]
