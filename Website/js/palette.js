// One shared character color palette. The Godot app uses the same list (GodotClient/Scripts/palette.gd); Backend/test/palette.mjs checks they match.
export const PALETTE = [
  "#ffe0bd", "#f1c27d", "#e0ac69", "#c68642", "#8d5524", "#5c3a21",
  "#f2f3f3", "#a3a2a5", "#635f62", "#1b2a35",
  "#c4281c", "#da8541", "#f5cd30", "#f2c744", "#4b974b", "#3f9a52",
  "#0d69ac", "#2f6fd6", "#6b327c", "#e8a0c4", "#7cc4ff", "#7ee0a6", "#ff8f7a", "#b9a2ff"
];
export const PART_DEFAULTS = {
  head: { size: 1, color: "#f2c744" }, torso: { size: 1, color: "#2f6fd6" },
  leftArm: { size: 1, color: "#f2c744" }, rightArm: { size: 1, color: "#f2c744" },
  leftLeg: { size: 1, color: "#3f9a52" }, rightLeg: { size: 1, color: "#3f9a52" }
};
