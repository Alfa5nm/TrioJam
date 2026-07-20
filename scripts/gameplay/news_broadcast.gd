class_name NewsBroadcast
extends Control

signal broadcast_finished

enum LineKind { REPORTER, PHONE_GOVERNMENT, PHONE_MC }

const PRESENTER_SHEET := preload("res://assets/art/Broadcast/presenter-sheet-v1.png")
const CELL_SIZE := Vector2(444, 444)
const DAY1_REPORT_CHECKPOINT := &"day1_checkpoint_killing"
const DAY1_REPORT_SEEDLESS := &"day1_seedless_fruit"
const TRUTHFUL := &"truthful"
const PROPAGANDA := &"propaganda"
const DAY1_OPENING := "And now, Today’s News:"
const DAY1_BRIDGE := "Now, for our other news of the day."
const MEDICAL_PENALTY := "Your household’s medical allocation has been reduced."
const MEDICAL_REACTION := "…I should have known this, but life is going to become very very expensive now…"
const SECURITY_PENALTY := "Your household’s security system’s budget has been reduced."
const SECURITY_REACTION := MEDICAL_REACTION

@export var instant_mode := false
@export var auto_advance_to_epilogue := true

var _lines: Array[String] = []
var _line_frames: Array[int] = []
var _line_report_ids: Array[StringName] = []
var _line_routes: Array[StringName] = []
var _line_kinds: Array[int] = []
var _line_sequences: Array = []
var _line_reports: Array = []
var _line_index := 0
var _typing := false
var _skip_requested := false
var _ended := false
var _scroll_tween: Tween
var _is_day1_context := false
var _is_day2_context := false
var _active_package_key := ""
var card_character_overlays: Array = []

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
@onready var phone_overlay: Control = %PhoneOverlay
@onready var phone_portrait: TextureRect = %PhonePortrait
@onready var phone_call_text: Label = %PhoneCallText
@onready var phone_advance_prompt: Label = %PhoneAdvancePrompt
@onready var intro_sting: AudioStreamPlayer = $Audio/IntroSting
@onready var news_bed: AudioStreamPlayer = $Audio/NewsBed
@onready var presenter_blip: AudioStreamPlayer = $Audio/PresenterBlip
@onready var phone_ring: AudioStreamPlayer = $Audio/PhoneRing
@onready var fade: ColorRect = %Fade


func _ready() -> void:
	_setup_presenter_frames()
	_setup_card_character_overlays()
	var session := get_node_or_null("/root/GameSession")
	_is_day1_context = session != null and session.broadcast_context == &"day1"
	_is_day2_context = session != null and session.broadcast_context == &"day2"
	if _is_day1_context:
		_configure_day1_broadcast(session)
	elif _is_day2_context:
		_configure_day2_broadcast(session)
	else:
		_configure_day0_broadcast(session)
	_set_news_bed_loop(true)
	# Keep the legacy channel-bed player alive for scene compatibility while the
	# persistent director supplies the audible authored Broadcast track.
	news_bed.volume_db = -40.0
	phone_overlay.visible = false
	fade.modulate.a = 1.0
	create_tween().tween_property(fade, "modulate:a", 0.0, 0.5)
	_set_card_focus(-1)
	if instant_mode:
		_start_broadcast_music()
		news_bed.play()
		_present_current_line()
	else:
		intro_sting.play()
		await intro_sting.finished
		_start_broadcast_music()
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


func _configure_day0_broadcast(session: Node) -> void:
	var report := BroadcastDemoData.rooftop_killing_report()
	_lines = report.propaganda_sequence.broadcast_lines.duplicate()
	_line_frames = report.propaganda_sequence.broadcast_line_frames.duplicate()
	for _line in _lines:
		_line_report_ids.append(report.report_id)
		_line_routes.append(PROPAGANDA)
		_line_kinds.append(LineKind.REPORTER)
		_line_sequences.append(report.propaganda_sequence)
		_line_reports.append(report)
	_apply_day0_broadcast_package(report, session)


