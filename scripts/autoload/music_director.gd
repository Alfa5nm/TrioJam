extends Node

## Persistent soundtrack controller. Scripted score cues survive scene changes and
## crossfade through two players; environmental layers remain owned by scenes.

const DEFAULT_FADE := 0.75
const SILENT_DB := -40.0

const CUES := {
	# Gains compensate for the widely different masters while keeping dialogue
	# clear. Most score sits around -20 to -24 LUFS; priority dramatic cues such
	# as Chaotic Music intentionally sit a few dB forward.
	&"broadcast_gameplay": {"path": "res://assets/audio/music/scripted/Broadcast_Gameplay.mp3", "loop": true, "gain": 0.0},
	&"broadcast": {"path": "res://assets/audio/music/scripted/Broadcast.mp3", "loop": true, "gain": -9.5},
	&"end_day12": {"path": "res://assets/audio/music/scripted/End_Day12.mp3", "loop": true, "gain": 7.5},
	&"day1_bg": {"path": "res://assets/audio/music/scripted/Day_1_BG.mp3", "loop": true, "gain": 4.0},
	&"soldier_civilian": {"path": "res://assets/audio/music/scripted/Soldier_Civilian.mp3", "loop": false, "gain": -9.5},
	&"chaotic_music": {"path": "res://assets/audio/music/scripted/Chaotic_Music_mixed.ogg", "loop": true, "gain": -1.5},
	&"night_ambient": {"path": "res://assets/audio/music/scripted/Night_Ambient.mp3", "loop": true, "gain": 4.0},
	&"rally_music": {"path": "res://assets/audio/music/scripted/Rally_Music.mp3", "loop": true, "gain": -7.5},
	&"end_day3": {"path": "res://assets/audio/music/scripted/End_Day3.mp3", "loop": false, "gain": 2.0},
	&"gun_reveal": {"path": "res://assets/audio/music/scripted/Gun_Reveal.mp3", "loop": true, "gain": 5.5},
	&"day3_not_shoot": {"path": "res://assets/audio/day3/music/credits-song-for-my-death.mp3", "loop": true, "gain": -5.5},
	&"day3_shoot": {"path": "res://assets/audio/day3/music/credits-song-final-boss.mp3", "loop": true, "gain": -11.0},
}

var _players: Array[AudioStreamPlayer] = []
var _active_index := 0
var _current_cue: StringName = &""
var _fade_tween: Tween


func _ready() -> void:
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.name = "MusicLane%d" % (index + 1)
		player.bus = &"Ambience"
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)


func has_cue(cue: StringName) -> bool:
	if not CUES.has(cue):
		return false
	var path := String(CUES[cue].get("path", ""))
	return not path.is_empty() and ResourceLoader.exists(path)


func play_cue(cue: StringName, fade_seconds := DEFAULT_FADE, restart := false) -> AudioStreamPlayer:
	if not has_cue(cue):
		push_warning("Music cue '%s' has no assigned asset yet." % cue)
		return null
	if _current_cue == cue and active_player().playing and not restart:
		return active_player()
	_kill_fade()
	var old_player := active_player()
	var old_was_playing := old_player.playing
	var next_index := 1 - _active_index if old_was_playing else _active_index
	var next_player := _players[next_index]
	if next_player != old_player:
		next_player.stop()
	_configure_player(next_player, cue)
	var target_db := float(CUES[cue].get("gain", -12.0))
	next_player.volume_db = SILENT_DB if fade_seconds > 0.0 else target_db
	next_player.play()
	_active_index = next_index
	_current_cue = cue
	if fade_seconds <= 0.0:
		if old_player != next_player:
			old_player.stop()
		return next_player
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(next_player, "volume_db", target_db, fade_seconds)
	if old_was_playing and old_player != next_player:
		_fade_tween.tween_property(old_player, "volume_db", SILENT_DB, fade_seconds)
		_fade_tween.finished.connect(func():
			if is_instance_valid(old_player) and old_player != active_player():
				old_player.stop()
		)
	return next_player


func stop_cue(fade_seconds := DEFAULT_FADE) -> void:
	_kill_fade()
	_current_cue = &""
	var player := active_player()
	for other_player in _players:
		if other_player != player and other_player.playing:
			other_player.stop()
	if not player.playing:
		return
	if fade_seconds <= 0.0:
		player.stop()
		player.volume_db = SILENT_DB
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(player, "volume_db", SILENT_DB, fade_seconds)
	_fade_tween.finished.connect(func():
		if is_instance_valid(player) and player == active_player() and _current_cue.is_empty():
			player.stop()
	)


func active_player() -> AudioStreamPlayer:
	if _players.is_empty():
		return null
	return _players[_active_index]


func current_cue() -> StringName:
	return _current_cue


func _configure_player(player: AudioStreamPlayer, cue: StringName) -> void:
	var data: Dictionary = CUES[cue]
	var stream := load(String(data["path"])) as AudioStream
	_set_loop(stream, bool(data.get("loop", false)))
	player.stream = stream
	player.bus = &"Ambience"


func _set_loop(stream: AudioStream, enabled: bool) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = enabled
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = enabled
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if enabled else AudioStreamWAV.LOOP_DISABLED


func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
