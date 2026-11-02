// Atlas de ícones de tecnologia com os LOGOS OFICIAIS (Simple Icons, CC0) nas cores oficiais,
// dentro de uma moldura/fundo noir nossa (chip escuro com borda na cor da marca).
// Saída: game/assets/tech_icons/<id>_128.png e _256.png, atlas.png e data/tech_icons.json.
//   cd tools/icons && npm i && node build_icons.mjs
import fs from "node:fs";
import path from "node:path";
import sharp from "sharp";
import * as si from "simple-icons";

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1")), "..", "..");
const OUT = path.join(ROOT, "game", "assets", "tech_icons");
fs.mkdirSync(OUT, { recursive: true });

// id do jogo -> slug do Simple Icons, nome de exibição e apelidos usados nos dados
const MAP = [
  ["godot", "siGodotengine", "Godot", ["GDScript", "Godot 4"]],
  ["blender", "siBlender", "Blender", []],
  ["node", "siNodedotjs", "Node.js", ["Node", "Node.js"]],
  ["vue", "siVuedotjs", "Vue", ["Vue.js", "Vue 3"]],
  ["react", "siReact", "React", ["React Native"]],
  ["nuxt", "siNuxt", "Nuxt", ["Nuxt 3", "Nuxt 4", "Nuxt.js"]],
  ["next", "siNextdotjs", "Next.js", ["Next"]],
  ["flutter", "siFlutter", "Flutter", []],
  ["dart", "siDart", "Dart", []],
  ["typescript", "siTypescript", "TypeScript", ["TS"]],
  ["javascript", "siJavascript", "JavaScript", ["JS"]],
  ["python", "siPython", "Python", []],
  ["rust", "siRust", "Rust", []],
  ["tauri", "siTauri", "Tauri", []],
  ["docker", "siDocker", "Docker", []],
  ["postgres", "siPostgresql", "PostgreSQL", ["Postgres", "RLS", "Postgres RLS"]],
  ["redis", "siRedis", "Redis", ["BullMQ"]],
  ["mongodb", "siMongodb", "MongoDB", []],
  ["prisma", "siPrisma", "Prisma", []],
  ["nest", "siNestjs", "NestJS", []],
  ["express", "siExpress", "Express", []],
  ["fastify", "siFastify", "Fastify", []],
  ["fastapi", "siFastapi", "FastAPI", []],
  ["spring", "siSpring", "Spring", ["Spring Boot"]],
  ["aws", "devicon:amazonwebservices/amazonwebservices-plain-wordmark.svg", "AWS", ["AWS S3", "S3", "Amazon S3"]],
  ["linux", "siLinux", "Linux", []],
  ["kali", "siKalilinux", "Kali Linux", ["Pentest"]],
  ["nginx", "siNginx", "Nginx", []],
  ["openai", "siOpenai", "OpenAI", ["GPT-4o-mini", "Whisper"]],
  ["claude", "siClaude", "Claude", ["Anthropic", "agentes", "IA"]],
  ["ollama", "siOllama", "Ollama", ["IA local", "LLM local"]],
  ["gemini", "siGooglegemini", "Gemini", ["IA (Gemini)"]],
  ["huggingface", "siHuggingface", "Hugging Face", []],
  ["stripe", "siStripe", "Stripe", []],
  ["whatsapp", "siWhatsapp", "WhatsApp", []],
  ["steam", "siSteam", "Steam", []],
  ["gsap", "siGreensock", "GSAP", []],
  ["materialdesign", "siMaterialdesign", "Material 3", ["Material"]],
  ["socketio", "siSocketdotio", "WebSocket", ["Socket.io", "WebSockets"]],
  ["electron", "siElectron", "Electron", []],
  ["tailwind", "siTailwindcss", "Tailwind", ["TailwindCSS"]],
  ["git", "siGit", "Git", []],
  ["github", "siGithub", "GitHub", []],
  ["figma", "siFigma", "Figma", []],
  ["vite", "siVite", "Vite", []],
];

