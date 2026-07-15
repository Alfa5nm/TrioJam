extends Node2D

var _active_interaction: StairwellInteraction
var _spawn_position := Vector2.ZERO
var _scene_complete := false
var _message_tween: Tween

@onready var player: Player = $Player
@onready var camera: CinematicCamera = $CinematicCamera
@onready var prompt_panel: PanelContainer = $HUD/Prompt
@onready var prompt_label: Label = $HUD/Prompt/Margin/Label
@onready var message_panel: PanelContainer = $HUD/Message
@onready var message_label: Label = $HUD/Message/Margin/Label
@onready var title_block: VBoxContainer = $HUD/SceneTitle
@onready var completion: Control = $HUD/Completion
@onready var fade: ColorRect = $HUD/Fade


func _ready() -> void:
	_spawn_position = player.global_position
	player.fell.connect(_on_player_fell)
	for node in get_tree().get_nodes_in_group("stairwell_interactions"):
		var interaction := node as StairwellInteraction
		interaction.proximity_changed.connect(_on_proximity_changed)
		interaction.activated.connect(_on_interaction_activated)
	prompt_panel.visible = false
	message_panel.visible = false
	completion.visible = false
	fade.modulate.a = 1.0
	var intro := create_tween()
	intro.tween_property(fade, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro.parallel().tween_property(title_block, "modulate:a", 1.0, 0.6)
	intro.tween_interval(2.0)
	intro.tween_property(title_block, "modulate:a", 0.0, 0.9)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _on_proximity_changed(interaction: StairwellInteraction, active: bool) -> void:
	if active:
		_active_interaction = interaction
		prompt_label.text = interaction.prompt_text
		prompt_panel.visible = true
		camera.set_focus_target(interaction)
	elif _active_interaction == interaction:
		_active_interaction = null
		prompt_panel.visible = false
		camera.clear_focus_target(interaction)


func _on_interaction_activated(interaction: StairwellInteraction) -> void:
	player.play_interaction()
	if interaction.completes_scene:
		_complete_scene(interaction)
	else:
		_show_message(interaction.message_text)


func _show_message(text: String) -> void:
	if _message_tween != null and _message_tween.is_running():
		_message_tween.kill()
	message_label.text = text
	message_panel.visible = true
	message_panel.modulate.a = 0.0
	_message_tween = create_tween()
	_message_tween.tween_property(message_panel, "modulate:a", 1.0, 0.2)
	_message_tween.tween_interval(2.8)
	_message_tween.tween_property(message_panel, "modulate:a", 0.0, 0.45)
	_message_tween.tween_callback(func(): message_panel.visible = false)


func _complete_scene(interaction: StairwellInteraction) -> void:
	if _scene_complete:
		return
	_scene_complete = true
	player.controls_enabled = false
	prompt_panel.visible = false
	camera.set_focus_target(interaction, 0.42)
	completion.visible = true
	completion.modulate.a = 0.0
	var outro := create_tween()
	outro.tween_property(completion, "modulate:a", 1.0, 0.65)


func _on_player_fell() -> void:
	if not _scene_complete:
		player.reset_to(_spawn_position)
