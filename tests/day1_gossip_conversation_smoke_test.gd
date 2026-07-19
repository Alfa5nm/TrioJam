extends SceneTree

const SCENE_PATH := "res://scenes/Day 1/Side Scroll Section/Side_Scroll Day 1.tscn"
const EXPECTED_LINES := [
	"Civilian 1|That poor boy got shot…",
	"Civilian 2|It’s all that report’s fault!",
]

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "Day 1 loads with the produce-stall gossip encounter")
	if packed == null:
		quit(1)
		return

	var level := packed.instantiate()
	root.add_child(level)
	for _frame in 4:
		await process_frame

	var gossip := level.get_node_or_null("ProduceStallGossip") as Day1GossipConversation
	var dialogue := level.get_node_or_null("CinematicDialogue") as CinematicDialogue
	var player := level.get_node_or_null("Player") as Player
	_check(gossip != null and gossip.position.distance_to(Vector2(4490, 607)) < 1.0, "gossip pair occupies the marked produce stall")
	_check(gossip != null and not gossip.visible and not gossip.is_armed, "post-event gossip is hidden before the shooting")
	_check(gossip != null and gossip.get_node("Civilian1").texture.resource_path.contains("gossiping-gal-a"), "first supplied gossip civilian is used")
	_check(gossip != null and gossip.get_node("Civilian2").texture.resource_path.contains("gossiping-gal-b"), "second supplied gossip civilian is used")

	dialogue.instant_mode = true
	dialogue.timing_scale = 0.01
	var lines: Array[String] = []
	gossip.line_started.connect(func(speaker_name: String, text: String):
		lines.append(speaker_name + "|" + text)
	)
	gossip.arm()
	gossip.trigger_conversation()
	var frames_waited := 0
	while lines.size() < EXPECTED_LINES.size() and frames_waited < 120:
		await process_frame
		frames_waited += 1
	_check(lines == EXPECTED_LINES, "both requested gossip lines play in order")
	_check(player.controls_enabled, "ambient gossip never locks player movement")
	_check(not dialogue.speaker_label.visible and dialogue.speaker_label.text.is_empty(), "gossip bubbles omit speaker names")
	_check(gossip.has_triggered and not gossip.is_armed, "gossip conversation is one-shot")

	var line_count := lines.size()
	gossip.trigger_conversation()
	await process_frame
	_check(lines.size() == line_count, "gossip cannot replay during the same visit")

	level.queue_free()
	for _frame in 3:
		await process_frame
	quit(failures)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
