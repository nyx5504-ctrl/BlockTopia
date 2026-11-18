// Server-side chat moderation. This is a STARTER filter: tune the lists below for your audience.
// You can add words without editing code: set CHAT_EXTRA_BAD_WORDS="word1,word2" on the server (Render > Environment).

// CHAT_FILTER_MODE=mask (default): bad words are replaced with #### and the rest of the message is sent (Roblox style).
// CHAT_FILTER_MODE=block: the whole message is rejected instead.
import { CONFUSABLES } from "./confusables.js";
import { CONFUSABLES_EXTRA } from "./confusables_extra.js";

export const FILTER_MODE = (process.env.CHAT_FILTER_MODE || "mask").toLowerCase() === "block" ? "block" : "mask";

// ---- word lists (lowercase Latin letters; matched as whole words, also with leetspeak, repeated letters, accents, f*ck, f.u.c.k) ----
const BAD_WORDS = new Set([
  "fuck", "fucker", "fuckers", "fucked", "fucking", "fuk", "fck", "fuc", "motherfucker", "wtf", "stfu", "gtfo",
  "shit", "shitty", "shite", "bullshit", "bitch", "bitches", "biatch", "asshole", "arsehole", "bastard", 
  "cunt", "dick", "dickhead", "cock", "cocks", "pussy", "penis", "vagina", "tits", "boobs", "slut", "whore", "skank", "milf",
  "sex", "sexy", "sexting", "nude", "nudes", "porn", "porno", "horny", "cum", "cumshot", "blowjob", "handjob", "dildo", "masturbate", "orgasm", "anal", "hentai", "rape", "raped", "rapist", "molest", "pedo", "pedophile",
  "nigger", "nigga", "niga", "faggot", "fag", "dyke", "tranny", "retard", "retarded", "spastic", "chink", "gook", "spic", "kike",
  "kys", "ass", "asses", "arse", "dumbass", "jackass", "asswipe", "douche", "douchebag", "prick", "twat", "wanker", "bollocks", "bugger",
  "phuck", "fvck", "fook", "sheit", "beetch", "bytch", "azzhole", "cunts", "dickhead", "dickheads", "cocksucker", "jerkoff", "jizz", "clit", "boner", "titties", "tittys",
  "fuckin", "fukin", "fuking", "fucken", "shitt", "shyt", "shiit", "biches", "bytches", "pussi", "pusy", "wank", "thot", "thots", "negga", "nigguh", "nibba", "n1gga", "paki", "wetback", "beaner", "mongoloid", "faggit", "fags", "lesbo", "shemale", "incest", "bukkake", "gangbang", "threesome", "orgy", "nutsack", "ballsack", "asswipe", "dumbfuck", "dipshit", "horseshit", "bullshitter", "shithead", "shitface", "fuckface", "fuckhead", "fuckboy", "fuckwit", "cockhead", "dickwad",
  // other languages, written in Latin letters (distinctive words only)
  "puta", "putas", "puto", "putos", "mierda", "joder", "cabron", "cabrona", "pendejo", "pendeja", "verga", "culero", "chingar", "chingada", "putain", "salope", "salaud", "connard", "connasse", "encule", "merde", "scheisse", "scheiße", "arschloch", "hurensohn", "wichser", "fotze", "orospu", "siktir", "yarrak", "blyat", "blyad", "pizdec", "pidor", "pidoras", "mudak", "gandon", "ebat", "stronzo", "vaffanculo", "puttana", "cazzo", "minchia"
]);
// Arabic written in Latin letters ("arabizi", digits kept: 3 = ع, 7 = ح). Checked on the text BEFORE leetspeak is undone.
const ARABIZI = new Set(["sharmouta", "sharmoota", "sharmota", "sharmoot", "sharmuta", "sharmuuta", "3ars", "3arss", "kosomak", "kosumak", "kosomk", "kosomek", "kosokhtak", "ayre", "ayri", "ayree", "manyak", "manyok", "manyouk", "manyoka", "mnyak", "qahba", "kahba", "ka7ba", "ka7be", "qa7ba", "zebi", "zeb", "neek", "nik", "khawal", "5awal", "ahbal"]);
const ARABIZI_PHRASES = [["ya", "kalb"], ["ibn", "el", "kalb"], ["ibn", "el", "sharmouta"], ["ibn", "al", "kalb"], ["kos", "omak"], ["kos", "ommak"], ["kos", "okhtak"], ["kos", "ukhtak"], ["yal3an", "abook"], ["yel3an", "abook"]];
// Distinctive stems that are blocked even inside a longer word ("fuuuuckk", "motherfuckers"). Only stems with (almost) no innocent words.
const EMBEDDED = ["fuck", "nigg", "whore", "bitch", "faggot", "cocksuck", "wanker", "shit", "asshole", "arsehole", "pussy", "slut", "cunt"];
// Innocent words that contain one of the stems above (whole-word allow-list).
const ALLOW = new Set(["spice", "spiced", "spicer", "spicers", "spices", "spicing", "spicy", "cocky", "cockier", "cockiest", "cocked", "cocker", "cockers", "pricked", "pricker", "prickers", "pricking", "pricky", "dicky", "dicker", "dickers", "cummin", "cummins", "cummers", "annal", "annals", "anally", "assess", "assessed", "assesses", "assessing", "poorness", "poornesses", "beanery", "rappee", "rappees", "tittle", "tittles", "shiitake", "shitake", "shiitakes", "shitakes", "scunthorpe", "cunthorpe", "assassin", "assassins", "slutsky", "pussycat", "pussycats", "pussywillow", "pussyfoot", "pussyfoots", "pussyfooted", "pussyfooting", "pussyfooter", "pussyfooters", "pussytoes", "mishit", "mishits", "mishitting",
  "niggle", "niggled", "niggles", "niggling", "snigger", "sniggered", "sniggering", "sniggers"]);
