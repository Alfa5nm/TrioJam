class_name Day3ScopeScene
extends Node2D

signal target_confirmed
signal resolution_sequence_finished

const FINALE_SCENE := "res://scenes/Day 3/day3_finale.tscn"
const TARGET_RECT := Rect2(430, 35, 390, 625)

@export var auto_advance_to_finale := true
@export var play_intro_on_ready := true
@export_range(0.01, 1.0, 0.01) var cinematic_timing_scale := 1.0

var resolved := false
var shots_taken := 0
var aim_enabled := false
var _aim_target := Vector2(640, 340)
var _aim_display := Vector2(640, 340)
var _elapsed := 0.0

@onready var scope_mask: ColorRect = $ScopeUI/ScopeMask
@onready var reticle: ScopeReticle = $ScopeUI/Reticle
@onready var fade: ColorRect = $ScopeUI/Fade
@onready var red_flash: ColorRect = $ScopeUI/RedFlash
@onready var wind: AudioStreamPlayer = $Wind
@onready var tension: AudioStreamPlayer = $Tension
@onready var pistol_shot: AudioStreamPlayer = $SniperShot
@onready var off_target_error: AudioStreamPlayer = $OffTargetError
@onready var dialogue: CinematicDialogue = $CinematicDialogue
@onready var pre_scope: CanvasLayer = $PreScope
@onready var gun_cg: TextureRect = $PreScope/GunCG
@onready var pre_scope_black: ColorRect = $PreScope/Black
@onready var shot_particles: CPUParticles2D = $ScopeUI/ShotParticles


func _ready() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.save_checkpoint("day3_scope")
	_set_looping(wind.stream, true)
	_set_looping(tension.stream, true)
	wind.play()
	tension.play()
	fade.modulate.a = 1.0
	create_tween().tween_property(fade, "modulate:a", 0.0, 0.55)
	_set_scope_position(_aim_display)
	if play_intro_on_ready:
		_play_scope_intro()
	else:
		pre_scope.visible = false
		aim_enabled = true


func _exit_tree() -> void:
	wind.stop()
	tension.stop()
	_set_looping(wind.stream, false)
	_set_looping(tension.stream, false)


func _process(delta: float) -> void:
	_elapsed += delta
	if resolved or not aim_enabled:
		return
	var breath_sway := Vector2(sin(_elapsed * 1.5) * 2.2, cos(_elapsed * 1.15) * 1.7)
	_aim_display = _aim_display.lerp(_aim_target + breath_sway, 1.0 - exp(-13.0 * delta))
	_set_scope_position(_aim_display)


func _unhandled_input(event: InputEvent) -> void:
	if resolved or not aim_enabled:
		return
	if event is InputEventMouseMotion:
		_aim_target = _clamp_aim(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		attempt_shot_at(_aim_display)


func attempt_shot_at(screen_position: Vector2) -> bool:
	if resolved or not aim_enabled:
		return false
	shots_taken += 1
	if TARGET_RECT.has_point(screen_position):
		_resolve_target()
		return true
	off_target_error.play()
	_show_scope_dialogue("Steady. Keep the Peace Leader in the scope.")
	_play_rejection_feedback()
	return false


func _resolve_target() -> void:
	resolved = true
	reticle.confirmed = true
	target_confirmed.emit()
	_play_resolution_sequence()


func _play_scope_intro() -> void:
	pre_scope.visible = true
	gun_cg.visible = true
	pre_scope_black.visible = false
	await dialogue.show_line_at("Choices… choices…", Vector2(640, 650), 0.7, true)
	await dialogue.show_line_at("These last few months have taught me one thing. I am just a pawn .", Vector2(640, 650), 0.9, true)
	await dialogue.show_line_at("A meaningless replaceable cog. However, the person that I’m about to shoot isn’t.", Vector2(640, 650), 1.0, true)
	await dialogue.show_line_at("…Why does the people in this country matter to me anyway? If none of my choices mattered, the country’s choices shouldn’t either.", Vector2(640, 650), 1.15, true)
	await dialogue.show_line_at("At least… in this path, I get to live.", Vector2(640, 650), 0.85, true)
	gun_cg.visible = false
	pre_scope_black.visible = true
	await dialogue.show_line_at("Fire.", Vector2(640, 650), 0.75, true)
	if is_inside_tree():
		pre_scope.visible = false
		aim_enabled = true


func _show_scope_dialogue(response: String) -> void:
	if dialogue.is_presenting:
		dialogue.hide_immediately()
	await dialogue.show_line_at(response, Vector2(640, 650), 0.8)


func _play_resolution_sequence() -> void:
	if dialogue.is_presenting:
		dialogue.hide_immediately()
	await dialogue.show_line_at("Peace begins when we refuse to become—", Vector2(640, 650), 0.95)
	var ambience_fade := create_tween().set_parallel(true)
	ambience_fade.tween_property(tension, "volume_db", -40.0, _duration(0.24))
	ambience_fade.tween_property(wind, "volume_db", -28.0, _duration(0.24))
	pistol_shot.play()
	shot_particles.restart()
	shot_particles.emitting = true
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method(&"start_day3_route_music"):
		session.start_day3_route_music(&"shoot")
	red_flash.color.a = 0.92
	create_tween().tween_property(red_flash, "color:a", 0.0, _duration(0.28))
	Engine.time_scale = 0.08
	await get_tree().create_timer(0.045, true, false, true).timeout
	Engine.time_scale = 1.0
	var transition := create_tween()
	transition.tween_interval(_duration(0.12))
	transition.tween_property(fade, "modulate:a", 1.0, _duration(0.38))
	await transition.finished
	resolution_sequence_finished.emit()
	if auto_advance_to_finale:
		_advance_to_finale()


func _advance_to_finale() -> void:
	# Keep this scene alive until the pistol transient and its natural tail finish.
	var audio_tail := 0.65
	if pistol_shot.stream != null:
		audio_tail = maxf(audio_tail, pistol_shot.stream.get_length() - pistol_shot.get_playback_position() + 0.12)
	await get_tree().create_timer(_duration(audio_tail)).timeout
	if not is_inside_tree():
		return
	var transition := get_node_or_null("/root/SceneTransition")
	if transition != null and not transition.busy:
		transition.transition_to(FINALE_SCENE, false)
	else:
		get_tree().change_scene_to_file(FINALE_SCENE)


func _set_scope_position(position: Vector2) -> void:
	reticle.position = position - reticle.size * 0.5
	(scope_mask.material as ShaderMaterial).set_shader_parameter("scope_center", position)


func _clamp_aim(position: Vector2) -> Vector2:
	return Vector2(clampf(position.x, 36.0, 1244.0), clampf(position.y, 48.0, 684.0))


func _play_rejection_feedback() -> void:
	var original_position := reticle.position
	var shake := create_tween()
	shake.tween_property(reticle, "position", original_position + Vector2(8, -3), 0.04)
	shake.tween_property(reticle, "position", original_position + Vector2(-6, 2), 0.04)
	shake.tween_property(reticle, "position", original_position, 0.06)


func _set_looping(stream: AudioStream, enabled: bool) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = enabled
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = enabled


func _duration(seconds: float) -> float:
	return maxf(seconds * cinematic_timing_scale, 0.001)
