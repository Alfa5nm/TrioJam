extends SceneTree

const SCENE_PATH := "res://scenes/Day 1/Side Scroll Section/Side_Scroll Day 1.tscn"
const PREVIEW_IDLE := "res://tests/artifacts/day1_birds_idle.png"
const PREVIEW_TAKEOFF := "res://tests/artifacts/day1_birds_takeoff.png"

var failures := 0


func _initialize() -> void:
	print("DAY1_BIRDS_TEST_START")
	_run.call_deferred()


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "Day 1 scene loads with the bird encounter")
	if packed == null:
		quit(1)
		return

	var level := packed.instantiate()
	root.add_child(level)
	for _frame in 45:
		await physics_frame

	var flock := level.get_node_or_null("PavementBirdFlock") as PavementBirdFlock
	var player := level.get_node_or_null("Player") as Player
	_check(flock != null, "pavement bird flock is instanced")
	_check(player != null, "player is available for the proximity trigger")
	_check(flock != null and not flock.has_flown and flock.visible, "birds begin grounded and visible")
	_check(flock != null and flock.birds.animation == &"idle", "birds begin on the pavement pose")
	_check(flock != null and flock.birds.sprite_frames.get_frame_count(&"idle") == 4, "idle loop has four varied animation frames")
	_check(flock != null and flock.birds.sprite_frames.get_frame_count(&"takeoff") == 4, "takeoff uses four continuity-safe animation frames")
	flock.play_idle_coo()
	await process_frame
	_check(flock.coo_player.playing and flock.coo_player.stream != null, "idle pigeon coo plays")
	player.global_position = flock.global_position + Vector2(-260, 63)
	player.velocity = Vector2.ZERO
	for _frame in 35:
		await physics_frame
	_check(not flock.has_flown, "idle preview approach remains outside the trigger")

	if DisplayServer.get_name() != "headless":
		_save_preview(PREVIEW_IDLE)

	var start_position := flock.position
	player.global_position = flock.global_position + Vector2(-90, 42)
	player.velocity = Vector2.ZERO
	for _frame in 4:
		await physics_frame
	_check(flock.has_flown, "approaching player triggers the flock")
	_check(flock.birds.animation == &"takeoff", "trigger plays the stepped takeoff animation")
	_check(flock.flap_player.playing and flock.flap_player.stream != null, "takeoff plays synchronized wing flaps")

	for _frame in 18:
		await process_frame
	_check(flock.position.x > start_position.x and flock.position.y < start_position.y, "flock moves up and away")
	if DisplayServer.get_name() != "headless":
		_save_preview(PREVIEW_TAKEOFF)

	while flock.visible:
		await process_frame
	_check(not flock.monitoring and flock.has_flown, "encounter disables itself after one use")

	level.queue_free()
	flock = null
	player = null
	level = null
	packed = null
	for _frame in 3:
		await process_frame
	if failures == 0:
		print("DAY1_BIRDS_TEST_PASS")
	quit(failures)


func _save_preview(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/artifacts"))
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(path))
	_check(error == OK, "rendered preview saves: %s" % path.get_file())


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
