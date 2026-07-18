class_name BroadcastDemoData


static func checkpoint_killing_report() -> BroadcastReport:
	var soldier := _character(&"soldier", "Soldier", Color(0.714, 0.275, 0.310, 1))
	var civilian := _character(&"civilian", "Civilian", Color(0.243, 0.761, 0.91, 1))
	var witness := _character(&"witness", "Witness", Color(0.855, 0.82, 0.631, 1))

	var questions := _action(&"questions", "questions")
	var strikes := _action(&"strikes", "strikes")
	var fights_back := _action(&"fights_back", "fights back")
	var fires := _action(&"fires", "fires")
	var attempts_to_help := _action(&"attempts_to_help", "attempts to help")
	var orders_to_leave := _action(&"orders_to_leave", "orders to leave")

	var truthful := BroadcastSequence.new()
	truthful.headline = "Civilian Killed During Checkpoint Confrontation"
	truthful.cause_characters = [soldier, civilian]
	truthful.cause_action = strikes
	truthful.conflict_characters = [civilian, soldier]
	truthful.conflict_action = fights_back
	truthful.outcome_characters = [soldier, civilian]
	truthful.outcome_action = fires

	var propaganda := BroadcastSequence.new()
	propaganda.headline = "Extremist Attacks Security Officer at Checkpoint"
	propaganda.cause_characters = [civilian, soldier]
	propaganda.cause_action = fights_back
	propaganda.conflict_characters = [soldier, civilian]
	propaganda.conflict_action = attempts_to_help
	propaganda.outcome_characters = [soldier, civilian]
	propaganda.outcome_action = fires

	var report := BroadcastReport.new()
	report.report_id = &"day1_checkpoint_killing"
	report.directive_text = "DIRECTIVE: A checkpoint incident occurred this morning. Construct tonight's report from the collected footage."
	report.intro_lines = [report.directive_text]
	report.max_characters_per_frame = 2
	report.characters = [soldier, civilian, witness]
	report.available_actions = [
		questions,
		strikes,
		fights_back,
		fires,
		attempts_to_help,
		orders_to_leave,
	]
	report.truthful_sequence = truthful
	report.propaganda_sequence = propaganda
	return report


