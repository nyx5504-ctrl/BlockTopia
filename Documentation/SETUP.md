# Setup

## 1. Firebase (accounts, database)
Project `blocktopia-f3341`:
1. Authentication > Sign-in method: enable **Email/Password**. Add your `<user>.github.io` under Settings > Authorized domains.
2. Firestore Database: create it, paste `Backend/firestore.rules` into Rules, **Publish**.
3. Project settings > Your apps > Web app: copy the config values into `Website/js/firebase-config.js`.
4. Project settings > Service accounts > **Generate new private key** (JSON). This goes ONLY on the game server as `FIREBASE_SERVICE_ACCOUNT`. Never commit it, never put it in the website.

## 2. Backend / multiplayer server (hosted separately)
Any host that runs Node 18+ and supports WebSockets with HTTPS (Render, Railway, Fly.io, a VPS). `Dockerfile` is included.
```
cd Backend && npm install
cp .env.example .env     # fill in ALLOWED_ORIGINS, PUBLIC_WS_URL (wss://...), FIREBASE_SERVICE_ACCOUNT
npm start
```
Set the same variables in your host's dashboard. `GET /health` shows rooms and players. Then put the server's HTTPS URL in `Website/js/config.js` (`BACKEND_URL`).
Tests: `npm test` (server, filter, movement, chat, reconnect) and `GODOT=/path/to/godot node test/godot_e2e.mjs` (real Godot client vs real server).

## 3. Website on GitHub Pages
Push this repo to GitHub, Settings > Pages > Source: **GitHub Actions**. `.github/workflows/pages.yml` publishes `/Website`.
Set `WEBSITE_URL` in `GodotClient/Scripts/settings.gd` to your Pages URL.

## 4. Client builds
See `BUILDING.md`. After the workflow runs, upload the zips/APK to a GitHub Release and paste their URLs into `DOWNLOADS` in `Website/js/config.js`.

## How PLAY works
Website -> `POST /launch` with the user's Firebase ID token -> server returns a **single-use code valid 60 s** -> website opens `blocktopia://play?game=baseplate&code=...&ws=wss://...` -> client opens the WebSocket and sends the code -> server swaps it for a session. No password or long-lived token is ever in a URL. Leaving sends `leave`, closes the socket, and quits the client if it was started by a link.
