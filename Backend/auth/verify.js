import admin from "firebase-admin";
export async function verifyToken(token) {
  if (typeof token !== "string" || token.length > 4000) throw new Error("bad token");
  if (process.env.DEV_AUTH === "1") {
    if (process.env.NODE_ENV === "production") throw new Error("DEV_AUTH is not allowed in production");
    if (token.startsWith("dev:")) { const [, uid, name] = token.split(":"); return { uid, name: name || uid, email_verified: true }; }
  }
  if (!admin.apps.length) throw new Error("auth not configured");
  return admin.auth().verifyIdToken(token);
}
