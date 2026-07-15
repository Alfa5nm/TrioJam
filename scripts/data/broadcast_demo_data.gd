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
	var opposition_person := _character(&"opposition_person", "Opposition Person", Color(0.714, 0.275, 0.310, 1))
	var mc := _character(&"mc", "MC", Color(0.243, 0.761, 0.91, 1))
	var government_official := _character(&"government_official", "Government Official", Color(0.855, 0.82, 0.631, 1))

	var rooftop_scene := _action(&"rooftop_scene", "Rooftop Scene")
	var rooftop_shoots := _action(&"rooftop_shoots", "Rooftop Shoots")
	var victim_shot := _action(&"victim_shot", "The victim being shot")

	# Day 0 has no truthful route — the protagonist has already been captured
	# and is not yet willing to resist. Only the propaganda framing is valid.
	var propaganda := BroadcastSequence.new()
	propaganda.headline = "Opposition Assassin Kills Government Official in Rooftop Attack"
	propaganda.cause_characters = [opposition_person]
	propaganda.cause_action = rooftop_scene
	propaganda.conflict_characters = [opposition_person]
	propaganda.conflict_action = rooftop_shoots
	propaganda.outcome_characters = [government_official]
	propaganda.outcome_action = victim_shot
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
	report.directive_text = "Select a scene, place it inside a frame, and drag the required characters into position. Arrange all three frames to construct the narrative requested by the government.\n\nThe report does not need to show what happened. It only needs to show what the public is supposed to believe happened."
	report.characters = [opposition_person, mc, government_official]
	report.available_actions = [rooftop_scene, rooftop_shoots, victim_shot]
	report.truthful_sequence = null
	report.propaganda_sequence = propaganda
	return report


static func _character(id: StringName, display_name: String, portrait_color: Color) -> CharacterDef:
	var character := CharacterDef.new()
	character.id = id
	character.display_name = display_name
	character.portrait_color = portrait_color
	return character


static func _action(id: StringName, display_name: String) -> ActionDef:
	var action := ActionDef.new()
	action.id = id
	action.display_name = display_name
	return action
