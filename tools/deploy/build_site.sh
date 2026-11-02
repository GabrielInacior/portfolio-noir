#!/usr/bin/env bash
# Monta a pasta de deploy estático `site/` (lida pela Vercel como Output Directory, sem build):
#   site/            páginas de SEO (pt/en, projetos, sitemap, robots, 404, og) vindas de game/web/
#   site/jogo/       export web do Godot (sem threads: sem COOP/COEP), arquivos originais sem .gz
# Uso: GODOT=/caminho/godot bash tools/deploy/build_site.sh
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-/c/Users/gabri/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe}"
cd "$ROOT"
python tools/seo_build.py
rm -rf site/* site/.[!.]* 2>/dev/null || true
mkdir -p site/jogo
# páginas estáticas (sem os .import do Godot)
(cd game/web && find . -type f ! -name "*.import" -exec cp --parents {} "$ROOT/site/" \;)
# jogo
cd game
"$GODOT" --headless --audio-driver Dummy --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --audio-driver Dummy --path . --export-release "Web" ../site/jogo/index.html 2>&1 | grep -E "ERROR|error" | grep -v "^$" | head -20 || true
cd "$ROOT"
# boot.js: o jogo abre por cima de todas as páginas (home, /en/, projetos)
python tools/deploy/make_boot.py
test -f site/jogo/index.wasm && test -f site/jogo/index.pck
du -sh site site/jogo
ls -la site/jogo
