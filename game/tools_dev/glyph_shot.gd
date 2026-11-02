extends Control
## Prova dos símbolos: rótulo usando SÓ a fonte NoirSymbols (sem fallback do sistema).
func _ready() -> void:
	var bg := ColorRect.new(); bg.color = Color("#05060c"); bg.size = Vector2(900, 200); add_child(bg)
	var l := Label.new()
	var f := FontFile.new()
	f.load_dynamic_font("res://assets/fonts/NoirSymbols.ttf")
	f.allow_system_fallback = false
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", 64)
	l.text = "✕ ↗ → ← ▶ ▸ ◀ ★ ♪ ☎ ▌ ✓ ●"
	l.position = Vector2(20, 50)
	add_child(l)
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_environment("RUMOR_SHOT").path_join("glyphs.png"))
	get_tree().quit()
