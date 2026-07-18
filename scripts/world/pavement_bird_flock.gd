class_name PavementBirdFlock
extends Area2D

signal startled
signal escaped

@export var flight_offset := Vector2(520, -360)
@export_range(0.4, 3.0, 0.05) var flight_duration := 1.15
@export_range(4, 30, 1) var motion_steps := 14
@export var coo_stream_a: AudioStream
@export var coo_stream_b: AudioStream
@export var coo_stream_c: AudioStream
@export var flap_stream_a: AudioStream
@export var flap_stream_b: AudioStream

@onready var birds: AnimatedSprite2D = $Birds
@onready var trigger: CollisionShape2D = $Trigger
@onready var coo_player: AudioStreamPlayer2D = $Coo
@onready var flap_player: AudioStreamPlayer2D = $Flap

var has_flown := false
var _flight_elapsed := 0.0
var _flight_start := Vector2.ZERO
var _idle_coo_timer := 0.0
var _flap_variant := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_idle_coo_timer = _rng.randf_range(2.8, 5.5)
	body_entered.connect(_on_body_entered)
	birds.frame_changed.connect(_on_bird_frame_changed)


func startle() -> void:
	if has_flown:
		return
	has_flown = true
	set_deferred("monitoring", false)
	trigger.set_deferred("disabled", true)
	_flight_elapsed = 0.0
	_flight_start = position
	coo_player.stop()
	birds.play(&"takeoff")
	_play_flap()
	startled.emit()


func _process(delta: float) -> void:
	if not has_flown:
		_idle_coo_timer -= delta
		if _idle_coo_timer <= 0.0:
			play_idle_coo()
		return

	_flight_elapsed += delta
	var progress := clampf(_flight_elapsed / flight_duration, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 2.0)
	var stepped := floorf(eased * float(motion_steps)) / float(motion_steps)
	if progress >= 1.0:
		stepped = 1.0
	position = _flight_start.lerp(_flight_start + flight_offset, stepped)
	modulate.a = 1.0 - clampf((progress - 0.68) / 0.32, 0.0, 1.0)

	if progress >= 1.0:
		visible = false
		set_process(false)
		escaped.emit()


func play_idle_coo() -> void:
	var choices: Array[AudioStream] = []
	for stream in [coo_stream_a, coo_stream_b, coo_stream_c]:
		if stream != null:
			choices.append(stream)
	if choices.is_empty():
		return
	coo_player.stream = choices[_rng.randi_range(0, choices.size() - 1)]
	coo_player.pitch_scale = _rng.randf_range(0.96, 1.04)
	coo_player.play()
	_idle_coo_timer = _rng.randf_range(4.0, 8.0)


func _play_flap() -> void:
	_flap_variant = not _flap_variant
	flap_player.stream = flap_stream_b if _flap_variant else flap_stream_a
	if flap_player.stream == null:
		return
	flap_player.pitch_scale = _rng.randf_range(0.96, 1.05)
	flap_player.play()


func _on_bird_frame_changed() -> void:
	if birds.animation == &"takeoff" and birds.frame in [1, 3]:
		_play_flap()


func _on_body_entered(body: Node) -> void:
	if body is Player:
		startle()
