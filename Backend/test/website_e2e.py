"""Browser test for the website's Google sign-in, app sign-in approval and Blocked players list.
Firebase and the backend are stubbed, so it needs no keys: `pip install playwright && playwright install chromium`, then `python Backend/test/website_e2e.py`."""
import json, subprocess, sys, time, os
from playwright.sync_api import sync_playwright

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "Website")
PORT = 8765
CODE = "ab" * 16

APP = "export const initializeApp = () => ({});"
AUTH = """
const L = []; let cur = null;
export const getAuth = () => ({ get currentUser() { return cur; } });
export class GoogleAuthProvider { setCustomParameters() {} }
export class EmailAuthProvider { static credential() { return {}; } }
export const browserLocalPersistence = {}, browserSessionPersistence = {};
export const setPersistence = async () => {};
export const onAuthStateChanged = (a, cb) => { L.push(cb); setTimeout(() => cb(cur), 0); return () => {}; };
const mk = (uid, email, name) => ({ uid, email, displayName: name, emailVerified: true, providerData: [{ providerId: "google.com" }], metadata: {}, getIdToken: async () => "tok-" + uid, reload: async () => {}, delete: async () => {} });
export const signInWithPopup = async () => { cur = mk("g1", "new.user@example.com", "New User"); L.forEach(f => f(cur)); return { user: cur }; };
export const signInWithRedirect = async () => {};
export const signOut = async () => { cur = null; L.forEach(f => f(null)); };
for (const n of []) {}
export const signInWithEmailAndPassword = async () => {}, signInWithCustomToken = async () => {}, createUserWithEmailAndPassword = async () => {}, sendEmailVerification = async () => {}, sendPasswordResetEmail = async () => {}, updatePassword = async () => {}, reauthenticateWithCredential = async () => {};
"""
FS = """
const S = (window.__store ||= new Map());
const snap = (path, d) => ({ id: path.split("/").pop(), exists: () => d !== undefined, data: () => d });
const empty = { docs: [], empty: true, size: 0, forEach() {}, docChanges: () => [], exists: () => false, data: () => undefined };
export const getFirestore = () => ({});
export const doc = (db, ...p) => ({ path: p.join("/") });
export const collection = (db, ...p) => ({ path: p.join("/"), col: true });
export const getDoc = async r => snap(r.path, S.get(r.path));
export const getDocs = async c => { const pre = c.path + "/"; const docs = [...S.keys()].filter(k => k.startsWith(pre) && !k.slice(pre.length).includes("/")).map(k => snap(k, S.get(k))); return { docs, empty: !docs.length, size: docs.length, forEach: f => docs.forEach(f) }; };
export const setDoc = async (r, d) => { S.set(r.path, d); };
export const updateDoc = async (r, d) => { S.set(r.path, { ...(S.get(r.path) || {}), ...d }); };
export const deleteDoc = async r => { S.delete(r.path); };
export const addDoc = async (c, d) => { const id = "a" + Math.random().toString(36).slice(2); S.set(c.path + "/" + id, d); return { id }; };
export const runTransaction = async (db, fn) => fn({ get: async r => snap(r.path, S.get(r.path)), set: (r, d) => S.set(r.path, d), update: (r, d) => S.set(r.path, { ...(S.get(r.path) || {}), ...d }), delete: r => S.delete(r.path) });
export const serverTimestamp = () => Date.now();
export const onSnapshot = (r, cb) => { setTimeout(() => cb(r.col ? empty : snap(r.path, S.get(r.path))), 0); return () => {}; };
export const query = c => c, where = () => ({}), orderBy = () => ({}), limit = () => ({});
export const getCountFromServer = async () => ({ data: () => ({ count: 0 }) });
export const arrayUnion = (...a) => a, arrayRemove = (...a) => a;
"""
CORS = {"access-control-allow-origin": "*", "access-control-allow-headers": "*", "access-control-allow-methods": "POST, OPTIONS"}
fails = []
def check(c, name):
    print(("  ok - " if c else "  FAIL - ") + name)
    if not c: fails.append(name)

