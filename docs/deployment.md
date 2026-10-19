# Deploying the Dashboard (Firebase Hosting)

This gives your Flutter web app a real public URL (e.g.
`https://solar-iot-101.web.app`), reachable from anywhere - no port
forwarding, no VPS, no always-on computer required. It's what makes "outside
your home network" work now that the ESP32 talks to Firebase directly.

## Prerequisites
- You've completed `docs/firebase-setup.md`
- Flutter is installed and the app runs locally
- `firebase-tools` installed: `npm install -g firebase-tools`

## 1. Log in and connect this project

From the project root (where `firebase.json` and `.firebaserc` live):

```bash
firebase login
```

This repository is already configured to use the `solar-iot-101` Firebase
project. If you use a different project, select it in Firebase CLI or pass its
project ID to the deploy command.

## 2. Build the Flutter web app

```bash
flutter build web --release
```

This produces `build/web/`, which Firebase Hosting is configured to serve.

## 3. Deploy

From the project root:

```bash
firebase deploy --only hosting --project solar-iot-101
```

Firebase will print your live URL when it's done. Database rules are deployed
separately with `firebase deploy --only database --project solar-iot-101`.

## 4. Verify

- Visit the printed URL, you should see the login screen
- Sign in with your dashboard account (not the ESP32's device account)
- Confirm live data shows up - if your ESP32 is running and reachable, you'll
  see readings update in real time from anywhere, not just your home WiFi

## Re-deploying after changes

Any time you change the Flutter app:
```bash
flutter build web --release
firebase deploy --only hosting --project solar-iot-101
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
