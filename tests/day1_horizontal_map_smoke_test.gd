extends SceneTree

const SCENE_PATH := "res://scenes/Day 1/Side Scroll Section/Side_Scroll Day 1.tscn"
const PREVIEW_PATH := "res://tests/artifacts/day1_horizontal_map_preview.png"

var failures := 0


func _initialize() -> void:
	print("DAY1_HORIZONTAL_MAP_TEST_START")
	_run.call_deferred()


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "Day 1 scene loads")
	if packed == null:
		quit(1)
		return

	var level := packed.instantiate()
	root.add_child(level)
	for _frame in 12:
		await physics_frame

	var tile_map := level.get_node_or_null("EnvironmentTileMap") as TileMapLayer
	var player := level.get_node_or_null("Player") as CharacterBody2D
	_check(tile_map != null, "scene contains a TileMapLayer")
	_check(tile_map != null and tile_map.tile_set != null, "TileMapLayer has a TileSet")
	_check(tile_map != null and tile_map.tile_set.get_source_count() == 18, "TileSet exposes all 18 sliced props")
	_check(tile_map != null and tile_map.get_used_cells().size() == 22, "horizontal map places 22 cells")
	_check(level.has_node("GroundCollision"), "horizontal map has walkable ground collision")
	_check(level.has_node("HorizontalCamera"), "scene has a horizontal follow camera")
	_check(player != null and player.is_on_floor(), "player settles onto the map floor")

	var start_x := player.position.x
	Input.action_press(&"move_right")
	for _frame in 45:
		await physics_frame
	Input.action_release(&"move_right")
	_check(player.position.x > start_x + 80.0, "player can traverse the map horizontally")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("SKIP: preview screenshot unavailable on the headless display")
	else:
		var screenshot := root.get_viewport().get_texture().get_image()
		var screenshot_error := screenshot.save_png(ProjectSettings.globalize_path(PREVIEW_PATH))
		_check(screenshot_error == OK, "preview screenshot saves")

	level.queue_free()
	for _frame in 3:
		await process_frame
	if failures == 0:
		print("DAY1_HORIZONTAL_MAP_TEST_PASS")
	quit(failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
