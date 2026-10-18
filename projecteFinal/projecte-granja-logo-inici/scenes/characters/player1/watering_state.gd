extends NodeState

@export var player: Player1
@export var animated_sprite_2d: AnimatedSprite2D

func _on_process(_delta: float) -> void:
	pass

func _on_physics_process(_delta: float) -> void:
	pass

func _on_next_transitions() -> void:
	if !animated_sprite_2d.is_playing():
		transition.emit("Idle")

func _on_enter() -> void:
	if not player.can_control():
		return

	var dir := player.player_direction
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN

	var anim_name: StringName = &"watering_front"
	if dir == Vector2.UP:
		anim_name = &"watering_back"
	elif dir == Vector2.RIGHT:
		anim_name = &"watering_right"
	elif dir == Vector2.LEFT:
		anim_name = &"watering_left"

	animated_sprite_2d.play(anim_name)
	player.sync_animation(anim_name)

func _on_exit() -> void:
	animated_sprite_2d.stop()
