class_name BroadcastDemoData


static func checkpoint_killing_report() -> BroadcastReport:
	var soldier := _character(
		&"soldier", "Soldier", Color(0.714, 0.275, 0.310, 1),
		"res://assets/art/ui/broadcast/portrait_soldier.png"
	)
	var civilian := _character(
		&"civilian", "Civilian", Color(0.243, 0.761, 0.91, 1),
		"res://assets/art/ui/broadcast/portrait_civilian.png"
	)

	# Only two scenes exist. "Attack" is reused for both cause and conflict; each
	# sequence is order_sensitive below, so the ORDER characters are placed in a
	# frame carries the story — the first character is the attacker/killer, the
	# second is the target. This is what lets the same two scenes tell either route.
	var attack := _action(&"attack", "Attack", "res://assets/art/ui/broadcast/scene_checkpoint_attack.png", 2)
	var kill := _action(&"kill", "Kill", "res://assets/art/ui/broadcast/scene_checkpoint_shoot.png", 2)

	# Full-frame character art layered over each scene's photo, one layer per
	# placed character. Each entry is [pose as 1st character, pose as 2nd
	# character] since order_sensitive gives the same character a different
	# pose depending on whether they're the attacker/shooter or the target.
	attack.character_overlays = {
		soldier.id: [
			load("res://assets/art/ui/broadcast/character_soldier_attack1.png"),
			load("res://assets/art/ui/broadcast/character_soldier_attack2.png"),
		],
		civilian.id: [
			load("res://assets/art/ui/broadcast/character_civilian_attack1.png"),
			load("res://assets/art/ui/broadcast/character_civilian_attack2.png"),
		],
	}
	kill.character_overlays = {
		soldier.id: [
			load("res://assets/art/ui/broadcast/character_soldier_shoot1.png"),
			load("res://assets/art/ui/broadcast/character_soldier_shoot2.png"),
		],
		civilian.id: [
			load("res://assets/art/ui/broadcast/character_civilian_shoot1.png"),
			load("res://assets/art/ui/broadcast/character_civilian_shoot2.png"),
		],
	}

	var truthful := BroadcastSequence.new()
	truthful.order_sensitive = true
	truthful.cause_characters = [soldier, civilian] # soldier attacks civilian first
	truthful.cause_action = attack
	truthful.conflict_characters = [civilian, soldier] # civilian attacks back / resists
	truthful.conflict_action = attack
	truthful.outcome_characters = [soldier, civilian] # soldier kills civilian
	truthful.outcome_action = kill
	# The events as MC actually knows them happened — resigned, not relieved.
	truthful.reaction_lines = [
		"The photographs are simple. First, the soldier hit him. Then he tried to protect himself. Then he died.",
		"…",
		"How long can we even keep playing this telephone game, till everything crashes out?",
	]
	truthful.broadcast_lines = [
		"A civilian was shot and killed by a member of the national security force earlier today during a confrontation on a residential street.",
		"The confrontation began when a soldier stopped an unarmed Opposition supporter.",
		"After the civilian refused to surrender his poster, the soldier struck him.",
		"The civilian pushed the soldier away in self-defence.",
		"He was unarmed.",
		"The soldier then shot him at close range.",
		"He died at the scene as bystanders were ordered away.",
		"The government calls it an arrest, and the street calls it murder.",
	]
	truthful.broadcast_line_frames = [-1, 0, 0, 1, 1, 2, 2, -1]

	var propaganda := BroadcastSequence.new()
	propaganda.order_sensitive = true
	propaganda.cause_characters = [civilian, soldier] # civilian attacks first
	propaganda.cause_action = attack
	propaganda.conflict_characters = [soldier, civilian] # soldier attacks back
	propaganda.conflict_action = attack
	propaganda.outcome_characters = [soldier, civilian] # soldier kills civilian
	propaganda.outcome_action = kill
	# The lie MC is submitting — anxious self-reassurance, not resignation.
	propaganda.reaction_lines = [
		"…",
		"This… is the right thing to do.",
		"It will calm things down. This simple domino effect will turn the consequences to be something good, I know.",
	]
	propaganda.broadcast_lines = [
		"A security officer was attacked today during an unauthorized Opposition protest.",
		"The protester refused orders to surrender prohibited political material.",
		"He then attacked the officer and resisted arrest.",
		"Authorities blame increasingly violent Opposition rhetoric.",
		"The officer was forced to defend themselves from the civilian.",
		"The attacker died at the scene.",
		"Citizens are urged to avoid illegal protests and report extremist material.",
		"Those who cooperate have nothing to fear.",
	]
	propaganda.broadcast_line_frames = [-1, 0, 0, 0, 1, 2, -1, -1]

	var report := BroadcastReport.new()
	report.report_id = &"day1_checkpoint_killing"
	report.directive_text = "An Opposition-affiliated agitator assaulted a member of the national security force."
	report.intro_lines = [
		"An Opposition-affiliated agitator assaulted a member of the national security force.",
		"The officer responded in accordance with public safety protocol.",
		"Avoid language suggesting excessive force or unlawful use of a firearm.",
		"…He pushed the soldier away because he was being beaten.",
		"….But I'm only a cog in this system.",
		"…Or, am I? I can change the course of history, just by these photos. I can be the start of something… different.",
	]
	report.intro_speakers = [
		&"government", &"government", &"government",
		&"mc", &"mc", &"mc",
	]
	report.speaker_portraits = {
		&"government": load("res://assets/art/ui/broadcast_v2/interrogation/government.png"),
	}
	report.max_characters_per_frame = 2
	report.mismatch_line = "…This doesn't add up either."
	report.characters = [soldier, civilian]
	report.available_actions = [attack, kill]
	report.truthful_sequence = truthful
	report.propaganda_sequence = propaganda
	return report


