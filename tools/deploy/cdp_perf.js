// Mede carregamento e quadros num Chrome próprio (headless), com flags de GPU escolhidas.
// Uso: node tools/deploy/cdp_perf.js <url> [--soft] [--w 1280] [--h 720] [--secs 8] [--shop id] [--shot arquivo.png]
//   --soft   usa --disable-gpu --use-angle=swiftshader (renderização por software, como um PC sem placa)
// Requer o servidor local (tools/deploy/serve_local.py) e ?perf=1 na URL (adicionado automaticamente).
const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const argv = process.argv.slice(2);
const opt = (k, d) => { const i = argv.indexOf(k); return i >= 0 ? argv[i + 1] : d; };
let url = argv[0];
url += (url.includes('?') ? '&' : '?') + 'perf=1';
const soft = argv.includes('--soft');
const W = +opt('--w', 1280), H = +opt('--h', 720), SECS = +opt('--secs', 8);
const chrome = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const keep = opt('--keep', '');
const dir = keep ? path.resolve(keep) : fs.mkdtempSync(path.join(os.tmpdir(), 'pfcdp-'));
const OLD = argv.includes('--old');  // site antigo, sem os ganchos pfAB/pfFrameStats: só mede o carregamento
const flags = ['--headless=new', '--remote-debugging-port=9333', '--user-data-dir=' + dir, '--window-size=' + W + ',' + H,
  '--autoplay-policy=no-user-gesture-required', '--mute-audio', '--no-first-run', '--disable-background-timer-throttling',
  '--disable-renderer-backgrounding', '--disable-backgrounding-occluded-windows'];
