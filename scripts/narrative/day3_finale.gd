class_name Day3Finale
extends Control

signal ending_started(route: StringName)
signal ending_completed(route: StringName)
signal line_started(speaker: String, text: String)
signal image_shown(key: String)
signal tv_story_shown(key: String)
signal center_card_shown(text: String)

const NOT_SHOOT := &"not_shoot"
const SHOOT := &"shoot"
const MAIN_MENU := "res://scenes/menu/main_menu.tscn"
const CG_PARALLAX_SCALE := Vector2(1.025, 1.025)
const CG_PARALLAX_MAX_OFFSET := Vector2(10.0, 6.0)
const CG_PARALLAX_RESPONSE := 5.5

const CG := {
	"gun_a": "res://assets/art/Day3/gun-command-a.png",
	"gun_b": "res://assets/art/Day3/gun-command-b.png",
	"leader": "res://assets/art/Day3/peace-leader-podium.png",
	"mc_shot_impact": "res://assets/art/Day3/mc-shot-impact.png",
	"dead_mc": "res://assets/art/Day3/mc-dead-armband.png",
	"television": "res://assets/art/Day3/television-aftermath.png",
	"tv_backdrop": "res://assets/art/Day3/foreign-apartment-tv-backdrop.png",
	"assassination": "res://assets/art/Day3/assassination-aftermath-placeholder.png",
	"arrests": "res://assets/art/Day3/opposition-arrests-placeholder.png",
	"passports": "res://assets/art/Day3/false-passports-placeholder.png",
	"helicopter": "res://assets/art/Day3/helicopter-escape-placeholder.png",
	"solidarity": "res://assets/art/Day3/solidarity-montage.png",
	"day0_shot": "res://assets/art/Day3/choice-consequence.png",
	"news_podium": "res://assets/art/Day3/news/empty-podium.png",
	"news_unrest": "res://assets/art/Day3/news/civil-unrest.png",
	"news_military": "res://assets/art/Day3/news/military-control.png",
}

const CREDITS := [
	"MADE FOR IUT GAME JAM",
	"Under the theme “Kick-off”",
	"",
	"Tasnuva: Project lead, Game Mechanics and Designer",
	"Farid: Lead Programmer, Side-Scrolling and Environmental Artist and Engineer",
	"Akib: Programmer, Logistics, Game mechanics",
	"",
	"Made in: Godot.",
	"Music credits: vivivivivi (aka safeinyrskin), GreenBearMusic and other free artists found in Pixabay",
	"",
	"Thank you for playing!",
]

@export var play_on_ready := true
@export var timing_scale := 1.0
@export var instant_mode := false
@export var auto_return_to_menu := true

var route: StringName = &""
var _skip_typewriter := false
var _skip_hold := false
var _credits_active := false
var _credits_skip_armed := false
var _ending_done := false
var _resume_at_credits := false
var _cg_parallax_active := false
var _cg_origin := Vector2.ZERO
var _default_caption_style: StyleBoxFlat

@onready var image: TextureRect = $Image
@onready var tv_broadcast: Day3TVBroadcast = $TVBroadcast
@onready var red_drift: CPUParticles2D = $RedDrift
@onready var grade: ColorRect = $Grade
@onready var flash: ColorRect = $Flash
@onready var placeholder: PanelContainer = $Placeholder
@onready var placeholder_label: Label = $Placeholder/Label
@onready var caption_panel: PanelContainer = $CaptionPanel
@onready var caption: RichTextLabel = $CaptionPanel/Caption
@onready var center_card: Control = $CenterCard
@onready var center_title: Label = $CenterCard/Title
@onready var credits: Control = $Credits
@onready var credits_text: Label = $Credits/CreditsText
@onready var credits_hint: Label = $Credits/SkipHint
@onready var route_music: AudioStreamPlayer = $Audio/RouteMusic
@onready var gunshot: AudioStreamPlayer = $Audio/Gunshot
@onready var body_fall: AudioStreamPlayer = $Audio/BodyFall
@onready var radio: AudioStreamPlayer = $Audio/Radio
@onready var crowd: AudioStreamPlayer = $Audio/Crowd
@onready var siren: AudioStreamPlayer = $Audio/Siren
@onready var helicopter: AudioStreamPlayer = $Audio/Helicopter
@onready var television_static: AudioStreamPlayer = $Audio/TelevisionStatic
@onready var death_stinger: AudioStreamPlayer = $Audio/DeathStinger
@onready var shoot_stinger: AudioStreamPlayer = $Audio/ShootStinger
@onready var dialogue_blip: AudioStreamPlayer = $Audio/DialogueBlip


