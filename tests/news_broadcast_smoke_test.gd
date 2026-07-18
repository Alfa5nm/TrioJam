extends SceneTree

var failures := 0
var finished_count := 0


func _init() -> void:
	print("NEWS_BROADCAST_TEST_START")
	_run.call_deferred()


func _run() -> void:
	var packed_scene := load("res://scenes/gameplay/news_broadcast.tscn") as PackedScene
	_check(packed_scene != null, "news broadcast scene loads")
	if packed_scene == null:
		quit(1)
		return
	var scene := packed_scene.instantiate() as NewsBroadcast
	scene.instant_mode = true
	scene.auto_advance_to_epilogue = false
	root.add_child(scene)
	for _frame in 5:
		await process_frame
	scene.broadcast_finished.connect(func(): finished_count += 1)

	_check(scene.get_node("UI/NewsLabel").text == "NEWS", "studio display is labelled NEWS rather than LIVE FEED")
	_check(scene.presenter.sprite_frames.get_frame_count(&"talk") == 4, "presenter has four registered mouth frames")
	_check(not scene.presenter.sprite_frames.has_animation(&"bang"), "presenter no longer has an unnecessary table-bang animation")
	_check(scene.news_bed.playing, "looping news-channel bed starts after the intro")
	_check(scene.intro_sting.stream != null and scene.presenter_blip.stream != null, "news intro and high-pitched presenter blip are assigned")
	_check(not scene.has_node("Audio/TableBang"), "unused table-bang audio is removed")
	_check(scene.get_node("UI/Teleprompter").clip_contents, "teleprompter clips scrolling dialogue to its housing")
	_check(is_equal_approx(scene.teleprompter_text.position.y, 14.0), "teleprompter stops inside the screen instead of travelling too far upward")
	_check(scene.cards.size() == 3, "all three Broadcast Interface frames are available chronologically")
	_check(scene.cards.all(func(card: Control): return not card.visible), "introductory reporter line begins on a clean NEWS slate")
	_check(scene.screen_slate.visible, "NEWS slate fills pauses that do not reference a story frame")

	scene._request_advance()
	await process_frame
	_check(scene.cards[0].visible and not scene.cards[1].visible and not scene.cards[2].visible, "Frame One is shown alone for the rooftop setup")
	scene._request_advance()
	await process_frame
	_check(scene.cards[0].visible and not scene.cards[1].visible, "Frame One remains alone while its dialogue continues")
	scene._request_advance()
	await process_frame
	_check(not scene.cards[0].visible and scene.cards[1].visible and not scene.cards[2].visible, "Frame Two replaces Frame One for the rifle line")

	_check(scene._line_index == 3, "manual progression reaches the hard-news rifle line")
	_check(scene.presenter.animation == &"talk", "hard-news lines keep the presenter on mouth-only talking animation")

	while not scene._ended:
		scene._request_advance()
		await process_frame
	_check(finished_count == 1, "broadcast completion signal fires after nine reporter lines")
	_check(scene.teleprompter_text.text == "— END OF BROADCAST —", "teleprompter closes with the broadcast end slate")

	scene.queue_free()
	await process_frame
	if failures == 0:
		print("NEWS_BROADCAST_TEST_PASS")
	quit(failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
