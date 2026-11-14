// Public deployment settings (no secrets here).
export const CONFIG = {
  BACKEND_URL: "https://blocktopia-server-i1bq.onrender.com",            // e.g. "https://blocktopia-server.onrender.com" (the Backend/ Node server)
  DOWNLOADS: {                // GitHub Releases links produced by .github/workflows/build-clients.yml
    windows: "", android: "https://github.com/nyx5504-ctrl/BlockTopia/releases/download/v1.0/BlockTopia.apk",, macos: "", linux: "",
    ios: ""                   // TestFlight / App Store link, if you publish one
  }
};
