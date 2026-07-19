class_name Day1OccupationStandoff
extends Node2D

@export_range(0.0, 4.0, 0.1) var idle_bob_height := 1.4
@export_range(0.1, 3.0, 0.05) var idle_bob_speed := 1.15

@onready var crowd_ambience: AudioStreamPlayer2D = $CrowdAmbience

var _elapsed := 0.0
var _protesters: Array[Sprite2D] = []
var _base_positions: Array[Vector2] = []


func _ready() -> void:
	for node in $Protesters.get_children():
		var protester := node as Sprite2D
		if protester == null:
			continue
		_protesters.append(protester)
		_base_positions.append(protester.position)
		protester.flip_h = false
	for node in $Soldiers.get_children():
		var soldier := node as Sprite2D
		if soldier != null:
			soldier.flip_h = true
	if crowd_ambience.stream is AudioStreamMP3:
		(crowd_ambience.stream as AudioStreamMP3).loop = true
	if crowd_ambience.stream != null:
		crowd_ambience.play()


func _process(delta: float) -> void:
	_elapsed += delta
	for index in range(_protesters.size()):
		var phase := _elapsed * idle_bob_speed + float(index) * 0.73
		_protesters[index].position.y = _base_positions[index].y + sin(phase) * idle_bob_height
