# Status and known limits (be honest with yourself before launch)
**v1.1 changes:** Roblox R6 rig as the character (colored noob look + procedural run/jump/fall/idle animation), Roblox-style chat bubbles, top-left menu + chat buttons with a chat window, in-game player list (replaces the website leaderboard) with a click-a-name tab: Add Friend / Block / Report, bright sunny map rework, branded email pages (`pages/action.html`, `pages/verify.html`, see `EMAILS.md`). Camera: hold **right mouse** to look (like Roblox), mouse wheel zooms.
**v1.2 changes:** (1) The native app's Settings now matches the website's: Account (email, verification, change password, log out), Security (devices, sign a device out), Privacy (friend requests, who can join you) and Language. The app lists itself under Security (Firestore `users/<uid>/devices`, the same rules as the website) and signs itself out if you sign that device out from the website. (2) Website Settings > Customization shows the real R6 rig (`Website/assets/roblox-r6.glb`, three.js bundled in `Website/js/rig.bundle.js`; rebuild from `tools/rig-preview`, `npm install && npm run build`); the old flat drawing is kept only as a fallback if WebGL is unavailable. (3) The in-game menu no longer has a Customization tab; customize on the website or in the app.
**Not tested in a real browser/device:** the 3D website preview (logic was checked in Node and the app screens were rendered in Godot with mocked Firebase). Check it once on the live site, and the app against live Firebase.

**Visually checked:** the desktop client was rendered headless under software GL and reviewed from screenshots (character, poses, bubbles, HUD, map). The website pages and emails were NOT rendered/tested in a browser.

**Tested (automated, here):** server auth/launch codes, single-use codes, two-player rooms, movement validation + corrections, respawn, chat filter/rate-limit/mute/report, room overflow, reconnect, leave, and the real Godot 4.7.2 client (headless) joining, moving, chatting and leaving. Website JS passes syntax checks.

**NOT tested:** the native app login/dashboard/feedback flow against live Firebase and the deployed backend; the website against live Firebase (needs your keys); Firestore rules in the emulator; real Firebase ID-token verification; any export/build (no export templates here); rendering, input, touch and gamepad on real devices; macOS/iOS/Android deep links; iOS in any form.

**Limits**
- Movement is client-reported but server-validated (speed, bounds, vertical speed, teleport correction). It is not a full server physics simulation, so subtle cheats (e.g. flying slowly) are not fully prevented.
- Timed score awards and score columns have been removed; Baseplate has no win condition or score-based leaderboard.
- Profile "friends only" visibility, request permissions and join permissions are enforced in the UI/server logic; Firestore rules still let signed-in users read other user docs.
- Chat filter is a starter word list plus pattern checks. Extend `Backend/chat/filter.js` and expect to tune it. It cannot catch everything.
- Email verification is sent but not required to play. Password reset is Firebase's emailed link.
- Single Node process holds all rooms; to scale horizontally you need sticky routing or a shared room registry.
- Android/iOS/macOS launch-by-link need the extra steps in BUILDING.md. Opening the app manually shows sign-in and the game dashboard; the website can still launch a game directly with a single-use code.
- No audio assets are included; the volume setting controls the master bus only.
- In-game player lists show names and player actions without timed scores. There is no global leaderboard page any more.
- Block is persisted by the server (Firestore `blocks/`) and hides that player's chat; there is no website screen to review/unblock yet (unblock from the in-game list).
- Google sign-in is not implemented. Reports are stored in Firestore `reports` (no moderation dashboard).
