class_name Day1EndingController
extends Node2D

signal ending_started
signal route_applied(checkpoint_route: StringName, seedless_route: StringName)
signal door_sequence_started
signal ending_finished

const CHECKPOINT_REPORT := &"day1_checkpoint_killing"
const SEEDLESS_REPORT := &"day1_seedless_fruit"
const TRUTHFUL := &"truthful"
const PROPAGANDA := &"propaganda"
const FINAL_ART := preload("res://assets/art/Day1 Scene 1/Day 1 ending/day1end.png")
const NIGHT_AMBIENCE := preload("res://assets/audio/day1/ending/night-ambience.wav")
const TRUTH_AMBIENCE := preload("res://assets/audio/day1/ending/truth-memorial.wav")
const PROPAGANDA_AMBIENCE := preload("res://assets/audio/day1/ending/propaganda-patrol.wav")
const ROOM_PULSE := preload("res://assets/audio/day1/ending/room-pulse.wav")
const DOOR_LATCH := preload("res://assets/audio/day1/ending/door-latch.wav")
const BLIP := preload("res://assets/audio/day1/cutscene/tense-dialogue-blip.wav")
const LEAF_ZONE := preload("res://scenes/world/day1_leaf_drift_zone.tscn")
const DUST_ZONE := preload("res://scenes/world/day1_dust_mote_zone.tscn")

const TRUTH_PROTEST_LINES: Array[String] = [
	"He was unarmed!",
	"Disperse immediately!",
	"Will you shoot all of us too?",
]
const TRUTH_ELDERLY_LINES: Array[String] = [
	"I knew that boy.",
	"The one who was killed?",
	"He printed posters at his father’s shop.",
	"Now they speak about him as though he entered the street carrying a war.",
]
const PROPAGANDA_ARGUMENT_LINES: Array[String] = [
	"Did you hear? An Opposition man attacked a soldier.",
	"That’s not what fucking happened. They’re lying!",
	"They showed photographs!",
	"God, just how dumb can you be to believe that so easily?!",
]
const PROPAGANDA_WITNESS_LINES: Array[String] = [
	"…He shot a man… with empty hands.",
	"Empty hands can still be dangerous, you have no idea what they can do.",
]
const COMMON_HUNGER := "That evening, the city learned that hunger does not always begin with an empty market, sometimes it begins with how farmers were denied access to the most basic rights to their labor."
const TRUTH_REPORT_2 := "However… The farmers had not lost their harvest yet. They were only losing the right to grow the next one. By showing the truth, I gave the city time to see what was coming."
const PROPAGANDA_REPORT_2 := "It sounded harmless to the common people. Convenient, even. No one asked what happens when a farmer must purchase permission to begin every season. The lie worked because its consequences had not arrived yet."
const COMMON_FRUIT := "For now, the fruit was sweet. By the time it became scarce, the city would have forgotten who had planted the idea."
const COUCH_LINES: Array[String] = [
	"Once upon a time, I never knew fear like this. After what that silver-haired bitch did to me, I had no choice but to kill him. But now, I’m in a pickle.",
	"I seemed to develop an obsession with opening doors that should’ve just stayed closed, but it made me have an compulsive need to find out even more.",
	"…",
]
const FINAL_QUESTION := "If I could go back in time, would it have been easier?"

@export var instant_mode := false
@export var auto_transition_to_day2 := true

var checkpoint_route: StringName = TRUTHFUL
var seedless_route: StringName = TRUTHFUL
var sequence_started := false
var interaction_locked := false
var _door_available := false
var _door_used := false
var _prompt_sources := 0
var _player_dialogue_anchor: Node2D

@onready var player: Player = $Player
@onready var horizontal_camera: Day1HorizontalCamera = $HorizontalCamera
@onready var dialogue: CinematicDialogue = $CinematicDialogue
@onready var truth_background: Sprite2D = $Day1EndingTruth
@onready var propaganda_background: Sprite2D = $Day1EndingPropaganda
@onready var prompt: Label = $EndingUI/Prompt
@onready var fade: ColorRect = $EndingUI/Fade
@onready var final_image: TextureRect = $EndingUI/FinalImage
@onready var narration: Label = $EndingUI/Narration
@onready var vignette: ColorRect = $EndingUI/Vignette
@onready var red_drift: CPUParticles2D = $EndingUI/RedDrift
@onready var night_audio: AudioStreamPlayer = $Audio/Night
@onready var route_audio = $Audio/Route
@onready var room_audio: AudioStreamPlayer = $Audio/Room
@onready var door_audio: AudioStreamPlayer = $Audio/Door
@onready var text_blip: AudioStreamPlayer = $Audio/TextBlip


