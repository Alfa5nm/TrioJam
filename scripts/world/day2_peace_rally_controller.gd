class_name Day2PeaceRallyController
extends Node2D

signal sequence_started
signal soldier_reveal_started
signal bomb_armed
signal explosion_started
signal aftermath_staged
signal escape_started
signal rescue_recorded
signal sequence_finished

enum State { ARRIVAL, FREE_ROAM, RALLY, SUSPICION, EXPLOSION, ESCAPE, BLOCKADE, RESCUE, EXIT }

const PODIUM_CG := preload("res://assets/art/Day 2 Side Scroll/cg/peace-leader-podium.png")
const WORKER_CG := preload("res://assets/art/Day 2 Side Scroll/cg/suspicious-worker.png")
const RESCUE_CG := preload("res://assets/art/Day 2 Side Scroll/cg/rescue-civilians.png")

@export var player_path: NodePath
@export var camera_path: NodePath
@export var dialogue_path: NodePath
@export var overlay_path: NodePath
@export_range(0.05, 2.0, 0.05) var timing_scale := 1.0

var state := State.ARRIVAL
var _rally_started := false
var _blockade_started := false
var _containment_started := false
var _containment_complete := false
var _blockade_pending := false
var _bomb_armed := false
var _previous_camera_target: Node2D
var _previous_camera_offset := Vector2.ZERO
var _previous_camera_zoom := Vector2.ONE

@onready var player: Player = get_node(player_path)
@onready var camera: Day1HorizontalCamera = get_node(camera_path)
@onready var dialogue: CinematicDialogue = get_node(dialogue_path)
@onready var overlay: Day2CinematicOverlay = get_node(overlay_path)
@onready var normal_background: Sprite2D = $World/NormalBackground
@onready var aftermath_background: Sprite2D = $World/AftermathBackground
@onready var rally_trigger: Area2D = $Triggers/Rally
@onready var containment_trigger: Area2D = $Triggers/Containment
@onready var blockade_trigger: Area2D = $Triggers/Blockade
@onready var exit_trigger: Area2D = $Triggers/Exit
@onready var left_debris: StaticBody2D = $Collision/LeftDebris
@onready var left_debris_shape: CollisionShape2D = $Collision/LeftDebris/Shape
@onready var east_blockade: StaticBody2D = $Collision/EastBlockade
@onready var east_blockade_shape: CollisionShape2D = $Collision/EastBlockade/Shape
@onready var stage_focus: Node2D = $Focus/Stage
@onready var soldier_focus: Node2D = $Focus/SoldierReveal
@onready var blockade_focus: Node2D = $Focus/Blockade
@onready var rescue_focus: Node2D = $Focus/Rescue
@onready var mc_anchor: Node2D = $DialogueAnchors/MC
@onready var soldier_anchor: Node2D = $DialogueAnchors/Soldier
@onready var civilian_anchor: Node2D = $DialogueAnchors/Civilian
@onready var mother_anchor: Node2D = $DialogueAnchors/Mother
@onready var leader_anchor: Node2D = $DialogueAnchors/Leader
@onready var rally_crowd: Node2D = $NPCs/RallyCrowd
@onready var panic_crowd: Node2D = $NPCs/PanicCrowd
@onready var blockade_crowd: Node2D = $NPCs/BlockadeCrowd
@onready var peace_leader: Sprite2D = $NPCs/PeaceLeader
@onready var foreground_podium: Sprite2D = $NPCs/ForegroundPodium
@onready var suspicious_worker: Sprite2D = $NPCs/SuspiciousWorker
@onready var bomb_planting_soldier: AnimatedSprite2D = $NPCs/BombPlantingSoldier
@onready var aftermath_actors: Node2D = $NPCs/AftermathActors
@onready var crouched_leader: AnimatedSprite2D = $NPCs/AftermathActors/CrouchedLeader
@onready var injured_civilian_a: AnimatedSprite2D = $NPCs/AftermathActors/InjuredA
@onready var injured_civilian_b: AnimatedSprite2D = $NPCs/AftermathActors/InjuredB
@onready var bomb_beep: AudioStreamPlayer2D = $Audio/BombBeep
@onready var cloth_handling: AudioStreamPlayer2D = $Audio/ClothHandling
@onready var package_placement: AudioStreamPlayer2D = $Audio/PackagePlacement
@onready var metal_latch: AudioStreamPlayer2D = $Audio/MetalLatch
@onready var arming_click: AudioStreamPlayer2D = $Audio/ArmingClick
@onready var distant_sirens: AudioStreamPlayer = $Audio/DistantSirens
@onready var explosion: AudioStreamPlayer = $Audio/Explosion
@onready var tinnitus: AudioStreamPlayer = $Audio/Tinnitus
@onready var rally_ambience: AudioStreamPlayer = $Audio/RallyAmbience
@onready var rally_music: AudioStreamPlayer = $Audio/RallyMusic
@onready var panic_ambience: AudioStreamPlayer = $Audio/PanicAmbience
@onready var aftermath_rumble: AudioStreamPlayer = $Audio/AftermathRumble
@onready var explosion_flash: ColorRect = $ScreenFX/ExplosionFlash
@onready var stress_vignette: ColorRect = $ScreenFX/StressVignette
@onready var pre_particles: GPUParticles2D = $Particles/DaylightMotes
@onready var smoke_particles: GPUParticles2D = $Particles/Smoke
@onready var ember_particles: GPUParticles2D = $Particles/Embers
@onready var ash_particles: GPUParticles2D = $Particles/Ash
@onready var settling_debris: GPUParticles2D = $Particles/SettlingDebris
@onready var fire_light: PointLight2D = $Lighting/FireLight


