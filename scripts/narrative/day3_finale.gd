class_name Day3Finale
extends Control

signal ending_started(route: StringName)
signal ending_completed(route: StringName)

const NOT_SHOOT := &"not_shoot"
const SHOOT := &"shoot"
const MAIN_MENU := "res://scenes/menu/main_menu.tscn"

const CG := {
	"gun_a": "res://assets/art/Day3/gun-command-a.png",
	"gun_b": "res://assets/art/Day3/gun-command-b.png",
	"leader": "res://assets/art/Day3/peace-leader-podium.png",
	"dead_mc": "res://assets/art/Day3/mc-dead-armband.png",
	"television": "res://assets/art/Day3/television-aftermath.png",
	"tv_backdrop": "res://assets/art/Day3/foreign-apartment-tv-backdrop.png",
	"assassination": "res://assets/art/Day3/assassination-aftermath-placeholder.png",
	"arrests": "res://assets/art/Day3/opposition-arrests-placeholder.png",
	"passports": "res://assets/art/Day3/false-passports-placeholder.png",
	"helicopter": "res://assets/art/Day3/helicopter-escape-placeholder.png",
	"solidarity": "res://assets/art/Day3/solidarity-montage.png",
	"day0_shot": "res://assets/art/ui/broadcast/scene_rooftop_shoots.png",
}

