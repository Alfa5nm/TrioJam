class_name BroadcastReport
extends Resource

@export var report_id: StringName = &""
@export var directive_text := ""
@export var characters: Array[CharacterDef] = []
@export var available_actions: Array[ActionDef] = []
@export var truthful_sequence: BroadcastSequence
@export var propaganda_sequence: BroadcastSequence


func find_matching_sequence(placed: Array[ShotElement]) -> BroadcastSequence:
	if truthful_sequence != null and truthful_sequence.matches(placed):
		return truthful_sequence
	if propaganda_sequence != null and propaganda_sequence.matches(placed):
		return propaganda_sequence
	return null
