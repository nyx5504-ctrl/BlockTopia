// 3D preview of the real BlockTopia R6 rig (same roblox-r6.glb the game client uses).
// Per-part colour and size are applied to the skinned mesh vertices exactly like GodotClient/Scripts/avatar.gd.
import * as THREE from "three";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";

const PARTS = ["head", "torso", "leftArm", "rightArm", "leftLeg", "rightLeg"];
const FEET_Y = -2;            // model space: feet at -2, top of head at ~3.1
const CAMERA_FIT = 1.25;      // frame for the tallest allowed character so the height slider is visible

export function partForBone(name) {
  const n = String(name || "").replace(/_/g, " ");
  if (n.startsWith("Head")) return "head";
  if (n.startsWith("Torso")) return "torso";
  if (n.includes("Left Arm")) return "leftArm";
  if (n.includes("Right Arm")) return "rightArm";
  if (n.includes("Left Leg")) return "leftLeg";
  if (n.includes("Right Leg")) return "rightLeg";
  return "torso";
}

// Same classic smiley the game puts on the head (AvatarChip.face_image), ink on transparent.
export function faceImageData(ctx, n = 128) {
  const img = ctx.createImageData(n, n), d = img.data;
  const curve = [[0.24, 0.69], [0.40, 1.02], [0.60, 1.02], [0.76, 0.69]], pts = [];
  for (let i = 0; i <= 48; i++) {
    const t = i / 48, q = 1 - t;
    pts.push([0, 1].map(k => curve[0][k] * q * q * q + curve[1][k] * 3 * q * q * t + curve[2][k] * 3 * q * t * t + curve[3][k] * t * t * t));
  }
  const clamp = v => Math.min(1, Math.max(0, v));
  for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
    const px = (x + 0.5) / n, py = (y + 0.5) / n;
    let a = 0;
    const lx = px - 0.28, ly = py - 0.28, ang = -0.45;
    const rx = lx * Math.cos(ang) + ly * Math.sin(ang), ry = -lx * Math.sin(ang) + ly * Math.cos(ang);
    a = Math.max(a, clamp((1 - Math.hypot(rx / 0.145, ry / 0.25)) * n * 0.55 + 0.5));
    a = Math.max(a, clamp((1 - Math.hypot((px - 0.76) / 0.12, (py - 0.28) / 0.235)) * n * 0.55 + 0.5));
    let sd = Infinity;
    for (const p of pts) sd = Math.min(sd, Math.hypot(px - p[0], py - p[1]));
    a = Math.max(a, clamp((0.022 - sd) * n * 0.8 + 0.5));
    const i = (y * n + x) * 4; d[i] = d[i + 1] = d[i + 2] = 0; d[i + 3] = Math.round(a * 255);
  }
  return img;
}

// The glb's head atlas is grey with a baked face. Make everything white (so the picked colour shows true) and swap the face
// for the game's smiley, in the same spot, using the same region logic as Avatar._replace_face_texture().
export function buildHeadTexture(sourceImage) {
  const w = sourceImage.width, h = sourceImage.height;
  const cv = document.createElement("canvas"); cv.width = w; cv.height = h;
  const ctx = cv.getContext("2d", { willReadFrequently: true });
  ctx.drawImage(sourceImage, 0, 0);
  const img = ctx.getImageData(0, 0, w, h), px = img.data;
  const x0 = Math.floor(w * 0.25), x1 = Math.floor(w * 0.52), y0 = Math.floor(h * 0.20), y1 = Math.floor(h * 0.82);
  let minX = x1, minY = y1, maxX = x0, maxY = y0;
  for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) {
    const i = (y * w + x) * 4;
    if (px[i] < 31 && px[i + 1] < 31 && px[i + 2] < 31) { if (x < minX) minX = x; if (x > maxX) maxX = x; if (y < minY) minY = y; if (y > maxY) maxY = y; }
  }
  for (let i = 0; i < px.length; i += 4) { px[i] = px[i + 1] = px[i + 2] = 255; px[i + 3] = 255; }   // flat white atlas
  ctx.putImageData(img, 0, 0);
  if (maxX >= minX && maxY >= minY) {
    const target = Math.max(1, Math.floor(Math.min(w, h) * 0.17)), cx = Math.floor((minX + maxX) / 2), cy = Math.floor((minY + maxY) / 2);
    const rx = Math.min(Math.max(cx - Math.floor(target / 2), x0), Math.max(x0, x1 - target));
    const ry = Math.min(Math.max(cy - Math.floor(target / 2), y0), Math.max(y0, y1 - target));
    const rw = Math.min(target, w - rx), rh = Math.min(target, h - ry);
    const face = document.createElement("canvas"); face.width = face.height = 128;
    const fctx = face.getContext("2d"); fctx.putImageData(faceImageData(fctx, 128), 0, 0);
    ctx.save(); ctx.imageSmoothingEnabled = true; ctx.imageSmoothingQuality = "high";
    ctx.translate(rx, ry + rh); ctx.scale(1, -1);            // the atlas stores the face upside down (game does face.flip_y())
    ctx.drawImage(face, 0, 0, rw, rh); ctx.restore();
  }
  const tex = new THREE.CanvasTexture(cv);
  tex.flipY = false; tex.colorSpace = THREE.SRGBColorSpace; tex.anisotropy = 4;
  return tex;
}