func _ready() -> void:
	ending_started.emit()
	_read_routes()
	_apply_route()
	_setup_audio()
	_setup_lighting()
	_setup_street_particles()
	_player_dialogue_anchor = Node2D.new()
	_player_dialogue_anchor.position = Vector2(0, -185)
	player.add_child(_player_dialogue_anchor)
	_setup_route_npcs()
	_setup_door()
	horizontal_camera.global_position = player.global_position + horizontal_camera.framing_offset
	horizontal_camera.reset_smoothing()
	player.controls_enabled = false
	player.animated_sprite.flip_h = true
	fade.visible = true
	fade.modulate.a = 0.0
	final_image.visible = false
	narration.visible = false
	vignette.visible = false
	red_drift.emitting = false
	_start_opening.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if _door_available and not _door_used and not interaction_locked and event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		_start_door_sequence()


func _read_routes() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return
	var stored_checkpoint: StringName = session.get_day1_report_route(CHECKPOINT_REPORT)
	var stored_seedless: StringName = session.get_day1_report_route(SEEDLESS_REPORT)
	if stored_checkpoint in [TRUTHFUL, PROPAGANDA]:
		checkpoint_route = stored_checkpoint
	if stored_seedless in [TRUTHFUL, PROPAGANDA]:
		seedless_route = stored_seedless


func _apply_route() -> void:
	truth_background.visible = checkpoint_route == TRUTHFUL
	propaganda_background.visible = checkpoint_route == PROPAGANDA
	route_applied.emit(checkpoint_route, seedless_route)


func selected_report2_narration() -> String:
	return TRUTH_REPORT_2 if seedless_route == TRUTHFUL else PROPAGANDA_REPORT_2


func _start_opening() -> void:
	sequence_started = true
	# Let the horizontal camera snap from its scene-origin default to the player
	# before the parallax bark captures its initial screen-space anchor.
	await get_tree().process_frame
	await get_tree().process_frame
	await dialogue.show_bark("I need to go out to buy some food….", "MC", _player_dialogue_anchor, 1.35)
	player.controls_enabled = true
	sequence_started = false


func _setup_route_npcs() -> void:
	if checkpoint_route == TRUTHFUL:
		var protester := _spawn_npc("res://assets/art/Day1 Scene 1/npcs/r1c3-occupation-protester-b.png", Vector2(3190, 605), Vector2(0.62, 0.62), false)
		var soldier := _spawn_npc("res://assets/art/Day1 Scene 1/npcs/r2c1-seedless-representative-guard-a.png", Vector2(3350, 605), Vector2(0.68, 0.68), true)
		_add_conversation(Vector2(3270, 545), ["Opposition", "Soldier", "Opposition"], TRUTH_PROTEST_LINES, [protester, soldier, protester])
		var elderly := _spawn_npc("res://assets/art/Day1 Scene 1/npcs/r3c1-seedless-campaign-representative.png", Vector2(2290, 605), Vector2(0.62, 0.62), true)
		_add_conversation(Vector2(2290, 545), ["Elderly Civilian", "MC", "Elderly Civilian", "Elderly Civilian"], TRUTH_ELDERLY_LINES, [elderly, _player_dialogue_anchor, elderly, elderly])
		_spawn_route_particles(Vector2(3250, 470), Color(1.0, 0.48, 0.24, 0.55), true)
	else:
		var civilian_one := _spawn_npc("res://assets/art/Day1 Scene 1/npcs/r2c3-gossiping-gal-a.png", Vector2(3260, 605), Vector2(0.65, 0.65), false)
		var civilian_two := _spawn_npc("res://assets/art/Day1 Scene 1/npcs/r2c4-gossiping-gal-b.png", Vector2(3390, 605), Vector2(0.65, 0.65), true)
		_add_conversation(Vector2(3325, 545), ["Civilian One", "Civilian Two", "Civilian One", "Civilian Two"], PROPAGANDA_ARGUMENT_LINES, [civilian_one, civilian_two, civilian_one, civilian_two])
		var bystander := _spawn_npc("res://assets/art/Day1 Scene 1/npcs/r1c3-occupation-protester-b.png", Vector2(2280, 605), Vector2(0.62, 0.62), false)
		var supporter := _spawn_npc("res://assets/art/Day1 Scene 1/npcs/r1c1-smoking-civilian.png", Vector2(2420, 605), Vector2(0.62, 0.62), true)
		_add_conversation(Vector2(2350, 545), ["Bystander", "Government Supporter"], PROPAGANDA_WITNESS_LINES, [bystander, supporter])
		_spawn_route_particles(Vector2(3290, 420), Color(0.75, 0.82, 0.92, 0.42), false)