func _ready() -> void:
	normal_background.visible = true
	aftermath_background.visible = false
	panic_crowd.visible = false
	blockade_crowd.visible = false
	peace_leader.visible = true
	foreground_podium.visible = true
	suspicious_worker.visible = true
	bomb_planting_soldier.visible = false
	aftermath_actors.visible = false
	left_debris_shape.disabled = true
	east_blockade_shape.disabled = true
	containment_trigger.monitoring = false
	blockade_trigger.monitoring = false
	exit_trigger.monitoring = false
	smoke_particles.emitting = false
	ember_particles.emitting = false
	ash_particles.emitting = false
	settling_debris.emitting = false
	fire_light.visible = false
	explosion_flash.modulate.a = 0.0
	stress_vignette.modulate.a = 0.0
	rally_trigger.body_entered.connect(_on_rally_entered)
	containment_trigger.body_entered.connect(_on_containment_entered)
	blockade_trigger.body_entered.connect(_on_blockade_entered)
	exit_trigger.body_entered.connect(_on_exit_entered)
	_set_loop(rally_ambience, true)
	_set_loop(rally_music, true)
	_set_loop(panic_ambience, true)
	_set_loop(aftermath_rumble, true)
	_set_loop(distant_sirens, true)
	rally_ambience.play()
	rally_music.play()
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.broadcast_context != &"day2_story":
		session.begin_day2()
	call_deferred(&"_play_arrival")


func _play_arrival() -> void:
	state = State.ARRIVAL
	_lock_player()
	mc_anchor.global_position = player.global_position + Vector2(0, -185)
	var session := get_node_or_null("/root/GameSession")
	var seedless_route: StringName = session.day1_seedless_route if session != null else &"truthful"
	if seedless_route == &"propaganda":
		await _say("MC", "There’s no seeds in this fruit… It’s… sweet.", mc_anchor, 0.8)
		await _say("MC", "….", mc_anchor, 0.6)
		await _say("MC", "This doesn’t feel good.", mc_anchor, 0.8)
	else:
		await _say("MC", "There’s seeds in this fruit… It’s a little expensive, but I’m glad that the farmers are getting what they needed. That’s what reform is for… I’m not getting medical aid anymore, but it’s for the best… Right?", mc_anchor, 1.15)
	_unlock_player()
	state = State.FREE_ROAM


