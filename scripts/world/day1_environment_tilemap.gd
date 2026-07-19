extends TileMapLayer


func _ready() -> void:
	# The restored legacy map contains two superseded antenna/vine placements that
	# Godot 4.6 preserves instead of collapsing. Remove those duplicate props so
	# the authored 22-cell composition remains stable across engine versions.
	erase_cell(Vector2i(19, 9))
	erase_cell(Vector2i(23, 9))