func _spawn_npc(path: String, position_value: Vector2, scale_value: Vector2, flip_h: bool) -> Node2D:
	var anchor := Node2D.new()
	anchor.position = position_value
	anchor.z_index = 4
	add_child(anchor)
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.position = Vector2(0, -118)
	sprite.scale = scale_value
	sprite.flip_h = flip_h
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	anchor.add_child(sprite)
	var dialogue_anchor := Node2D.new()
	dialogue_anchor.position = Vector2(0, -265)
	anchor.add_child(dialogue_anchor)
	return dialogue_anchor


func _add_conversation(position_value: Vector2, names: Array[String], lines: Array[String], anchors: Array[Node2D]) -> void:
	var conversation := Day1OptionalConversation.new()
	conversation.position = position_value
	conversation.configure(dialogue, names, lines, anchors)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(360, 190)
	shape.position = Vector2(0, -80)
	shape.shape = rectangle
	conversation.add_child(shape)
	conversation.prompt_changed.connect(_on_prompt_changed)
	add_child(conversation)


func _setup_door() -> void:
	var door_area := Area2D.new()
	door_area.position = Vector2(1035, 520)
	door_area.collision_layer = 0
	door_area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(180, 230)
	shape.position = Vector2(0, -75)
	shape.shape = rectangle
	door_area.add_child(shape)
	door_area.body_entered.connect(func(body: Node):
		if body is Player and not _door_used:
			_door_available = true
			_on_prompt_changed(true, "E  ENTER")
	)
	door_area.body_exited.connect(func(body: Node):
		if body is Player:
			_door_available = false
			_on_prompt_changed(false, "E  ENTER")
	)
	add_child(door_area)


func _on_prompt_changed(visible_value: bool, text_value: String) -> void:
	_prompt_sources += 1 if visible_value else -1
	_prompt_sources = maxi(_prompt_sources, 0)
	prompt.text = text_value
	prompt.visible = _prompt_sources > 0 and not interaction_locked


func _start_door_sequence() -> void:
	if _door_used:
		return
	_door_used = true
	interaction_locked = true
	prompt.visible = false
	player.play_door_interaction()
	door_audio.play()
	door_sequence_started.emit()
	var cover := create_tween()
	cover.tween_property(fade, "modulate:a", 1.0, _duration(0.75))
	await cover.finished
	night_audio.stop()
	route_audio.stop()
	await _show_black_narration(COMMON_HUNGER)
	await _show_black_narration(selected_report2_narration())
	await _show_black_narration(COMMON_FRUIT)
	await _show_final_art()


func _show_black_narration(text: String) -> void:
	final_image.visible = false
	vignette.visible = false
	red_drift.emitting = false
	narration.visible = true
	narration.position = Vector2(160, 205)
	narration.size = Vector2(960, 310)
	narration.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	await _type_text(text, 27.0)
	await _wait(maxf(1.6, text.length() / 78.0))
	narration.visible = false


func _show_final_art() -> void:
	room_audio.play()
	final_image.texture = FINAL_ART
	final_image.visible = true
	final_image.modulate.a = 0.0
	final_image.scale = Vector2(1.03, 1.03)
	vignette.visible = true
	vignette.modulate.a = 0.0
	red_drift.emitting = true
	var reveal := create_tween().set_parallel()
	reveal.tween_property(final_image, "modulate:a", 1.0, _duration(1.2))
	reveal.tween_property(final_image, "scale", Vector2.ONE, _duration(12.0)).set_trans(Tween.TRANS_SINE)
	reveal.tween_property(vignette, "modulate:a", 0.72, _duration(1.3))
	await get_tree().create_timer(_duration(1.2)).timeout
	narration.position = Vector2(90, 500)
	narration.size = Vector2(1100, 170)
	narration.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	narration.visible = true
	for text in COUCH_LINES:
		await _type_text(text, 25.0)
		await _wait(1.65 if text != "…" else 1.1)
	narration.visible = false
	var blackout := create_tween()
	blackout.tween_property(final_image, "modulate:a", 0.0, _duration(0.9))
	await blackout.finished
	final_image.visible = false
	vignette.visible = false
	red_drift.emitting = false
	room_audio.stop()
	await _show_black_narration(FINAL_QUESTION)
	ending_finished.emit()
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method(&"complete_day1"):
		session.complete_day1()
	if auto_transition_to_day2:
		var transition_service := get_node_or_null("/root/SceneTransition")
		if transition_service != null and not transition_service.busy:
			transition_service.transition_to("res://scenes/narrative/day2_placeholder.tscn", false)


