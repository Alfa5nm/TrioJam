class_name Day3TVBroadcast
extends Control

const PRESENTER_SHEET := preload("res://assets/art/Broadcast/presenter-sheet-v1.png")
const CELL_SIZE := Vector2(444, 444)

@onready var presenter: AnimatedSprite2D = $Presenter
@onready var signal_noise: ColorRect = $SignalNoise
@onready var story_image: TextureRect = $StoryImage


func _ready() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation(&"idle")
	frames.add_animation(&"talk")
	frames.set_animation_loop(&"idle", true)
	frames.set_animation_loop(&"talk", true)
	frames.set_animation_speed(&"idle", 2.0)
	frames.set_animation_speed(&"talk", 7.0)
	for column in 4:
		var frame := AtlasTexture.new()
		frame.atlas = PRESENTER_SHEET
		frame.region = Rect2(Vector2(column, 0) * CELL_SIZE, CELL_SIZE)
		frames.add_frame(&"talk", frame)
	frames.add_frame(&"idle", frames.get_frame_texture(&"talk", 0))
	presenter.sprite_frames = frames
	presenter.play(&"idle")


func set_talking(talking: bool) -> void:
	presenter.play(&"talk" if talking else &"idle")


func pulse_interference() -> void:
	signal_noise.modulate.a = 0.42
	create_tween().tween_property(signal_noise, "modulate:a", 0.08, 0.18)


func set_story_image(texture: Texture2D) -> void:
	story_image.texture = texture
	story_image.modulate.a = 0.0
	create_tween().tween_property(story_image, "modulate:a", 1.0, 0.2)
