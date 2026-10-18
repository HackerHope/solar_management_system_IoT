# Deploying the Dashboard (Firebase Hosting)

This gives your React dashboard a real public URL (e.g.
`https://solariot-dashboard.web.app`), reachable from anywhere - no port
forwarding, no VPS, no always-on computer required. It's what makes "outside
your home network" work now that the ESP32 talks to Firebase directly.

## Prerequisites
- You've completed `docs/firebase-setup.md`
- Your frontend `.env` is filled in and the app runs locally with `npm run dev`
- `firebase-tools` installed: `npm install -g firebase-tools`

## 1. Log in and connect this project

From the project root (where `firebase.json` and `.firebaserc` live):

```bash
firebase login
```

Edit `.firebaserc` and replace `YOUR_FIREBASE_PROJECT_ID` with your actual
project ID (find it in Firebase console > Project settings > General).

## 2. Build the frontend

```bash
cd frontend
npm install
npm run build
```

This produces `frontend/dist/` - `firebase.json` is already configured to
serve that folder.

## 3. Deploy

From the project root:

```bash
firebase deploy --only hosting,database
```

This pushes both your built frontend and your `database.rules.json` security
rules. Firebase will print your live URL when it's done.

## 4. Verify

- Visit the printed URL, you should see the login screen
- Sign in with your dashboard account (not the ESP32's device account)
- Confirm live data shows up - if your ESP32 is running and reachable, you'll
  see readings update in real time from anywhere, not just your home WiFi

## Re-deploying after changes

Any time you change frontend code:
```bash
cd frontend && npm run build && cd .. && firebase deploy --only hosting
```

Any time you change `database.rules.json`:
```bash
firebase deploy --only database
```

## Custom domain (optional)

Firebase Hosting supports connecting your own domain for free: Hosting
section of the console > Add custom domain, then follow the DNS verification
steps. Not required, just a nice-to-have if you want `solar.yourdomain.com`
instead of the `.web.app` URL.
