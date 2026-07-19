class_name Day2DispersalActor
extends AnimatedSprite2D

signal run_started
signal run_finished

@export var strip: Texture2D
@export var default_pose: Texture2D
@export var blocked_flip_h := false
@export var flee_direction := 1.0
@export_range(0.0, 1.0, 0.01) var start_delay := 0.0
@export_range(120.0, 520.0, 5.0) var flee_speed := 285.0
@export_range(0.05, 0.5, 0.01) var startled_hold := 0.16
@export_range(450.0, 1400.0, 10.0) var travel_distance := 820.0
@export var barrier_x := -1.0

var _running := false
var _origin := Vector2.ZERO
var _elapsed := 0.0
var _locked_scale := Vector2.ONE
var _frame_bounds: Array[Rect2i] = []
var _default_bounds := Rect2i(0, 0, 384, 384)
var _pavement_y := 0.0


func _ready() -> void:
	_locked_scale = scale
	# Scene Y values describe the pavement surface, not the center of the padded
	# 384px atlas cell.
	_pavement_y = position.y
	_build_frames()
	frame = 0
	frame_changed.connect(_apply_frame_alignment)
	_apply_frame_alignment()
	_origin = position
	stop()


func begin_dispersal() -> void:
	if _running:
		return
	_running = true
	_elapsed = 0.0
	animation = &"startled"
	flip_h = false
	frame = 0
	_apply_frame_alignment()
	stop()
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	if not _running:
		return
	await get_tree().create_timer(startled_hold).timeout
	if not _running:
		return
	play(&"run")
	run_started.emit()


func reset_actor() -> void:
	_running = false
	position = _origin
	scale = _locked_scale
	modulate.a = 1.0
	visible = true
	flip_h = false
	animation = &"startled"
	frame = 0
	_apply_frame_alignment()
	stop()


func _process(delta: float) -> void:
	# Animation frames must never alter the actor's authored world scale.  The
	# generated poses have different transparent margins, so allowing their
	# visual bounds to drive the transform reads as a size pulse.
	scale = _locked_scale
	if not _running or not is_playing():
		return
	_elapsed += delta
	position.x += flee_direction * flee_speed * delta
	# Keep the feet pinned to the pavement.  The stepped pose animation already
	# supplies enough vertical energy without moving the whole actor off-ground.
	position.y = _origin.y
	if flee_direction > 0.0 and barrier_x > 0.0 and position.x >= barrier_x:
		position.x = barrier_x
		_running = false
		modulate.a = 1.0
		if default_pose != null and sprite_frames.has_animation(&"blocked"):
			animation = &"blocked"
			flip_h = blocked_flip_h
		else:
			frame = 0
		stop()
		_apply_frame_alignment()
		run_finished.emit()
		return
	var travelled := absf(position.x - _origin.x)
	if travelled > travel_distance * 0.78:
		modulate.a = 1.0 - clampf((travelled - travel_distance * 0.78) / (travel_distance * 0.22), 0.0, 1.0)
	if travelled >= travel_distance:
		_running = false
		visible = false
		stop()
		run_finished.emit()


func _build_frames() -> void:
	var library := SpriteFrames.new()
	library.remove_animation(&"default")
	library.add_animation(&"startled")
	library.set_animation_loop(&"startled", false)
	library.set_animation_speed(&"startled", 1.0)
	library.add_animation(&"run")
	library.set_animation_loop(&"run", true)
	library.set_animation_speed(&"run", 7.5)
	if default_pose != null:
		library.add_animation(&"blocked")
		library.set_animation_loop(&"blocked", false)
		library.set_animation_speed(&"blocked", 1.0)
		library.add_frame(&"blocked", default_pose)
		var default_image := default_pose.get_image()
		if default_image != null and not default_image.is_empty():
			var default_alpha_rect := default_image.get_used_rect()
			if default_alpha_rect.size.x > 0 and default_alpha_rect.size.y > 0:
				_default_bounds = default_alpha_rect
	_frame_bounds.clear()
	var strip_image := strip.get_image() if strip != null else null
	for index in range(3):
		var atlas := AtlasTexture.new()
		atlas.atlas = strip
		atlas.region = Rect2(index * 384.0, 0.0, 384.0, 384.0)
		var used_rect := Rect2i(0, 0, 384, 384)
		if strip_image != null and not strip_image.is_empty():
			var cell := strip_image.get_region(Rect2i(index * 384, 0, 384, 384))
			var alpha_rect := cell.get_used_rect()
			if alpha_rect.size.x > 0 and alpha_rect.size.y > 0:
				used_rect = alpha_rect
		_frame_bounds.append(used_rect)
		if index == 0:
			library.add_frame(&"startled", atlas)
		else:
			library.add_frame(&"run", atlas)
	sprite_frames = library


func _apply_frame_alignment() -> void:
	if animation == &"blocked" and default_pose != null:
		_apply_bounds_alignment(_default_bounds)
		return
	if _frame_bounds.is_empty():
		return
	var source_index := 0 if animation == &"startled" else frame + 1
	source_index = clampi(source_index, 0, _frame_bounds.size() - 1)
	_apply_bounds_alignment(_frame_bounds[source_index])


func _apply_bounds_alignment(bounds: Rect2i) -> void:
	var visual_bottom := float(bounds.position.y + bounds.size.y)
	# Keep the atlas unshifted and solve the node center from the frame's actual
	# opaque bottom. This avoids double-applying AnimatedSprite2D's centered-cell
	# offset, which previously left the crowd hovering above the pavement.
	offset = Vector2.ZERO
	scale = _locked_scale
	position.y = _pavement_y - (visual_bottom - 192.0) * absf(_locked_scale.y)
