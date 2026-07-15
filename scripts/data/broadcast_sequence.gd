class_name BroadcastSequence
extends Resource

@export var headline := ""

## Reporter narration played back line-by-line after a successful broadcast.
@export var broadcast_lines: Array[String] = []
## Parallel to broadcast_lines: which frame (0=cause, 1=conflict, 2=outcome, -1=none) each line highlights.
@export var broadcast_line_frames: Array[int] = []

@export var cause_characters: Array[CharacterDef] = []
@export var cause_action: ActionDef

@export var conflict_characters: Array[CharacterDef] = []
@export var conflict_action: ActionDef

@export var outcome_characters: Array[CharacterDef] = []
@export var outcome_action: ActionDef


func matches(placed: Array[ShotElement]) -> bool:
	if placed.size() != 3:
		return false
	return (
		_slot_matches(placed[0], cause_characters, cause_action)
		and _slot_matches(placed[1], conflict_characters, conflict_action)
		and _slot_matches(placed[2], outcome_characters, outcome_action)
	)


func _slot_matches(shot: ShotElement, characters: Array[CharacterDef], action: ActionDef) -> bool:
	if shot == null:
		return false
	var expected := ShotElement.new(characters, action)
	return shot.matches(expected)
