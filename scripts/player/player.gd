class_name Player
extends CharacterBody2D

signal fell

@export var move_speed := 280.0
@export var acceleration := 1800.0
@export var friction := 2200.0
@export var jump_velocity := -540.0
@export var fall_limit := 850.0

const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.12

var controls_enabled := true
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _fall_reported := false
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var body_visual: Polygon2D = $BodyVisual


func _physics_process(delta: float) -> void:
	if not controls_enabled:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

	if is_on_floor():
		_coyote_timer = COYOTE_TIME
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
		velocity.y += _gravity * delta

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

	if Input.is_action_just_released("jump") and velocity.y < jump_velocity * 0.45:
		velocity.y = jump_velocity * 0.45

	var direction := Input.get_axis("move_left", "move_right")
	var change_rate := acceleration if not is_zero_approx(direction) else friction
	velocity.x = move_toward(velocity.x, direction * move_speed, change_rate * delta)

	if not is_zero_approx(direction):
		body_visual.scale.x = signf(direction)

	move_and_slide()

	if global_position.y > fall_limit and not _fall_reported:
		_fall_reported = true
		fell.emit()


func reset_to(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	_fall_reported = false
	controls_enabled = true