// Stems blocked only at the START of a word (so "Dickinson" and "grape" stay allowed).
const STARTS = ["porn"];
const HARM = [
  /\bkill\s*(your\s*self|urself|ur\s*self|yourself)\b/, /\bgo\s+(die|kill\s*yourself|hang)\b/, /\b(hang|neck|off)\s*(your\s*self|urself|yourself)\b/,
  /\bi\s*('?ll|will|am\s+going\s+to|gonna)\s+(kill|murder|stab|shoot|hurt|rape)\s+(you|u|ya)\b/, /\b(commit|go\s+commit)\s+suicide\b/
];
// Arabic starter list (normalised: no diacritics, ا for أإآ, ي for ى, ه for ة). Have a native speaker review and extend it.
const AR_WORDS = new Set(["شرموطه", "شرموط", "شراميط", "قحبه", "قحاب", "عرص", "عرصه", "منيوك", "منيوكه", "متناك", "كسمك", "كسختك"]);
const AR_PHRASES = ["كس امك", "كس اختك", "ابن الكلب", "ابن الشرموطه", "ابن القحبه", "يلعن ابوك", "يلعن امك", "يلعن دينك"];
for (const w of (process.env.CHAT_EXTRA_BAD_WORDS || "").split(",")) { const x = w.trim().toLowerCase(); if (x) BAD_WORDS.add(x); }

const LEET = { "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "8": "b", "9": "g", "@": "a", "$": "s", "!": "i", "+": "t", "|": "i", "€": "e", "¢": "c", "£": "l" };
// Look-alike letters from other alphabets that people use to dodge filters.
const HOMOGLYPH = { "а": "a", "е": "e", "о": "o", "р": "p", "с": "c", "х": "x", "у": "y", "і": "i", "ѕ": "s", "ј": "j", "ɡ": "g", "ο": "o", "α": "a", "ε": "e", "ι": "i", "κ": "k", "ν": "v", "ρ": "p", "τ": "t", "υ": "u", "ß": "ss", "ø": "o", "đ": "d", "ł": "l", "ı": "i", "ɪ": "i", "ʟ": "l", "ᴀ": "a", "ᴇ": "e", "ᴏ": "o", "ᴜ": "u", "ѵ": "v", "ԁ": "d", "һ": "h", "ո": "n", "ս": "u" };
const SUFFIXES = ["s", "es", "ed", "ing", "er", "ers", "y", "in", "z"];
const PII = [
  [/[a-z0-9._%+-]+\s?(@|\(at\)|\[at\])\s?[a-z0-9.-]+\s?(\.|\(dot\))\s?[a-z]{2,}/i, "email"],
  [/(https?:\/\/|www\.)\S+|\b[a-z0-9-]{2,}\s?(\.|\(dot\)|\bdot\b)\s?(com|net|org|io|gg|me|co|xyz|ly|tv|app|ru|info|cc|link|site|online)\b/i, "link"],
  [/(\d[\s().\-_]*){7,}/, "number"],
  [/\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/, "ip"],
  [/\b(discord\.gg|t\.me|wa\.me|bit\.ly)\b/i, "link"],
  [/\b(my|add me|dm me|msg me|text me|follow me|hmu|pm me)\b.{0,30}\b(snap(chat)?|insta(gram)?|discord|whats\s?app|telegram|kik|tiktok|number|phone|address|email|password|real name|roblox|fortnite)\b/i, "contact"],
  [/\bi (live|go to school) (at|in|on)\b|\bmy (school|address|street)\b|\bhow old are you\b|\bwhat('s| is) your (address|number|age|real name)\b|\bwhere do you live\b/i, "personal"]
];

// Characters that are invisible or only steer the text direction. They are removed from the message itself, so they can't hide inside a word.
const INVISIBLE = /[\u0000-\u001f\u007f-\u009f\u00ad\u034f\u061c\u115f\u1160\u17b4\u17b5\u180b-\u180f\u200b-\u200f\u2028-\u202f\u205f-\u206f\u2800\u3164\ufe00-\ufe0f\ufeff\uffa0\ufff9-\ufffb]|\udb40[\udc00-\udfff]|\ud834[\udd73-\udd7a]/g;
const collapse = s => s.replace(/(.)\1+/g, "$1");
const stripAr = s => s.replace(/[ً-ٰٟـ]/g, "").replace(/[أإآٱ]/g, "ا").replace(/ى/g, "ي").replace(/ة/g, "ه").replace(/(.)\1{2,}/g, "$1$1");

// Elongation: "fuuuck", "shiiit", "boooobs" still match, but only by repeating letters the word already has ("bobs" is not "boobs", "as" is not "ass").
const runsOf = w => { const ch = [], n = []; for (const c of w) { if (ch.length && ch[ch.length - 1] === c) n[n.length - 1]++; else { ch.push(c); n.push(1); } } return [ch.join(""), n]; };
const RUN_INDEX = new Map();
for (const w of BAD_WORDS) { if (w.length < 3) continue; const [k, n] = runsOf(w); if (!RUN_INDEX.has(k)) RUN_INDEX.set(k, []); RUN_INDEX.get(k).push(n); }
function isBadWord(t) {
  if (BAD_WORDS.has(t)) return true;
  const [k, n] = runsOf(t), c = RUN_INDEX.get(k);
  return !!c && n.some(x => x >= 3) && c.some(m => m.every((v, i) => n[i] >= v));
}
const swapLI = t => t.replace(/l/g, "i");                                // l / I / 1 / | all look alike: try both readings
function suffixBad(t) { for (const sfx of SUFFIXES) if (t.length - sfx.length >= 4 && t.endsWith(sfx) && isBadWord(t.slice(0, -sfx.length))) return true; return false; }
const exactBad = t => isBadWord(t) || suffixBad(t) || isBadWord(swapLI(t));

function badToken(tok) {
  if (tok.length < 2) return false;
  if (tok.includes("*")) {                                  // f*ck, sh*t, b*tch: '*' stands for any one letter
    const re = new RegExp("^" + tok.replace(/[^a-z*]/g, "").replace(/\*+/g, m => ".".repeat(m.length)) + "$");
    for (const w of BAD_WORDS) if (w.length >= 3 && re.test(w)) return true;
    return false;
  }
  if (ALLOW.has(tok) || ALLOW.has(collapse(tok))) return false;
  for (const t of new Set([tok, swapLI(tok)])) {
    const c = collapse(t);
    if (isBadWord(t) || (t === tok && suffixBad(t))) return true;
    if (EMBEDDED.some(st => c.includes(st) || t.includes(st))) return true;           // "youfuckingsuck", "xxshitxx"
    if (STARTS.some(st => t.startsWith(st))) return true;
  }
  return false;
}

// Emoji people use as letters.
const EMOJI_LETTER = { "💲": "s", "⭕": "o", "🅾": "o", "🅰": "a", "🅱": "b", "ℹ": "i", "❌": "x", "✖": "x", "❎": "x", "🔠": "", "🆎": "ab", "🆑": "cl", "🆒": "cool", "🆓": "free", "🆗": "ok", "🔞": "", "💯": "100", "🅿": "p", "Ⓜ": "m", "©": "c", "®": "r", "™": "tm", "§": "s", "¥": "y", "€": "e", "¢": "c", "£": "l", "∂": "d", "∑": "e", "∏": "n", "∫": "j", "√": "v", "∞": "oo", "≠": "e", "∆": "a", "Ω": "o", "µ": "u", "×": "x", "÷": "", "¡": "i", "¿": "" };
// Seen through fancy fonts: NFKD folds bold/italic/circled/fullwidth/accented forms, CONFUSABLES folds look-alike alphabets, small caps and upside-down text.
// Characters whose NFKD form would turn into a different (wrong) letter, so they are read before folding.
const RAW = { "Ϲ": "c", "ϲ": "c", "ӏ": "l", "Ⅰ": "l", "ɯ": "w" };
const normLatin = s => {
  let out = "";
  s = s.replace(/[ϹϲӏⅠɯ]/g, c => RAW[c]);
  for (const ch of s.normalize("NFKD")) {
    if (/\p{M}/u.test(ch)) continue;                                     // accents, zalgo, strike-through, underline, keycaps
    const m = CONFUSABLES[ch] ?? CONFUSABLES_EXTRA[ch] ?? EMOJI_LETTER[ch] ?? HOMOGLYPH[ch];
    out += m !== undefined ? m : ch;
  }
  return out.toLowerCase().replace(/[^\u0000-\u007f]/g, c => CONFUSABLES[c] || CONFUSABLES_EXTRA[c] || HOMOGLYPH[c] || c);
};
const leetOf = plain => plain.replace(/[01345789@$!+|€¢£]/g, c => LEET[c] || c);
const stripEdges = c => c.replace(/^['"(\[]+/, "").replace(/[!.,?;:'")\]]+$/, "");     // "fuck!!!" -> "fuck" (otherwise ! would turn into an i)
const letterForm = c => leetOf(normLatin(stripEdges(c))).replace(/[^a-z*]/g, "");
const plainWord = c => normLatin(stripEdges(c)).replace(/[^a-z0-9]/g, "");
const arWord = c => stripAr(c).replace(/[^؀-ۿ]/g, "");
function chunkBad(c) {
  const plain = normLatin(stripEdges(c)), leet = leetOf(plain);
  const toks = leet.split(/[^a-z*]+/).filter(Boolean);
  if (toks.some(badToken)) return true;
  if (toks.length >= 2 && toks.length <= 12) {                         // pieces joined by punctuation: "f.u.c.k", "sh_it", "f-uck", "f🔥u🔥c🔥k"
    const j = toks.join("");
    if (j.length >= 4 && toks.some(t => t.length <= 2) && (toks.every(t => t.length <= 2) ? badToken(j) : exactBad(j))) return true;
  }
  return plain.split(/[^a-z0-9]+/).filter(Boolean).some(t => ARABIZI.has(t));
}
function arabicChunkBad(c) {
  const w = arWord(c); if (!w) return false;
  return AR_WORDS.has(w) || AR_WORDS.has(w.replace(/^(و|ف|ب|ل)/, "")) || AR_PHRASES.some(ph => w === stripAr(ph).replace(/ /g, ""));
}

export function checkMessage(raw) {
  if (typeof raw !== "string") return { ok: false, reason: "invalid" };
  const text = raw.replace(/[ϹϲӏⅠɯ]/g, c => RAW[c]).normalize("NFKC").replace(INVISIBLE, "").replace(/\s+/g, " ").trim();
  if (!text) return { ok: false, reason: "empty" };
  if (text.length > 150) return { ok: false, reason: "long" };
  const letters = text.replace(/[^A-Za-z]/g, "");
  if (/(.)\1{7,}/.test(text) || (text.length > 8 && text.replace(/[^A-Z]/g, "").length / Math.max(1, letters.length) > 0.8 && letters.length > 12)) return { ok: false, reason: "spam" };
  const wordsRaw = text.toLowerCase().split(/\s+/);
  if (wordsRaw.length >= 8) { const cnt = {}; for (const w of wordsRaw) { cnt[w] = (cnt[w] || 0) + 1; if (cnt[w] >= 8) return { ok: false, reason: "spam" }; } }
  for (const [re] of PII) if (re.test(text)) return { ok: false, reason: "personal" };

  // HARM (threats / self-harm) is always blocked, never just masked.
  const plainAll = normLatin(text), leetAll = leetOf(plainAll);
  for (const re of HARM) if (re.test(leetAll.replace(/\s+/g, " "))) return { ok: false, reason: "harm" };

  // Bad language: work word by word on the ORIGINAL text so only the bad words are hidden.
  const chunks = text.split(" "), hit = new Array(chunks.length).fill(false);
  chunks.forEach((c, i) => { if (chunkBad(c) || arabicChunkBad(c)) hit[i] = true; });
  // Spaced-out evasion: "f u c k", "s h i t", "sh it", "f uck". Only runs of 1-2 letter pieces (or one lone letter + one longer piece) are glued together,
  // so "my pen is blue" is never read as "penis".
  const lf = chunks.map(letterForm);
  for (let i = 0; i < chunks.length; i++) {
    if (!lf[i]) continue;
    const idx = []; let j = "";
    for (let k = i; k < chunks.length && idx.length < 12; k++) {
      if (!lf[k]) continue;                                            // a lone "." or "-" between letters
      idx.push(k); j += lf[k];
      if (lf[k].length > 2 && idx.length > 2) break;
      if (idx.length < 2 || j.length < 4) continue;
      const lens = idx.map(x => lf[x].length);
      const allShort = lens.every(n => n <= 2);
      const lone = idx.length === 2 && Math.min(...lens) === 1 && Math.max(...lens) >= 3;
      if ((allShort && badToken(j)) || ((allShort || lone) && exactBad(j))) { for (let x = i; x <= k; x++) hit[x] = true; break; }
    }
  }
  // Arabic: spaced letters ("ش ر م و ط ه") and two/three-word phrases
  let arun = [];
  const flushAr = () => { if (arun.length >= 3) { const j = arun.map(i => arWord(chunks[i])).join(""); if (AR_WORDS.has(j)) arun.forEach(i => hit[i] = true); } arun = []; };
  chunks.forEach((c, i) => { const w = arWord(c); if (w.length === 1) arun.push(i); else flushAr(); });
  flushAr();
  for (const ph of AR_PHRASES) { const toks = stripAr(ph).split(" "); for (let i = 0; i + toks.length <= chunks.length; i++) if (toks.every((t, k) => arWord(chunks[i + k]) === t)) for (let k = 0; k < toks.length; k++) hit[i + k] = true; }
  for (const ph of ARABIZI_PHRASES) for (let i = 0; i + ph.length <= chunks.length; i++) if (ph.every((t, k) => plainWord(chunks[i + k]) === t)) for (let k = 0; k < ph.length; k++) hit[i + k] = true;

  if (hit.some(Boolean)) {
    if (FILTER_MODE === "block") return { ok: false, reason: "language" };
    return { ok: true, masked: true, text: chunks.map((c, i) => hit[i] ? Array.from(c, ch => /\s/.test(ch) ? ch : "#").join("") : c).join(" ") };
  }
  return { ok: true, text };
}
// "fu" then "ck" in two quick messages. Only very short fragments are joined, so ordinary chat ("pen" ... "is") is never touched.
export function checkSplit(prevRaw, curRaw) {
  if (typeof prevRaw !== "string" || typeof curRaw !== "string") return false;
  const clean = x => letterForm(x.replace(/[ϹϲӏⅠɯ]/g, c => RAW[c]).normalize("NFKC").replace(INVISIBLE, "").trim());
  const a = clean(prevRaw), b = clean(curRaw);
  if (!a || !b || a.length > 4 || b.length > 4 || a.length + b.length < 4) return false;
  const ok = (a.length <= 2 && b.length <= 2) || (Math.min(a.length, b.length) === 1);
  return ok && exactBad(a + b);
}
export const FRIENDLY = {
  language: "Let's keep BlockTopia friendly! Your message wasn't sent.",
  harm: "Threats and messages about hurting yourself or others aren't allowed. If you're struggling, please talk to someone you trust.",
  personal: "For your safety, don't share personal info or links. Your message wasn't sent.",
  spam: "That looks like spam. Your message wasn't sent.",
  long: "Message too long (150 characters max).", empty: "", invalid: "",
  rate: "You're chatting too fast. Slow down a little.", cooldown: "Chat is paused for a minute. Please keep it friendly."
};