func _type_text(text: String, speed: float) -> void:
	narration.text = text
	narration.visible_characters = 0
	if instant_mode:
		narration.visible_characters = -1
		await get_tree().process_frame
		return
	for index in text.length():
		narration.visible_characters = index + 1
		var character := text.substr(index, 1)
		if not character.strip_edges().is_empty() and index % 3 == 0:
			text_blip.pitch_scale = randf_range(0.94, 1.03)
			text_blip.play()
		var delay := 1.0 / speed
		if character in ".,!?…":
			delay += 0.08
		await get_tree().create_timer(delay).timeout


func _setup_audio() -> void:
	night_audio.stream = NIGHT_AMBIENCE
	route_audio.stream = TRUTH_AMBIENCE if checkpoint_route == TRUTHFUL else PROPAGANDA_AMBIENCE
	room_audio.stream = ROOM_PULSE
	door_audio.stream = DOOR_LATCH
	text_blip.stream = BLIP
	for audio in [night_audio, route_audio, room_audio]:
		if audio.stream is AudioStreamWAV:
			(audio.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	night_audio.play()
	route_audio.play()


func _setup_lighting() -> void:
	_add_light(Vector2(1050, 250), Color(0.38, 0.56, 0.9, 1), 1.15, Vector2(5.2, 3.4))
	_add_light(Vector2(2300, 255), Color(0.32, 0.5, 0.84, 1), 0.8, Vector2(5.8, 3.2))
	_add_light(Vector2(3330, 430), Color(1.0, 0.55, 0.26, 1) if checkpoint_route == TRUTHFUL else Color(0.42, 0.58, 0.9, 1), 0.72, Vector2(3.0, 1.8))
	_add_occluder(PackedVector2Array([Vector2(250, 165), Vector2(420, 165), Vector2(390, 615), Vector2(275, 615)]))
	_add_occluder(PackedVector2Array([Vector2(920, -40), Vector2(1610, -40), Vector2(1610, 410), Vector2(1260, 410), Vector2(1260, 585), Vector2(920, 585)]))
	_add_occluder(PackedVector2Array([Vector2(4050, -40), Vector2(5480, -40), Vector2(5480, 360), Vector2(4050, 360)]))


func _add_light(position_value: Vector2, color_value: Color, energy: float, scale_value: Vector2) -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var light := PointLight2D.new()
	light.position = position_value
	light.texture = texture
	light.color = color_value
	light.energy = energy
	light.scale = scale_value
	light.shadow_enabled = true
	light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	add_child(light)


func _add_occluder(points: PackedVector2Array) -> void:
	var polygon := OccluderPolygon2D.new()
	polygon.polygon = points
	polygon.closed = true
	var occluder := LightOccluder2D.new()
	occluder.occluder = polygon
	occluder.z_index = -2
	add_child(occluder)


func _spawn_route_particles(position_value: Vector2, color_value: Color, rise: bool) -> void:
	var particles := CPUParticles2D.new()
	particles.position = position_value
	particles.z_index = 6
	particles.amount = 18
	particles.lifetime = 4.8
	particles.preprocess = 4.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(260, 80)
	particles.direction = Vector2(0.25, -1.0 if rise else 0.35)
	particles.spread = 42.0
	particles.gravity = Vector2(2, -5 if rise else 8)
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 14.0
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.1
	particles.color = color_value
	particles.texture = load("res://assets/art/Day1 Scene 1/particles/dust-mote.svg" if rise else "res://assets/art/Day1 Scene 1/particles/leaf-particle.svg")
	add_child(particles)


func _setup_street_particles() -> void:
	for position_value in [Vector2(330, 80), Vector2(1830, 75), Vector2(3370, 110)]:
		var leaves := LEAF_ZONE.instantiate() as CPUParticles2D
		leaves.position = position_value
		leaves.modulate = Color(0.55, 0.72, 0.9, 0.62)
		add_child(leaves)
	for position_value in [Vector2(1080, 455), Vector2(2440, 440), Vector2(4690, 430)]:
		var motes := DUST_ZONE.instantiate() as CPUParticles2D
		motes.position = position_value
		motes.modulate = Color(0.62, 0.76, 0.94, 0.58)
		add_child(motes)


func _wait(seconds: float) -> void:
	if instant_mode:
		await get_tree().process_frame
	else:
		await get_tree().create_timer(seconds).timeout


func _duration(seconds: float) -> float:
	return 0.001 if instant_mode else seconds