func _configure_day1_broadcast(session: Node) -> void:
	_lines.clear()
	_line_frames.clear()
	_line_report_ids.clear()
	_line_routes.clear()
	_line_kinds.clear()
	_line_sequences.clear()
	_line_reports.clear()
	var reports := BroadcastDemoData.day1_reports()
	var checkpoint_report: BroadcastReport = reports[0]
	var seedless_report: BroadcastReport = reports[1]
	var checkpoint_route: StringName = session.get_day1_report_route(DAY1_REPORT_CHECKPOINT)
	var seedless_route: StringName = session.get_day1_report_route(DAY1_REPORT_SEEDLESS)
	if checkpoint_route not in [TRUTHFUL, PROPAGANDA]:
		checkpoint_route = TRUTHFUL
	if seedless_route not in [TRUTHFUL, PROPAGANDA]:
		seedless_route = TRUTHFUL
	var checkpoint_sequence := _sequence_for_route(checkpoint_report, checkpoint_route)
	var seedless_sequence := _sequence_for_route(seedless_report, seedless_route)
	_append_line(DAY1_OPENING, -1, null, &"", &"", LineKind.REPORTER)
	_append_sequence(checkpoint_report, checkpoint_sequence, checkpoint_route)
	if checkpoint_route == TRUTHFUL:
		_append_line(MEDICAL_PENALTY, -1, null, DAY1_REPORT_CHECKPOINT, checkpoint_route, LineKind.PHONE_GOVERNMENT)
		_append_line(MEDICAL_REACTION, -1, null, DAY1_REPORT_CHECKPOINT, checkpoint_route, LineKind.PHONE_MC)
	_append_line(DAY1_BRIDGE, -1, null, &"", &"", LineKind.REPORTER)
	_append_sequence(seedless_report, seedless_sequence, seedless_route)
	if seedless_route == TRUTHFUL:
		_append_line(SECURITY_PENALTY, -1, null, DAY1_REPORT_SEEDLESS, seedless_route, LineKind.PHONE_GOVERNMENT)
		_append_line(SECURITY_REACTION, -1, null, DAY1_REPORT_SEEDLESS, seedless_route, LineKind.PHONE_MC)


func _configure_day2_broadcast(session: Node) -> void:
	_lines.clear()
	_line_frames.clear()
	_line_report_ids.clear()
	_line_routes.clear()
	_line_kinds.clear()
	_line_sequences.clear()
	_line_reports.clear()
	var report := BroadcastDemoData.bombing_report()
	var route: StringName = session.get_day2_report_route() if session != null and session.has_method(&"get_day2_report_route") else TRUTHFUL
	if route not in [TRUTHFUL, PROPAGANDA]:
		route = TRUTHFUL
	var sequence := _sequence_for_route(report, route)
	_append_line("And now, Today’s News.", -1, null, &"", &"", LineKind.REPORTER)
	_append_sequence(report, sequence, route)


func _append_sequence(report: BroadcastReport, sequence: BroadcastSequence, route: StringName) -> void:
	for index in sequence.broadcast_lines.size():
		var frame := sequence.broadcast_line_frames[index] if index < sequence.broadcast_line_frames.size() else -1
		_append_line(sequence.broadcast_lines[index], frame, sequence, report.report_id, route, LineKind.REPORTER, report)


func _append_line(
	text: String,
	frame: int,
	sequence: BroadcastSequence,
	report_id: StringName,
	route: StringName,
	kind: int,
	report: BroadcastReport = null
) -> void:
	_lines.append(text)
	_line_frames.append(frame)
	_line_report_ids.append(report_id)
	_line_routes.append(route)
	_line_kinds.append(kind)
	_line_sequences.append(sequence)
	_line_reports.append(report)


