extends Node
## Painéis com identidade por projeto (mudo): a mesma peça aberta em lojas diferentes.
## RUMOR_SHOT=<pasta> TAG=<nome> godot --path . res://tools_dev/theme_shot.tscn
var main: Node


func _ready() -> void:
	var dir := OS.get_environment("RUMOR_SHOT")
	var tag := OS.get_environment("TAG")
	main = load("res://scenes/city.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.6).timeout
	main._gate.queue_free()
	main.hud.visible = true
	var hud = main.hud
	for id in ["rumor", "fortress", "inaciocyber", "labia", "atende360", "sitembm", "buscavagas"]:
		var pr := {}
		for p in Data.projects:
			if str(p.get("id", "")) == id:
				pr = p
		if pr.is_empty():
			continue
		hud.enter_museum(pr)
		await get_tree().create_timer(1.0).timeout
		if hud._museum and hud._museum.items.size() > 0:
			var e: Dictionary = hud._museum.items[0]
			for it in hud._museum.items:
				if str(it["item"].get("img", "")) != "":
					e = it
					break
			hud._museum.mark_seen(e)
			hud._modal_open()
			var ex = load("res://scripts/exhibit.gd").new()
			ex.setup(e["item"], hud._museum._accent, hud._museum.project)
			hud.add_child(UI.full(ex))
			await get_tree().create_timer(0.9).timeout
			get_viewport().get_texture().get_image().save_png(dir.path_join("%s_%s.png" % [tag, id]))
			print("SHOT ", id)
			ex.queue_free()
			hud._sheet_open = false
		hud.exit_museum()
	get_tree().quit()