func start_rally_sequence() -> void:
	if _rally_started or state != State.FREE_ROAM:
		return
	_rally_started = true
	rally_trigger.set_deferred(&"monitoring", false)
	state = State.RALLY
	sequence_started.emit()
	_lock_player()
	_previous_camera_target = camera.target
	_previous_camera_offset = camera.framing_offset
	_previous_camera_zoom = camera.zoom
	mc_anchor.global_position = player.global_position + Vector2(0, -185)
	await _say("MC", "There’s apparently a peace leader that’s going to tie both of the teams in order to bring peace. What is there slogan again…?", mc_anchor, 0.95)
	await _say("MC", "ONE COUNTRY. ONE PEOPLE. NO MORE BLOOD. …?", mc_anchor, 0.8)
	await _say("MC", "Well… Let’s pull my camera out. It might be worth shooting….", mc_anchor, 0.8)
	player.play_interaction()
	await _wait(0.35)
	await overlay.show_frame(&"peace_leader_opening", PODIUM_CG, [
		_beat(&"Peace Leader", "Thank you for coming.", &"bottom", Color(0.78, 0.94, 1), 0.65),
		_beat(&"Peace Leader", "Some of you were told not to stand beside one another. Some of you were told that the person beside you wants your family dead.", &"bottom", Color(0.78, 0.94, 1), 0.9),
		_beat(&"Peace Leader", "Look at them now. They are frightened. They are tired. They are waiting for the same country to become livable again.", &"bottom", Color(0.78, 0.94, 1), 0.9),
		_beat(&"Peace Leader", "The government must answer for its violence. And the Opposition must answer for its own.", &"bottom", Color(0.78, 0.94, 1), 0.85),
		_beat(&"Peace Leader", "Peace is deciding that no more blood will improve the argument.", &"bottom", Color(0.78, 0.94, 1), 0.8),
	])
	state = State.SUSPICION
	# Let the player re-orient in the real space before revealing the covert act.
	await _focus_with_zoom(stage_focus, Vector2.ONE, 0.42)
	await _wait(0.55)
	await _reveal_bomb_planting()
	await overlay.show_frame(&"suspicious_worker", WORKER_CG, [
		_beat(&"MC", "(…Maybe they work here? No… That can’t be right.)", &"bottom", Color(0.78, 0.91, 1), 0.75),
		_beat(&"MC", "(What’s a soldier doing here…..?)", &"bottom", Color(0.78, 0.91, 1), 0.75),
	])
	await overlay.show_frame(&"peace_leader_warning", PODIUM_CG, [
		_beat(&"Peace Leader", "I ask the government to meet us without soldiers between us. I ask the Opposition to enter that meeting without weapons behind its back.", &"bottom", Color(0.78, 0.94, 1), 0.9),
		_beat(&"MC", "The beeping… it’s getting louder…", &"bottom", Color(0.78, 0.91, 1), 0.65),
		_beat(&"Peace Leader", "There will be no victory if half the country must be buried beneath it.", &"bottom", Color(0.78, 0.94, 1), 0.8),
		_beat(&"MC", "Wait…!", &"bottom", Color(0.78, 0.91, 1), 0.35),
	], true, false)
	await _detonate()


