extends NodeState

@export var player: Player1
@export var animated_sprite_2d: AnimatedSprite2D
@export var speed: int = 50

func _on_process(_delta: float) -> void:
	pass

func _on_physics_process(_delta: float) -> void:
	if not player.can_control():
		return

	var direction: Vector2 = GameInputEvents.movement_input()
	var anim_name: StringName = &""

	if direction == Vector2.UP:
		anim_name = &"walk_back"
	elif direction == Vector2.RIGHT:
		anim_name = &"walk_right"
	elif direction == Vector2.DOWN:
		anim_name = &"walk_front"
	elif direction == Vector2.LEFT:
		anim_name = &"walk_left"

	if anim_name != &"" and animated_sprite_2d.animation != anim_name:
		animated_sprite_2d.play(anim_name)

	if direction != Vector2.ZERO:
		player.player_direction = direction
		player._update_tool_indicator_position()

	player.velocity = direction * speed
	player.move_and_slide()
	player.sync_motion()

func _on_next_transitions() -> void:
	if not player.can_control():
		return
	if not GameInputEvents.is_movement_input():
		transition.emit("Idle")

func _on_enter() -> void:
	pass

func _on_exit() -> void:
	animated_sprite_2d.stop()