static func seedless_fruit_report() -> BroadcastReport:
	# Only three reusable characters — each can be dragged into more than one
	# frame, same as Report 1's soldier/civilian. Order carries the story here
	# too: order_sensitive below means {soldier, opposition} and
	# {opposition, soldier} in the same scene are different, recognized answers.
	var soldier := _character(
		&"soldier", "Soldier", Color(0.714, 0.275, 0.310, 1),
		"res://assets/art/ui/broadcast/portrait_soldier.png"
	)
	# Distinct from Report 1's &"civilian" (a different-looking character) —
	# kept as its own id/art on purpose rather than reusing that one.
	var civilian := _character(
		&"civilian_customer", "Civilian", Color(0.243, 0.761, 0.91, 1),
		"res://assets/art/ui/broadcast/portrait_civilian_customer.png"
	)
	var opposition := _character(
		&"opposition", "Opposition", Color(0.62, 0.42, 0.78, 1),
		"res://assets/art/ui/broadcast/portrait_opposition_group.png"
	)

	# Shared cause — identical handshake photo for both routes.
	var licensing_seeds := _action(
		&"licensing_seeds", "Licensing Seeds",
		"res://assets/art/ui/broadcast/scene_licensing.png", 2
	)
	var protest := _action(&"protest", "Protest", "res://assets/art/ui/broadcast/scene_protest.png", 1)
	var happy := _action(&"happy", "Happy", "res://assets/art/ui/broadcast/scene_feedback.png", 1)
	# Shared outcome action — same "arrest" photo op and same [soldier, opposition]
	# order for both routes; cause/conflict alone discriminate truthful vs propaganda.
	var arrest := _action(&"arrest", "Arrest", "res://assets/art/ui/broadcast/scene_arrest.png", 2)

	# Full-frame character art layered over each scene's photo. Licensing and
	# Arrest are order_sensitive with two slots, so each character has a
	# [1st placed, 2nd placed] pose pair; Protest/Happy cap at 1 character
	# so there's only ever one pose per character.
	licensing_seeds.character_overlays = {
		soldier.id: [
			load("res://assets/art/ui/broadcast/character_soldier_licensing1.png"),
			load("res://assets/art/ui/broadcast/character_soldier_licensing2.png"),
		],
		opposition.id: [
			load("res://assets/art/ui/broadcast/character_oppo_licensing1.png"),
			load("res://assets/art/ui/broadcast/character_oppo_licensing2.png"),
		],
		civilian.id: [
			load("res://assets/art/ui/broadcast/character_cust_licensing1.png"),
			load("res://assets/art/ui/broadcast/character_cust_licensing2.png"),
		],
	}
	protest.character_overlays = {
		soldier.id: load("res://assets/art/ui/broadcast/character_soldier_protest.png"),
		opposition.id: load("res://assets/art/ui/broadcast/character_oppo_protest.png"),
		civilian.id: load("res://assets/art/ui/broadcast/character_cust_protest.png"),
	}
	happy.character_overlays = {
		soldier.id: load("res://assets/art/ui/broadcast/character_soldier_feedback.png"),
		opposition.id: load("res://assets/art/ui/broadcast/character_oppo_feedback.png"),
		civilian.id: load("res://assets/art/ui/broadcast/character_cust_feedback.png"),
	}
	arrest.character_overlays = {
		soldier.id: [
			load("res://assets/art/ui/broadcast/character_soldier_arrest1.png"),
			load("res://assets/art/ui/broadcast/character_soldier_arrest2.png"),
		],
		opposition.id: [
			load("res://assets/art/ui/broadcast/character_oppo_arrest1.png"),
			load("res://assets/art/ui/broadcast/character_oppo_arrest2.png"),
		],
		civilian.id: [
			load("res://assets/art/ui/broadcast/character_cust_arrest1.png"),
			load("res://assets/art/ui/broadcast/character_cust_arrest2.png"),
		],
	}

	var truthful := BroadcastSequence.new()
	truthful.order_sensitive = true
	truthful.cause_characters = [soldier, opposition]
	truthful.cause_action = licensing_seeds
	truthful.conflict_characters = [opposition]
	truthful.conflict_action = protest
	truthful.outcome_characters = [soldier, opposition]
	truthful.outcome_action = arrest
	truthful.reaction_lines = [
		"…I'm going to end up having so much shit because of it.",
		"But it's for the country's sake. I have to.",
	]
	truthful.broadcast_lines = [
		"Farmers protested today against new government-backed seed licensing laws.",
		"The agreement gives private companies control over licensed seeds and farmland, however the farmers were very displeased with it.",
		"Farmers say they will be forced to buy new seeds every season and may lose land for refusing, thus the protest occurred.",
		"Officials rejected their demands, and soldiers began arresting protesters.",
		"The government calls it modernization. Farmers call it losing the right to grow.",
	]
	truthful.broadcast_line_frames = [-1, 0, 1, 2, -1]

	var propaganda := BroadcastSequence.new()
	propaganda.order_sensitive = true
	propaganda.cause_characters = [soldier, civilian]
	propaganda.cause_action = licensing_seeds
	propaganda.conflict_characters = [civilian]
	propaganda.conflict_action = happy
	propaganda.outcome_characters = [soldier, opposition]
	propaganda.outcome_action = arrest
	propaganda.reaction_lines = [
		"Hahahaa… Hah…..",
		"It's not my fault. I'm just doing what I'm told.",
		"It's not my fault… It's not my fault….",
	]
	propaganda.broadcast_lines = [
		"The government launched a new agricultural program today to meet growing demand for seedless fruit.",
		"The new partnership will introduce licensed seeds and modern farming methods across the country.",
		"Customers welcomed the produce, praising it as cleaner, easier and more convenient to eat.",
		"The peaceful launch was briefly disturbed by an Opposition agitator attempting to disrupt the event.",
		"Security quickly restored order.",
		"The future is modern and seedless.",
	]
	propaganda.broadcast_line_frames = [-1, 0, 1, 2, 2, -1]

	var report := BroadcastReport.new()
	report.report_id = &"day1_seedless_fruit"
	report.directive_text = "Consumer demand for seedless fruit has encouraged a new agricultural modernization program."
	report.intro_lines = [
		"Consumer demand for seedless fruit has encouraged a new agricultural modernization program.",
		"A small group of Opposition-aligned agitators attempted to disrupt the launch.",
		"Avoid discussion of seed licensing, land acquisition or unauthorized claims made by protesters.",
		"…",
		"The truth… Or the lie? Whatever it is, it will be the start of a revolution.",
	]
	report.intro_speakers = [
		&"government", &"government", &"government",
		&"mc", &"mc",
	]
	report.disconnect_after_intro_line = 2
	report.speaker_portraits = {
		&"government": load("res://assets/art/ui/broadcast_v2/interrogation/government.png"),
	}
	report.max_characters_per_frame = 2
	report.mismatch_line = "No no no, this doesn't make any sense. Let's try again."
	report.characters = [soldier, civilian, opposition]
	report.available_actions = [licensing_seeds, protest, happy, arrest]
	report.truthful_sequence = truthful
	report.propaganda_sequence = propaganda
	return report


