extends Node
## Opens every screen and popup of the real UI, saving a screenshot of each.
## Run under a display: xvfb-run godot --path . --rendering-driver opengl3 --resolution 720x1280 res://tests/ui.tscn
## Pass "-- --fresh" to start from a new game instead of the existing save.

const OUT := "user://shots/"
var main: Control

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var fresh := OS.get_cmdline_user_args().has("--fresh")
	if fresh:
		Game.reset_save()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(10)
	if fresh:
		# The opening: welcome screen, gift reveal, Cubert in the barn, Cubert at work.
		await _shot("start_1_welcome")
		Game.claim_gift()
		await _frames(30)
		await _shot("start_2_gift")
		main.close_popup()
		await _frames(6)
		await _shot("start_3_barn")
		Game.assign_pen(int(Game.cubes[0].id), 0)
		for i in 40:
			Game.tick(1.0, false)
		await _frames(6)
		await _shot("start_4_working")
	for k in Game.unlocked:
		Game.unlocked[k] = true
	Game._check_unlocks()
	main._rebuild()
	await _frames(6)
	for s in ["ranch", "wilds", "nest", "gym", "trade", "codex"]:
		main._set_screen(s)
		await _frames(6)
		await _shot(s)
	# Popups
	if Game.cubes.size() > 0:
		var best: Dictionary = Game.cubes[0]
		for c in Game.cubes:
			if int(c.rarity) > int(best.rarity):
				best = c
		main.show_cube_details(int(best.id))
		await _frames(6)
		await _shot("popup_details")
		main.close_popup()
		main._show_reveal(best, "MUTATION!")
		await _frames(30)
		await _shot("popup_reveal")
		main.close_popup()
		main._open_haggle(int(best.id), Game.TRADERS[0])
		main._haggle_push()
		await _frames(6)
		await _shot("popup_haggle")
		main.close_popup()
	main._open_picker("Pick a cube for Pen 1", func(c): return true, func(_cid): pass)
	await _frames(6)
	await _shot("popup_picker")
	main.close_popup()
	if Game.encounters.size() > 0:
		main.show_preview(Game.encounters[0], 1)
		await _frames(6)
		await _shot("popup_wild")
		main.close_popup()
	main._on_welcome({"seconds": 15240.0, "capped": false, "squares": 123456.0, "eggs": 7, "encounters": 4, "zones": 1})
	await _frames(6)
	await _shot("popup_welcome")
	main.close_popup()
	main.show_toast("CUBE IRS AUDIT! They took 1.2K Squares. Breed a Tax Exempt cube.")
	main._set_screen("ranch")
	await _frames(6)
	await _shot("toast")
	print("UI test complete")
	get_tree().quit()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT + name + ".png")
	img.save_png(path)
	print("shot ", path, " ", img.get_size())
