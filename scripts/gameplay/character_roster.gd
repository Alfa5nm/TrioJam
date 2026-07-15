class_name CharacterRoster
extends PanelContainer

const CHARACTER_CHIP_SCENE := preload("res://scenes/gameplay/character_chip.tscn")

@onready var chip_grid: GridContainer = $Margin/Layout/ChipGrid


func setup(characters: Array[CharacterDef]) -> void:
	for child in chip_grid.get_children():
		child.queue_free()
	for character in characters:
		var chip := CHARACTER_CHIP_SCENE.instantiate() as CharacterChip
		chip_grid.add_child(chip)
		chip.setup(character)
