# SolarIoT Backend (optional - legacy path)

**As of the Firebase migration, this backend is no longer required.** The
ESP32 now writes straight to Firebase Realtime Database, and the frontend
reads from Firebase too - see `docs/firebase-setup.md` and
`esp32-firmware/firebase_solar_monitor/`.

This Express server is kept in case you'd rather self-host instead of using
Firebase (e.g. `esp32-firmware/solar_monitor/solar_monitor.ino` still posts
here). If you're on the Firebase path, you can ignore this whole folder.

---

Receives readings from your ESP32 over WiFi, keeps a rolling history in memory,
generates simple threshold alerts, and streams live updates to the React
dashboard over WebSocket.

## Setup

```bash
cd backend
npm install
npm start
```

Server runs on `http://localhost:4000` by default (set `PORT` env var to change it).

Find your computer's LAN IP (needed for the ESP32 to reach it):

```bash
# macOS/Linux
ipconfig getifaddr en0   # or: hostname -I
# Windows
ipconfig
```

Use that IP (e.g. `http://192.168.1.100:4000`) as `SERVER_URL` in the ESP32
sketch and as `VITE_API_BASE_URL` in the frontend `.env`.

## API

| Method | Path                     | Description                                  |
|--------|--------------------------|-----------------------------------------------|
| POST   | `/api/readings`          | ESP32 posts `{ voltage, current, temperature, batteryPercent }` |
| GET    | `/api/readings/latest`   | Most recent reading                          |
| GET    | `/api/readings/history?limit=100` | Recent readings for charts          |
| GET    | `/api/devices`           | Derived online/offline status                |
| GET    | `/api/alerts`            | Recent threshold-based alerts                |
| GET    | `/api/health`            | Health check                                 |
| WS     | `/` (same port)          | Pushes `{type:"reading",data}` and `{type:"alert",data}` in real time |

## Notes

- Data is stored **in memory only** — it resets when the server restarts.
  If you want history to survive restarts, swap the `history`/`alerts` arrays
  for a SQLite file (say the word and I'll wire that up).
- Alert thresholds (`temperature > 45`, `batteryPercent < 20`, `voltage < 10`)
  are placeholders — tune them in `server.js` to match your actual system.
- CORS is wide open for local development. Lock down `cors()` before deploying
  this anywhere public.