export const DEFAULT_CHARACTER = {
  height: 1, bodyType: "classic",
  parts: {
    head: { size: 1, color: "#f2c744" }, torso: { size: 1, color: "#2f6fd6" },
    leftArm: { size: 1, color: "#f2c744" }, rightArm: { size: 1, color: "#f2c744" },
    leftLeg: { size: 1, color: "#3f9a52" }, rightLeg: { size: 1, color: "#3f9a52" }
  }
};

// Reads the glb once, remembers each vertex's part, then recolours/resizes in place whenever the character changes.
export function prepareMeshes(root) {
  const meshes = [];
  root.traverse(o => {
    if (!o.isSkinnedMesh) return;
    const g = o.geometry, pos = g.attributes.position, si = g.attributes.skinIndex, sw = g.attributes.skinWeight, bones = o.skeleton.bones;
    const roles = new Array(pos.count), bounds = {};
    for (let v = 0; v < pos.count; v++) {
      let best = 0, bw = -1;
      for (let k = 0; k < 4; k++) { const wk = sw.getComponent(v, k); if (wk > bw) { bw = wk; best = si.getComponent(v, k); } }
      const role = partForBone(bones[best]?.name); roles[v] = role;
      const b = bounds[role] || (bounds[role] = new THREE.Box3());
      b.expandByPoint(new THREE.Vector3(pos.getX(v), pos.getY(v), pos.getZ(v)));
    }
    const centres = {}; for (const r in bounds) centres[r] = bounds[r].getCenter(new THREE.Vector3());
    g.setAttribute("color", new THREE.BufferAttribute(new Float32Array(pos.count * 3), 3));
    o.frustumCulled = false;
    meshes.push({ mesh: o, base: Float32Array.from(pos.array), roles, centres });
  });
  return meshes;
}

