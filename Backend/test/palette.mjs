// Checks that the website and the Godot app use the same character color palette.
import fs from "node:fs";
import { PALETTE } from "../../Website/js/palette.js";
const gd = fs.readFileSync(new URL("../../GodotClient/Scripts/palette.gd", import.meta.url), "utf8");
const gdColors = [...gd.matchAll(/"(#[0-9a-fA-F]{6})"/g)].map(m => m[1].toLowerCase());
const same = gdColors.length === PALETTE.length && PALETTE.every((c, i) => c.toLowerCase() === gdColors[i]);
console.log(same ? `palette OK (${PALETTE.length} colors in both)` : "palette MISMATCH between Website/js/palette.js and GodotClient/Scripts/palette.gd");
process.exit(same ? 0 : 1);
