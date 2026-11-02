// Gerado por tools/deploy/make_boot.py. Abre a cidade noir por cima da página.
(function () {
  var CFG = {"canvasResizePolicy": 2, "emscriptenPoolSize": 8, "ensureCrossOriginIsolationHeaders": true, "executable": "/jogo/index", "experimentalVK": false, "fileSizes": {"index.pck": 13455064, "index.wasm": 39513091}, "focusCanvas": true, "gdextensionLibs": [], "godotPoolSize": 4, "mainPack": "/jogo/index.pck"};
  var path = location.pathname;
  var en = /^\/en(\/|$)/.test(path) || document.documentElement.lang === 'en';
  var loja = (path.match(/^\/projetos\/([^\/]+)/) || [])[1] || new URLSearchParams(location.search).get('loja') || '';
  function start() {
    var probe = document.createElement('canvas');
    var gl = probe.getContext('webgl2');
    if (!gl) return; // sem WebGL 2: fica o cartão noir com os links
    document.body.classList.add('pf-on');
    var css = document.createElement('style');
    css.textContent =
      '#pfg{position:fixed;inset:0;z-index:9999;background:#05060c}' +
      '#pfg canvas{display:block;width:100vw;height:100vh;outline:none;touch-action:none}' +
      '#pfl{position:fixed;inset:0;z-index:10000;display:flex;flex-direction:column;align-items:center;justify-content:center;' +
      'background:radial-gradient(ellipse at 50% 72%,#1a0f2e 0%,#05060c 66%);color:#e8e2d0;transition:opacity .7s}' +
      '#pfl .o{font:600 13px/1 "Courier New",monospace;letter-spacing:.42em;color:#ff4fa3;margin:0 0 .5em}' +
      '#pfl .n{font:400 clamp(42px,9.5vw,94px)/1 "Bebas Neue",Impact,sans-serif;letter-spacing:.07em;color:#f3ead8;margin:0;' +
      'text-shadow:0 0 18px #ff4fa3aa,0 0 42px #5aaadc66}' +
      '#pfl .s{font:clamp(13px,2.6vw,17px) "Courier New",monospace;color:#ffb23d;margin:.7em 0 2em}' +
      '#pfl .b{width:min(320px,70vw);height:4px;background:#1b1a28;border-radius:2px;overflow:hidden}' +
      '#pfl .f{height:100%;width:0;background:linear-gradient(90deg,#ff4fa3,#ffc83d);box-shadow:0 0 12px #ff4fa3;transition:width .3s}' +
      '#pfl .m{margin-top:14px;font:12px "Courier New",monospace;color:#8a86a8;min-height:1em}' +
      '#pfl .r{position:absolute;inset:0;pointer-events:none;opacity:.22;' +
      'background:repeating-linear-gradient(100deg,transparent 0 22px,#9fb3ff22 22px 23px);animation:pfr .6s linear infinite}' +
      '@keyframes pfr{from{background-position:0 0}to{background-position:-40px 160px}}' +
      'html.pf-lock,html.pf-lock body{overflow:hidden!important}';
    document.head.appendChild(css);
    document.documentElement.classList.add('pf-lock');
    var wrap = document.createElement('div');
    wrap.id = 'pfg';
    var canvas = document.createElement('canvas');
    canvas.id = 'canvas';
    canvas.tabIndex = 0;
    canvas.setAttribute('aria-label', en ? 'Noir city in 3D' : 'Cidade noir em 3D');
    wrap.appendChild(canvas);
    var load = document.createElement('div');
    load.id = 'pfl';
    load.innerHTML = '<div class="r"></div><p class="o">' + (en ? 'PORTFOLIO' : 'PORTFÓLIO') + '</p><p class="n">GABRIEL INÁCIO</p>' +
      '<p class="s">' + (en ? 'software engineering · games · AI' : 'engenharia de software · games · IA') + '</p>' +
      '<div class="b"><div class="f"></div></div><div class="m">' + (en ? 'turning on the neon...' : 'acendendo os neons...') + '</div>';
    document.body.appendChild(wrap);
    document.body.appendChild(load);
    var fill = load.querySelector('.f'), msg = load.querySelector('.m');
    var hidden = false;
    function hide() {
      if (hidden) return;
      hidden = true;
      load.style.opacity = '0';
      setTimeout(function () { load.remove(); }, 800);
    }
    // o jogo avisa quando a tela de entrada está pronta (cidade montada e desenhada)
    window.pfReady = hide;
    var args = [];
    if (en) args.push('lang=en');
    if (loja) args.push('loja=' + loja);
    var s = document.createElement('script');
    s.src = '/jogo/index.js';
    s.onload = function () {
      var engine = new Engine(Object.assign({}, CFG, { canvas: canvas, args: args.length ? ['--'].concat(args) : [] }));
      engine.startGame({
        onProgress: function (cur, total) {
          if (total > 0) fill.style.width = Math.min(92, Math.round(cur / total * 92)) + '%';
          if (total > 0 && cur >= total) msg.textContent = en ? 'building the city...' : 'montando a cidade...';
        },
      }).then(function () {
        fill.style.width = '100%';
        setTimeout(hide, 25000); // garantia, caso o aviso do jogo não chegue
      }, function (err) {
        msg.textContent = (en ? 'Could not open the city: ' : 'Não foi possível abrir a cidade: ') + err;
      });
    };
    document.body.appendChild(s);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();