func _detonate() -> void:
	state = State.EXPLOSION
	_bomb_armed = false
	bomb_beep.stop()
	explosion_started.emit()
	explosion.play()
	explosion_flash.modulate.a = 1.0
	camera.position = Vector2.ZERO
	var flash_tween := create_tween()
	flash_tween.tween_property(explosion_flash, "modulate:a", 0.0, _duration(0.55))
	await _wait(0.08)
	normal_background.visible = false
	aftermath_background.visible = true
	rally_crowd.visible = false
	peace_leader.visible = false
	foreground_podium.visible = false
	suspicious_worker.visible = false
	bomb_planting_soldier.visible = false
	aftermath_actors.visible = true
	crouched_leader.play(&"injured")
	injured_civilian_a.play(&"injured")
	injured_civilian_b.play(&"injured")
	leader_anchor.global_position = crouched_leader.global_position + Vector2(0.0, -128.0)
	panic_crowd.visible = true
	blockade_crowd.visible = true
	_start_crowd_dispersal()
	pre_particles.emitting = false
	smoke_particles.emitting = true
	ember_particles.emitting = true
	ash_particles.emitting = true
	settling_debris.restart()
	fire_light.visible = true
	distant_sirens.play()
	aftermath_staged.emit()
	_pulse_fire_light()
	left_debris_shape.set_deferred(&"disabled", false)
	east_blockade_shape.set_deferred(&"disabled", false)
	_run_camera_impact()
	rally_ambience.stop()
	rally_music.stop()
	tinnitus.play()
	aftermath_rumble.play()
	await _wait(0.42)
	panic_ambience.play()
	stress_vignette.modulate.a = 0.72
	state = State.ESCAPE
	escape_started.emit()
	_restore_camera()
	_unlock_player()
	containment_trigger.set_deferred(&"monitoring", true)
	blockade_trigger.set_deferred(&"monitoring", true)
	mc_anchor.global_position = player.global_position + Vector2(0, -185)
	await _say("MC", "(Fuck fuck fuck, they planted a bomb to a peace rally…?!)", mc_anchor, 0.75)
	mc_anchor.global_position = player.global_position + Vector2(0, -185)
	await _say("MC", "(I need to get the fuck out of here…!)", mc_anchor, 0.7)


func _start_containment_barks() -> void:
	if _containment_started or state != State.ESCAPE:
		return
	_containment_started = true
	await _say("Civilian", "There’s been an explosion!", civilian_anchor, 0.6)
	await _say("Soldier", "The area is under security containment!", soldier_anchor, 0.65)
	await _say("Mother", "My child can’t breathe!", mother_anchor, 0.6)
	await _say("Soldier", "Step back!", soldier_anchor, 0.55)
	_containment_complete = true
	containment_trigger.set_deferred(&"monitoring", false)
	if _blockade_pending or blockade_trigger.overlaps_body(player):
		_start_blockade.call_deferred()


func _start_blockade() -> void:
	if _blockade_started or state != State.ESCAPE:
		return
	if not _containment_complete:
		_blockade_pending = true
		if not _containment_started:
			_start_containment_barks()
		return
	_blockade_started = true
	_blockade_pending = false
	state = State.BLOCKADE
	_lock_player()
	await _focus(blockade_focus)
	mc_anchor.global_position = player.global_position + Vector2(0, -185)
	await _say("MC", "Are you serious?! There’s people fucking dying here! Let us out!", mc_anchor, 0.85)
	await _say("Soldier", "I understand but the culprit might be here!", soldier_anchor, 0.75)
	mc_anchor.global_position = player.global_position + Vector2(0, -185)
	await _say("MC", "(Ain’t no fucking way this is actually real.)", mc_anchor, 0.7)
	await _play_shove_reaction()
	await _focus(stage_focus)
	await _say("Opposition", "STOP!", leader_anchor, 0.55)
	await _say("Opposition", "DO NOT FIGHT THEM! Listen to me! The explosion wants us frightened. Do not give it what it wants!", leader_anchor, 0.95)
	await _say("Opposition", "Move the children and the injured through the eastern passage! Do not push!", leader_anchor, 0.85)
	await _say("Opposition", "Government supporters, help the wounded! Opposition volunteers, clear the debris!", leader_anchor, 0.9)
	await _focus(rescue_focus)
	state = State.RESCUE
	await overlay.show_frame(&"rescue", RESCUE_CG, [
		_beat(&"Opposition", "Let me see where you’re hurt!", &"left", Color(1.0, 0.78, 0.32), 0.65),
		_beat(&"Civilian", "I’m sorry, I-I can’t feel my legs…!", &"right", Color.WHITE, 0.7),
		_beat(&"Civilian", "AHHH…! The bleeding won’t stop…!", &"right", Color.WHITE, 0.65),
		_beat(&"Opposition", "I’m coming with medical aid! Please don’t panic and stay calm!", &"left", Color(1.0, 0.78, 0.32), 0.8),
	])
	rescue_recorded.emit()
	east_blockade_shape.set_deferred(&"disabled", true)
	exit_trigger.set_deferred(&"monitoring", true)
	_restore_camera()
	mc_anchor.global_position = player.global_position + Vector2(0, -185)
	await _say("MC", "I need to get the fuck out of here. Fast.", mc_anchor, 0.75)
	_unlock_player()
	state = State.EXIT


