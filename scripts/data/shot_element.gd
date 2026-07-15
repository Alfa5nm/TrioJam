class_name ShotElement
extends RefCounted

var characters: Array[CharacterDef] = []
var action: ActionDef


func _init(p_characters: Array[CharacterDef] = [], p_action: ActionDef = null) -> void:
	characters = p_characters
	action = p_action


func phrase() -> String:
	if not is_complete():
		return "?"
	var name_text := ""
	for i in characters.size():
		if i > 0:
			name_text += " & "
		name_text += characters[i].display_name
	return "%s · %s" % [name_text, action.display_name]


func is_complete() -> bool:
	return action != null and not characters.is_empty()


func matches(other: ShotElement) -> bool:
	if other == null or not is_complete() or not other.is_complete():
		return false
	if action.id != other.action.id:
		return false
	if characters.size() != other.characters.size():
		return false
	var self_ids: Array = characters.map(func(c: CharacterDef): return c.id)
	var other_ids: Array = other.characters.map(func(c: CharacterDef): return c.id)
	self_ids.sort()
	other_ids.sort()
	return self_ids == other_ids


func has_character(character: CharacterDef) -> bool:
	for existing in characters:
		if existing.id == character.id:
			return true
	return false
