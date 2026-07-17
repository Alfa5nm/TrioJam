class_name BroadcastDialogueBeat
extends Resource

enum Kind { SPOKEN, SILENT, THOUGHT, NAME_INPUT }

@export var speaker_id: StringName = &""
@export_multiline var text := ""
@export var emotion_id: StringName = &"neutral"
@export var kind := Kind.SPOKEN
@export var emphasis := 0.0


static func make(
		p_speaker: StringName,
		p_text: String,
		p_emotion: StringName = &"neutral",
		p_kind: Kind = Kind.SPOKEN,
		p_emphasis := 0.0
	) -> BroadcastDialogueBeat:
	var beat := BroadcastDialogueBeat.new()
	beat.speaker_id = p_speaker
	beat.text = p_text
	beat.emotion_id = p_emotion
	beat.kind = p_kind
	beat.emphasis = p_emphasis
	return beat