if (soft) flags.push('--disable-gpu', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist');
else flags.push('--ignore-gpu-blocklist', '--enable-gpu-rasterization');
const proc = spawn(chrome, flags, { stdio: 'ignore' });
const sleep = ms => new Promise(r => setTimeout(r, ms));
(async () => {
  let tabs;
  for (let i = 0; i < 40; i++) {
    try { tabs = await (await fetch('http://127.0.0.1:9333/json')).json(); if (tabs.length) break; } catch (e) {}
    await sleep(250);
  }
  const page = tabs.find(t => t.type === 'page');
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise(r => ws.onopen = r);
  let id = 0; const pend = {};
  const logs = []; const T00 = Date.now();
  ws.onmessage = m => { const d = JSON.parse(m.data); if (d.method === 'Runtime.consoleAPICalled') { const t = d.params.args.map(a => a.value).join(' '); if (/PFT|pf\]|ERROR|AUDIO/.test(t)) logs.push(((Date.now() - T00) / 1000).toFixed(1) + 's ' + t); } if (d.id && pend[d.id]) { pend[d.id](d); delete pend[d.id]; } };
  const send = (method, params = {}) => new Promise(r => { const i = ++id; pend[i] = r; ws.send(JSON.stringify({ id: i, method, params })); });
  const ev = async (expr) => { const r = await send('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true }); return r.result && r.result.result ? r.result.result.value : r; };
  await send('Page.enable'); await send('Runtime.enable');
  // --mobile: celular médio (390x844, toque, UA Android) e --throttle N (CPU N vezes mais lenta; padrão 4 no --mobile)
  const MOBILE = argv.includes('--mobile');
  const THR = +opt('--throttle', MOBILE ? 4 : 1);
  if (MOBILE) {
    await send('Emulation.setDeviceMetricsOverride', { width: 390, height: 844, deviceScaleFactor: 2, mobile: true });
    await send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 });
    await send('Emulation.setUserAgentOverride', { userAgent: 'Mozilla/5.0 (Linux; Android 13; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0 Mobile Safari/537.36' });
  } else {
    await send('Emulation.setDeviceMetricsOverride', { width: W, height: H, deviceScaleFactor: 1, mobile: false });
  }
  if (THR > 1) await send('Emulation.setCPUThrottlingRate', { rate: THR });
  await send('Page.addScriptToEvaluateOnNewDocument', { source: 'window.__lt=[];try{new PerformanceObserver(function(l){l.getEntries().forEach(function(e){window.__lt.push([Math.round(e.startTime),Math.round(e.duration)])})}).observe({type:"longtask",buffered:true})}catch(e){}' });
  // --audiocheck: conta as amostras que o mixer do Godot entrega ao worklet (sem threads) por segundo de relógio;
  // abaixo de ~98% do necessário = buraco no som (estalo/distorção dos efeitos)
  if (argv.includes('--audiocheck')) await send('Page.addScriptToEvaluateOnNewDocument', { source: 'window.__au={n:0,t0:0,sr:0,ch:2,src:0};(function(){var S=window.AudioBufferSourceNode;if(S){var st=S.prototype.start;S.prototype.start=function(){window.__au.src++;return st.apply(this,arguments)}}var W=window.AudioWorkletNode;if(!W)return;window.AudioWorkletNode=function(ctx,name,o){var w=new W(ctx,name,o);if(name==="godot-processor"){window.__au.sr=ctx.sampleRate;window.__au.ch=(o&&o.outputChannelCount&&o.outputChannelCount[0])||2;var pm=w.port.postMessage.bind(w.port);w.port.postMessage=function(m,t){try{if(m&&m.cmd==="chunk"&&m.data){window.__au.n+=m.data.length}}catch(e){}return pm(m,t)}}return w};window.AudioWorkletNode.prototype=W.prototype})();' });
  if (opt('--lang', '')) await send('Page.addScriptToEvaluateOnNewDocument', { source: 'try{localStorage.setItem("pf_lang","' + opt('--lang', '') + '")}catch(e){}' });
  const t0 = Date.now();
  await send('Page.navigate', { url });
  if (opt('--loadshot', '')) { setTimeout(async () => { const r = await send('Page.captureScreenshot', { format: 'png' }); fs.writeFileSync(opt('--loadshot', ''), Buffer.from(r.result.data, 'base64')); }, +opt('--loadshot-ms', 6000)); }
  let ready = false;
  for (let i = 0; i < 160; i++) {
    await sleep(500);
    const st = await ev(OLD ? '(document.querySelector("#pfg canvas")&&!document.getElementById("pfl"))?1:0' : '(!document.getElementById("pfl")&&!!window.pfAB)?1:0').catch(() => 0);
    if (st === 1) { ready = true; break; }
  }
  const out = { url, soft, ready, wall_ready_s: (Date.now() - t0) / 1000 };
  out.t = await ev('JSON.stringify(window.__pf&&window.__pf.t)');
  out.msg = await ev('(document.querySelector("#pfl .m")||{}).textContent');
  out.gpu = await ev('JSON.stringify(window.pfGPU)');
  out.longtasks_load = await ev('JSON.stringify(window.__lt.sort(function(a,b){return b[1]-a[1]}).slice(0,6))');
  out.first_paint = await ev('JSON.stringify(performance.getEntriesByType("paint").map(function(p){return p.name+":"+Math.round(p.startTime)}))');
  if (ready && !OLD) {
    await sleep(1500);
    // ENTRAR
    if (MOBILE) {
      await ev('pfAB("enter",true)');
    } else {
      const x = Math.round(W * 0.157), y = Math.round(H * 0.62);
      for (const t of ['mousePressed', 'mouseReleased']) await send('Input.dispatchMouseEvent', { type: t, x, y, button: 'left', clickCount: 1 });
    }
    await sleep(2500);
    await ev('pfFrameStats(true)');
    await sleep(SECS * 1000);
    out.city = await ev('JSON.stringify(pfFrameStats(true))');
    // música pelo navegador: o tempo da trilha tem que andar junto com o relógio
    const m1 = await ev('window.pfMus?window.pfMus.state():""'); const c1 = Date.now();
    await sleep(3000);
    const m2 = await ev('window.pfMus?window.pfMus.state():""'); const c2 = Date.now();
    try { const a = JSON.parse(m1), b = JSON.parse(m2); out.music = 'trilha ' + (b.t - a.t).toFixed(2) + ' s em ' + ((c2 - c1) / 1000).toFixed(2) + ' s de relógio | ' + m2; } catch (e) { out.music = 'sem pfMus: ' + m1; }
    await ev('pfAB("info",true)'); await sleep(300);
    out.info = await ev('window.__pfInfo');
    if (argv.includes('--audiocheck')) {
      const a1 = JSON.parse(await ev('JSON.stringify(window.__au)')); const c1 = Date.now();
      await sleep(6000);
      const a2 = JSON.parse(await ev('JSON.stringify(window.__au)')); const c2 = Date.now();
      const need = a2.sr * a2.ch * (c2 - c1) / 1000;
      out.audio_mixer = 'efeitos (mixer do Godot): ' + (100 * (a2.n - a1.n) / Math.max(1, need)).toFixed(1) + '% das amostras necessárias em ' + ((c2 - c1) / 1000).toFixed(1) + ' s (sr ' + a2.sr + ', canais ' + a2.ch + ') | sons tocados pelo navegador: ' + a2.src;
    }
    const abl = opt('--ab', '');
    if (abl) {
      out.ab = {};
      for (const n of abl.split(',')) {
        await ev('pfAB("' + n + '",false)'); await sleep(2500); await ev('pfFrameStats(true)'); await sleep(4000);
        const st = JSON.parse(await ev('JSON.stringify(pfFrameStats(true))'));
        await ev('pfAB("info",true)'); await sleep(300);
        out.ab['no_' + n] = 'gap ' + st.gap_avg + ' p95 ' + st.gap_p95 + ' cpu ' + st.cpu_avg + ' | ' + await ev('window.__pfInfo');
        await ev('pfAB("' + n + '",true)'); await sleep(500);
      }
    }
    const shops = (opt('--shops', '') || opt('--shop', '')).split(',').filter(Boolean);
    out.shops = {};
    for (const shop of shops) {
      await ev('pfFrameStats(true)');
      await ev('pfAB("shop",true,"' + shop + '")');
      await sleep(2500);
      const en = JSON.parse(await ev('JSON.stringify(pfFrameStats(true))'));
      if (opt('--shopshots', '')) { const r = await send('Page.captureScreenshot', { format: 'png' }); fs.writeFileSync(path.join(opt('--shopshots', ''), shop + '.png'), Buffer.from(r.result.data, 'base64')); }
      await sleep(SECS * 1000);
      const st = JSON.parse(await ev('JSON.stringify(pfFrameStats(true))'));
      await ev('pfAB("info",true)'); await sleep(300);
      if (argv.includes('--shopcensus')) { await ev('pfAB("census",true,"' + shop + '")'); await sleep(300); out['census_' + shop] = await ev('window.__pfCensus'); }
      out.shops[shop] = 'enter_max ' + en.cpu_max + ' ms | cpu avg ' + st.cpu_avg + ' p95 ' + st.cpu_p95 + ' max ' + st.cpu_max + ' | gap avg ' + st.gap_avg + ' max ' + st.gap_max + ' | ' + await ev('window.__pfInfo');
      await ev('pfAB("shop",false,"' + shop + '")'); await sleep(1500);
    }
    // --langswitch pt|en: troca de idioma ao vivo (sem recarregar); tempo do jogo e do relógio, captura antes/depois
    const ls = opt('--langswitch', '');
    if (ls) {
      const pre = opt('--langshot', '');
      if (pre) { const r = await send('Page.captureScreenshot', { format: 'png' }); fs.writeFileSync(pre.replace(/\.png$/, '_antes.png'), Buffer.from(r.result.data, 'base64')); }
      const href0 = await ev('location.href');
      await ev('window.__pfLangMs=-1;window.__pfLangAllMs=-1;window.__pfNav=performance.getEntriesByType("navigation").length');
      const c0 = Date.now();
      await ev('pfFrameStats(true)');
      await ev('pfAB("lang",true,"' + ls + '")');
      let ms = -1;
      for (let i = 0; i < 100 && ms < 0; i++) { await sleep(50); ms = await ev('window.__pfLangMs'); }
      const wall = Date.now() - c0;
      await sleep(600);
      const st = JSON.parse(await ev('JSON.stringify(pfFrameStats(true))'));
      for (let i = 0; i < 100 && !(await ev('window.__pfLangAllMs>=0')); i++) await sleep(50);
      out.langswitch = 'textos ' + ms + ' ms, imagens ' + await ev('window.__pfLangAllMs') + ' ms | relógio ' + wall + ' ms | pior quadro ' + st.cpu_max + ' ms | url ' + href0 + ' -> ' + await ev('location.href') + ' | lang=' + await ev('document.documentElement.lang') + ' | title=' + await ev('document.title');
      if (pre) { await sleep(400); const r = await send('Page.captureScreenshot', { format: 'png' }); fs.writeFileSync(pre.replace(/\.png$/, '_depois.png'), Buffer.from(r.result.data, 'base64')); }
    }
    const shot = opt('--shot', '');
    if (shot) { const r = await send('Page.captureScreenshot', { format: 'png' }); fs.writeFileSync(shot, Buffer.from(r.result.data, 'base64')); }
  }
  if (argv.includes('--logs')) out.logs = logs;
  console.log(JSON.stringify(out, null, 1));
  ws.close(); proc.kill();
  setTimeout(() => process.exit(0), 500);
})().catch(e => { console.error(e); proc.kill(); process.exit(1); });
