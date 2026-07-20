class_name BroadcastPackage
extends Resource

@export var report_id: StringName = &""
@export var headline := ""
@export var action_ids: Array[StringName] = []
@export var character_ids: Array = []


static func from_sequence(report_id_value: StringName, sequence: BroadcastSequence) -> BroadcastPackage:
	return from_shots(report_id_value, sequence.headline, sequence.shots())


## Captures the frames exactly as the player assembled them. Character IDs stay
## in placement order because several actions use that order to select poses.
static func from_shots(report_id_value: StringName, headline_value: String, shots: Array[ShotElement]) -> BroadcastPackage:
	var package := BroadcastPackage.new()
	package.report_id = report_id_value
	package.headline = headline_value
	for shot in shots:
		package.action_ids.append(shot.action.id if shot.action != null else &"")
		var ids: Array[StringName] = []
		for character in shot.characters:
			ids.append(character.id)
		package.character_ids.append(ids)
	return package