static func day1_reports() -> Array[BroadcastReport]:
	return [checkpoint_killing_report(), seedless_fruit_report()]


## Day 2's "Emergency Reporting Directive" (the Peace Rally bombing). Built as a
## standalone single-report function — unlike day1_reports(), nothing calls this
## automatically. Wire it in with load_report(BroadcastDemoData.bombing_report())
## wherever it belongs in the actual game flow.
static func bombing_report() -> BroadcastReport:
	var suspicious_individual := _character(
		&"suspicious_individual", "Suspicious Individual", Color(0.55, 0.53, 0.58, 1),
		"res://assets/art/ui/broadcast/portrait_suspicious_individual.png"
	)
	var civilians := _character(
		&"civilians", "Civilians", Color(0.243, 0.761, 0.91, 1),
		"res://assets/art/ui/broadcast/portrait_civilians.png"
	)
	var opposition := _character(
		&"opposition", "Opposition", Color(0.62, 0.42, 0.78, 1),
		"res://assets/art/ui/broadcast/portrait_opposition_group.png"
	)
	var soldiers := _character(
		&"soldiers", "Soldiers", Color(0.714, 0.275, 0.310, 1),
		"res://assets/art/ui/broadcast/portrait_soldiers.png"
	)

	var planting_bomb := _action(&"planting_bomb", "Planting Bomb Scene", "res://assets/art/ui/broadcast/scene_planting_bomb.png", 1)
	var peace_rally_victims := _action(&"peace_rally_victims", "Peace Rally Victims", "res://assets/art/ui/broadcast/scene_peace_rally_victims.png", 1)
	# Order matters here — the scene literally asks "Who is Helping Who?": the
	# first character placed is the one doing the helping, the second is who's helped.
	var helping := _action(&"helping", "Who is Helping Who?", "res://assets/art/ui/broadcast/scene_helping.png", 2)

	# Full-frame character art layered over each scene's photo. Bomb and Rally
	# cap at 1 character so there's only ever one pose per character; Helping is
	# order_sensitive with two slots, so each character has a [helper, helped] pair.
	planting_bomb.character_overlays = {
		suspicious_individual.id: load("res://assets/art/ui/broadcast/character_sus_bomb.png"),
		opposition.id: load("res://assets/art/ui/broadcast/character_oppo_bomb.png"),
		soldiers.id: load("res://assets/art/ui/broadcast/character_soldier_bomb.png"),
		civilians.id: load("res://assets/art/ui/broadcast/character_civilian_bomb.png"),
	}
	peace_rally_victims.character_overlays = {
		suspicious_individual.id: load("res://assets/art/ui/broadcast/character_sus_rally.png"),
		civilians.id: load("res://assets/art/ui/broadcast/character_civilian_rally.png"),
		opposition.id: load("res://assets/art/ui/broadcast/character_oppo_rally.png"),
		soldiers.id: load("res://assets/art/ui/broadcast/character_soldier_rally.png"),
	}
	helping.character_overlays = {
		suspicious_individual.id: [
			load("res://assets/art/ui/broadcast/character_sus_help1.png"),
			load("res://assets/art/ui/broadcast/character_sus_help2.png"),
		],
		civilians.id: [
			load("res://assets/art/ui/broadcast/character_civilian_help1.png"),
			load("res://assets/art/ui/broadcast/character_civilian_help2.png"),
		],
		opposition.id: [
			load("res://assets/art/ui/broadcast/character_oppo_help1.png"),
			load("res://assets/art/ui/broadcast/character_oppo_help2.png"),
		],
		soldiers.id: [
			load("res://assets/art/ui/broadcast/character_soldier_help1.png"),
			load("res://assets/art/ui/broadcast/character_soldier_help2.png"),
		],
	}

	var truthful := BroadcastSequence.new()
	truthful.order_sensitive = true
	truthful.cause_characters = [suspicious_individual]
	truthful.cause_action = planting_bomb
	truthful.conflict_characters = [civilians]
	truthful.conflict_action = peace_rally_victims
	truthful.outcome_characters = [opposition, civilians]
	truthful.outcome_action = helping
	truthful.reaction_lines = [
		"This has been going too far. I'm not going to tell lies for this murderous being.",
		"I can't exactly tell their name… But this is good enough.",
		"I'm not going to let this pass.",
	]
	truthful.broadcast_lines = [
		"…And now, Today's news.",
		"New evidence suggests that the Peace Rally bombing may have been deliberately planned.",
		"A suspicious individual was photographed placing a package beneath the stage shortly before the explosion.",
		"The blast struck a peaceful crowd gathered to hear the Opposition leader call for negotiation and unity.",
		"Following the explosion, the leader helped wounded civilians escape and repeatedly called for calm.",
		"Authorities have not explained the identity of the individual seen placing the package.",
		"The rally was meant to end the violence, however someone wanted it to become another reason for war.",
	]
	truthful.broadcast_line_frames = [-1, -1, 0, 1, 2, -1, -1]

	var propaganda := BroadcastSequence.new()
	propaganda.order_sensitive = true
	propaganda.cause_characters = [opposition]
	propaganda.cause_action = planting_bomb
	propaganda.conflict_characters = [soldiers]
	propaganda.conflict_action = peace_rally_victims
	propaganda.outcome_characters = [soldiers, civilians]
	propaganda.outcome_action = helping
	propaganda.reaction_lines = [
		"…..",
		"I'm… definitely bound to hell after publishing this. There's no god for me, I'm sure.",
	]
	propaganda.broadcast_lines = [
		"Authorities have linked today's deadly rally explosion to violent Opposition activity.",
		"An Opposition member was seen placing a suspicious package near the stage shortly before the blast.",
		"The explosion endangered both the Opposition leader and security personnel assigned to protect the event.",
		"Soldiers entered the damaged square, rescued civilians and restored order.",
		"Officials are now investigating the Opposition leader's connection to the attack.",
		"A rally advertised as peaceful became an act of terror. Security forces have promised that those responsible will be found.",
		"Peace cannot survive those who use it as a disguise.",
	]
	propaganda.broadcast_line_frames = [-1, 0, 1, 2, -1, -1, -1]

	var report := BroadcastReport.new()
	report.report_id = &"day2_bombing"
	report.directive_text = "The Opposition leader organized a violent rally that resulted in a terrorist explosion."
	report.intro_lines = [
		"The Opposition leader organized a violent rally that resulted in a terrorist explosion.",
		"Opposition militants attacked security forces following the detonation.",
		"Military personnel intervened to protect civilians and restore public order.",
		"…..",
		"…Oh there has to be a limit to everything. Now I need to lie about a bomb planter…?!",
		"No fucking way….",
	]
	report.intro_speakers = [
		&"government", &"government", &"government",
		&"mc", &"mc", &"mc",
	]
	report.max_characters_per_frame = 2
	report.mismatch_line = "…None of this adds up."
	report.characters = [suspicious_individual, civilians, opposition, soldiers]
	report.available_actions = [planting_bomb, peace_rally_victims, helping]
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

	# Day 0's frames are capped at 1 character each; set explicitly per action
	# since ActionDef's own default (2) would otherwise override the report-level
	# cap the moment any of these scenes is placed.
	var rooftop_scene := _action(
		&"rooftop_scene", "Rooftop Scene", "res://assets/art/ui/broadcast/scene_rooftop.png", 1
	)
	var rooftop_shoots := _action(
		# Identity-neutral evidence: the perpetrator is assigned by a separate physical chip,
		# not by which character is visible in the photo itself.
		&"rooftop_shoots", "Rooftop Shoots", "res://assets/art/ui/broadcast/scene_rooftop_shoots.png", 1
	)
	var victim_shot := _action(
		&"victim_shot", "The victim being shot", "res://assets/art/ui/broadcast/scene_victim_shot.png", 1
	)

	# Full-frame character art layered over each scene's photo once that
	# character is the one placed in the frame (see ActionDef.character_overlays).
	rooftop_scene.character_overlays = {
		mc.id: load("res://assets/art/ui/broadcast/character_mc_going.png"),
		opposition_person.id: load("res://assets/art/ui/broadcast/character_oppo_going.png"),
	}
	rooftop_shoots.character_overlays = {
		mc.id: load("res://assets/art/ui/broadcast/character_mc_shoots.png"),
		opposition_person.id: load("res://assets/art/ui/broadcast/character_oppo_shoots.png"),
	}
	victim_shot.character_overlays = {
		government_official.id: load("res://assets/art/ui/broadcast/character_gov_shot.png"),
	}

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


static func _action(id: StringName, display_name: String, scene_image_path: String = "", max_characters := 2) -> ActionDef:
	var action := ActionDef.new()
	action.id = id
	action.display_name = display_name
	action.max_characters = max_characters
	if not scene_image_path.is_empty():
		action.scene_image = load(scene_image_path)
	return action