export function applyCharacter(meshes, character) {
  const parts = (character && character.parts) || {};
  const col = new THREE.Color();
  for (const m of meshes) {
    const pos = m.mesh.geometry.attributes.position, colAttr = m.mesh.geometry.attributes.color;
    for (let v = 0; v < m.roles.length; v++) {
      const role = m.roles[v], spec = parts[role] || DEFAULT_CHARACTER.parts[role] || DEFAULT_CHARACTER.parts.torso;
      const s = Math.min(1.3, Math.max(0.7, Number(spec.size) || 1)), c = m.centres[role];
      pos.setXYZ(v, c.x + (m.base[v * 3] - c.x) * s, c.y + (m.base[v * 3 + 1] - c.y) * s, c.z + (m.base[v * 3 + 2] - c.z) * s);
      col.set(/^#[0-9a-f]{6}$/i.test(spec.color) ? spec.color : DEFAULT_CHARACTER.parts[role].color);
      colAttr.setXYZ(v, col.r, col.g, col.b);
    }
    pos.needsUpdate = true; colAttr.needsUpdate = true;
    m.mesh.geometry.computeBoundingSphere();
  }
}

export async function createRig(container, url) {
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: "low-power" });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  const gltf = await new GLTFLoader().loadAsync(url);
  const meshes = prepareMeshes(gltf.scene);
  if (!meshes.length) throw new Error("rig has no skinned meshes");
  for (const m of meshes) {
    const mat = m.mesh.material;
    const isHead = /head/i.test(m.mesh.name) || /head/i.test(mat.name || "");
    const next = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.9, metalness: 0, side: THREE.DoubleSide });
    if (isHead && mat.map?.image) next.map = buildHeadTexture(mat.map.image);
    m.mesh.material = next;
  }
  const scene = new THREE.Scene();
  scene.add(new THREE.HemisphereLight(0xffffff, 0x8a8a96, 1.15));
  const sun = new THREE.DirectionalLight(0xffffff, 1.4); sun.position.set(2.5, 5, 6); scene.add(sun);
  const pivot = new THREE.Group(), body = new THREE.Group();
  body.add(gltf.scene); pivot.add(body); scene.add(pivot);
  const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 100);
  const top = FEET_Y + 5.1 * CAMERA_FIT, bottom = FEET_Y - 0.1;      // floor line to the top of the tallest allowed head
  const midY = (top + bottom) / 2, spanY = (top - bottom) * 1.1;
  let yaw = 0.35, drag = null, idleStart = performance.now(), idle = true, dirty = true, scaleXZ = 1;
  const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;

  const resize = () => {
    const w = container.clientWidth, h = container.clientHeight;
    if (w < 2 || h < 2) return;
    renderer.setSize(w, h, false); camera.aspect = w / h;
    const fovV = THREE.MathUtils.degToRad(camera.fov), distV = (spanY / 2) / Math.tan(fovV / 2);
    const distH = (5.4 / 2) / (Math.tan(fovV / 2) * camera.aspect);
    const dist = Math.max(distV, distH);
    camera.position.set(0, midY, dist); camera.lookAt(0, midY, 0); camera.updateProjectionMatrix(); dirty = true;
  };
  const ro = new ResizeObserver(resize); ro.observe(container);
  const cv = renderer.domElement; cv.style.cssText = "width:100%;height:100%;display:block;touch-action:pan-y;cursor:grab";
  cv.setAttribute("role", "img"); cv.setAttribute("aria-label", "3D character preview. Drag to turn.");
  container.replaceChildren(cv);
  cv.addEventListener("pointerdown", e => { drag = { x: e.clientX, yaw }; idle = false; cv.setPointerCapture(e.pointerId); cv.style.cursor = "grabbing"; });
  cv.addEventListener("pointermove", e => { if (!drag) return; yaw = drag.yaw + (e.clientX - drag.x) * 0.012; dirty = true; });
  const end = () => { drag = null; cv.style.cursor = "grab"; };
  cv.addEventListener("pointerup", end); cv.addEventListener("pointercancel", end);
  cv.addEventListener("dblclick", () => { yaw = 0.35; idle = !reduce; idleStart = performance.now(); dirty = true; });

  const widthFor = t => (t === "slim" ? 0.84 : t === "broad" ? 1.16 : 1);
  function set(character) {
    const c = character || DEFAULT_CHARACTER, h = Math.min(1.25, Math.max(0.75, Number(c.height) || 1));
    scaleXZ = widthFor(c.bodyType);
    body.scale.set(scaleXZ, h, scaleXZ); body.position.y = -FEET_Y * h + FEET_Y;   // keep the feet on the same floor line
    applyCharacter(meshes, c); dirty = true;
  }
  let raf = 0;
  const frame = now => {
    raf = requestAnimationFrame(frame);
    if (!container.isConnected || container.clientWidth < 2) return;
    if (idle && !reduce && !drag) { pivot.rotation.y = 0.35 + Math.sin((now - idleStart) / 1800) * 0.5; dirty = true; }
    else pivot.rotation.y = yaw;
    if (!dirty) return; dirty = false; renderer.render(scene, camera);
  };
  set(DEFAULT_CHARACTER); resize(); raf = requestAnimationFrame(frame);
  return { set, dispose() { cancelAnimationFrame(raf); ro.disconnect(); renderer.dispose(); } };
}
