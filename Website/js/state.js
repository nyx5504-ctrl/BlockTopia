// Shared app state + a tiny event bus.
export const S = {
  user: null, profile: null, deviceId: null, signingUp: false,
  friends: new Map(),      // uid -> {username, avatarColor, since}
  incoming: [],            // pending requests sent to me
  outgoing: new Set(),     // uids I sent a pending request to
  presence: new Map(),     // uid -> presence doc (who is in a game)
  fprof: new Map(),        // uid -> {at, data}  cached friend profiles
  notifs: [],
  stops: [],               // unsubscribe functions
};
const subs = {};
export const on = (evt, fn) => (subs[evt] ||= []).push(fn);
export const emit = evt => (subs[evt] || []).forEach(fn => { try { fn(); } catch (e) { console.error(evt, e); } });
