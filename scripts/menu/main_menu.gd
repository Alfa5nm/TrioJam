class_name MainMenu
extends Control

const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const PARALLAX_RESPONSE := 5.5
const DEFAULT_BACKDROP := preload("res://scenes/menu/Untitled509_20260719170240.png")
const SHOOT_ENDING_BACKDROP := preload("res://assets/art/ui/main-menu-shoot-ending.png")
const NOT_SHOOT_ENDING_BACKDROP := preload("res://assets/art/ui/main-menu-not-shoot-ending.png")

@onready var backdrop: Control = %BackdropParallax
@onready var backdrop_image: TextureRect = $BackdropParallax/Image
@onready var title_logo: Sprite2D = %TitleLogo
@onready var menu: VBoxContainer = %Menu
@onready var continue_button: Button = %ContinueButton
@onready var settings_dim: ColorRect = %SettingsDim
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var master_slider: HSlider = %MasterSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var ambience_slider: HSlider = %AmbienceSlider
@onready var ui_slider: HSlider = %UISlider
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var resolution_options: OptionButton = %ResolutionOptions
@onready var navigate_audio: AudioStreamPlayer = $Audio/Navigate

var _backdrop_origin := Vector2.ZERO
var _title_origin := Vector2.ZERO
var _menu_origin := Vector2.ZERO
var _button_tweens: Dictionary = {}
var _settings_open := false


func _ready() -> void:
	_apply_completed_route_backdrop()
	settings_dim.visible = false
	settings_panel.visible = false
	continue_button.disabled = not _session().has_continue()
	%NewGameButton.pressed.connect(_start_new_game)
	continue_button.pressed.connect(_continue_game)
	%SettingsButton.pressed.connect(_open_settings)
	%QuitButton.pressed.connect(func(): get_tree().quit())
	%SettingsClose.pressed.connect(_save_and_close_settings)
	_populate_settings()
	_backdrop_origin = backdrop.position
	_title_origin = title_logo.position
	_menu_origin = menu.position
	for button in _menu_buttons():
		button.pivot_offset = button.size * 0.5
		button.mouse_entered.connect(_animate_button.bind(button, true))
		button.mouse_exited.connect(_animate_button.bind(button, false))
		button.focus_entered.connect(_animate_button.bind(button, true))
		button.focus_exited.connect(_animate_button.bind(button, false))
	%NewGameButton.grab_focus()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _apply_completed_route_backdrop() -> void:
	var session := _session()
	if session.has_method(&"has_completed_day3_route") and session.has_completed_day3_route(&"shoot"):
		backdrop_image.texture = SHOOT_ENDING_BACKDROP
	elif session.has_method(&"has_completed_day3_route") and session.has_completed_day3_route(&"not_shoot"):
		backdrop_image.texture = NOT_SHOOT_ENDING_BACKDROP
	else:
		backdrop_image.texture = DEFAULT_BACKDROP


func _process(delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var normalized := (get_viewport().get_mouse_position() / viewport_size - Vector2(0.5, 0.5)) * 2.0
	normalized.x = clampf(normalized.x, -1.0, 1.0)
	normalized.y = clampf(normalized.y, -1.0, 1.0)
	var weight := minf(1.0, delta * PARALLAX_RESPONSE)
	backdrop.position = backdrop.position.lerp(_backdrop_origin + normalized * Vector2(-15.0, -9.0), weight)
	title_logo.position = title_logo.position.lerp(_title_origin + normalized * Vector2(5.0, 3.0), weight)
	menu.position = menu.position.lerp(_menu_origin + normalized * Vector2(8.0, 5.0), weight)


func _unhandled_input(event: InputEvent) -> void:
	if _settings_open and event.is_action_pressed(&"ui_cancel"):
		_save_and_close_settings()
		get_viewport().set_input_as_handled()


func _menu_buttons() -> Array[Button]:
	return [%NewGameButton, %ContinueButton, %SettingsButton, %QuitButton]


func _animate_button(button: Button, active: bool) -> void:
	if button.disabled:
		return
	if _button_tweens.has(button) and is_instance_valid(_button_tweens[button]):
		(_button_tweens[button] as Tween).kill()
	var tween := create_tween().set_parallel(true)
	_button_tweens[button] = tween
	tween.tween_property(button, "scale", Vector2(1.025, 1.025) if active else Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", Color(1.08, 1.03, 1.08, 1.0) if active else Color.WHITE, 0.14)
	if active:
		navigate_audio.pitch_scale = randf_range(0.96, 1.04)
		navigate_audio.play()


func _start_new_game() -> void:
	_session().begin_day_zero()
	_transition_service().transition_to("res://scenes/main/main.tscn", true)


func _continue_game() -> void:
	var scene_path: String = _session().continue_scene_path()
	if not scene_path.is_empty():
		_transition_service().transition_to(scene_path, _session().checkpoint in ["scene0", "scene1"])


func _open_settings() -> void:
	_settings_open = true
	settings_dim.visible = true
	settings_panel.visible = true
	settings_panel.modulate.a = 0.0
	settings_panel.scale = Vector2(0.96, 0.96)
	settings_panel.pivot_offset = settings_panel.size * 0.5
	_populate_settings()
	var reveal := create_tween().set_parallel(true)
	reveal.tween_property(settings_panel, "modulate:a", 1.0, 0.2)
	reveal.tween_property(settings_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	%SettingsClose.grab_focus()


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
	_settings_open = false
	settings_dim.visible = false
	settings_panel.visible = false
	%SettingsButton.grab_focus()


func _session() -> Node:
	return get_node("/root/GameSession")


func _transition_service() -> Node:
	return get_node("/root/SceneTransition")
