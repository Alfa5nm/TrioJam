class_name ScopedTargetScene
extends Node2D

signal wrong_target_shot(subject_id: StringName, response: String)
signal target_confirmed

@export var auto_advance_to_broadcast := true

const OCCUPANT_SHEET := preload("res://assets/art/Scene 2/office-occupants-v2.png")
const CELL_SIZE := Vector2(384, 384)
const WRONG_TARGET_LINES := [
	"Not this one.",
	"AGHH — not this one either.",
	"Not the guy I want dead today.",
	"Wrong silhouette. Keep searching.",
]

var resolved := false
var shots_taken := 0
var wrong_shots := 0
var last_shot_subject: StringName = &""
var _aim_target := Vector2(640, 360)
var _aim_display := Vector2(640, 360)
var _elapsed := 0.0

@onready var target_actor: AnimatedSprite2D = $Occupants/Target
@onready var typist_actor: AnimatedSprite2D = $Occupants/Typist
@onready var clerk_actor: AnimatedSprite2D = $Occupants/Clerk
@onready var employee_actor: AnimatedSprite2D = $Occupants/Employee
@onready var scope_mask: ColorRect = $ScopeUI/ScopeMask
@onready var reticle: ScopeReticle = $ScopeUI/Reticle
@onready var feedback: Label = $ScopeUI/Feedback
@onready var shots_label: Label = $ScopeUI/Shots
@onready var fade: ColorRect = $ScopeUI/Fade
@onready var wind: AudioStreamPlayer = $Wind


func _ready() -> void:
	_setup_actor(target_actor, 0, &"target_idle", 2.0)
	_setup_actor(typist_actor, 1, &"typist_idle", 3.0)
	_setup_actor(clerk_actor, 2, &"clerk_idle", 2.2)
	_setup_actor(employee_actor, 3, &"employee_idle", 2.5)
	_set_looping(wind.stream, true)
	wind.play()
	feedback.text = "Find the silver-haired official on the balcony."
	_update_shots_label()
	fade.modulate.a = 1.0
	create_tween().tween_property(fade, "modulate:a", 0.0, 0.55)
	_set_scope_position(_aim_display)


func _exit_tree() -> void:
	wind.stop()
	_set_looping(wind.stream, false)
	wind.stream = null


func _process(delta: float) -> void:
	_elapsed += delta
	if resolved:
		return
	var breath_sway := Vector2(sin(_elapsed * 1.45) * 2.4, cos(_elapsed * 1.1) * 1.8)
	_aim_display = _aim_display.lerp(_aim_target + breath_sway, 1.0 - exp(-13.0 * delta))
	_set_scope_position(_aim_display)


func _unhandled_input(event: InputEvent) -> void:
	if resolved:
		return
	if event is InputEventMouseMotion:
		_aim_target = _clamp_aim(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		attempt_shot_at(_aim_display)


func attempt_shot_at(screen_position: Vector2) -> bool:
	if resolved:
		return false
	shots_taken += 1
	_update_shots_label()
	var subject_id := _subject_at(screen_position)
	last_shot_subject = subject_id
	if subject_id == &"target":
		_resolve_target()
		return true
	if subject_id != &"":
		var response: String = WRONG_TARGET_LINES[wrong_shots % WRONG_TARGET_LINES.size()]
		wrong_shots += 1
		feedback.text = response
		wrong_target_shot.emit(subject_id, response)
		_play_rejection_feedback()
	else:
		feedback.text = "Steady. Identify a person before firing."
		_play_rejection_feedback()
	return false


func _subject_at(position: Vector2) -> StringName:
	if Rect2(1000, 315, 235, 290).has_point(position):
		return &"target"
	if Rect2(95, 300, 235, 250).has_point(position):
		return &"typist"
	if Rect2(385, 300, 255, 250).has_point(position):
		return &"clerk"
	if Rect2(660, 290, 205, 275).has_point(position):
		return &"employee"
	return &""


func _resolve_target() -> void:
	resolved = true
	feedback.text = "TARGET CONFIRMED"
	reticle.confirmed = true
	target_actor.pause()
	var impact := create_tween()
	impact.tween_property(target_actor, "modulate", Color(1.45, 1.35, 1.15, 1), 0.06)
	impact.tween_property(target_actor, "modulate", Color(0.72, 0.72, 0.78, 0.42), 0.22)
	target_confirmed.emit()
	if auto_advance_to_broadcast:
		_advance_to_broadcast()


func _advance_to_broadcast() -> void:
	await get_tree().create_timer(0.9).timeout
	if not is_inside_tree():
		return
	var transition := create_tween()
	transition.tween_property(fade, "modulate:a", 1.0, 0.5)
	await transition.finished
	get_tree().change_scene_to_file("res://scenes/gameplay/broadcast_interface.tscn")


func _play_rejection_feedback() -> void:
	var original_position := reticle.position
	var shake := create_tween()
	shake.tween_property(reticle, "position", original_position + Vector2(8, -3), 0.04)
	shake.tween_property(reticle, "position", original_position + Vector2(-6, 2), 0.04)
	shake.tween_property(reticle, "position", original_position, 0.06)


func _setup_actor(actor: AnimatedSprite2D, row: int, animation_name: StringName, speed: float) -> void:
	var frames := SpriteFrames.new()
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, true)
	frames.set_animation_speed(animation_name, speed)
	for column in 4:
		var frame := AtlasTexture.new()
		frame.atlas = OCCUPANT_SHEET
		frame.region = Rect2(Vector2(column, row) * CELL_SIZE, CELL_SIZE)
		frames.add_frame(animation_name, frame)
	actor.sprite_frames = frames
	actor.play(animation_name)


func _set_scope_position(position: Vector2) -> void:
	reticle.position = position - reticle.size * 0.5
	(scope_mask.material as ShaderMaterial).set_shader_parameter("scope_center", position)


func _clamp_aim(position: Vector2) -> Vector2:
	return Vector2(clampf(position.x, 36.0, 1244.0), clampf(position.y, 48.0, 684.0))


func _update_shots_label() -> void:
	shots_label.text = "SHOTS  %02d" % shots_taken


func _set_looping(stream: AudioStream, enabled: bool) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = enabled
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = enabled