func _ready() -> void:
	var initial_caption_style := caption_panel.get_theme_stylebox(&"panel")
	if initial_caption_style is StyleBoxFlat:
		_default_caption_style = (initial_caption_style as StyleBoxFlat).duplicate() as StyleBoxFlat
	caption_panel.visible = false
	center_card.visible = false
	placeholder.visible = false
	credits.visible = false
	flash.modulate.a = 0.0
	image.modulate.a = 0.0
	tv_broadcast.visible = false
	red_drift.emitting = false
	_cg_origin = image.position
	image.pivot_offset = image.size * 0.5
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		_resume_at_credits = session.checkpoint == "day3_credits"
		if not _resume_at_credits:
			session.save_checkpoint("day3_finale")
		route = session.day3_resolution
		if route not in [NOT_SHOOT, SHOOT]:
			route = session.resolve_day3_route()
	if route not in [NOT_SHOOT, SHOOT]:
		route = NOT_SHOOT
	ending_started.emit(route)
	if play_on_ready:
		if _resume_at_credits:
			_play_credits()
		else:
			play_finale()


func _process(delta: float) -> void:
	if not _cg_parallax_active or image.modulate.a <= 0.0:
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	image.pivot_offset = image.size * 0.5
	var normalized := (get_viewport().get_mouse_position() / viewport_size - Vector2(0.5, 0.5)) * 2.0
	normalized.x = clampf(normalized.x, -1.0, 1.0)
	normalized.y = clampf(normalized.y, -1.0, 1.0)
	var target := _cg_origin - normalized * CG_PARALLAX_MAX_OFFSET
	image.position = image.position.lerp(target, minf(1.0, delta * CG_PARALLAX_RESPONSE))


func _input(event: InputEvent) -> void:
	if not (event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept") or (
		event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	)):
		return
	if _credits_active and _credits_skip_armed:
		_finish_to_menu()
	elif caption.visible_characters >= 0 and caption.visible_characters < caption.get_total_character_count():
		_skip_typewriter = true
	else:
		_skip_hold = true


func play_finale() -> void:
	# Begin the route score with the ending itself. The SHOOT path may already be
	# carrying this player forward from the rifle impact; the session service
	# keeps that playback seamless instead of restarting it.
	_start_route_music(route)
	if route == NOT_SHOOT:
		await _play_not_shoot()
	else:
		await _play_shoot()
	if not is_inside_tree():
		return
	await _play_credits()


func _play_not_shoot() -> void:
	_black_screen()
	radio.play()
	await _line("GOVERNMENT REPRESENTATIVE — EARPIECE", "Fire", Color(0.95, 0.28, 0.34))
	await _line("PEACE LEADER — DISTANT", "We have spent too long turning frightened people into weapons.", Color(0.7, 0.86, 1.0))
	await _line("PEACE LEADER — DISTANT", "Today, we put them down.", Color(0.7, 0.86, 1.0))
	await _show_image("gun_a")
	radio.play()
	await _line("GOVERNMENT REPRESENTATIVE — EARPIECE", "Fire.", Color(0.95, 0.28, 0.34))
	await _line("MC", "…", Color(0.7, 0.86, 1.0))
	await _line("MC", "No.", Color(0.7, 0.86, 1.0))
	radio.play()
	await _line("GOVERNMENT REPRESENTATIVE — EARPIECE", "Repeat that.", Color(0.95, 0.28, 0.34))
	await _line("MC", "Find another ending for your report. I’m done with your bullshit. I’m not killing a guy who wants the best for humanity.\nYes it was for the—-", Color(0.7, 0.86, 1.0), 1.45)
	await _offscreen_shot()
	_black_screen()
	death_stinger.play()
	await _line("REPORTER", "And now, On Today’s News:", Color.WHITE)
	await _line("REPORTER", "An armed Opposition extremist was discovered in a nearby building with a rifle aimed toward the gathering.", Color.WHITE)
	await _show_image("dead_mc")
	await _line("REPORTER", "Evidence recovered at the scene suggests that the attacker belonged to a radical faction opposed to the leader’s calls for negotiation.", Color.WHITE)
	await _line("REPORTER", "Authorities have identified the attacker as G-03S-93.", Color.WHITE)
	await _line("REPORTER", "However, the Leader has to say something different about it.", Color.WHITE)
	await _show_image("leader")
	await _line("PEACE LEADER", "I’ve heard reports of this man. Apparently, this man was the one who reported the truth behind the cases of these recent times. How he died remains a mystery.", Color(0.7, 0.86, 1.0), 1.45)
	await _line("PEACE LEADER", "However, it rings true that he must have attempted assination at that time.", Color(0.7, 0.86, 1.0))
	_black_screen()
	await _line("MC — NARRATION", "They argued over my name. Some called me a hero, Most called me a dirty, filthy murderer.", Color(0.7, 0.86, 1.0))
	await _line("MC — NARRATION", "Neither word was large enough to hold everything I had done.", Color(0.7, 0.86, 1.0))
	await _show_image("day0_shot")
	await _line("MC — NARRATION", "I fired the first shot.\nThere was no lie in that.", Color(0.7, 0.86, 1.0))
	await _line("MC — NARRATION", "Everything that followed began with a choice I could never take back.", Color(0.7, 0.86, 1.0))
	await _line("MC — NARRATION", "I spent three days arranging the truth when my back was faced against lies.", Color(0.7, 0.86, 1.0))
	_black_screen()
	await _show_image("solidarity")
	await _line("MC — NARRATION", "The government gave the people stories so they would never speak to one another.", Color(0.7, 0.86, 1.0))
	await _line("MC — NARRATION", "In the end, the stories failed. The people stepped outside. They began searching for a sense of solidarity.", Color(0.7, 0.86, 1.0))
	await _line("MC", "Holding each other close, and united, confiscating their destiny and future.", Color(0.7, 0.86, 1.0))
	await _line("MC — NARRATION", "And the city began speaking for itself.", Color(0.7, 0.86, 1.0), 1.7)


	_black_screen()
	await _centered_card("Oroboros Route", 1.8)


