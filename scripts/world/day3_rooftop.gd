class_name Day3Rooftop
extends RooftopScene

signal route_resolution_started(route: StringName)
signal route_resolved(route: StringName)

const FINALE_SCENE := "res://scenes/Day 3/day3_finale.tscn"
const SCOPE_SCENE := "res://scenes/Day 3/day3_scope_scene.tscn"
const NOT_SHOOT := &"not_shoot"
const SHOOT := &"shoot"

@export var verdict_hold_seconds := 2.2

var _pending_route: StringName = &""
var _debug_mode := false

@onready var verdict_overlay: Control = $HUD/RouteVerdict
@onready var not_shoot_panel: PanelContainer = $HUD/RouteVerdict/Layout/VBox/Choices/NotShoot
@onready var shoot_panel: PanelContainer = $HUD/RouteVerdict/Layout/VBox/Choices/Shoot
@onready var not_shoot_label: Label = $HUD/RouteVerdict/Layout/VBox/Choices/NotShoot/Label
@onready var shoot_label: Label = $HUD/RouteVerdict/Layout/VBox/Choices/Shoot/Label
@onready var verdict_caption: Label = $HUD/RouteVerdict/Layout/VBox/Caption
@onready var debug_help: Label = $HUD/RouteVerdict/Layout/VBox/DebugHelp
@onready var radio_click: AudioStreamPlayer = $Day3Audio/RadioClick
@onready var heartbeat: AudioStreamPlayer = $Day3Audio/Heartbeat


func _ready() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.save_checkpoint("day3_rooftop")
	_spawn_position = player.global_position
	player.fell.connect(_on_player_fell)
	execute_zone.body_entered.connect(_on_execute_zone_entered)
	execute_zone.body_exited.connect(_on_execute_zone_exited)
	plan_prompt.visible = false
	completion.visible = false
	verdict_overlay.visible = false
	$HUD/PlanPrompt/Label.text = "E / SPACE  FACE THE CHOICE"
	_start_loop(wind)
	_start_loop(birds)
	fade.modulate.a = 1.0
	create_tween().tween_property(fade, "modulate:a", 0.0, 0.65)
	_play_day3_intro()


func _play_day3_intro() -> void:
	player.controls_enabled = false
	await get_tree().create_timer(0.65).timeout
	await dialogue.show_line("I feel like I chased an impossible dream in the beginning. Now now it’s biting me, and the people of this country on its back.", 1.4, player, true)
	if is_inside_tree() and not plan_executed:
		player.controls_enabled = true


func execute_plan() -> void:
	if plan_executed:
		return
	plan_executed = true
	execute_available = false
	plan_prompt.visible = false
	player.controls_enabled = false
	player.play_pistol_plan()
	await player.execute_plan_finished
	if not is_inside_tree():
		return
	var session := get_node_or_null("/root/GameSession")
	_pending_route = session.resolve_day3_route() if session != null else &""
	_debug_mode = _pending_route == &""
	_show_verdict()
	if not _debug_mode:
		await _commit_route_after_hold()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		get_tree().reload_current_scene()
	elif not plan_executed and event.is_action_pressed(&"interact") and execute_available:
		execute_plan()
	elif _debug_mode and verdict_overlay.visible:
		var key := event as InputEventKey
		if event.is_action_pressed(&"ui_left") or (key != null and key.pressed and key.keycode == KEY_1):
			_choose_debug_route(NOT_SHOOT)
		elif event.is_action_pressed(&"ui_right") or (key != null and key.pressed and key.keycode == KEY_2):
			_choose_debug_route(SHOOT)


func _show_verdict() -> void:
	verdict_overlay.visible = true
	debug_help.visible = _debug_mode
	if _debug_mode:
		verdict_caption.text = "REPORT HISTORY INCOMPLETE — EDITOR ROUTE PREVIEW"
		not_shoot_label.modulate = Color.WHITE
		shoot_label.modulate = Color.WHITE
		return
	verdict_caption.text = "THE REPORTS HAVE ALREADY DECIDED"
	_set_choice_state(not_shoot_panel, not_shoot_label, _pending_route == NOT_SHOOT)
	_set_choice_state(shoot_panel, shoot_label, _pending_route == SHOOT)
	route_resolution_started.emit(_pending_route)
	radio_click.play()
	heartbeat.play()


func _set_choice_state(panel: PanelContainer, label: Label, selected: bool) -> void:
	panel.modulate = Color(1.0, 1.0, 1.0, 1.0) if selected else Color(0.25, 0.27, 0.34, 0.58)
	label.text = label.text.trim_suffix("  [LOCKED]") if selected else label.text + "  [LOCKED]"


func _choose_debug_route(route: StringName) -> void:
	if not _debug_mode:
		return
	_debug_mode = false
	_pending_route = route
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.set_day3_debug_route_override(route)
	_set_choice_state(not_shoot_panel, not_shoot_label, route == NOT_SHOOT)
	_set_choice_state(shoot_panel, shoot_label, route == SHOOT)
	verdict_caption.text = "NON-PERSISTENT EDITOR PREVIEW"
	debug_help.visible = false
	route_resolution_started.emit(route)
	radio_click.play()
	_commit_route_after_hold()


func _commit_route_after_hold() -> void:
	await get_tree().create_timer(verdict_hold_seconds).timeout
	if not is_inside_tree():
		return
	if heartbeat.playing:
		var heartbeat_release := create_tween()
		heartbeat_release.tween_property(heartbeat, "volume_db", -34.0, 0.45)
		await heartbeat_release.finished
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.set_day3_resolution(_pending_route)
	route_resolved.emit(_pending_route)
	var destination := SCOPE_SCENE if _pending_route == SHOOT else FINALE_SCENE
	var transition_service := get_node_or_null("/root/SceneTransition")
	if transition_service != null and not transition_service.busy:
		transition_service.transition_to(destination, false)
	else:
		get_tree().change_scene_to_file(destination)


func get_pause_objective() -> String:
	if verdict_overlay.visible:
		return "Face the choice determined by your reports."
	if plan_executed:
		return "Wait for the final order."
	if execute_available:
		return "Confront the final choice at the firing position."
	return "Cross the rooftop and reach the firing position."
