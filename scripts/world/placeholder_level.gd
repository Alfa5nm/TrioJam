extends Node2D

var _reports_collected := 0
var _total_reports := 0
var _spawn_position := Vector2.ZERO
var _level_complete := false

@onready var player: Player = $Player
@onready var newsroom_gate: NewsroomGate = $Level/NewsroomGate
@onready var reports_label: Label = $HUD/TopBar/Panel/Margin/Rows/Reports
@onready var message_label: Label = $HUD/Message
@onready var completion_panel: PanelContainer = $HUD/Completion


func _ready() -> void:
	_spawn_position = player.global_position
	var report_points := get_tree().get_nodes_in_group("report_points")
	_total_reports = report_points.size()
	for report_point: ReportPoint in report_points:
		report_point.collected.connect(_on_report_collected)
	player.fell.connect(_on_player_fell)
	newsroom_gate.attempted.connect(_on_newsroom_attempted)
	newsroom_gate.set_unlocked(false)
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _on_report_collected(_report_id: StringName, headline: String) -> void:
	_reports_collected += 1
	message_label.text = "Collected: %s" % headline
	newsroom_gate.set_unlocked(_reports_collected >= _total_reports)
	_update_hud()


func _on_newsroom_attempted() -> void:
	if _reports_collected < _total_reports:
		message_label.text = "Two reports are required before the broadcast."
		return
	_level_complete = true
	player.controls_enabled = false
	completion_panel.visible = true
	message_label.visible = false


func _on_player_fell() -> void:
	if _level_complete:
		return
	message_label.text = "You fell. Returning to the checkpoint..."
	player.reset_to(_spawn_position)


func _update_hud() -> void:
	reports_label.text = "REPORTS  %d / %d" % [_reports_collected, _total_reports]