func _play_shoot() -> void:
	shoot_stinger.play()
	red_drift.emitting = true
	await _show_tv_scene()
	television_static.play()
	_set_tv_story("news_podium")
	await _line("REPORTER", "The Opposition Peace Leader was assassinated today by a radical member of their own movement.", Color.WHITE)
	_set_tv_story("arrests")
	await _line("REPORTER", "Authorities believe violent divisions within the Opposition led to the attack.", Color.WHITE)
	_set_tv_story("news_military")
	await _line("REPORTER", "The military has assumed emergency control to restore order.", Color.WHITE)
	await _line("REPORTER", "Citizens are instructed to remain indoors.", Color.WHITE)
	television_static.stop()
	_black_screen()
	red_drift.emitting = false
	await _hold(2.0)
	await _line("MC — NARRATION", "Like cowards, we fled to another country.", Color(0.7, 0.86, 1.0))
	await _show_image("passports")
	await _line("MC — NARRATION", "All it took for the government was a helicopter and false passports. It’s honestly laughable how easy it all was.", Color(0.7, 0.86, 1.0), 1.4)
	await _line("MC — NARRATION", "I turn to the television.", Color(0.7, 0.86, 1.0))
	await _show_tv_scene()
	television_static.play()
	_set_tv_story("news_unrest")
	await _line("REPORTER — TELEVISION", "Necessary force was used against armed rioters.", Color.WHITE)
	_set_tv_story("news_military")
	await _line("REPORTER — TELEVISION", "Enemy sympathizers have attacked government supply routes.", Color.WHITE)
	await _line("REPORTER — TELEVISION", "Order will soon be restored.", Color.WHITE)
	television_static.stop()
	await _show_image("television")
	await _line("MC — NARRATION", "They kept their promise, and my family survived.", Color(0.7, 0.86, 1.0))
	await _line("MC — NARRATION", "The Opposition fractured, and the soldiers went to the streets. Hunger became riots, and riots became war.", Color(0.7, 0.86, 1.0), 1.45)
	await _line("MC — NARRATION", "Every report used words I had given them.", Color(0.7, 0.86, 1.0))
	await _line("MC — NARRATION", "I saved the people inside this apartment, and I destroyed the only person who might have saved everyone outside it.", Color(0.7, 0.86, 1.0), 1.6)
	_black_screen()
	await _centered_card("And Now, Today’s News.", 1.8)
	await _centered_card("Running away from Consequences Route", 1.8)


func _line(speaker: String, text: String, color: Color, hold_multiplier := 1.0) -> void:
	line_started.emit(speaker, text)
	var television_line := tv_broadcast.visible and "TELEVISION" in speaker
	if television_line:
		tv_broadcast.set_talking(true)
		tv_broadcast.pulse_interference()
	caption.clear()
	caption.add_theme_color_override(&"default_color", color)
	caption.text = text
	_apply_caption_box_style(speaker)
	_layout_caption_panel(speaker, text)
	caption_panel.visible = true
	caption.visible_characters = -1 if instant_mode else 0
	_skip_typewriter = false
	_skip_hold = false
	if not instant_mode:
		var total := caption.get_total_character_count()
		for index in range(total + 1):
			if _skip_typewriter:
				break
			caption.visible_characters = index
			if index > 0 and index % 4 == 0:
				dialogue_blip.pitch_scale = randf_range(0.985, 1.015)
				dialogue_blip.play()
			await get_tree().create_timer(0.026 * timing_scale).timeout
		caption.visible_characters = -1
	await _hold(0.9 * hold_multiplier)
	if television_line:
		tv_broadcast.set_talking(false)
	caption_panel.visible = false