func _play_shove_reaction() -> void:
	var civilian := $NPCs/BlockadeCrowd/StrugglingCivilian as Node2D
	var soldier_a := $NPCs/PanicCrowd/SoldierA as Node2D
	var soldier_b := $NPCs/PanicCrowd/SoldierB as Node2D
	if civilian == null or soldier_a == null or soldier_b == null:
		return
	var civilian_origin := civilian.position
	var soldier_a_origin := soldier_a.position
	var soldier_b_origin := soldier_b.position
	var tween := create_tween()
	# Lunge, struggle, then recoil while the line splits enough to expose the
	# eastern passage. The player remains locked until the leader finishes.
	tween.tween_property(civilian, "position:x", civilian_origin.x + 44.0, _duration(0.16)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(soldier_a, "position:x", soldier_a_origin.x + 14.0, _duration(0.16))
	for direction in [-1.0, 1.0, -1.0, 1.0]:
		tween.tween_property(civilian, "rotation", direction * 0.055, _duration(0.055))
		tween.parallel().tween_property(soldier_a, "rotation", -direction * 0.035, _duration(0.055))
	tween.tween_property(civilian, "position", civilian_origin + Vector2(-76.0, 2.0), _duration(0.22)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(civilian, "rotation", -0.13, _duration(0.18))
	tween.parallel().tween_property(soldier_a, "position", soldier_a_origin + Vector2(62.0, 0.0), _duration(0.3))
	tween.parallel().tween_property(soldier_b, "position", soldier_b_origin + Vector2(94.0, 0.0), _duration(0.3))
	tween.parallel().tween_property(soldier_a, "rotation", 0.0, _duration(0.2))
	await tween.finished


func _start_crowd_dispersal() -> void:
	for child in panic_crowd.get_children():
		var actor := child as Day2DispersalActor
		if actor != null:
			actor.begin_dispersal()


func _finish_day2_world() -> void:
	if state != State.EXIT:
		return
	state = State.FREE_ROAM
	_lock_player()
	sequence_finished.emit()
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.begin_day2_broadcast()
	var transition := get_node_or_null("/root/SceneTransition")
	if transition != null and not transition.busy:
		transition.transition_to("res://scenes/gameplay/broadcast_interface.tscn", false)
	else:
		get_tree().change_scene_to_file("res://scenes/gameplay/broadcast_interface.tscn")


func _run_bomb_beeps() -> void:
	var interval := 1.2
	var loudness := -18.0
	while _bomb_armed:
		bomb_beep.pitch_scale = remap(interval, 0.24, 1.2, 1.35, 0.88)
		bomb_beep.volume_db = loudness
		bomb_beep.play()
		await _wait(interval)
		interval = maxf(0.24, interval * 0.79)
		loudness = minf(-4.0, loudness + 1.8)


func _reveal_bomb_planting() -> void:
	soldier_reveal_started.emit()
	var duck := create_tween().set_parallel(true)
	duck.tween_property(rally_ambience, "volume_db", -29.0, _duration(0.45))
	duck.tween_property(rally_music, "volume_db", -32.0, _duration(0.45))
	# The standing guard is replaced in-place by the authored kneeling poses.
	await _focus_with_zoom(soldier_focus, Vector2(1.25, 1.25), 0.55)
	suspicious_worker.visible = false
	bomb_planting_soldier.visible = true
	bomb_planting_soldier.pause()
	bomb_planting_soldier.frame = 0
	cloth_handling.play()
	await _wait(0.42)
	package_placement.play()
	await _wait(0.28)
	bomb_planting_soldier.frame = 1
	metal_latch.play()
	await _wait(0.3)
	arming_click.play()
	_bomb_armed = true
	bomb_armed.emit()
	_run_bomb_beeps()
	await _wait(0.5)


func _run_camera_impact() -> void:
	var tween := create_tween()
	for offset in [Vector2(18, -10), Vector2(-14, 8), Vector2(9, -5), Vector2(-5, 3), Vector2.ZERO]:
		tween.tween_property(camera, "offset", offset, _duration(0.055))


func _pulse_fire_light() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(fire_light, "energy", 1.35, 0.12)
	tween.tween_property(fire_light, "energy", 0.78, 0.18)
	tween.tween_property(fire_light, "energy", 1.08, 0.09)


func _say(speaker: String, text: String, anchor: Node2D, hold: float) -> void:
	while dialogue.is_presenting:
		await get_tree().process_frame
	await dialogue.show_bark(text, speaker, anchor, hold)


func _focus(target: Node2D) -> void:
	camera.target = target
	camera.framing_offset = Vector2(0, -210)
	await _wait(0.38)


func _focus_with_zoom(target: Node2D, target_zoom: Vector2, travel_time: float) -> void:
	camera.target = target
	camera.framing_offset = Vector2(0, -210)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(camera, "zoom", target_zoom, _duration(travel_time)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await _wait(travel_time)


func _restore_camera() -> void:
	camera.target = _previous_camera_target if is_instance_valid(_previous_camera_target) else player
	camera.framing_offset = _previous_camera_offset if _previous_camera_offset != Vector2.ZERO else Vector2(240, -262)
	var restore := create_tween()
	restore.tween_property(camera, "zoom", _previous_camera_zoom, _duration(0.28)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _lock_player() -> void:
	player.controls_enabled = false
	player.velocity = Vector2.ZERO
	player.animated_sprite.play(&"idle")


func _unlock_player() -> void:
	player.controls_enabled = true
	player.velocity = Vector2.ZERO
	player.animated_sprite.play(&"idle")


func _beat(speaker: StringName, text: String, placement: StringName, color: Color, hold: float) -> Dictionary:
	return {"speaker": speaker, "text": text, "placement": placement, "color": color, "hold": hold}


func _set_loop(player_node: AudioStreamPlayer, enabled: bool) -> void:
	if player_node.stream is AudioStreamWAV:
		(player_node.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if enabled else AudioStreamWAV.LOOP_DISABLED
	elif player_node.stream is AudioStreamMP3:
		(player_node.stream as AudioStreamMP3).loop = enabled
	elif player_node.stream is AudioStreamOggVorbis:
		(player_node.stream as AudioStreamOggVorbis).loop = enabled


func _on_rally_entered(body: Node) -> void:
	if body == player:
		start_rally_sequence()


func _on_containment_entered(body: Node) -> void:
	if body == player:
		_start_containment_barks()


func _on_blockade_entered(body: Node) -> void:
	if body == player:
		_start_blockade()


func _on_exit_entered(body: Node) -> void:
	if body == player:
		_finish_day2_world()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(_duration(seconds)).timeout


func _duration(seconds: float) -> float:
	return maxf(seconds * timing_scale, 0.001)
