// Public deployment settings (no secrets here).
// Download links use "releases/latest/download/<file name>", so they always point at your newest GitHub Release.
// The release must contain files with EXACTLY these names: BlockTopia-Windows.zip and BlockTopia.apk
const REL = "https://github.com/nyx5504-ctrl/BlockTopia/releases/latest/download/";
export const CONFIG = {
  BACKEND_URL: "https://blocktopia-server-i1bq.onrender.com",
  DOWNLOADS: {
    windows: REL + "BlockTopia-Windows.zip",
    android: REL + "BlockTopia.apk",
    macos: "", linux: "",
    ios: ""
  }
};
