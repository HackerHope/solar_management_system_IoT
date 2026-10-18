import express from "express";
import cors from "cors";
import http from "http";
import { WebSocketServer } from "ws";

const PORT = process.env.PORT || 4000;
const MAX_HISTORY = 200; // how many readings to keep in memory for charts
const STALE_MS = 15000; // if no reading for this long, device is considered offline

const app = express();
app.use(cors());
app.use(express.json());

/** @type {Array<{timestamp:string, voltage:number, current:number, temperature:number, batteryPercent:number, power:number}>} */
let history = [];
let lastSeen = null;
let offlineAlertSent = false;

/** @type {Array<{id:string, timestamp:string, level:"info"|"warning"|"error", title:string, message:string}>} */
let alerts = [];

// ---- WebSocket broadcast ----
const server = http.createServer(app);
const wss = new WebSocketServer({ server });

function broadcast(message) {
  const payload = JSON.stringify(message);
  wss.clients.forEach((client) => {
    if (client.readyState === client.OPEN) client.send(payload);
  });
}

function addAlert(level, title, message) {
  const alert = {
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    timestamp: new Date().toISOString(),
    level,
    title,
    message,
  };
  alerts.unshift(alert);
  alerts = alerts.slice(0, 50);
  broadcast({ type: "alert", data: alert });
  return alert;
}

// simple threshold-based alerts - tune these to your actual system
function evaluateThresholds(reading) {
  if (reading.temperature > 45) {
    addAlert("warning", "High Temperature", `Temperature reached ${reading.temperature.toFixed(1)}°C`);
  }
  if (reading.batteryPercent < 20) {
    addAlert("warning", "Low Battery", `Battery at ${reading.batteryPercent.toFixed(0)}%`);
  }
  if (reading.voltage < 10) {
    addAlert("error", "Low Solar Voltage", `Voltage dropped to ${reading.voltage.toFixed(2)}V`);
  }
}

// ---- Routes ----

// ESP32 posts a new sensor reading here
app.post("/api/readings", (req, res) => {
  const { voltage, current, temperature, batteryPercent } = req.body || {};

  if (
    typeof voltage !== "number" ||
    typeof current !== "number" ||
    typeof temperature !== "number" ||
    typeof batteryPercent !== "number"
  ) {
    return res.status(400).json({
      error: "Body must include numeric voltage, current, temperature, batteryPercent",
    });
  }

  const reading = {
    timestamp: new Date().toISOString(),
    voltage,
    current,
    temperature,
    batteryPercent,
    power: Number((voltage * current).toFixed(2)),
  };

  history.push(reading);
  if (history.length > MAX_HISTORY) history.shift();

  if (offlineAlertSent) {
    addAlert("info", "Device Reconnected", "ESP32 is sending data again");
    offlineAlertSent = false;
  }
  lastSeen = Date.now();

  evaluateThresholds(reading);
  broadcast({ type: "reading", data: reading });

  res.json({ ok: true });
});

app.get("/api/readings/latest", (req, res) => {
  res.json(history[history.length - 1] || null);
});

app.get("/api/readings/history", (req, res) => {
  const limit = Number(req.query.limit) || MAX_HISTORY;
  res.json(history.slice(-limit));
});

// Derived device/sensor status - based on whether the ESP32 has reported recently.
// If you add more physical sensors later, give each its own heartbeat field here.
app.get("/api/devices", (req, res) => {
  const online = lastSeen !== null && Date.now() - lastSeen < STALE_MS;
  const status = online ? "Online" : "Offline";
  res.json([
    { name: "ESP32 Controller", status },
    { name: "Solar Voltage Sensor", status },
    { name: "Current Sensor", status },
    { name: "Temperature Sensor", status },
    { name: "Battery Monitor", status },
  ]);
});

app.get("/api/alerts", (req, res) => {
  res.json(alerts);
});

app.get("/api/health", (req, res) => {
  res.json({ ok: true, uptimeSeconds: process.uptime() });
});

// ---- Offline detection ----
setInterval(() => {
  if (lastSeen && !offlineAlertSent && Date.now() - lastSeen > STALE_MS) {
    offlineAlertSent = true;
    addAlert("error", "Device Disconnected", "No data received from the ESP32 for 15+ seconds");
  }
}, 5000);

server.listen(PORT, () => {
  console.log(`SolarIoT backend listening on http://localhost:${PORT}`);
  console.log(`WebSocket available on the same port`);
});
