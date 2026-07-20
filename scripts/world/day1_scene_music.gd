extends Node

## Starts the daytime street bed. Encounter controllers take over at the
## checkpoint and depot beats, then return to this cue between crises.


func _ready() -> void:
	var music_director := get_node_or_null("/root/MusicDirector")
	if music_director != null:
		music_director.play_cue(&"day1_bg", 0.8)
