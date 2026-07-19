class_name Day1GossipConversation
extends Area2D

signal conversation_started
signal line_started(speaker_name: String, text: String)
signal conversation_finished

@export var dialogue_path: NodePath
@export var enabled_on_ready := false
@export_range(0.1, 5.0, 0.05) var hold_seconds := 1.25

@onready var trigger_shape: CollisionShape2D = $TriggerShape
@onready var civilian_1_anchor: Node2D = $Civilian1Anchor
@onready var civilian_2_anchor: Node2D = $Civilian2Anchor

var has_triggered := false
var is_armed := false
var _dialogue: CinematicDialogue


func _ready() -> void:
	_dialogue = get_node_or_null(dialogue_path) as CinematicDialogue
	body_entered.connect(_on_body_entered)
	if enabled_on_ready:
		arm()
	else:
		visible = false
		_set_trigger_enabled(false)


func arm() -> void:
	visible = true
	is_armed = not has_triggered
	_set_trigger_enabled(is_armed)


func trigger_conversation() -> void:
	if not is_armed or has_triggered or _dialogue == null:
		return
	has_triggered = true
	is_armed = false
	_set_trigger_enabled(false)
	conversation_started.emit()

	while is_instance_valid(_dialogue) and _dialogue.is_presenting:
		await get_tree().process_frame
	if not is_instance_valid(_dialogue):
		return

	await _say("Civilian 1", "That poor boy got shot…", civilian_1_anchor)
	await _say("Civilian 2", "It’s all that report’s fault!", civilian_2_anchor)
	conversation_finished.emit()


func _say(speaker_name: String, text: String, anchor: Node2D) -> void:
	line_started.emit(speaker_name, text)
	await _dialogue.show_bark(text, speaker_name, anchor, hold_seconds)


func _set_trigger_enabled(enabled: bool) -> void:
	set_deferred(&"monitoring", enabled)
	trigger_shape.set_deferred(&"disabled", not enabled)


func _on_body_entered(body: Node) -> void:
	if body is Player:
		trigger_conversation()
