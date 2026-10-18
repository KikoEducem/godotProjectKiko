extends NodeState

@export var player: Player1
@export var animated_sprite_2d: AnimatedSprite2D

func _on_process(_delta: float) -> void:
	pass

func _on_physics_process(_delta: float) -> void:
	if not player.can_control():
		return

	var dir := player.player_direction
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN

	var anim_name: StringName = &"idle_front"
	if dir == Vector2.UP:
		anim_name = &"idle_back"
	elif dir == Vector2.RIGHT:
		anim_name = &"idle_right"
	elif dir == Vector2.LEFT:
		anim_name = &"idle_left"

	if animated_sprite_2d.animation != anim_name:
		animated_sprite_2d.play(anim_name)
		player.sync_animation(anim_name)

func _on_next_transitions() -> void:
	if not player.can_control():
		return

	GameInputEvents.movement_input()
	var wants_to_use_tool: bool = GameInputEvents.use_tool()

	if GameInputEvents.is_movement_input():
		transition.emit("Walk")
		return

	if wants_to_use_tool:
		if player.current_tool == DataTypes.Tools.tool_apple or player.current_tool == DataTypes.Tools.tool_potions:
			player.try_use_selected_consumable()
		elif player.current_tool == DataTypes.Tools.AxeWood and player.try_use_current_tool_energy():
			transition.emit("Chopping")
		elif player.current_tool == DataTypes.Tools.TillGround and player.try_use_current_tool_energy():
			transition.emit("Tilling")
		elif player.current_tool == DataTypes.Tools.WaterCrops and player.try_use_current_tool_energy():
			transition.emit("Watering")

func _on_enter() -> void:
	pass

func _on_exit() -> void:
	animated_sprite_2d.stop()
