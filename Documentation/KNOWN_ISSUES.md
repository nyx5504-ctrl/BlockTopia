# Status and known limits (be honest with yourself before launch)
**v1.1 changes:** Roblox R6 rig as the character (colored noob look + procedural run/jump/fall/idle animation), Roblox-style chat bubbles, top-left menu + chat buttons with a chat window, in-game player list (replaces the website leaderboard) with a click-a-name tab: Add Friend / Block / Report, bright sunny map rework, branded email pages (`pages/action.html`, `pages/verify.html`, see `EMAILS.md`). Camera: hold **right mouse** to look (like Roblox), mouse wheel zooms.
**Visually checked:** the desktop client was rendered headless under software GL and reviewed from screenshots (character, poses, bubbles, HUD, map). The website pages and emails were NOT rendered/tested in a browser.

**Tested (automated, here):** server auth/launch codes, single-use codes, two-player rooms, movement validation + corrections, respawn, chat filter/rate-limit/mute/report, room overflow, reconnect, leave, and the real Godot 4.7.2 client (headless) joining, moving, chatting and leaving. Website JS passes syntax checks.

**NOT tested:** the website against live Firebase (needs your keys); Firestore rules in the emulator; real Firebase ID-token verification; any export/build (no export templates here); rendering, input, touch and gamepad on real devices; macOS/iOS/Android deep links; iOS in any form.

**Limits**
- Movement is client-reported but server-validated (speed, bounds, vertical speed, teleport correction). It is not a full server physics simulation, so subtle cheats (e.g. flying slowly) are not fully prevented.
- Score = 1 per 10 s connected. **Wins** stay 0: Baseplate has no win condition yet.
- Profile "friends only" visibility, request permissions and join permissions are enforced in the UI/server logic; Firestore rules still let signed-in users read other user docs.
- Chat filter is a starter word list plus pattern checks. Extend `Backend/chat/filter.js` and expect to tune it. It cannot catch everything.
- Email verification is sent but not required to play. Password reset is Firebase's emailed link.
- Single Node process holds all rooms; to scale horizontally you need sticky routing or a shared room registry.
- Android/iOS/macOS launch-by-link need the extra steps in BUILDING.md. The in-client "Join from link" box works everywhere.
- No audio assets are included; the volume setting controls the master bus only.
- Player-list scores are per-server live (1 per 10 s) on top of your saved total. There is no global leaderboard page any more.
- Block is persisted by the server (Firestore `blocks/`) and hides that player's chat; there is no website screen to review/unblock yet (unblock from the in-game list).
- Google sign-in is not implemented. Reports are stored in Firestore `reports` (no moderation dashboard).
