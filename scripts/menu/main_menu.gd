class_name MainMenu
extends Control

const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

@onready var menu: VBoxContainer = %Menu
@onready var continue_button: Button = %ContinueButton
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var master_slider: HSlider = %MasterSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var ambience_slider: HSlider = %AmbienceSlider
@onready var ui_slider: HSlider = %UISlider
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var resolution_options: OptionButton = %ResolutionOptions


func _ready() -> void:
	settings_panel.visible = false
	continue_button.disabled = not _session().has_continue()
	%NewGameButton.pressed.connect(_start_new_game)
	continue_button.pressed.connect(_continue_game)
	%SettingsButton.pressed.connect(_open_settings)
	%QuitButton.pressed.connect(func(): get_tree().quit())
	%SettingsClose.pressed.connect(_save_and_close_settings)
	_populate_settings()


func _start_new_game() -> void:
	_session().begin_day_zero()
	_transition_service().transition_to("res://scenes/main/main.tscn", true)


func _continue_game() -> void:
	var scene_path: String = _session().continue_scene_path()
	if not scene_path.is_empty():
		_transition_service().transition_to(scene_path, _session().checkpoint in ["scene0", "scene1"])


func _open_settings() -> void:
	settings_panel.visible = true
	_populate_settings()


func _populate_settings() -> void:
	master_slider.value = _session().master_volume * 100.0
	sfx_slider.value = _session().sfx_volume * 100.0
	ambience_slider.value = _session().ambience_volume * 100.0
	ui_slider.value = _session().ui_volume * 100.0
	fullscreen_toggle.button_pressed = _session().fullscreen
	resolution_options.clear()
	for size in RESOLUTIONS:
		resolution_options.add_item("%d × %d" % [size.x, size.y])
	resolution_options.select(maxi(RESOLUTIONS.find(_session().resolution), 0))


func _save_and_close_settings() -> void:
	_session().master_volume = master_slider.value / 100.0
	_session().sfx_volume = sfx_slider.value / 100.0
	_session().ambience_volume = ambience_slider.value / 100.0
	_session().ui_volume = ui_slider.value / 100.0
	_session().fullscreen = fullscreen_toggle.button_pressed
	_session().resolution = RESOLUTIONS[resolution_options.selected]
	_session().save_settings()
	settings_panel.visible = false


func _session() -> Node:
	return get_node("/root/GameSession")


func _transition_service() -> Node:
	return get_node("/root/SceneTransition")
