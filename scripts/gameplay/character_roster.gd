class_name CharacterRoster
extends GridContainer

const CHARACTER_CHIP_SCENE := preload("res://scenes/gameplay/character_chip.tscn")


func setup(characters: Array[CharacterDef]) -> void:
	for child in get_children():
		child.queue_free()
	for character in characters:
		var chip := CHARACTER_CHIP_SCENE.instantiate() as CharacterChip
		add_child(chip)
		chip.setup(character)
