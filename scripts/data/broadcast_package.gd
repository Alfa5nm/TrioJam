class_name BroadcastPackage
extends Resource

@export var report_id: StringName = &""
@export var headline := ""
@export var action_ids: Array[StringName] = []
@export var character_ids: Array = []


static func from_sequence(report_id_value: StringName, sequence: BroadcastSequence) -> BroadcastPackage:
	var package := BroadcastPackage.new()
	package.report_id = report_id_value
	package.headline = sequence.headline
	for shot in sequence.shots():
		package.action_ids.append(shot.action.id if shot.action != null else &"")
		var ids: Array[StringName] = []
		for character in shot.characters:
			ids.append(character.id)
		package.character_ids.append(ids)
	return package
