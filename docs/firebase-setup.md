# Firebase Project Setup

Do this once, in the Firebase console (console.firebase.google.com). Everything
downstream (frontend, ESP32) needs the values you collect here.

## 1. Create the project
1. Go to https://console.firebase.google.com → **Add project**
2. Name it (e.g. `solariot-dashboard`) → disable Google Analytics (not needed) → Create

## 2. Enable Realtime Database
1. Left sidebar → **Build > Realtime Database** → Create Database
2. Pick a region close to you
3. Start in **locked mode** (we'll deploy our own rules from `database.rules.json`)
4. Copy the database URL shown at the top, e.g. `https://solariot-dashboard-default-rtdb.europe-west1.firebasedatabase.app` — you'll need this.

## 3. Enable Authentication
1. Left sidebar → **Build > Authentication** → Get started
2. Sign-in method tab → enable **Email/Password**
3. Users tab → **Add user**, create TWO accounts:
   - Your own login, e.g. `you@example.com` / a real password (this is what you'll use to log into the dashboard)
   - A device account for the ESP32, e.g. `esp32-device@solariot.local` / a long random password (the ESP32 uses this to authenticate its writes — it's not a real inbox, just an identity)

## 4. Register a Web App (for the React frontend)
1. Project Overview (gear icon) → **Project settings** → scroll to "Your apps" → click the `</>` (Web) icon
2. Nickname it anything, skip Firebase Hosting setup here (we'll do that separately later)
3. Copy the `firebaseConfig` object shown — you'll paste these values into the frontend `.env`

It looks like:
```js
const firebaseConfig = {
  apiKey: "AIza...",
  authDomain: "solariot-dashboard.firebaseapp.com",
  databaseURL: "https://solariot-dashboard-default-rtdb.europe-west1.firebasedatabase.app",
  projectId: "solariot-dashboard",
  storageBucket: "solariot-dashboard.appspot.com",
  messagingSenderId: "...",
  appId: "1:...:web:...",
};
```

## 5. Deploy the database security rules
From the `frontend` (or project root, wherever you keep `database.rules.json`):
```bash
npm install -g firebase-tools
firebase login
firebase init database   # point it at the existing project, use database.rules.json
firebase deploy --only database
```
See `database.rules.json` in this project for the rules being deployed — short version:
**any signed-in identity (your login or the ESP32's) can read/write**. That's
intentionally simple for a single-user personal project. See its comments for
how to tighten this later.

## What you now have
- A database URL
- A web app config (for React)
- Two Auth accounts: your login + the ESP32's device account
- Deployed security rules

Keep these handy — the frontend `.env` and the ESP32 sketch both need pieces of this.
