class_name Player
extends CharacterBody2D

signal fell
signal execute_plan_finished
signal foley_cue_played(cue: StringName, animation_frame: int)

@export var move_speed := 280.0
@export var acceleration := 900.0
@export var friction := 1250.0
@export var jump_velocity := -540.0
@export var fall_limit := 850.0
@export var allow_jump := false
@export var footstep_stream: AudioStream
@export var footstep_stream_alt_a: AudioStream
@export var footstep_stream_alt_b: AudioStream
@export var bag_search_stream: AudioStream
@export var rifle_assembly_stream: AudioStream
@export_range(0.5, 2.0, 0.01) var presentation_scale := 1.0

const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.12
const AUTHORED_MOVE_SPEED := 165.0

var controls_enabled := true
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _fall_reported := false
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var visual: Node2D = $Visual
@onready var animated_sprite: AnimatedSprite2D = $Visual/Sprite
@onready var shadow: Polygon2D = $Shadow
@onready var footstep_dust: CPUParticles2D = $FootstepDust
@onready var audio_listener: AudioListener2D = $AudioListener2D
@onready var footstep_player: AudioStreamPlayer2D = $Footsteps
@onready var bag_search_player: AudioStreamPlayer2D = $BagSearch
@onready var rifle_assembly_player: AudioStreamPlayer2D = $RifleAssembly

var _was_on_floor := false
var _alternate_step := false
var _footstep_cooldown := 0.0
var _footstep_variant_index := 0
var _footstep_variants: Array[AudioStream] = []
var _presentation_base_scale := Vector2.ONE

const FOOTSTEP_COOLDOWN := 0.56


func _ready() -> void:
	_presentation_base_scale = Vector2.ONE * presentation_scale
	visual.scale = _presentation_base_scale
	audio_listener.make_current()
	footstep_player.stream = footstep_stream
	for candidate in [footstep_stream, footstep_stream_alt_a, footstep_stream_alt_b]:
		if candidate != null:
			_footstep_variants.append(candidate)
	bag_search_player.stream = bag_search_stream
	rifle_assembly_player.stream = rifle_assembly_stream
	animated_sprite.frame_changed.connect(_on_animation_frame_changed)


func _exit_tree() -> void:
	footstep_player.stop()
	bag_search_player.stop()
	rifle_assembly_player.stop()


func _physics_process(delta: float) -> void:
	_footstep_cooldown = maxf(_footstep_cooldown - delta, 0.0)
	if not controls_enabled:
		if animated_sprite.animation == &"walk":
			animated_sprite.speed_scale = 1.0
			animated_sprite.play(&"idle")
		footstep_dust.emitting = false
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		if not is_on_floor():
			velocity.y += _gravity * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		return

	if is_on_floor():
		_coyote_timer = COYOTE_TIME
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
		velocity.y += _gravity * delta

	if allow_jump and Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

	if allow_jump and Input.is_action_just_released("jump") and velocity.y < jump_velocity * 0.45:
		velocity.y = jump_velocity * 0.45

	var direction := Input.get_axis("move_left", "move_right")
	var change_rate := acceleration if not is_zero_approx(direction) else friction
	velocity.x = move_toward(velocity.x, direction * move_speed, change_rate * delta)

	move_and_slide()
	_update_presentation(direction, delta)

	if is_on_floor() and not _was_on_floor:
		_play_landing_effect()
	_was_on_floor = is_on_floor()

	if global_position.y > fall_limit and not _fall_reported:
		_fall_reported = true
		fell.emit()


func reset_to(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	_fall_reported = false
	controls_enabled = true


func play_interaction() -> void:
	animated_sprite.speed_scale = 1.0
	animated_sprite.play(&"interact")
	var tween := create_tween()
	tween.tween_interval(0.45)
	tween.tween_callback(func():
		if is_instance_valid(animated_sprite):
			animated_sprite.play(&"idle")
	)


func play_door_interaction() -> void:
	controls_enabled = false
	velocity.x = 0.0
	animated_sprite.speed_scale = 1.0
	animated_sprite.play(&"interact")
	visual.rotation = 0.0
	footstep_dust.emitting = false
	footstep_player.stop()


func play_execute_plan() -> void:
	controls_enabled = false
	velocity = Vector2.ZERO
	animated_sprite.speed_scale = 1.0
	animated_sprite.flip_h = false
	visual.rotation = 0.0
	animated_sprite.play(&"execute")
	await animated_sprite.animation_finished
	animated_sprite.play(&"aim")
	execute_plan_finished.emit()


func _on_animation_frame_changed() -> void:
	if animated_sprite.animation == &"walk" and animated_sprite.frame == 0:
		if controls_enabled and is_on_floor() and absf(velocity.x) > 8.0 and _footstep_cooldown <= 0.0:
			_play_next_footstep()
	elif animated_sprite.animation == &"execute":
		if animated_sprite.frame == 1:
			_play_foley(bag_search_player, &"bag_search")
		elif animated_sprite.frame == 3:
			_play_foley(rifle_assembly_player, &"rifle_assembly")


func _play_next_footstep() -> void:
	if _footstep_variants.is_empty():
		return
	footstep_player.stream = _footstep_variants[_footstep_variant_index]
	_footstep_variant_index = (_footstep_variant_index + 1) % _footstep_variants.size()
	_alternate_step = not _alternate_step
	footstep_player.pitch_scale = 1.025 if _alternate_step else 0.975
	_footstep_cooldown = FOOTSTEP_COOLDOWN
	_play_foley(footstep_player, &"footstep")


func _play_foley(audio_player: AudioStreamPlayer2D, cue: StringName) -> void:
	if audio_player.stream == null:
		return
	audio_player.stop()
	audio_player.play()
	foley_cue_played.emit(cue, animated_sprite.frame)


func _update_presentation(direction: float, delta: float) -> void:
	var moving := absf(velocity.x) > 8.0 and controls_enabled
	if moving:
		animated_sprite.speed_scale = move_speed / AUTHORED_MOVE_SPEED
		if animated_sprite.animation != &"walk":
			animated_sprite.play(&"walk")
	else:
		animated_sprite.speed_scale = 1.0
		if animated_sprite.animation != &"idle" and animated_sprite.animation != &"interact":
			animated_sprite.play(&"idle")

	if not is_zero_approx(direction):
		animated_sprite.flip_h = direction < 0.0

	var target_rotation := clampf(velocity.x / move_speed, -1.0, 1.0) * 0.025
	visual.rotation = lerpf(visual.rotation, target_rotation, 1.0 - exp(-9.0 * delta))
	shadow.scale.x = lerpf(shadow.scale.x, 1.18 if moving else 1.0, 1.0 - exp(-8.0 * delta))
	footstep_dust.emitting = moving and is_on_floor()


func _play_landing_effect() -> void:
	var tween := create_tween()
	visual.scale = _presentation_base_scale * Vector2(1.07, 0.93)
	tween.tween_property(visual, "scale", _presentation_base_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
