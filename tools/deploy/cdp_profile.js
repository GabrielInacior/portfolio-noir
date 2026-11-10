// Perfil de CPU (CDP Profiler) de um trecho do carregamento: do início até uma marca do carregador
// (window.__pf.t[marca]) ou até um texto no console. Resume as funções com mais tempo próprio.
// Uso: node tools/deploy/cdp_profile.js <url> [--mobile] [--throttle 4] [--until cidade_iniciada | --until-log "texto"]
//      [--from-log "texto"] (só perfila do 1º log com o texto até o --until-log)
//      [--keep pasta-perfil] [--out arquivo.cpuprofile] [--top 40]
const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const argv = process.argv.slice(2);
const opt = (k, d) => { const i = argv.indexOf(k); return i >= 0 ? argv[i + 1] : d; };
let url = argv[0];
url += (url.includes('?') ? '&' : '?') + 'perf=1';
const keep = opt('--keep', '');
const dir = keep ? path.resolve(keep) : fs.mkdtempSync(path.join(os.tmpdir(), 'pfprof-'));
const MOBILE = argv.includes('--mobile');
const THR = +opt('--throttle', MOBILE ? 4 : 1);
const UNTIL = opt('--until', ''), UNTIL_LOG = opt('--until-log', ''), FROM_LOG = opt('--from-log', '');
const chrome = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const proc = spawn(chrome, ['--headless=new', '--remote-debugging-port=9334', '--user-data-dir=' + dir, '--window-size=1280,720',
  '--mute-audio', '--no-first-run', '--disable-background-timer-throttling', '--disable-renderer-backgrounding',
  '--ignore-gpu-blocklist', '--enable-gpu-rasterization'], { stdio: 'ignore' });
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  let tabs;
  for (let i = 0; i < 40; i++) { try { tabs = await (await fetch('http://127.0.0.1:9334/json')).json(); if (tabs.length) break; } catch (e) {} await sleep(250); }
  const ws = new WebSocket(tabs.find(t => t.type === 'page').webSocketDebuggerUrl);
  await new Promise(r => ws.onopen = r);
  let id = 0; const pend = {}; let hit = false; let started = !FROM_LOG; const T0 = Date.now(); const logs = [];
  ws.onmessage = m => { const d = JSON.parse(m.data); if (d.method === 'Runtime.consoleAPICalled') { const t = d.params.args.map(a => a.value).join(' '); if (/PFT|pf\]/.test(t)) logs.push(((Date.now() - T0) / 1000).toFixed(1) + 's ' + t); if (FROM_LOG && !started && t.includes(FROM_LOG)) { started = true; send('Profiler.start'); } if (UNTIL_LOG && started && t.includes(UNTIL_LOG)) hit = true; } if (d.id && pend[d.id]) { pend[d.id](d); delete pend[d.id]; } };
  const send = (method, params = {}) => new Promise(r => { const i = ++id; pend[i] = r; ws.send(JSON.stringify({ id: i, method, params })); });
  const ev = async (e) => { const r = await send('Runtime.evaluate', { expression: e, returnByValue: true }); return r.result && r.result.result ? r.result.result.value : null; };
  await send('Page.enable'); await send('Runtime.enable'); await send('Profiler.enable');
  await send('Profiler.setSamplingInterval', { interval: 500 });
  if (MOBILE) {
    await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: true });
    await send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 });
    await send('Emulation.setUserAgentOverride', { userAgent: 'Mozilla/5.0 (Linux; Android 13; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0 Mobile Safari/537.36' });
  }
  if (THR > 1) await send('Emulation.setCPUThrottlingRate', { rate: THR });
  if (started) await send('Profiler.start');
  await send('Page.navigate', { url });
  for (let i = 0; i < 400 && !hit; i++) {
    await sleep(250);
    if (UNTIL) { const v = await ev('window.__pf&&window.__pf.t&&window.__pf.t["' + UNTIL + '"]'); if (v) hit = true; }
  }
  const r = await send('Profiler.stop');
  const prof = r.result.profile;
  if (opt('--out', '')) fs.writeFileSync(opt('--out', ''), JSON.stringify(prof));
  const self = {}; const byId = {};
  for (const n of prof.nodes) byId[n.id] = n;
  const dt = prof.timeDeltas; let total = 0;
  for (let i = 0; i < prof.samples.length; i++) {
    const n = byId[prof.samples[i]]; const d = dt[i] || 0; total += d;
    const cf = n.callFrame; const k = (cf.functionName || '(anon)') + ' ' + (cf.url ? path.basename(cf.url) : '') ;
    self[k] = (self[k] || 0) + d;
  }
  const top = Object.entries(self).sort((a, b) => b[1] - a[1]).slice(0, +opt('--top', 40));
  console.log('total amostrado: ' + (total / 1e6).toFixed(2) + ' s');
  for (const [k, v] of top) console.log((v / 1e6).toFixed(2).padStart(7) + ' s  ' + k);
  console.log(logs.join('\n'));
  ws.close(); proc.kill(); setTimeout(() => process.exit(0), 500);
})().catch(e => { console.error(e); proc.kill(); process.exit(1); });
