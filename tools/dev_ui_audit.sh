#!/bin/bash
# Auditoria visual da UI em 5 tamanhos (mudo). Uso: bash tools/dev_ui_audit.sh <pasta_saida> [cena]
G="/c/Users/gabri/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe"
OUT="$1"; SCENE="${2:-res://tools_dev/ui_shot.tscn}"
mkdir -p "$OUT"
cd "$(dirname "$0")/../game"
for res in ${SIZES:-360x780 405x720 430x932 844x390 1920x1080}; do
  W="${res%x*}"; H="${res#*x}"
  printf '[display]\n\nwindow/size/viewport_width=%s\nwindow/size/viewport_height=%s\nwindow/size/window_width_override=%s\nwindow/size/window_height_override=%s\nwindow/size/borderless=true\nwindow/size/initial_position_type=0\nwindow/size/initial_position=Vector2i(0, 0)\n' "$W" "$H" "$W" "$H" > override.cfg
  RUMOR_SHOT="$OUT" TAG="$res" timeout 240 "$G" --audio-driver Dummy --path . "$SCENE" 2>&1 | grep -E "SHOT|SCRIPT ERROR" | head -12
done
rm -f override.cfg
