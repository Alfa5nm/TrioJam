class_name SpectrumLightFlicker
extends Node

@export var light_path: NodePath
@export var beam_paths: Array[NodePath] = []
@export var audio_bus := &"Electrical"
@export var base_energy := 0.58
@export var minimum_energy := 0.2
@export var response_speed := 18.0

var _light: PointLight2D
var _beams: Array[CanvasItem] = []
var _spectrum: AudioEffectSpectrumAnalyzerInstance
var _smoothed_level := 0.65


func _ready() -> void:
	_light = get_node_or_null(light_path) as PointLight2D
	for path in beam_paths:
		var beam := get_node_or_null(path) as CanvasItem
		if beam != null:
			_beams.append(beam)
	var bus_index := AudioServer.get_bus_index(audio_bus)
	if bus_index >= 0:
		_spectrum = AudioServer.get_bus_effect_instance(bus_index, 0) as AudioEffectSpectrumAnalyzerInstance


func _process(delta: float) -> void:
	if _light == null:
		return
	var target_level := 0.72
	if _spectrum != null:
		var mains := _band_level(45.0, 78.0)
		var buzz := _band_level(90.0, 260.0)
		var crackle := _band_level(1500.0, 6000.0)
		target_level = clampf(0.48 + mains * 0.34 + buzz * 0.24 - crackle * 0.16, 0.0, 1.0)
	_smoothed_level = lerpf(_smoothed_level, target_level, 1.0 - exp(-response_speed * delta))
	_light.energy = lerpf(minimum_energy, base_energy, _smoothed_level)
	for beam in _beams:
		beam.modulate.a = lerpf(0.34, 0.82, _smoothed_level)


func _band_level(from_hz: float, to_hz: float) -> float:
	var magnitude := _spectrum.get_magnitude_for_frequency_range(from_hz, to_hz).length()
	var decibels := linear_to_db(maxf(magnitude, 0.000001))
	return clampf(inverse_lerp(-62.0, -20.0, decibels), 0.0, 1.0)