srv = subprocess.Popen([sys.executable, "-m", "http.server", str(PORT), "-d", ROOT], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(1)
try:
    with sync_playwright() as p:
        b = p.chromium.launch(); ctx = b.new_context(); page = ctx.new_page()
        errors, approve, desc = [], {}, {}
        page.on("pageerror", lambda e: errors.append(str(e)))
        js = lambda body: dict(status=200, content_type="text/javascript", body=body, headers={"access-control-allow-origin": "*"})
        ctx.route("**/*", lambda r: r.abort() if not r.request.url.startswith(f"http://localhost:{PORT}") and "gstatic.com/firebasejs" not in r.request.url and "onrender.com" not in r.request.url else r.fallback())
        ctx.route("**/firebasejs/10.12.2/firebase-app.js", lambda r: r.fulfill(**js(APP)))
        ctx.route("**/firebasejs/10.12.2/firebase-auth.js", lambda r: r.fulfill(**js(AUTH)))
        ctx.route("**/firebasejs/10.12.2/firebase-firestore.js", lambda r: r.fulfill(**js(FS)))
        def backend(route):
            req = route.request
            if req.method == "OPTIONS": return route.fulfill(status=204, headers=CORS)
            if req.url.endswith("/auth/device/info"): return route.fulfill(status=200, headers=CORS, content_type="application/json", body=json.dumps({"userCode": "K7Q-2MX"}))
            if req.url.endswith("/auth/device/approve"):
                approve.update(auth=req.headers.get("authorization"), body=req.post_data); return route.fulfill(status=200, headers=CORS, content_type="application/json", body='{"ok":true}')
            if req.url.endswith("/profile"):
                desc.update(auth=req.headers.get("authorization"), body=req.post_data); return route.fulfill(status=200, headers=CORS, content_type="application/json", body='{"profile":{"description":"Hi there"}}')
            route.fulfill(status=200, headers=CORS, content_type="application/json", body="{}")
        ctx.route("**onrender.com/**", backend)

        page.goto(f"http://localhost:{PORT}/?link={CODE}"); page.wait_for_selector("#auth:not([hidden])")
        check(page.is_visible("#googleBtn"), "Continue with Google button is on the log-in screen")
        check(page.is_visible("#linkNote"), "app sign-in notice shows when opened from the app")
        page.click("#tabSignup"); check(page.is_visible("#googleBtn"), "Google button is on the sign-up screen too")
        page.click("#tabLogin")
        page.click("#googleBtn"); page.wait_for_selector("#formPick:not([hidden])")
        check(page.input_value("#pkUser") == "NewUser", "new Google account is asked for a username (prefilled from the Google name)")
        check(not page.is_visible("#authTabs") and not page.is_visible("#googleBtn"), "tabs and Google button hide on the username step")
        page.fill("#pkUser", "x!"); page.click("#pkBtn"); check(page.text_content("#pkErr").strip() != "", "invalid username is rejected")
        page.fill("#pkUser", "NewUser"); page.click("#pkBtn"); page.wait_for_selector("#app:not([hidden])")
        st = page.evaluate("[...window.__store.keys()]")
        check("users/g1" in st and "usernames/newuser" in st, "profile + username reserved for the Google account")
        page.wait_for_selector("#linkModal:not([hidden])"); check(page.text_content("#linkCode").strip() == "K7Q-2MX", "approval dialog shows the app's confirm code")
        page.click("#linkOk"); page.wait_for_selector("#linkModal", state="hidden")
        check(approve.get("auth") == "Bearer tok-g1" and CODE in (approve.get("body") or ""), "approving sends the signed-in user's token and the link code")

        page.evaluate("window.__store.set('blocks/g1/list/u2',{at:1}); window.__store.set('users/u2',{username:'Bob',avatarColor:'#7cc4ff'})")
        page.evaluate("location.hash='#/settings/privacy'"); page.wait_for_selector("#blockList .row")
        check("Bob" in page.text_content("#blockList"), "blocked player appears in Settings > Privacy")
        page.click("[data-unblock='u2']"); page.wait_for_selector("#blockList .empty")
        check("blocks/g1/list/u2" not in page.evaluate("[...window.__store.keys()]"), "Unblock removes the block")
        page.evaluate("location.hash='#/settings/account'"); page.wait_for_selector("#setUser")
        check(not page.is_visible("#pwOpen"), "Google-only accounts don't show Change password")
        page.fill("#descInput", "Hi there"); page.click("#descSave"); page.wait_for_function("document.querySelector('#descSave').disabled === false")
        check(desc.get("auth") == "Bearer tok-g1" and "Hi there" in (desc.get("body") or ""), "description is saved through the server with the user's token")
        # ---- 35 s email verification + update prompt ----
        def fresh(verified, remaining):
            c2 = b.new_context(viewport={"width": 1280, "height": 800}); pg = c2.new_page(); errs = []; pg.on("pageerror", lambda e: errs.append(str(e)))
            c2.route("**/*", lambda r: r.abort() if not r.request.url.startswith(f"http://localhost:{PORT}") and "gstatic.com/firebasejs" not in r.request.url and "onrender.com" not in r.request.url else r.fallback())
            c2.route("**/firebasejs/10.12.2/firebase-app.js", lambda r: r.fulfill(**js(APP)))
            c2.route("**/firebasejs/10.12.2/firebase-auth.js", lambda r: r.fulfill(**js(AUTH.replace("emailVerified: true", "emailVerified: " + ("true" if verified else "false")))))
            c2.route("**/firebasejs/10.12.2/firebase-firestore.js", lambda r: r.fulfill(**js(FS)))
            def be(r):
                if r.request.method == "OPTIONS": return r.fulfill(status=204, headers=CORS)
                u = r.request.url
                if u.endswith("/verify/start"): return r.fulfill(status=200, headers=CORS, content_type="application/json", body=json.dumps({"remainingMs": remaining}))
                if u.endswith("/verify/check"): return r.fulfill(status=200, headers=CORS, content_type="application/json", body=json.dumps({"status": "verified" if verified else "pending"}))
                r.fulfill(status=200, headers=CORS, content_type="application/json", body="{}")
            c2.route("**onrender.com/**", be)
            ver = {"v": "a"}
            c2.route("**/version.json*", lambda r: r.fulfill(status=200, content_type="application/json", body=json.dumps({"version": ver["v"]})))
            return c2, pg, ver, errs
        def google_in(pg):
            pg.goto(f"http://localhost:{PORT}/"); pg.wait_for_selector("#auth:not([hidden])"); pg.click("#googleBtn"); pg.wait_for_selector("#formPick:not([hidden])"); pg.click("#pkBtn")
        c2, pg, ver, errs = fresh(False, 2000); google_in(pg)
        pg.wait_for_selector("#verifyOverlay:not([hidden])")
        check(pg.text_content("#vfMail").strip() == "new.user@example.com" and pg.is_hidden("#vfResend"), "unverified sign-up shows the 35 s verify pop-up with a countdown")
        pg.wait_for_selector("#vfResend:not([hidden])", timeout=8000)
        check("0" == pg.text_content("#vfNum").strip() and pg.is_hidden("#app"), "when the time runs out the link expires and the app stays locked")
        pg.click("#vfBack"); pg.wait_for_selector("#verifyOverlay", state="hidden"); check(pg.is_visible("#auth"), "Back to log in returns to the sign-in page"); c2.close()
        c2, pg, ver, errs = fresh(True, 2000); google_in(pg); pg.wait_for_selector("#app:not([hidden])")
        check(pg.is_hidden("#verifyOverlay"), "verified accounts go straight in")
        ver["v"] = "b"; pg.evaluate("document.dispatchEvent(new Event('visibilitychange'))"); pg.wait_for_selector("#updateOverlay:not([hidden])")
        check("update to share with you" in pg.text_content("#updTitle"), "a new GitHub deploy shows the update prompt")
        pg.click("#updLater"); pg.wait_for_selector("#updateOverlay", state="hidden")
        sn = json.loads(pg.evaluate("localStorage.getItem('bt_update_snooze')")); check(sn["version"] == "b" and 3500000 < sn["until"] - time.time() * 1000 < 3700000, "Later snoozes for one hour")
        pg.evaluate("localStorage.setItem('bt_update_snooze', JSON.stringify({version:'b', until: Date.now()-1}))")
        with pg.expect_navigation(timeout=8000): pg.evaluate("document.dispatchEvent(new Event('visibilitychange'))")
        check(True, "after the hour the site updates by itself"); check(not errs, "no page errors in verify/update flows: " + "; ".join(errs[:3])); c2.close()
        check(page.locator("[data-sec=language]").count() == 0 and page.locator("[data-panel=account] #langRow").count() == 1 and page.locator("[data-panel=account] [data-theme-pick]").count() == 2, "Language and Background (black/white) both live in Settings > Account; no Language tab")
        check(not errors, "no page errors: " + "; ".join(errors[:3]))
        b.close()
finally:
    srv.kill()
print("\nFAILED: " + ", ".join(fails) if fails else "\nWEBSITE E2E PASSED"); sys.exit(1 if fails else 0)
