class_name ProtestCrowd
extends Node2D

signal dispersal_started
signal dispersal_finished

enum State {
	CHANTING,
	DISPERSING,
	DISPERSED,
}

@export_range(0.08, 1.0, 0.01) var frame_interval := 0.3
@export var auto_disperse_on_player_approach := true
@export_range(100.0, 1200.0, 10.0) var trigger_radius := 480.0
@export_range(80.0, 500.0, 5.0) var horizontal_flee_speed := 285.0
@export_range(20.0, 220.0, 5.0) var south_flee_speed := 82.0
@export_range(0.0, 0.5, 0.01) var actor_stagger := 0.09
@export_range(0.1, 1.0, 0.01) var panic_hold := 0.34
@export_range(400.0, 1600.0, 10.0) var fade_start_distance := 760.0
@export_range(500.0, 2000.0, 10.0) var despawn_distance := 980.0

const FRAME_SEQUENCE := [0, 1, 2, 3, 2, 1]
const PANIC_RUN_INTERVAL := 0.11
const PANIC_TEXTURES := {
	"sign_male": preload("res://assets/art/Day1 Scene 1/protest/sign_male-panic-v1.png"),
	"fist_chanter": preload("res://assets/art/Day1 Scene 1/protest/fist_chanter-panic-v1.png"),
	"sign_female": preload("res://assets/art/Day1 Scene 1/protest/sign_female-panic-v1.png"),
	"megaphone_worker": preload("res://assets/art/Day1 Scene 1/protest/megaphone_worker-panic-v1.png"),
}

var state := State.CHANTING
var _elapsed := 0.0
var _dispersal_elapsed := 0.0
var _sprites: Array[Sprite2D] = []
var _shadows: Array[Sprite2D] = []
var _start_positions: Array[Vector2] = []
var _start_scales: Array[Vector2] = []
var _start_modulates: Array[Color] = []
var _chant_textures: Array[Texture2D] = []
var _flee_directions: Array[Vector2] = []
var _player: Player

@onready var crowd_ambience: AudioStreamPlayer2D = $CrowdAmbience


func _ready() -> void:
	_player = get_parent().get_node_or_null("Player") as Player
	for node in find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		if sprite == null:
			continue
		if sprite.hframes == 4:
			_sprites.append(sprite)
			_start_positions.append(sprite.position)
			_start_scales.append(sprite.scale)
			_start_modulates.append(sprite.modulate)
			_chant_textures.append(sprite.texture)
			var horizontal_sign := -1.0 if sprite.position.x < 0.0 else 1.0
			_flee_directions.append(Vector2(horizontal_sign, south_flee_speed / horizontal_flee_speed))
		else:
			_shadows.append(sprite)

	if crowd_ambience.stream is AudioStreamMP3:
		(crowd_ambience.stream as AudioStreamMP3).loop = true
	if crowd_ambience.stream != null:
		crowd_ambience.play()


func _process(delta: float) -> void:
	match state:
		State.CHANTING:
			_update_chant(delta)
			_check_auto_dispersal()
		State.DISPERSING:
			_update_dispersal(delta)


func disperse(_threat_position := Vector2.ZERO) -> void:
	if state != State.CHANTING:
		return
	state = State.DISPERSING
	_dispersal_elapsed = 0.0
	for index in range(_sprites.size()):
		var sprite := _sprites[index]
		sprite.texture = _panic_texture_for(_chant_textures[index])
		sprite.frame = 0
		sprite.scale.x = absf(_start_scales[index].x) * _flee_directions[index].x
	dispersal_started.emit()


func reset_crowd() -> void:
	state = State.CHANTING
	_elapsed = 0.0
	_dispersal_elapsed = 0.0
	for index in range(_sprites.size()):
		var sprite := _sprites[index]
		sprite.texture = _chant_textures[index]
		sprite.position = _start_positions[index]
		sprite.scale = _start_scales[index]
		sprite.modulate = _start_modulates[index]
		sprite.visible = true
	for shadow in _shadows:
		shadow.modulate.a = 1.0
		shadow.visible = true
	crowd_ambience.volume_db = -5.0
	if crowd_ambience.stream != null and not crowd_ambience.playing:
		crowd_ambience.play()


func _update_chant(delta: float) -> void:
	_elapsed += delta
	for index in range(_sprites.size()):
		var rate_variation := 1.0 + float(index % 3) * 0.08
		var step := int(floor(_elapsed * rate_variation / frame_interval))
		var phase := (step + index * 2) % FRAME_SEQUENCE.size()
		_sprites[index].frame = FRAME_SEQUENCE[phase]


func _check_auto_dispersal() -> void:
	if not auto_disperse_on_player_approach or _player == null or not _player.controls_enabled:
		return
	var separation := _player.global_position - global_position
	if absf(separation.x) <= trigger_radius and absf(separation.y) <= 260.0:
		disperse(_player.global_position)


func _update_dispersal(delta: float) -> void:
	_dispersal_elapsed += delta
	var active_count := 0
	var furthest_progress := 0.0
	for index in range(_sprites.size()):
		var sprite := _sprites[index]
		var local_time := _dispersal_elapsed - float(index) * actor_stagger
		if local_time < 0.0:
			active_count += 1
			continue
		if local_time < 0.16:
			sprite.frame = 0
			active_count += 1
			continue
		if local_time < panic_hold:
			sprite.frame = 1
			active_count += 1
			continue

		var run_time := local_time - panic_hold
		sprite.frame = 2 + int(floor(run_time / PANIC_RUN_INTERVAL)) % 2
		var acceleration := clampf(run_time / 0.32, 0.0, 1.0)
		var velocity := Vector2(
			_flee_directions[index].x * horizontal_flee_speed,
			south_flee_speed
		) * ease(acceleration, 0.65)
		sprite.position += velocity * delta

		var traveled := sprite.position.distance_to(_start_positions[index])
		furthest_progress = maxf(furthest_progress, traveled)
		if traveled > fade_start_distance:
			var fade_range := maxf(despawn_distance - fade_start_distance, 1.0)
			var alpha := 1.0 - clampf((traveled - fade_start_distance) / fade_range, 0.0, 1.0)
			sprite.modulate.a = _start_modulates[index].a * alpha
		if traveled >= despawn_distance:
			sprite.visible = false
		else:
			active_count += 1

	var shadow_alpha := 1.0 - clampf(furthest_progress / 360.0, 0.0, 1.0)
	for shadow in _shadows:
		shadow.modulate.a = shadow_alpha

	crowd_ambience.volume_db = lerpf(-5.0, -32.0, clampf(furthest_progress / despawn_distance, 0.0, 1.0))
	if active_count == 0:
		state = State.DISPERSED
		crowd_ambience.stop()
		dispersal_finished.emit()


func _panic_texture_for(chant_texture: Texture2D) -> Texture2D:
	var path := chant_texture.resource_path
	for actor_name in PANIC_TEXTURES:
		if path.contains(actor_name):
			return PANIC_TEXTURES[actor_name]
	return chant_texture
