class_name GameInputEvents

static var direction: Vector2

static func movement_input() -> Vector2:
	if Input.is_action_pressed("walk_left_1"):
		direction = Vector2.LEFT
	elif Input.is_action_pressed("walk_right_1"):
		direction = Vector2.RIGHT
	elif Input.is_action_pressed("walk_up_1"):
		direction = Vector2.UP
	elif Input.is_action_pressed("walk_down_1"):
		direction = Vector2.DOWN
	else:
		direction = Vector2.ZERO

	return direction

static func is_movement_input() -> bool:
	return direction != Vector2.ZERO

static func use_tool() -> bool:
	if _is_trade_panel_open():
		return false

	return Input.is_action_just_pressed("hit")

static func _is_trade_panel_open() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false

	for node in tree.get_nodes_in_group("trade_panel"):
		if node is CanvasItem and node.visible:
			return true

	return false
