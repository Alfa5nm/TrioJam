class_name SceneFrame
extends PanelContainer

var current_action: ActionDef = null

var _available_actions: Array[ActionDef] = []
var _action_index := -1

@onready var scene_label: Label = $Margin/SceneLabel


func setup(available_actions: Array[ActionDef]) -> void:
	_available_actions = available_actions
	_action_index = -1
	current_action = null
	_refresh_visual()


func cycle_scene() -> void:
	if _available_actions.is_empty():
		return
	_action_index = (_action_index + 1) % _available_actions.size()
	current_action = _available_actions[_action_index]
	_refresh_visual()


func _refresh_visual() -> void:
	scene_label.text = current_action.display_name if current_action != null else "— click SCENE —"


func _get_drag_data(_at_position: Vector2) -> Variant:
	if current_action == null:
		return null
	set_drag_preview(_build_preview())
	return {"type": "broadcast_scene", "action": current_action}


func _build_preview() -> Control:
	var preview := Label.new()
	preview.text = current_action.display_name
	preview.add_theme_color_override("font_color", Color(0.878, 0.902, 0.949, 1))
	preview.modulate.a = 0.85
	return preview
