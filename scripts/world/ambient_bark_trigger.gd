class_name AmbientBarkTrigger
extends Area2D

signal bark_started
signal bark_finished

@export var dialogue_path: NodePath
@export var speaker_name := "Civilian"
@export_multiline var dialogue_text := "..."
@export_range(0.1, 5.0, 0.05) var hold_seconds := 1.15
@export var blip_stream: AudioStream
@export var visual_texture: Texture2D
@export var visual_position := Vector2(0.0, -128.0)
@export var visual_scale := Vector2(0.92, 0.92)
@export var visual_flip_h := false

@onready var dialogue_anchor: Node2D = $DialogueAnchor
@onready var trigger_shape: CollisionShape2D = $TriggerShape
@onready var placeholder_visual: Sprite2D = $PlaceholderVisual

var has_triggered := false
var _dialogue: CinematicDialogue


func _ready() -> void:
	_dialogue = get_node_or_null(dialogue_path) as CinematicDialogue
	placeholder_visual.texture = visual_texture
	placeholder_visual.visible = visual_texture != null
	placeholder_visual.position = visual_position
	placeholder_visual.scale = visual_scale
	placeholder_visual.flip_h = visual_flip_h
	body_entered.connect(_on_body_entered)


func trigger_bark() -> void:
	if has_triggered or _dialogue == null:
		return
	has_triggered = true
	set_deferred(&"monitoring", false)
	trigger_shape.set_deferred(&"disabled", true)
	bark_started.emit()
	while is_instance_valid(_dialogue) and _dialogue.is_presenting:
		await get_tree().process_frame
	if not is_instance_valid(_dialogue):
		return
	await _dialogue.show_bark(dialogue_text, speaker_name, dialogue_anchor, hold_seconds, blip_stream)
	bark_finished.emit()


func _on_body_entered(body: Node) -> void:
	if body is Player:
		trigger_bark()
