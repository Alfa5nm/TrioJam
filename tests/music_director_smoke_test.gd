extends SceneTree

const SUPPLIED_CUES: Array[StringName] = [
	&"broadcast_gameplay", &"broadcast", &"end_day12", &"soldier_civilian",
	&"chaotic_music", &"night_ambient", &"rally_music", &"end_day3",
	&"gun_reveal", &"day3_not_shoot", &"day3_shoot",
]

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("MUSIC_DIRECTOR_TEST_START")
	var director := root.get_node_or_null("MusicDirector")
	_check(director != null, "persistent MusicDirector autoload exists")
	if director == null:
		quit(failures)
		return
	for cue in SUPPLIED_CUES:
		_check(director.has_cue(cue), "supplied cue is registered: %s" % cue)
	_check(director.has_cue(&"day1_bg"), "Day_1_BG is registered")
	_check(String(director.CUES[&"chaotic_music"]["path"]).ends_with("Chaotic_Music_mixed.ogg") and is_equal_approx(float(director.CUES[&"chaotic_music"]["gain"]), -1.5), "chaotic cue uses the EQ-balanced priority master")
	var gameplay_player: AudioStreamPlayer = director.play_cue(&"broadcast_gameplay", 0.0, true)
	_check(gameplay_player != null and gameplay_player.playing, "gameplay score starts")
	_check(director.current_cue() == &"broadcast_gameplay", "active cue is tracked")
	_check(gameplay_player.stream is AudioStreamMP3 and (gameplay_player.stream as AudioStreamMP3).loop, "gameplay score loops")
	_check(not director.has_cue(&"credits"), "shared credits cue is removed from active runtime selection")
	_check(FileAccess.file_exists("res://assets/audio/music/scripted/Credits.mp3"), "unused shared credits asset remains in the project")
	var death_route_player: AudioStreamPlayer = director.play_cue(&"day3_not_shoot", 0.0, true)
	_check(death_route_player != null and death_route_player.playing, "NOT SHOOT route score starts")
	_check(death_route_player.stream is AudioStreamMP3 and (death_route_player.stream as AudioStreamMP3).loop, "NOT SHOOT route score loops through credits")
	var inherited_player: AudioStreamPlayer = director.play_cue(&"day3_not_shoot", 0.75)
	_check(inherited_player == death_route_player, "credits boundary inherits the same NOT SHOOT player without restart")
	var shoot_route_player: AudioStreamPlayer = director.play_cue(&"day3_shoot", 0.0, true)
	_check(shoot_route_player.stream is AudioStreamMP3 and (shoot_route_player.stream as AudioStreamMP3).loop, "SHOOT route score loops through credits")
	var rally: Node = (load("res://scenes/Day 2/day2_peace_rally.tscn") as PackedScene).instantiate()
	_check(rally.get_node("Audio/RallyAmbience").stream.resource_path.ends_with("Crowd.mp3"), "Day 2 uses supplied crowd ambience")
	_check(rally.get_node("Audio/BombBeep").stream.resource_path.ends_with("Beep.wav"), "Day 2 uses supplied bomb warning")
	_check(rally.get_node("Audio/ReporterSFX").stream.resource_path.ends_with("Reporter_SFX.wav"), "Day 2 uses supplied reporter loop")
	rally.free()
	director.stop_cue(0.0)
	if failures == 0:
		print("MUSIC_DIRECTOR_TEST_PASS")
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: %s" % message)
