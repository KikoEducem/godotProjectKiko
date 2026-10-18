extends NodeState

@export var player: Player1
@export var animated_sprite_2d: AnimatedSprite2D
@export var hit_component_collision_shape: CollisionShape2D

func _ready() -> void:
	if hit_component_collision_shape != null:
		hit_component_collision_shape.disabled = true
		hit_component_collision_shape.position = Vector2(0, 0)

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

	player.begin_attack()
	var dir := player.player_direction
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN

	var anim_name: StringName = &"tilling_front"
	if dir == Vector2.UP:
		anim_name = &"tilling_back"
	elif dir == Vector2.RIGHT:
		anim_name = &"tilling_right"
	elif dir == Vector2.LEFT:
		anim_name = &"tilling_left"

	animated_sprite_2d.play(anim_name)
	player.sync_animation(anim_name)
	if hit_component_collision_shape != null:
		hit_component_collision_shape.position = player._tool_offset_for_direction(dir)
		hit_component_collision_shape.disabled = false

func _on_exit() -> void:
	animated_sprite_2d.stop()
	if hit_component_collision_shape != null:
		hit_component_collision_shape.disabled = true
