extends SceneTree

const OUT_DIR := "res://tests/artifacts"


func _init() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	var session := root.get_node("GameSession")
	session.broadcast_context = &"day2_story"
	session.day1_seedless_route = &"truthful"
	var rally := (load("res://scenes/Day 2/day2_peace_rally.tscn") as PackedScene).instantiate() as Day2PeaceRallyController
	rally.timing_scale = 0.001
	var dialogue := rally.get_node("CinematicDialogue") as CinematicDialogue
	dialogue.instant_mode = true
	dialogue.timing_scale = 0.001
	root.add_child(rally)
	for _frame in range(30):
		await process_frame
		if rally.state == Day2PeaceRallyController.State.FREE_ROAM:
			break
	dialogue.timing_scale = 1.0
	var camera := rally.get_node("HorizontalCamera") as Day1HorizontalCamera
	camera.position_smoothing_enabled = false
	camera.target = rally.get_node("Focus/Stage")
	camera.framing_offset = Vector2(0, -60)
	await process_frame
	await process_frame
	_save("day2_peaceful_rally_preview.png")
	var arrival_anchor := rally.get_node("DialogueAnchors/MC") as Node2D
	arrival_anchor.global_position = Vector2(1540, 350)
	dialogue.show_bark("There’s no seeds in this fruit… It’s a little expensive, but I’m glad that the farmers are getting what they needed.", "MC", arrival_anchor, 1.0)
	# Let the normal reveal tween finish so this capture verifies both the
	# presentation layer and the fully visible wrapped text.
	for _frame in range(18):
		await process_frame
	_save("day2_arrival_dialogue_preview.png")
	dialogue.hide_immediately()
	var overlay := rally.get_node("Day2CinematicOverlay") as Day2CinematicOverlay
	_show_overlay_preview(overlay, preload("res://assets/art/Day 2 Side Scroll/cg/peace-leader-podium.png"), "Thank you for coming.", &"bottom", Color(0.78, 0.94, 1))
	await process_frame
	_save("day2_podium_cg_preview.png")
	overlay.hide_immediately()
	camera.target = rally.get_node("Focus/SoldierReveal")
	camera.zoom = Vector2(1.25, 1.25)
	rally.get_node("NPCs/SuspiciousWorker").visible = false
	var planting := rally.get_node("NPCs/BombPlantingSoldier") as AnimatedSprite2D
	planting.visible = true
	planting.frame = 1
	await process_frame
	await process_frame
	_save("day2_soldier_planting_preview.png")
	_show_overlay_preview(overlay, preload("res://assets/art/Day 2 Side Scroll/cg/suspicious-worker.png"), "(What’s a soldier doing here…..?)", &"bottom", Color(0.78, 0.91, 1))
	await process_frame
	_save("day2_suspicious_worker_cg_preview.png")
	_show_overlay_preview(overlay, preload("res://assets/art/Day 2 Side Scroll/cg/peace-leader-podium.png"), "There will be no victory if half the country must be buried beneath it.", &"bottom", Color(0.78, 0.94, 1))
	await process_frame
	_save("day2_warning_cg_preview.png")
	overlay.hide_immediately()
	rally.normal_background.visible = false
	rally.aftermath_background.visible = true
	rally.get_node("NPCs/RallyCrowd").visible = false
	rally.get_node("NPCs/PeaceLeader").visible = false
	rally.get_node("NPCs/SuspiciousWorker").visible = false
	rally.get_node("NPCs/ForegroundPodium").visible = false
	rally.get_node("NPCs/BombPlantingSoldier").visible = false
	rally.get_node("NPCs/AftermathActors").visible = true
	rally.get_node("NPCs/PanicCrowd").visible = true
	rally.get_node("NPCs/BlockadeCrowd").visible = true
	rally._start_crowd_dispersal()
	rally.get_node("Particles/Smoke").emitting = true
	rally.get_node("Particles/Embers").emitting = true
	rally.get_node("Lighting/FireLight").visible = true
	await process_frame
	await process_frame
	_save("day2_active_dispersal_preview.png")
	for _frame in range(18):
		await process_frame
	_save("day2_aftermath_preview.png")
	camera.target = rally.get_node("Focus/Stage")
	camera.zoom = Vector2.ONE
	var leader_anchor := rally.get_node("DialogueAnchors/Leader") as Node2D
	leader_anchor.global_position = (rally.get_node("NPCs/AftermathActors/CrouchedLeader") as Node2D).global_position + Vector2(0, -128)
	dialogue.show_bark("Move the children and the injured through the eastern passage! Do not push!", "Opposition", leader_anchor, 1.0)
	for _frame in range(18):
		await process_frame
	_save("day2_crouched_leader_dialogue_preview.png")
	dialogue.hide_immediately()
	camera.target = rally.get_node("Focus/Blockade")
	await process_frame
	await process_frame
	_save("day2_containment_bottleneck_preview.png")
	await rally._play_shove_reaction()
	await process_frame
	_save("day2_passage_open_preview.png")
	_show_overlay_preview(overlay, preload("res://assets/art/Day 2 Side Scroll/cg/rescue-civilians.png"), "I’m coming with medical aid! Please don’t panic and stay calm!", &"left", Color(1.0, 0.78, 0.32))
	await process_frame
	_save("day2_rescue_cg_preview.png")
	rally.queue_free()
	await process_frame
	quit()


func _save(filename: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUT_DIR + "/" + filename))
	if error != OK:
		push_error("Could not save " + filename)


func _show_overlay_preview(overlay: Day2CinematicOverlay, texture: Texture2D, text: String, placement: StringName, color: Color) -> void:
	overlay.visible = true
	overlay.root.visible = true
	overlay.image.texture = texture
	overlay.chrome.visible = true
	overlay.flash.modulate.a = 0.0
	overlay.caption_text.text = text
	overlay.caption_text.visible_characters = -1
	overlay.caption_text.add_theme_color_override(&"font_color", color)
	overlay._place_caption(placement, text)
	overlay.caption.modulate.a = 1.0
	overlay.caption.visible = true