func _apply_caption_box_style(speaker: String) -> void:
	if _default_caption_style == null:
		return
	var active_style := _default_caption_style.duplicate() as StyleBoxFlat
	if speaker.begins_with("GOVERNMENT"):
		active_style.bg_color = Color(0.13, 0.008, 0.024, 0.95)
		active_style.border_color = Color(0.96, 0.12, 0.2, 0.94)
		active_style.shadow_color = Color(0.96, 0.02, 0.08, 0.3)
		active_style.shadow_size = 8
	caption_panel.add_theme_stylebox_override(&"panel", active_style)


func _layout_caption_panel(_speaker: String, text: String) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var font_size := 22.0
	var maximum_width := minf(920.0, viewport_size.x - 96.0)
	var minimum_width := minf(420.0, maximum_width)
	var estimated_single_line_width := 56.0 + float(text.length()) * font_size * 0.52
	var width := clampf(estimated_single_line_width, minimum_width, maximum_width)
	var characters_per_line := maxf(24.0, (width - 56.0) / (font_size * 0.52))
	var body_lines := maxi(1, ceili(float(text.length()) / characters_per_line))
	var height := clampf(38.0 + float(body_lines) * 29.0, 92.0, 190.0)
	caption_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	caption.custom_minimum_size = Vector2(width - 56.0, height - 34.0)
	caption_panel.custom_minimum_size = Vector2(width, height)
	caption_panel.size = Vector2(width, height)
	caption_panel.position = Vector2((viewport_size.x - width) * 0.5, viewport_size.y - height - 28.0)


func _show_image(key: String) -> void:
	image_shown.emit(key)
	center_card.visible = false
	placeholder.visible = false
	tv_broadcast.visible = false
	image.texture = load(CG[key])
	_begin_cg_parallax()
	image.modulate.a = 0.0
	create_tween().tween_property(image, "modulate:a", 1.0, 0.28 * timing_scale)
	await _hold(0.45)


func _show_tv_scene() -> void:
	image_shown.emit("tv_broadcast")
	center_card.visible = false
	placeholder.visible = false
	image.texture = load(CG["tv_backdrop"])
	# The broadcast overlay is fitted precisely to the painted television glass,
	# so keep the apartment backdrop fixed while this composite is visible.
	_end_cg_parallax()
	image.position = Vector2.ZERO
	image.scale = Vector2.ONE
	image.modulate.a = 0.0
	tv_broadcast.visible = true
	tv_broadcast.modulate.a = 0.0
	var reveal := create_tween().set_parallel(true)
	reveal.tween_property(image, "modulate:a", 1.0, 0.35 * timing_scale)
	reveal.tween_property(tv_broadcast, "modulate:a", 1.0, 0.42 * timing_scale)
	await _hold(0.55)


func _set_tv_story(key: String) -> void:
	if not CG.has(key):
		return
	tv_story_shown.emit(key)
	tv_broadcast.set_story_image(load(CG[key]))


func _placeholder(title: String) -> void:
	_end_cg_parallax()
	image.modulate.a = 0.0
	tv_broadcast.visible = false
	placeholder_label.text = title + "\n\nNAMED REPLACEMENT SLOT"
	placeholder.visible = true
	await _hold(0.85)


func _black_screen() -> void:
	_end_cg_parallax()
	image.modulate.a = 0.0
	tv_broadcast.visible = false
	placeholder.visible = false
	caption_panel.visible = false
	center_card.visible = false


func _centered_card(text: String, seconds := 1.8) -> void:
	center_card_shown.emit(text)
	_black_screen()
	center_title.text = text
	center_card.modulate.a = 0.0
	center_card.visible = true
	create_tween().tween_property(center_card, "modulate:a", 1.0, 0.35 * timing_scale)
	await _hold(seconds)
	if center_card.visible:
		var fade_card := create_tween().tween_property(center_card, "modulate:a", 0.0, 0.3 * timing_scale)
		await fade_card.finished
	center_card.visible = false


