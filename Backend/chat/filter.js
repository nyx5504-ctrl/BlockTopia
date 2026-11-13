// Server-side chat moderation. Starter lists: extend BAD_WORDS for your audience.
const BAD_WORDS = new Set(["fuck","fucker","fucking","shit","shitty","bitch","asshole","bastard","cunt","dick","dickhead","pussy","slut","whore","retard","retarded","nigger","nigga","faggot","fag","rape","rapist","kys","porn","sex","sexy","nude","nudes","cock","penis","vagina","wtf","stfu"]);
const LONG_STEMS = ["fuck","shit","bitch","cunt","nigg","fagg","whore","retard","porn"]; // also caught when spaced out: "f u c k"
const LEET = { "0":"o","1":"i","3":"e","4":"a","5":"s","7":"t","8":"b","@":"a","$":"s","!":"i","+":"t","(":"c","|":"i" };
const PII = [
  [/[a-z0-9._%+-]+\s?(@|\(at\)|\[at\])\s?[a-z0-9.-]+\s?(\.|\(dot\))\s?[a-z]{2,}/i, "email"],
  [/(https?:\/\/|www\.)\S+|\b[a-z0-9-]{2,}\s?(\.|\(dot\)|\bdot\b)\s?(com|net|org|io|gg|me|co|xyz|ly|tv|app|ru|info)\b/i, "link"],
  [/(\d[\s().\-_]*){7,}/, "number"],
  [/\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/, "ip"],
  [/\b(my|add me|dm me|msg me|text me|follow me|hmu)\b.{0,30}\b(snap(chat)?|insta(gram)?|discord|whats\s?app|telegram|kik|tiktok|number|phone|address|email|password|real name)\b/i, "contact"],
  [/\bi (live|go to school) (at|in|on)\b|\bmy (school|address|street)\b|\bhow old are you\b|\bwhat('s| is) your (address|number|age)\b/i, "personal"]
];
export function checkMessage(raw) {
  if (typeof raw !== "string") return { ok: false, reason: "invalid" };
  const text = raw.normalize("NFKC").replace(/[\u0000-\u001f\u007f\u200b-\u200f\u2028-\u202f\u2060\ufeff]/g, "").replace(/\s+/g, " ").trim();
  if (!text) return { ok: false, reason: "empty" };
  if (text.length > 150) return { ok: false, reason: "long" };
  if (/(.)\1{9,}/.test(text) || (text.length > 8 && text.replace(/[^A-Z]/g, "").length / text.replace(/[^A-Za-z]/g, "").length > 0.8 && text.replace(/[^A-Za-z]/g, "").length > 12)) return { ok: false, reason: "spam" };
  for (const [re] of PII) if (re.test(text)) return { ok: false, reason: "personal" };
  const leet = text.toLowerCase().replace(/[01345788@$!+(|]/g, c => LEET[c] || c);
  const words = leet.split(/[^a-z]+/).filter(Boolean);
  for (const w of words) { if (BAD_WORDS.has(w) || BAD_WORDS.has(w.replace(/(.)\1+/g, "$1")) || BAD_WORDS.has(w.replace(/(.)\1+/g, "$1$1"))) return { ok: false, reason: "language" }; }
  // Catch spaced-out evasion ("f u c k") by joining runs of 3+ single/double-letter tokens, not whole sentences (avoids "Scunthorpe" false positives).
  const runs = []; let cur = [];
  for (const w of leet.split(/[^a-z]+/)) { if (w && w.length <= 2) cur.push(w); else { if (cur.length >= 3) runs.push(cur.join("")); cur = []; } }
  if (cur.length >= 3) runs.push(cur.join(""));
  for (const run of runs) { const q = run.replace(/(.)\1+/g, "$1"); if (LONG_STEMS.some(st => q.includes(st))) return { ok: false, reason: "language" }; }
  return { ok: true, text };
}
export const FRIENDLY = {
  language: "Let's keep BlockTopia friendly! Your message wasn't sent.",
  personal: "For your safety, don't share personal info or links. Your message wasn't sent.",
  spam: "That looks like spam. Your message wasn't sent.",
  long: "Message too long (150 characters max).", empty: "", invalid: "",
  rate: "You're chatting too fast. Slow down a little.", cooldown: "Chat is paused for a minute. Please keep it friendly."
};
