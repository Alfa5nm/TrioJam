class_name BroadcastReport
extends Resource

@export var report_id: StringName = &""
@export var directive_text := ""
## Directive text split into short pages, shown one at a time via CONTINUE.
## Falls back to a single page of directive_text if left empty.
@export var intro_lines: Array[String] = []
## Parallel to intro_lines: which character portrait to show per page (e.g. &"government", &"mc").
## An empty StringName leaves the portrait untouched.
@export var intro_speakers: Array[StringName] = []
## Rich cinematic beats. When populated these replace intro_lines/intro_speakers.
@export var intro_beats: Array[BroadcastDialogueBeat] = []
## Maps a speaker id (as used in intro_speakers) to the portrait texture shown for them.
## These are separate from the puzzle roster's CharacterDef portraits — the intro
## can feature people (e.g. an interrogating government agent) who never appear in the roster.
@export var speaker_portraits: Dictionary = {}
@export var characters: Array[CharacterDef] = []
@export var available_actions: Array[ActionDef] = []
@export var max_characters_per_frame := 2
## Shown when BROADCAST is pressed but no sequence matches.
@export var mismatch_line := "The story doesn't hold together. Try a different arrangement."
@export var truthful_sequence: BroadcastSequence
@export var propaganda_sequence: BroadcastSequence


func find_matching_sequence(placed: Array[ShotElement]) -> BroadcastSequence:
	if truthful_sequence != null and truthful_sequence.matches(placed):
		return truthful_sequence
	if propaganda_sequence != null and propaganda_sequence.matches(placed):
		return propaganda_sequence
	return null
