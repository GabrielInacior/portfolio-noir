// Resume um .cpuprofile (cdp_profile.js --out) com os nomes das funções do wasm (emcc --emit-symbol-map do
// MESMO wasm): tempo próprio e tempo inclusivo (função + o que ela chama).
// Uso: node tools/deploy/prof_names.js perfil.cpuprofile godot.symbols [--top 40] [--grep texto]
const fs = require('fs');
const [prof_path, sym_path] = process.argv.slice(2);
const argv = process.argv.slice(2);
const opt = (k, d) => { const i = argv.indexOf(k); return i >= 0 ? argv[i + 1] : d; };
const SYM = {};
for (const ln of fs.readFileSync(sym_path, 'utf8').split(/\r?\n/)) { const i = ln.indexOf(':'); if (i > 0) SYM[ln.slice(0, i)] = ln.slice(i + 1).trim(); }
const prof = JSON.parse(fs.readFileSync(prof_path));
const byId = {}, par = {};
prof.nodes.forEach(n => { byId[n.id] = n; });
prof.nodes.forEach(n => (n.children || []).forEach(c => { par[c] = n.id; }));
const nm = (f) => { const m = /^(?:wasm-function\[)?(\d+)\]?$/.exec(f); return m && SYM[m[1]] ? SYM[m[1]] : (f || '(anon)'); };
const self = {}, incl = {};
let total = 0;
for (let i = 0; i < prof.samples.length; i++) {
  let id = prof.samples[i]; const d = prof.timeDeltas[i] || 0; total += d;
  const seen = new Set(); let first = true;
  while (id) {
    const f = nm(byId[id].callFrame.functionName);
    if (first) { self[f] = (self[f] || 0) + d; first = false; }
    if (!seen.has(f)) { incl[f] = (incl[f] || 0) + d; seen.add(f); }
    id = par[id];
  }
}
const top = +opt('--top', 40), g = opt('--grep', '');
const pr = (o) => Object.entries(o).filter(([f]) => !g || f.includes(g)).sort((a, b) => b[1] - a[1]).slice(0, top)
  .forEach(([f, v]) => console.log((v / 1e6).toFixed(2).padStart(7) + ' s  ' + f.slice(0, 150)));
console.log('total ' + (total / 1e6).toFixed(2) + ' s\n-- tempo próprio'); pr(self);
console.log('-- inclusivo'); pr(incl);
