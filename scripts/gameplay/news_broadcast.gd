class_name NewsBroadcast
extends Control

signal broadcast_finished

const PRESENTER_SHEET := preload("res://assets/art/Broadcast/presenter-sheet-v1.png")
const CELL_SIZE := Vector2(444, 444)
const HARD_NEWS_LINES := [3, 4, 6]

@export var instant_mode := false
@export var auto_advance_to_epilogue := true

var _lines: Array[String] = []
var _line_frames: Array[int] = []
var _line_index := 0
var _typing := false
var _skip_requested := false
var _ended := false
var _scroll_tween: Tween
var _bang_sound_played := false

@onready var presenter: AnimatedSprite2D = $Presenter
@onready var teleprompter_text: Label = %TeleprompterText
@onready var advance_prompt: Label = %AdvancePrompt
@onready var cards: Array[Control] = [%FrameOne, %FrameTwo, %FrameThree]
@onready var card_images: Array[TextureRect] = [
	%FrameOne.get_node("Image"), %FrameTwo.get_node("Image"), %FrameThree.get_node("Image")
]
@onready var card_tags: Array[Label] = [
	%FrameOne.get_node("Tag/Text"), %FrameTwo.get_node("Tag/Text"), %FrameThree.get_node("Tag/Text")
]
@onready var screen_slate: Label = %ScreenSlate
@onready var intro_sting: AudioStreamPlayer = $Audio/IntroSting
@onready var news_bed: AudioStreamPlayer = $Audio/NewsBed
@onready var presenter_blip: AudioStreamPlayer = $Audio/PresenterBlip
@onready var table_bang: AudioStreamPlayer = $Audio/TableBang
@onready var fade: ColorRect = %Fade


func _ready() -> void:
	_setup_presenter_frames()
	presenter.frame_changed.connect(_on_presenter_frame_changed)
	presenter.animation_finished.connect(_on_presenter_animation_finished)
	var report := BroadcastDemoData.rooftop_killing_report()
	_lines = report.propaganda_sequence.broadcast_lines
	_line_frames = report.propaganda_sequence.broadcast_line_frames
	_apply_broadcast_package(report)
	_set_news_bed_loop(true)
	fade.modulate.a = 1.0
	create_tween().tween_property(fade, "modulate:a", 0.0, 0.5)
	_set_card_focus(-1)
	if instant_mode:
		news_bed.play()
		_present_current_line()
	else:
		intro_sting.play()
		await intro_sting.finished
		news_bed.play()
		_present_current_line()


func _exit_tree() -> void:
	_set_news_bed_loop(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") or (
		event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	):
		_request_advance()
		get_viewport().set_input_as_handled()


func _request_advance() -> void:
	if _ended:
		return
	if _typing:
		_skip_requested = true
		return
	_line_index += 1
	_present_current_line()