func _offscreen_shot() -> void:
	caption_panel.visible = false
	image_shown.emit("mc_shot_impact")
	image.texture = load(CG["mc_shot_impact"])
	_begin_cg_parallax()
	image.modulate.a = 0.0
	gunshot.play()
	flash.color = Color.WHITE
	flash.modulate.a = 1.0
	if instant_mode:
		image.modulate.a = 0.0
		flash.modulate.a = 0.0
		body_fall.play()
		await get_tree().process_frame
		_end_cg_parallax()
		return
	var impact_reveal := create_tween().set_parallel(true)
	impact_reveal.tween_property(flash, "modulate:a", 0.0, 0.16 * timing_scale)
	impact_reveal.tween_property(image, "modulate:a", 1.0, 0.18 * timing_scale)
	await _hold(0.2)
	body_fall.play()
	await _hold(0.62)
	var impact_fade := create_tween()
	impact_fade.tween_property(image, "modulate:a", 0.0, 0.42 * timing_scale)
	await impact_fade.finished
	_end_cg_parallax()


func _assassination_shot() -> void:
	gunshot.play()
	crowd.play()
	siren.play()
	_flash_screen()
	Engine.time_scale = 0.08
	await get_tree().create_timer(0.045, true, false, true).timeout
	Engine.time_scale = 1.0
	await _hold(0.55)


func _flash_screen() -> void:
	flash.color = Color.WHITE
	flash.modulate.a = 1.0
	create_tween().tween_property(flash, "modulate:a", 0.0, 0.22)


func _hold(seconds: float) -> void:
	if instant_mode:
		return
	var elapsed := 0.0
	while elapsed < seconds * timing_scale and not _skip_hold:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_skip_hold = false


func _start_route_music(which_route: StringName, fade_seconds := 3.5) -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method(&"start_day3_route_music"):
		route_music = session.start_day3_route_music(which_route, fade_seconds)
		return
	if route_music.playing:
		return
	var target_volume := -10.5
	if which_route == NOT_SHOOT:
		route_music.stream = load("res://assets/audio/day3/music/credits-song-for-my-death.mp3")
	else:
		route_music.stream = load("res://assets/audio/day3/music/credits-song-final-boss.mp3")
		target_volume = -16.0
	if route_music.stream is AudioStreamMP3:
		(route_music.stream as AudioStreamMP3).loop = true
	route_music.volume_db = -36.0 if fade_seconds > 0.0 else target_volume
	route_music.play()
	if fade_seconds > 0.0:
		create_tween().tween_property(route_music, "volume_db", target_volume, fade_seconds)


func _play_credits() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.save_checkpoint("day3_credits")
	caption_panel.visible = false
	center_card.visible = false
	placeholder.visible = false
	_end_cg_parallax()
	image.modulate.a = 0.0
	tv_broadcast.visible = false
	credits.visible = true
	# Normal endings keep the already-playing route track and its playback
	# position. A direct credits checkpoint has no live player to inherit, so
	# this same call restores the correct route with a short entrance.
	_start_route_music(route, 0.75)
	var route_heading := "Oroboros Route" if route == NOT_SHOOT else "Running away from Consequences Route"
	credits_text.text = route_heading + "\n\n" + "\n".join(CREDITS)
	credits_text.position.y = 760.0
	credits_hint.modulate.a = 0.0
	_credits_active = true
	if instant_mode:
		await get_tree().process_frame
		_finish_to_menu()
		return
	await get_tree().create_timer(2.0 * timing_scale).timeout
	_credits_skip_armed = true
	create_tween().tween_property(credits_hint, "modulate:a", 1.0, 0.4)
	var scroll := create_tween()
	scroll.tween_property(credits_text, "position:y", -credits_text.size.y - 120.0, 32.0 * timing_scale)
	await scroll.finished
	if is_inside_tree():
		_finish_to_menu()


func _begin_cg_parallax() -> void:
	_cg_origin = Vector2.ZERO
	image.position = _cg_origin
	image.pivot_offset = image.size * 0.5
	image.scale = CG_PARALLAX_SCALE
	_cg_parallax_active = true


func _end_cg_parallax() -> void:
	_cg_parallax_active = false
	image.position = _cg_origin
	image.scale = Vector2.ONE


func _finish_to_menu() -> void:
	if _ending_done:
		return
	_ending_done = true
	_credits_active = false
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.complete_day3()
	ending_completed.emit(route)
	if not auto_return_to_menu:
		return
	if session != null and session.has_method(&"stop_day3_route_music"):
		session.stop_day3_route_music(1.2)
	var transition := get_node_or_null("/root/SceneTransition")
	if transition != null and not transition.busy:
		transition.transition_to(MAIN_MENU, false)
	else:
		get_tree().change_scene_to_file(MAIN_MENU)