function hexLum(h) {
  const n = parseInt(h, 16);
  const c = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((v) => {
    v /= 255;
    return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}

function svgFor(icon, size) {
  // logo escuro demais (preto/cinza escuro) vira claro para ler no fundo noir
  let col = icon.hex;
  if (hexLum(col) < 0.05) col = "EEF2FF";
  else if (hexLum(col) < 0.16) {  // escuro demais no fundo noir: clareia mantendo o tom da marca
    const n = parseInt(col, 16);
    col = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((v) => Math.round(v + (255 - v) * 0.45).toString(16).padStart(2, "0")).join("");
  }
  const pad = size * 0.2;
  const s = (size - pad * 2) / 24;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
  <defs><radialGradient id="g" cx="50%" cy="40%" r="70%"><stop offset="0" stop-color="#1b2140"/><stop offset="1" stop-color="#070a16"/></radialGradient></defs>
  <rect x="${size * 0.04}" y="${size * 0.04}" width="${size * 0.92}" height="${size * 0.92}" rx="${size * 0.2}" fill="url(#g)" stroke="#${col}" stroke-opacity="0.85" stroke-width="${size * 0.035}"/>
  ${icon.devicon
    ? `<g transform="translate(${pad},${pad}) scale(${(size - pad * 2) / icon.devicon.vb[2]})" fill="#${col}">${icon.devicon.inner}</g>`
    : `<g transform="translate(${pad},${pad}) scale(${s})"><path d="${icon.path}" fill="#${col}"/></g>`}</svg>`;
}

const index = [];
const tiles = [];
for (const [id, slug, name, alias] of MAP) {
  let icon = si[slug];
  if (!icon && slug.startsWith("devicon:")) {
    // fallback: Devicon (MIT) quando a marca não está no Simple Icons (ex.: AWS)
    const f = path.join(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1")), "node_modules", "devicon", "icons", slug.slice(8));
    const raw = fs.readFileSync(f, "utf8");
    const vb = (raw.match(/viewBox="([^"]+)"/) || [0, "0 0 128 128"])[1].split(/\s+/).map(Number);
    const inner = raw.replace(/^[\s\S]*?<svg[^>]*>/, "").replace(/<\/svg>\s*$/, "");
    icon = { hex: "FF9900", title: "Devicon: amazonwebservices", devicon: { vb, inner } };
  }
  if (!icon) { console.log("SEM ÍCONE", slug); continue; }
  for (const size of [128, 256]) {
    const buf = await sharp(Buffer.from(svgFor(icon, size))).png().toBuffer();
    fs.writeFileSync(path.join(OUT, `${id}_${size}.png`), buf);
    if (size === 128) tiles.push({ id, buf });
  }
  index.push({ id, name, alias, color: "#" + icon.hex, source: icon.devicon ? icon.title : "Simple Icons: " + icon.title, license: icon.devicon ? "MIT" : "CC0-1.0" });
}
// atlas único (grade de 8 colunas de 128 px)
const cols = 8;
const rows = Math.ceil(tiles.length / cols);
const atlas = sharp({ create: { width: cols * 128, height: rows * 128, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } } });
await atlas.composite(tiles.map((t, i) => ({ input: t.buf, left: (i % cols) * 128, top: Math.floor(i / cols) * 128 }))).png()
  .toFile(path.join(OUT, "atlas.png"));
index.forEach((it, i) => { it.atlas = { col: i % cols, row: Math.floor(i / cols), size: 128 }; });
fs.writeFileSync(path.join(ROOT, "data", "tech_icons.json"), JSON.stringify(index, null, 1));
// versão lida pelo jogo (ui.gd): {"icons": {nome: {id, file, aliases, color}}}
const game = { icons: Object.fromEntries(index.map((it) => [it.name, { id: it.id, file: it.id + "_128.png", aliases: it.alias, color: it.color }])) };
fs.writeFileSync(path.join(ROOT, "game", "assets", "data", "tech_icons.json"), JSON.stringify(game, null, 1));
console.log("ícones:", index.length);