func _present_current_line() -> void:
	if _line_index >= _lines.size():
		_finish_broadcast()
		return
	var text := _lines[_line_index]
	var frame_index := _line_frames[_line_index] if _line_index < _line_frames.size() else -1
	_set_card_focus(frame_index)
	teleprompter_text.text = text
	teleprompter_text.visible_characters = 0
	teleprompter_text.position.y = 72.0
	advance_prompt.visible = false
	_typing = true
	_skip_requested = false
	_start_presenter_motion()
	if _scroll_tween != null and _scroll_tween.is_running():
		_scroll_tween.kill()
	var reading_duration := maxf(text.length() / 16.0, 4.2)
	_scroll_tween = create_tween()
	_scroll_tween.tween_property(teleprompter_text, "position:y", 14.0, reading_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if instant_mode:
		teleprompter_text.visible_characters = -1
		teleprompter_text.position.y = 14.0
	else:
		for index in text.length():
			if _skip_requested:
				teleprompter_text.visible_characters = -1
				if _scroll_tween != null:
					_scroll_tween.kill()
				teleprompter_text.position.y = 14.0
				break
			teleprompter_text.visible_characters = index + 1
			var character := text.substr(index, 1)
			if not character.strip_edges().is_empty() and index % 2 == 0:
				presenter_blip.pitch_scale = randf_range(0.97, 1.065)
				presenter_blip.play()
			await get_tree().create_timer(0.06).timeout
	_typing = false
	if presenter.animation == &"talk":
		presenter.stop()
		presenter.frame = 0
	advance_prompt.visible = true


func _start_presenter_motion() -> void:
	if _line_index in HARD_NEWS_LINES:
		_bang_sound_played = false
		presenter.play(&"bang")
	else:
		presenter.play(&"talk")


func _on_presenter_frame_changed() -> void:
	if presenter.animation == &"bang" and presenter.frame == 2 and not _bang_sound_played:
		_bang_sound_played = true
		table_bang.play()


func _on_presenter_animation_finished() -> void:
	if presenter.animation == &"bang" and _typing:
		presenter.play(&"talk")


func _set_card_focus(frame_index: int) -> void:
	screen_slate.visible = frame_index < 0
	for index in cards.size():
		cards[index].visible = index == frame_index
		cards[index].modulate = Color.WHITE
		cards[index].scale = Vector2.ONE


func _finish_broadcast() -> void:
	_ended = true
	_typing = false
	_set_card_focus(-1)
	screen_slate.text = "BROADCAST COMPLETE"
	teleprompter_text.position.y = 32.0
	teleprompter_text.visible_characters = -1
	teleprompter_text.text = "— END OF BROADCAST —"
	advance_prompt.visible = false
	presenter.stop()
	presenter.frame = 0
	broadcast_finished.emit()
	if auto_advance_to_epilogue:
		await get_tree().create_timer(1.35).timeout
		var transition_service := get_node_or_null("/root/SceneTransition")
		if transition_service != null and not transition_service.busy:
			transition_service.transition_to("res://scenes/narrative/day0_epilogue.tscn", false)


func _setup_presenter_frames() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation(&"talk")
	frames.set_animation_loop(&"talk", true)
	frames.set_animation_speed(&"talk", 7.0)
	frames.add_animation(&"bang")
	frames.set_animation_loop(&"bang", false)
	frames.set_animation_speed(&"bang", 6.5)
	for column in 4:
		frames.add_frame(&"talk", _atlas_frame(column, 0))
		frames.add_frame(&"bang", _atlas_frame(column, 1))
	presenter.sprite_frames = frames
	presenter.animation = &"talk"
	presenter.frame = 0


func _atlas_frame(column: int, row: int) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = PRESENTER_SHEET
	frame.region = Rect2(Vector2(column, row) * CELL_SIZE, CELL_SIZE)
	return frame


func _set_news_bed_loop(enabled: bool) -> void:
	if news_bed.stream is AudioStreamOggVorbis:
		(news_bed.stream as AudioStreamOggVorbis).loop = enabled


func _apply_broadcast_package(report: BroadcastReport) -> void:
	var session := get_node_or_null("/root/GameSession")
	var package: BroadcastPackage = session.pending_broadcast_package if session != null else null
	if package == null or package.report_id != report.report_id:
		package = BroadcastPackage.from_sequence(report.report_id, report.propaganda_sequence)
	for index in mini(3, package.action_ids.size()):
		var action := _find_action(report, package.action_ids[index])
		if action != null and action.scene_image != null:
			card_images[index].texture = action.scene_image
		var names: Array[String] = []
		if index < package.character_ids.size():
			for character_id in package.character_ids[index]:
				var character := _find_character(report, character_id)
				if character != null:
					names.append(character.display_name.to_upper())
		var action_name := action.display_name.to_upper() if action != null else "UNLABELED CAPTURE"
		card_tags[index].text = "%02d  %s\n%s" % [index + 1, action_name, ", ".join(names)]


func _find_action(report: BroadcastReport, id: StringName) -> ActionDef:
	for action in report.available_actions:
		if action.id == id:
			return action
	return null


func _find_character(report: BroadcastReport, id: StringName) -> CharacterDef:
	for character in report.characters:
		if character.id == id:
			return character
	return null
