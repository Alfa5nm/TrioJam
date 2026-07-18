class_name BroadcastSequence
extends Resource

@export var headline := ""

## When true, a frame's character order must match exactly (first character is
## the actor/aggressor, second is the target) instead of just the same set of
## characters in any order. Used by reports where direction carries the story's
## meaning (e.g. who attacked whom).
@export var order_sensitive := false

## MC's personal reaction, shown first (before broadcast_lines, if any). No frame highlighting.
## Leave broadcast_lines empty to end here without a reporter recap (e.g. MC refuses to broadcast).
@export var reaction_lines: Array[String] = []

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


func shots() -> Array[ShotElement]:
	return [
		ShotElement.new(cause_characters, cause_action),
		ShotElement.new(conflict_characters, conflict_action),
		ShotElement.new(outcome_characters, outcome_action),
	]


func matches_slot(index: int, shot: ShotElement) -> bool:
	match index:
		0:
			return _slot_matches(shot, cause_characters, cause_action)
		1:
			return _slot_matches(shot, conflict_characters, conflict_action)
		2:
			return _slot_matches(shot, outcome_characters, outcome_action)
		_:
			return false


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
	return shot.matches(expected, order_sensitive)
