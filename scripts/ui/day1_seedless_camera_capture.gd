class_name Day1SeedlessCameraCapture
extends Day1CameraCapture

const PROTEST_FRAME := preload("res://assets/art/Day1 Scene 1/camera-cutscene/seedless/seedless-protest-recording.png")
const ARREST_FRAME := preload("res://assets/art/Day1 Scene 1/camera-cutscene/seedless/seedless-arrest-recording.png")
const CUSTOMER_FRAME := preload("res://assets/art/Day1 Scene 1/camera-cutscene/seedless/seedless-happy-customer-recording.png")


func begin_capture() -> void:
	if active:
		return
	active = true
	captured_frames = 0
	for preview in previews:
		preview.texture = null
	overlay.visible = true
	camera_chrome.visible = true
	caption_panel.visible = false
	frame_image.visible = true
	blackout.visible = false
	capture_started.emit()

	await _show_frame(PROTEST_FRAME, 1)
	await _line("Opposition Volunteer", "We are farmers! Customers cannot eat what we cannot afford to grow!", &"seedless_protest", 0.65, &"left")
	await _line("Crowd", "OUR LAND! OUR SEEDS!", &"seedless_protest", 0.6, &"center")
	await _line("Soldier", "Remain behind the barrier!", &"seedless_protest", 0.55, &"right")
	await _line("Soldier", "Step back!", &"seedless_protest", 0.5, &"right")

	await _show_frame(ARREST_FRAME, 2)
	await _line("Soldier", "You are under arrest for disrupting an authorized public event.", &"seedless_arrest", 0.65, &"right")
	await _line("Opposition Volunteer", "This is not a public event!", &"seedless_arrest", 0.55, &"left")
	await _line("Soldier", "Do not resist! Fires will be shot for resisting.", &"seedless_arrest", 0.65, &"right")
	await _line("Opposition", "This country is doomed if this continues.", &"seedless_arrest", 0.65, &"left")

	await _show_frame(CUSTOMER_FRAME, 3)
	await _line("Civilian", "These fruits aren’t that bad though….", &"seedless_customer", 0.65, &"center")
	await _line("Civilian", "It IS convenient…", &"seedless_customer", 0.6, &"center")

	active = false
	overlay.visible = false
	caption_panel.visible = false
	frame_image.visible = false
	camera_chrome.visible = false
	_stop_audio()
	capture_finished.emit()