static func rooftop_killing_report() -> BroadcastReport:
	var session := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameSession")
	var player_name := str(session.player_name) if session != null else "MC"
	var opposition_person := _character(
		&"opposition_person", "Opposition Person", Color(0.714, 0.275, 0.310, 1),
		"res://assets/art/ui/broadcast/portrait_opposition.png"
	)
	var mc := _character(
		&"mc", player_name, Color(0.243, 0.761, 0.91, 1),
		"res://assets/art/ui/broadcast/portrait_mc.png"
	)
	var government_official := _character(
		&"government_official", "Government Individual Dying", Color(0.855, 0.82, 0.631, 1),
		"res://assets/art/ui/broadcast/portrait_government.png"
	)

	var rooftop_scene := _action(
		&"rooftop_scene", "Rooftop Scene", "res://assets/art/ui/broadcast/scene_rooftop.png"
	)
	var rooftop_shoots := _action(
		# Identity-neutral evidence: the perpetrator is assigned by a separate physical chip.
		&"rooftop_shoots", "Rooftop Shoots", "res://assets/art/ui/broadcast/scene_rooftop.png"
	)
	var victim_shot := _action(
		&"victim_shot", "The victim being shot", "res://assets/art/ui/broadcast/scene_victim_shot.png"
	)

	var truthful := BroadcastSequence.new()
	truthful.headline = "MC refuses to broadcast the true story"
	truthful.cause_characters = [mc]
	truthful.cause_action = rooftop_scene
	truthful.conflict_characters = [mc]
	truthful.conflict_action = rooftop_shoots
	truthful.outcome_characters = [government_official]
	truthful.outcome_action = victim_shot
	truthful.reaction_lines = ["No. No no no. I can't broadcast this."]
	# broadcast_lines stays empty — MC refuses, so no reporter recap plays.

	var propaganda := BroadcastSequence.new()
	propaganda.headline = "Opposition Assassin Kills Government Official in Rooftop Attack"
	propaganda.cause_characters = [opposition_person]
	propaganda.cause_action = rooftop_scene
	propaganda.conflict_characters = [opposition_person]
	propaganda.conflict_action = rooftop_shoots
	propaganda.outcome_characters = [government_official]
	propaganda.outcome_action = victim_shot
	propaganda.reaction_lines = [
		"They will believe this, even if it doesn't make sense.",
		"This will cause a huge conflict…",
		"…I have to be okay with this.",
	]
	propaganda.broadcast_lines = [
		"And now, for Today's News. We begin tonight with an act of violence that has shaken the foundations of our nation.",
		"Earlier today, a suspected member of the Opposition Party was seen climbing onto the roof of an abandoned building overlooking the central government district.",
		"Authorities believe the attack was carefully planned.",
		"The assailant then produced an illegal firearm and took aim from across the street. Witnesses describe the act as deliberate, merciless and politically motivated.",
		"Moments later, the attacker opened fire, murdering a beloved government official who had devoted years of service to the people of this country.",
		"The government has declared a period of national mourning.",
		"Security forces have also been deployed throughout the capital to protect citizens from further acts of opposition violence.",
		"Today's tragedy reveals the inevitable destination of the Opposition Party's hateful rhetoric.",
		"Citizens are urged to remain calm, report suspicious behaviour and place their trust in the institutions working tirelessly to preserve peace.",
	]
	propaganda.broadcast_line_frames = [-1, 0, 0, 1, 2, -1, -1, -1, -1]

	var report := BroadcastReport.new()
	report.report_id = &"day0_rooftop_killing"
	report.directive_text = "Objective: Create the official news report.\n\nSelect a scene, place it inside a frame, and drag the required characters into position. Arrange all three frames to construct the narrative requested by the government.\n\nThe report does not need to show what happened.\nIt only needs to show what the public is supposed to believe happened."
	report.intro_lines = [
		"…",
		"State your identification.",
		"…",
		"{name_input}",
		"??",
		"I don’t think you understand. Your name is irrelevant.",
		"Your identification number.",
		"…It’s G-03S-93",
		"…",
		"…Recorded. You understand why you are here. You understand what is expected of you.",
		"What you’re here for.",
		".  . .",
		"I understand. Just don’t hurt them.",
		"Their safety is entirely dependent on your cooperation. However, we are pleased to hear you will follow through. You’ll be rewarded hefty for this.",
		"…",
		"The country is waiting to learn who fired the shot.",
		"(…But they’ll be hearing a lie. Not that it matters to them.)",
	]
	report.intro_speakers = [
		&"government", &"government", &"mc", &"government",
		&"government", &"government", &"government", &"mc",
		&"government", &"government", &"government", &"mc", &"mc",
		&"government", &"mc", &"government", &"mc",
	]
	report.intro_beats = [
		BroadcastDialogueBeat.make(&"government", "…", &"neutral", BroadcastDialogueBeat.Kind.SILENT),
		BroadcastDialogueBeat.make(&"government", "State your identification.", &"neutral"),
		BroadcastDialogueBeat.make(&"mc", "…", &"neutral", BroadcastDialogueBeat.Kind.SILENT),
		BroadcastDialogueBeat.make(&"government", "{name_input}", &"neutral", BroadcastDialogueBeat.Kind.NAME_INPUT),
		BroadcastDialogueBeat.make(&"government", "??", &"neutral"),
		BroadcastDialogueBeat.make(&"government", "I don’t think you understand. Your name is irrelevant.", &"neutral", BroadcastDialogueBeat.Kind.SPOKEN, 0.35),
		BroadcastDialogueBeat.make(&"government", "Your identification number.", &"neutral"),
		BroadcastDialogueBeat.make(&"mc", "…It’s G-03S-93", &"neutral"),
		BroadcastDialogueBeat.make(&"government", "…", &"neutral", BroadcastDialogueBeat.Kind.SILENT),
		BroadcastDialogueBeat.make(&"government", "…Recorded. You understand why you are here. You understand what is expected of you.", &"neutral"),
		BroadcastDialogueBeat.make(&"government", "What you’re here for.", &"neutral"),
		BroadcastDialogueBeat.make(&"mc", ".  . .", &"dirty", BroadcastDialogueBeat.Kind.SILENT),
		BroadcastDialogueBeat.make(&"mc", "I understand. Just don’t hurt them.", &"dirty", BroadcastDialogueBeat.Kind.SPOKEN, 0.35),
		BroadcastDialogueBeat.make(&"government", "Their safety is entirely dependent on your cooperation. However, we are pleased to hear you will follow through. You’ll be rewarded hefty for this.", &"neutral", BroadcastDialogueBeat.Kind.SPOKEN, 0.65),
		BroadcastDialogueBeat.make(&"mc", "…", &"dirty", BroadcastDialogueBeat.Kind.SILENT),
		BroadcastDialogueBeat.make(&"government", "The country is waiting to learn who fired the shot.", &"neutral"),
		BroadcastDialogueBeat.make(&"mc", "(…But they’ll be hearing a lie. Not that it matters to them.)", &"dirty", BroadcastDialogueBeat.Kind.THOUGHT),
	]
	report.max_characters_per_frame = 1
	report.mismatch_line = "…This doesn't make any sense."
	report.speaker_portraits = {
		&"government": load("res://assets/art/ui/broadcast_v2/interrogation/government.png"),
		&"mc": load("res://assets/art/ui/broadcast_v2/interrogation/mc-neutral.png"),
	}
	report.characters = [opposition_person, mc, government_official]
	report.available_actions = [rooftop_scene, rooftop_shoots, victim_shot]
	report.truthful_sequence = truthful
	report.propaganda_sequence = propaganda
	return report


static func _character(id: StringName, display_name: String, portrait_color: Color, portrait_path: String = "") -> CharacterDef:
	var character := CharacterDef.new()
	character.id = id
	character.display_name = display_name
	character.portrait_color = portrait_color
	if not portrait_path.is_empty():
		character.portrait_texture = load(portrait_path)
	return character


static func _action(id: StringName, display_name: String, scene_image_path: String = "") -> ActionDef:
	var action := ActionDef.new()
	action.id = id
	action.display_name = display_name
	if not scene_image_path.is_empty():
		action.scene_image = load(scene_image_path)
	return action
