extends SceneTree

const SCENE_PATH := "res://scenes/Day 1/Side Scroll Section/Side_Scroll Day 1.tscn"
const TILESET_PATH := "res://assets/art/Day1 Scene 1/day1_scene1_tileset.tres"
const TILE_ROOT := "res://assets/art/Day1 Scene 1/tiles/"
const CAMERA_SCRIPT := preload("res://scripts/world/day1_horizontal_camera.gd")
const TILE_SIZE := Vector2i(64, 64)
const GROUND_ROW := 10

const TILE_DEFINITIONS := [
	{"name": "notice_board", "z": 1},
	{"name": "authority_entrance", "z": 1},
	{"name": "authority_sign", "z": 2},
	{"name": "iron_gate", "z": 1},
	{"name": "one_voice_poster", "z": 2},
	{"name": "frequency_poster", "z": 2},
	{"name": "broadcast_signpost", "z": 2},
	{"name": "walled_fence", "z": 0},
	{"name": "tree", "z": 1},
	{"name": "broadcast_antenna", "z": 1},
	{"name": "authority_building", "z": -2},
	{"name": "security_door", "z": 2},
	{"name": "barred_window", "z": 2},
	{"name": "wall_lamp", "z": 3},
	{"name": "hanging_vines", "z": 3},
	{"name": "sidewalk_light", "z": -1},
	{"name": "sidewalk_road", "z": -1},
	{"name": "authority_emblem", "z": 3},
]

# Each entry is [tile name, map column, map row].  The exported tiles use a
# bottom-center visual origin, so pieces with different heights share a clean
# ground line while still snapping to the 64 px map grid.
const PLACEMENTS := [
	["sidewalk_road", 4, GROUND_ROW],
	["sidewalk_road", 13, GROUND_ROW],
	["sidewalk_road", 22, GROUND_ROW],
	["sidewalk_road", 31, GROUND_ROW],
	["sidewalk_road", 40, GROUND_ROW],
	["sidewalk_road", 49, GROUND_ROW],
	["walled_fence", 5, GROUND_ROW],
	["notice_board", 10, GROUND_ROW],
	["iron_gate", 17, GROUND_ROW],
	["authority_sign", 17, 5],
	["authority_entrance", 24, GROUND_ROW],
	["security_door", 25, GROUND_ROW],
	["barred_window", 27, 9],
	["wall_lamp", 29, 8],
	["hanging_vines", 30, 8],
	["tree", 33, GROUND_ROW],
	["broadcast_antenna", 38, GROUND_ROW],
	["authority_building", 41, GROUND_ROW],
	["frequency_poster", 42, 8],
	["one_voice_poster", 45, 7],
	["authority_emblem", 42, GROUND_ROW],
	["broadcast_signpost", 50, GROUND_ROW],
]


func _initialize() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Could not load %s" % SCENE_PATH)
		quit(1)
		return

	var root := packed.instantiate() as Node2D
	_remove_generated_nodes(root)
	var player := root.get_node_or_null("Player") as CanvasItem
	if player != null:
		player.z_index = 5

	var tile_set := _build_tile_set()
	if tile_set == null:
		root.queue_free()
		quit(1)
		return

	var layer := TileMapLayer.new()
	layer.name = "EnvironmentTileMap"
	layer.tile_set = tile_set
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	layer.y_sort_enabled = false
	root.add_child(layer)
	layer.owner = root

	var source_ids: Dictionary = tile_set.get_meta("source_ids")
	for placement in PLACEMENTS:
		var tile_name: String = placement[0]
		var cell := Vector2i(placement[1], placement[2])
		layer.set_cell(cell, source_ids[tile_name], Vector2i.ZERO, 0)

	_add_backdrop(root)
	_add_ground(root)
	_add_camera(root)

	var tile_set_error := ResourceSaver.save(tile_set, TILESET_PATH)
	if tile_set_error != OK:
		push_error("Could not save TileSet: %s" % error_string(tile_set_error))
		root.queue_free()
		quit(1)
		return
	var external_tile_set := ResourceLoader.load(
		TILESET_PATH, "TileSet", ResourceLoader.CACHE_MODE_IGNORE
	) as TileSet
	if external_tile_set == null:
		push_error("Could not reload external TileSet")
		root.queue_free()
		quit(1)
		return
	layer.tile_set = external_tile_set

	var output := PackedScene.new()
	var pack_error := output.pack(root)
	if pack_error != OK:
		push_error("Could not pack Day 1 scene: %s" % error_string(pack_error))
		root.queue_free()
		quit(1)
		return

	var save_error := ResourceSaver.save(output, SCENE_PATH)
	if save_error != OK:
		push_error("Could not save Day 1 scene: %s" % error_string(save_error))
		root.queue_free()
		quit(1)
		return

	print("Built Day 1 horizontal map with %d placed tiles." % PLACEMENTS.size())
	root.queue_free()
	quit()


func _build_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = TILE_SIZE
	var source_ids: Dictionary = {}

	for definition in TILE_DEFINITIONS:
		var tile_name: String = definition.name
		var texture_path := TILE_ROOT + tile_name + ".png"
		var texture := load(texture_path) as Texture2D
		if texture == null:
			push_error("Could not load tile texture %s" % texture_path)
			return null

		var source := TileSetAtlasSource.new()
		source.texture = texture
		source.texture_region_size = Vector2i(texture.get_width(), texture.get_height())
		source.create_tile(Vector2i.ZERO)
		var data := source.get_tile_data(Vector2i.ZERO, 0)
		data.texture_origin = Vector2i(0, int(texture.get_height() / 2.0))
		data.z_index = definition.z

		var source_id := tile_set.add_source(source)
		source_ids[tile_name] = source_id

	tile_set.set_meta("source_ids", source_ids)
	return tile_set


func _add_backdrop(root: Node2D) -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.position = Vector2(-512, -512)
	backdrop.size = Vector2(4608, 1536)
	backdrop.color = Color("17212b")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_index = -10
	root.add_child(backdrop)
	backdrop.owner = root


func _add_ground(root: Node2D) -> void:
	var body := StaticBody2D.new()
	body.name = "GroundCollision"
	body.collision_layer = 2
	body.collision_mask = 1
	body.position = Vector2(1600, 664)
	root.add_child(body)
	body.owner = root

	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(3456, 48)
	shape_node.shape = rectangle
	body.add_child(shape_node)
	shape_node.owner = root


func _add_camera(root: Node2D) -> void:
	var camera := Camera2D.new()
	camera.name = "HorizontalCamera"
	camera.set_script(CAMERA_SCRIPT)
	camera.set("target_path", NodePath("../Player"))
	camera.set("framing_offset", Vector2(240, -262))
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 3456
	camera.limit_bottom = 720
	root.add_child(camera)
	camera.owner = root


func _remove_generated_nodes(root: Node) -> void:
	for path in ["EnvironmentTileMap", "Backdrop", "GroundCollision", "HorizontalCamera"]:
		var node := root.get_node_or_null(path)
		if node != null:
			root.remove_child(node)
			node.free()
	var player := root.get_node_or_null("Player")
	if player != null and player.has_node("HorizontalCamera"):
		var legacy_camera := player.get_node("HorizontalCamera")
		player.remove_child(legacy_camera)
		legacy_camera.free()