const CREDITS := [
	"DAY 3 — THE REPORTS HAVE ALREADY DECIDED",
	"",
	"Design and Lead Artist — Tasnuva (Raye)",
	"",
	"Audio Design, Level Design, Side-Scroll Technical Lead, E2E Polish — Farid",
	"",
	"Broadcast UI Interface Mechanics and Routing Mechanics — Akib",
	"",
	"“credits song for my death” — vivivivivi",
	"",
	"“credits song for my death but im the final boss.” — Astron",
	"",
	"Permission granted by safeinyrskin",
	"",
	"Thank you for playing.",
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

@onready var image: TextureRect = $Image
@onready var tv_broadcast: Day3TVBroadcast = $TVBroadcast
@onready var grade: ColorRect = $Grade
@onready var flash: ColorRect = $Flash
@onready var placeholder: PanelContainer = $Placeholder
@onready var placeholder_label: Label = $Placeholder/Label
@onready var caption_panel: PanelContainer = $CaptionPanel
@onready var caption: RichTextLabel = $CaptionPanel/Caption
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


func _ready() -> void:
	caption_panel.visible = false
	placeholder.visible = false
	credits.visible = false
	flash.modulate.a = 0.0
	image.modulate.a = 0.0
	tv_broadcast.visible = false
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
			_start_route_music(route)
			_play_credits()
		else:
			play_finale()


func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept")):
		return
	if _credits_active and _credits_skip_armed:
		_finish_to_menu()
	elif caption.visible_characters >= 0 and caption.visible_characters < caption.get_total_character_count():
		_skip_typewriter = true
	else:
		_skip_hold = true


func play_finale() -> void:
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
	_start_route_music(NOT_SHOOT)
	await _show_image("solidarity")
	await _line("MC — NARRATION", "The government gave the people stories so they would never speak to one another.", Color(0.7, 0.86, 1.0))
	await _line("MC — NARRATION", "In the end, the stories failed. The people stepped outside. They began searching for a sense of solidarity.", Color(0.7, 0.86, 1.0))
	await _line("MC", "Holding each other close, and united, confiscating their destiny and future.", Color(0.7, 0.86, 1.0))
	await _line("MC — NARRATION", "And the city began speaking for itself.", Color(0.7, 0.86, 1.0), 1.7)


func _play_shoot() -> void:
	shoot_stinger.play()
	await _show_image("assassination")
	await _line("REPORTER", "The Opposition Peace Leader was assassinated today by a radical member of their own movement.", Color.WHITE)
	await _show_image("arrests")
	await _line("REPORTER", "Authorities believe violent divisions within the Opposition led to the attack.", Color.WHITE)
	await _line("REPORTER", "The military has assumed emergency control to restore order.", Color.WHITE)
	await _line("REPORTER", "Citizens are instructed to remain indoors.", Color.WHITE)
	_black_screen()
	await _line("MC — NARRATION", "Like cowards, we fled to another country.", Color(0.7, 0.86, 1.0))
	await _show_image("passports")
	await _line("MC — NARRATION", "All it took for the government was a helicopter and false passports. It’s honestly laughable how easy it all was.", Color(0.7, 0.86, 1.0), 1.4)
	await _show_image("helicopter")
	helicopter.play()
	await _hold(1.1)
	helicopter.stop()
	await _show_image("television")
	await _hold(0.7)
	await _show_tv_scene()
	television_static.play()
	await _line("REPORTER — TELEVISION", "Necessary force was used against armed rioters.", Color.WHITE)
	await _line("REPORTER — TELEVISION", "Enemy sympathizers have attacked government supply routes.", Color.WHITE)
	await _line("REPORTER — TELEVISION", "Order will soon be restored.", Color.WHITE)
	television_static.stop()
	_start_route_music(SHOOT)
	await _line("MC — NARRATION", "They kept their promise, and my family survived.", Color(0.7, 0.86, 1.0))
	await _line("MC — NARRATION", "The Opposition fractured, and the soldiers went to the streets. Hunger became riots, and riots became war.", Color(0.7, 0.86, 1.0), 1.45)
	await _line("MC — NARRATION", "Every report used words I had given them.", Color(0.7, 0.86, 1.0))
	await _line("MC — NARRATION", "I saved the people inside this apartment, and I destroyed the only person who might have saved everyone outside it.", Color(0.7, 0.86, 1.0), 1.6)
	_black_screen()
	await _line("", "And Now, Today’s News.", Color.WHITE, 1.8)


func _line(speaker: String, text: String, color: Color, hold_multiplier := 1.0) -> void:
	var television_line := tv_broadcast.visible and "TELEVISION" in speaker
	if television_line:
		tv_broadcast.set_talking(true)
		tv_broadcast.pulse_interference()
	caption_panel.visible = true
	caption.clear()
	var heading := "" if speaker.is_empty() else "[color=#%s][b]%s[/b][/color]\n" % [color.to_html(false), speaker]
	caption.text = heading + text
	caption.visible_characters = -1 if instant_mode else 0
	_skip_typewriter = false
	_skip_hold = false
	if not instant_mode:
		var total := caption.get_total_character_count()
		for index in range(total + 1):
			if _skip_typewriter:
				break
			caption.visible_characters = index
			await get_tree().create_timer(0.026 * timing_scale).timeout
		caption.visible_characters = -1
	await _hold(0.9 * hold_multiplier)
	if television_line:
		tv_broadcast.set_talking(false)


func _show_image(key: String) -> void:
	placeholder.visible = false
	tv_broadcast.visible = false
	image.texture = load(CG[key])
	image.modulate.a = 0.0
	create_tween().tween_property(image, "modulate:a", 1.0, 0.28 * timing_scale)
	await _hold(0.45)


func _show_tv_scene() -> void:
	placeholder.visible = false
	image.texture = load(CG["tv_backdrop"])
	image.modulate.a = 0.0
	tv_broadcast.visible = true
	tv_broadcast.modulate.a = 0.0
	var reveal := create_tween().set_parallel(true)
	reveal.tween_property(image, "modulate:a", 1.0, 0.35 * timing_scale)
	reveal.tween_property(tv_broadcast, "modulate:a", 1.0, 0.42 * timing_scale)
	await _hold(0.55)


func _placeholder(title: String) -> void:
	image.modulate.a = 0.0
	tv_broadcast.visible = false
	placeholder_label.text = title + "\n\nNAMED REPLACEMENT SLOT"
	placeholder.visible = true
	await _hold(0.85)


func _black_screen() -> void:
	image.modulate.a = 0.0
	tv_broadcast.visible = false
	placeholder.visible = false
	caption_panel.visible = false


func _offscreen_shot() -> void:
	gunshot.play()
	_flash_screen()
	await _hold(0.18)
	body_fall.play()
	await _hold(0.75)


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


func _start_route_music(which_route: StringName) -> void:
	if route_music.playing:
		return
	if which_route == NOT_SHOOT:
		route_music.stream = load("res://assets/audio/day3/music/credits-song-for-my-death.mp3")
		route_music.volume_db = -36.0
		create_tween().tween_property(route_music, "volume_db", -10.5, 3.5)
	else:
		route_music.stream = load("res://assets/audio/day3/music/credits-song-final-boss.mp3")
		route_music.volume_db = -36.0
		create_tween().tween_property(route_music, "volume_db", -16.0, 3.5)
	route_music.play()


func _play_credits() -> void:
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		session.save_checkpoint("day3_credits")
	caption_panel.visible = false
	placeholder.visible = false
	image.modulate.a = 0.0
	tv_broadcast.visible = false
	credits.visible = true
	var credits_gain := -1.5 if route == NOT_SHOOT else -7.0
	create_tween().tween_property(route_music, "volume_db", credits_gain, 2.2)
	credits_text.text = "\n".join(CREDITS)
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
	var transition := get_node_or_null("/root/SceneTransition")
	if transition != null and not transition.busy:
		transition.transition_to(MAIN_MENU, false)
	else:
		get_tree().change_scene_to_file(MAIN_MENU)