func _sequence_for_route(report: BroadcastReport, route: StringName) -> BroadcastSequence:
	return report.propaganda_sequence if route == PROPAGANDA else report.truthful_sequence


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
	var kind := _line_kinds[_line_index]
	_apply_line_package(_line_index)
	_apply_line_kind(kind)
	if kind == LineKind.REPORTER:
		_set_card_focus(frame_index)
	var active_text: Label = teleprompter_text if kind == LineKind.REPORTER else phone_call_text
	active_text.text = text
	active_text.visible_characters = 0
	if kind == LineKind.REPORTER:
		teleprompter_text.position.y = 72.0
	advance_prompt.visible = false
	phone_advance_prompt.visible = false
	_typing = true
	_skip_requested = false
	if kind == LineKind.REPORTER:
		_start_presenter_motion()
	else:
		presenter.stop()
		presenter.frame = 0
	if _scroll_tween != null and _scroll_tween.is_running():
		_scroll_tween.kill()
	if kind == LineKind.REPORTER:
		var reading_duration := maxf(text.length() / 16.0, 4.2)
		_scroll_tween = create_tween()
		_scroll_tween.tween_property(teleprompter_text, "position:y", 14.0, reading_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if instant_mode:
		active_text.visible_characters = -1
		if kind == LineKind.REPORTER:
			teleprompter_text.position.y = 14.0
	else:
		for index in text.length():
			if _skip_requested:
				active_text.visible_characters = -1
				if _scroll_tween != null:
					_scroll_tween.kill()
				if kind == LineKind.REPORTER:
					teleprompter_text.position.y = 14.0
				break
			active_text.visible_characters = index + 1
			var character := text.substr(index, 1)
			if not character.strip_edges().is_empty() and index % 2 == 0:
				presenter_blip.pitch_scale = randf_range(0.9, 0.98) if kind == LineKind.PHONE_GOVERNMENT else randf_range(0.97, 1.065)
				presenter_blip.play()
			await get_tree().create_timer(0.06).timeout
	_typing = false
	if presenter.animation == &"talk":
		presenter.stop()
		presenter.frame = 0
	if kind == LineKind.REPORTER:
		advance_prompt.visible = true
	else:
		phone_advance_prompt.visible = true


func _apply_line_kind(kind: int) -> void:
	var is_phone := kind != LineKind.REPORTER
	phone_overlay.visible = is_phone
	phone_portrait.visible = is_phone
	presenter.modulate = Color.WHITE
	match kind:
		LineKind.PHONE_GOVERNMENT:
			phone_call_text.add_theme_color_override("font_color", Color(1.0, 0.72, 0.72, 1.0))
			phone_ring.play()
		LineKind.PHONE_MC:
			phone_call_text.add_theme_color_override("font_color", Color(0.78, 0.9, 1.0, 1.0))
		_:
			phone_call_text.text = ""


func _apply_line_package(index: int) -> void:
	if index >= _line_sequences.size():
		return
	var sequence: BroadcastSequence = _line_sequences[index]
	var report: BroadcastReport = _line_reports[index]
	if sequence == null or report == null:
		return
	var key := "%s:%s" % [_line_report_ids[index], _line_routes[index]]
	if key == _active_package_key:
		return
	_active_package_key = key
	_apply_sequence_package(report, sequence)


func _start_presenter_motion() -> void:
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
	phone_overlay.visible = false
	phone_advance_prompt.visible = false
	presenter.modulate = Color.WHITE
	_set_card_focus(-1)
	screen_slate.text = "BROADCAST COMPLETE"
	teleprompter_text.position.y = 32.0
	teleprompter_text.visible_characters = -1
	teleprompter_text.text = "— END OF BROADCAST —"
	advance_prompt.visible = false
	presenter.stop()
	presenter.frame = 0
	broadcast_finished.emit()
	var music_director := get_node_or_null("/root/MusicDirector")
	if music_director != null:
		music_director.stop_cue(0.65)
	if auto_advance_to_epilogue:
		await get_tree().create_timer(1.35).timeout
		var transition_service := get_node_or_null("/root/SceneTransition")
		if transition_service != null and not transition_service.busy:
			var destination := "res://scenes/narrative/day0_epilogue.tscn"
			if _is_day1_context:
				destination = "res://scenes/Day 1/Side Scroll Section/Day 1 ending.tscn"
			elif _is_day2_context:
				destination = "res://scenes/Day 2/day2_breakdown.tscn"
			if _is_day1_context:
				var session := get_node_or_null("/root/GameSession")
				if session != null:
					session.save_checkpoint("day1_ending")
			elif _is_day2_context:
				var session := get_node_or_null("/root/GameSession")
				if session != null:
					session.save_checkpoint("day2_breakdown")
			transition_service.transition_to(destination, false)


func _setup_presenter_frames() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation(&"talk")
	frames.set_animation_loop(&"talk", true)
	frames.set_animation_speed(&"talk", 7.0)
	for column in 4:
		frames.add_frame(&"talk", _atlas_frame(column, 0))
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


func _start_broadcast_music() -> void:
	var music_director := get_node_or_null("/root/MusicDirector")
	if music_director != null:
		music_director.play_cue(&"broadcast")


func _apply_day0_broadcast_package(report: BroadcastReport, session: Node) -> void:
	var package: BroadcastPackage = null
	if session != null and session.has_method(&"get_pending_broadcast_package"):
		package = session.get_pending_broadcast_package(report.report_id)
	elif session != null:
		package = session.pending_broadcast_package
	if package == null or package.report_id != report.report_id:
		package = BroadcastPackage.from_sequence(report.report_id, report.propaganda_sequence)
	_apply_package(report, package)


func _apply_sequence_package(report: BroadcastReport, sequence: BroadcastSequence) -> void:
	var package: BroadcastPackage = null
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method(&"get_pending_broadcast_package"):
		package = session.get_pending_broadcast_package(report.report_id)
	if package == null:
		package = BroadcastPackage.from_sequence(report.report_id, sequence)
	_apply_package(report, package)


func _apply_package(report: BroadcastReport, package: BroadcastPackage) -> void:
	_clear_card_package()
	for index in mini(3, package.action_ids.size()):
		var action := _find_action(report, package.action_ids[index])
		if action != null and action.scene_image != null:
			card_images[index].texture = action.scene_image
		var names: Array[String] = []
		if index < package.character_ids.size():
			for position_index in package.character_ids[index].size():
				var character_id = package.character_ids[index][position_index]
				var character := _find_character(report, character_id)
				if character != null:
					names.append(character.display_name.to_upper())
					var overlay_texture := _overlay_texture_for(action, character, position_index)
					if overlay_texture != null and position_index < card_character_overlays[index].size():
						var overlay: TextureRect = card_character_overlays[index][position_index]
						overlay.texture = overlay_texture
						overlay.visible = true
		var action_name := action.display_name.to_upper() if action != null else "UNLABELED CAPTURE"
		card_tags[index].text = "%02d  %s\n%s" % [index + 1, action_name, ", ".join(names)]


func _setup_card_character_overlays() -> void:
	card_character_overlays.clear()
	for index in cards.size():
		var layers: Array[TextureRect] = []
		for position_index in 2:
			var overlay := TextureRect.new()
			overlay.name = "CharacterOverlay%d" % (position_index + 1)
			overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
			overlay.offset_bottom = -62.0
			overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			overlay.visible = false
			cards[index].add_child(overlay)
			cards[index].move_child(overlay, card_images[index].get_index() + 1 + position_index)
			layers.append(overlay)
		card_character_overlays.append(layers)


func _clear_card_package() -> void:
	for index in cards.size():
		card_images[index].texture = null
		card_tags[index].text = "%02d  UNLABELED CAPTURE" % (index + 1)
		for overlay_node in card_character_overlays[index]:
			var overlay := overlay_node as TextureRect
			overlay.texture = null
			overlay.visible = false


func _overlay_texture_for(action: ActionDef, character: CharacterDef, position_index: int) -> Texture2D:
	if action == null or not action.character_overlays.has(character.id):
		return null
	var entry = action.character_overlays[character.id]
	if entry is Array:
		return entry[position_index] if position_index < entry.size() else null
	return entry as Texture2D


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
