class_name Player1
extends CharacterBody2D

const HURT_COMPONENT_SCENE := preload("res://scenes/components/hurt_component.tscn")
const TOOL_ENERGY_COST: int = 2
const FOOD_ENERGY_RECOVERY: int = 25
const POTION_HEAL: int = 25
const FINAL_BATTLE_SCENE_PATH: String = "res://scenes/worlds/Coliseum_world.tscn"

@export var speed: float = 170.0
@export var max_health: int = 100
@export var attack_damage: int = 20
@export var respawn_delay: float = 1.25
@export var current_tool: DataTypes.Tools = DataTypes.Tools.None

var health: int = max_health
var player_direction: Vector2 = Vector2.DOWN
var alive: bool = true
var spawn_position: Vector2 = Vector2.ZERO

var _next_attack_token: int = 0
var _processed_attacks: Dictionary = {}
var _is_respawning: bool = false

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hit_component: HitComponent = $HitComponent
@onready var hit_component_collision_shape: CollisionShape2D = $HitComponent/HitComponentCollisionShape2D

var hurt_component: HurtComponent
var hurt_component_collision_shape: CollisionShape2D
var health_bar: ProgressBar
var name_label: Label
var display_name: String = ""

func _enter_tree() -> void:
	var id := name.to_int()
	if id > 0:
		set_multiplayer_authority(id, true)

func _ready() -> void:
	add_to_group("player")
	spawn_position = global_position
	if _is_final_battle_player():
		_load_final_battle_health_from_player_stats()
	else:
		health = max_health
	player_direction = Vector2.DOWN

	var sync := get_node_or_null("MultiplayerSynchronizer")
	if sync != null:
		sync.queue_free()

	_connect_tool_manager()

	if _is_final_battle_player():
		current_tool = DataTypes.Tools.AxeWood
		_announce_initial_final_battle_health.call_deferred()
	elif current_tool == DataTypes.Tools.None:
		var tool_manager = get_node_or_null("/root/ToolManager")
		if tool_manager != null:
			current_tool = tool_manager.selected_tool

	_update_hit_damage()
	_ensure_health_bar()
	_ensure_name_label()
	_ensure_hurt_component()
	_configure_hit_component()
	_update_tool_indicator_position()
	_update_health_ui()
	_apply_alive_visuals()

func _physics_process(_delta: float) -> void:
	if not can_control():
		velocity = Vector2.ZERO
		return

	if Input.is_action_just_pressed("change_tool") and _is_final_battle_player():
		_cycle_tool()
		sync_state()

func can_control() -> bool:
	return is_multiplayer_authority() and alive and not _is_respawning

func begin_attack() -> void:
	if not can_control():
		return

	_next_attack_token += 1
	_update_hit_damage()
	hit_component.current_tool = current_tool
	hit_component.hit_damage = attack_damage
	hit_component.owner_peer_id = name.to_int()
	hit_component.attack_token = _next_attack_token
	_update_tool_indicator_position()

func sync_motion() -> void:
	sync_state()

func sync_state() -> void:
	if not _has_active_multiplayer() or not is_multiplayer_authority():
		return

	_update_tool_indicator_position()
	_apply_state.rpc(global_position, velocity, animated_sprite_2d.animation, current_tool, player_direction, health, max_health, alive)

func sync_animation(anim_name: StringName) -> void:
	if not _has_active_multiplayer() or not is_multiplayer_authority():
		return

	_update_tool_indicator_position()
	_apply_animation.rpc(anim_name, current_tool, player_direction)

func on_tool_selected(tool: DataTypes.Tools) -> void:
	if _is_final_battle_player():
		return

	current_tool = tool
	_update_hit_damage()
	print("Tool:", tool)

func on_tool_damage_changed(_tool: DataTypes.Tools, _damage: int) -> void:
	_update_hit_damage()

func update_hit_damage() -> void:
	_update_hit_damage()

func try_use_current_tool_energy() -> bool:
	if current_tool == DataTypes.Tools.AxeWood or current_tool == DataTypes.Tools.TillGround or current_tool == DataTypes.Tools.WaterCrops:
		var player_stats: Node = get_node_or_null("/root/PlayerStats")
		if player_stats != null and player_stats.has_method("spend_energy"):
			return player_stats.spend_energy(TOOL_ENERGY_COST)

	return true


func try_use_selected_consumable() -> bool:
	if current_tool == DataTypes.Tools.tool_apple:
		return _use_inventory_consumable("food", FOOD_ENERGY_RECOVERY, true)
	if current_tool == DataTypes.Tools.tool_potions:
		return _use_inventory_consumable("potion", POTION_HEAL, false)
	return false


func _use_inventory_consumable(collectable_name: String, amount: int, recover_energy: bool) -> bool:
	var inventory_manager: Node = get_node_or_null("/root/InventoryManager")
	var player_stats: Node = get_node_or_null("/root/PlayerStats")
	if inventory_manager == null or player_stats == null:
		return false
	if not inventory_manager.has_method("spend_collectable"):
		return false
	if not inventory_manager.spend_collectable(collectable_name, 1):
		return false

	if recover_energy:
		if player_stats.has_method("recover_energy"):
			player_stats.recover_energy(amount)
	else:
		if player_stats.has_method("heal"):
			player_stats.heal(amount)

	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("on_consumable_used"):
		scene.on_consumable_used(collectable_name, amount)

	return true

func take_damage(amount: int) -> void:
	if not is_multiplayer_authority() or not alive:
		return

	health = maxi(health - amount, 0)
	_update_health_ui()
	if _has_active_multiplayer():
		_sync_health.rpc(health, max_health)
		_play_hit_feedback.rpc()
	else:
		_play_hit_feedback()

	if health <= 0:
		_start_respawn()

func apply_environment_damage(amount: int, _source_key: String = "env") -> void:
	if not is_multiplayer_authority() or not alive:
		return

	take_damage(amount)

func _start_respawn() -> void:
	if _is_respawning:
		return

	_is_respawning = true
	alive = false
	velocity = Vector2.ZERO
	_update_health_ui()
	_apply_alive_visuals()

	if _has_active_multiplayer():
		_sync_alive_state.rpc(false)

	if _is_final_battle_player():
		var arena := get_parent()
		if arena != null and arena.has_method("register_player_defeated"):
			arena.register_player_defeated(name.to_int())
		return

	_respawn_after_delay()

func _respawn_after_delay() -> void:
	await get_tree().create_timer(respawn_delay).timeout

	if not is_instance_valid(self) or not is_multiplayer_authority():
		return

	health = max_health
	alive = true
	_is_respawning = false
	player_direction = Vector2.DOWN
	global_position = spawn_position
	velocity = Vector2.ZERO
	_processed_attacks.clear()
	_update_tool_indicator_position()
	_update_health_ui()
	_apply_alive_visuals()
	if _has_active_multiplayer():
		_sync_respawn.rpc(global_position, health, player_direction, &"idle_front")
	sync_state()

func _on_hurt_with_hit(hit_damage: int, source_hit_component: HitComponent) -> void:
	if not alive:
		return
	if source_hit_component == null:
		return

	var attacker_peer_id := source_hit_component.owner_peer_id
	if attacker_peer_id <= 0 or attacker_peer_id == name.to_int():
		return

	var attack_token := source_hit_component.attack_token

	if is_multiplayer_authority():
		_apply_incoming_hit(attacker_peer_id, hit_damage, attack_token)
	elif _has_active_multiplayer():
		request_damage.rpc_id(name.to_int(), attacker_peer_id, hit_damage, attack_token)

func _apply_incoming_hit(attacker_peer_id: int, hit_damage: int, attack_token: int) -> void:
	if not alive:
		return

	var attack_key := str(attacker_peer_id) + ":" + str(attack_token)
	if _processed_attacks.has(attack_key):
		return

	if _processed_attacks.size() > 64:
		_processed_attacks.clear()

	_processed_attacks[attack_key] = true
	take_damage(hit_damage)

func _ensure_hurt_component() -> void:
	hurt_component = get_node_or_null("HurtComponent") as HurtComponent

	if hurt_component == null:
		hurt_component = HURT_COMPONENT_SCENE.instantiate() as HurtComponent
		hurt_component.name = "HurtComponent"
		add_child(hurt_component)

	hurt_component.tool = DataTypes.Tools.AxeWood
	hurt_component.monitoring = true
	hurt_component.monitorable = true

	if not hurt_component.hurt_with_hit.is_connected(_on_hurt_with_hit):
		hurt_component.hurt_with_hit.connect(_on_hurt_with_hit)

	hurt_component_collision_shape = hurt_component.get_node_or_null("HurtComponentCollisionShape2D") as CollisionShape2D

	if hurt_component_collision_shape == null:
		hurt_component_collision_shape = CollisionShape2D.new()
		hurt_component_collision_shape.name = "HurtComponentCollisionShape2D"
		var shape := CircleShape2D.new()
		shape.radius = 5.0
		hurt_component_collision_shape.shape = shape
		hurt_component_collision_shape.position = Vector2(0, -6)
		hurt_component.add_child(hurt_component_collision_shape)

func _configure_hit_component() -> void:
	hit_component.current_tool = current_tool
	hit_component.hit_damage = attack_damage
	hit_component.owner_peer_id = name.to_int()
	hit_component.attack_token = 0
	hit_component.monitoring = true
	hit_component.monitorable = true
	_update_tool_indicator_position()

func _ensure_health_bar() -> void:
	health_bar = get_node_or_null("HealthBar") as ProgressBar

	if health_bar == null:
		health_bar = ProgressBar.new()
		health_bar.name = "HealthBar"
		health_bar.position = Vector2(-30, -26)
		health_bar.custom_minimum_size = Vector2(60, 1)
		health_bar.size = Vector2(60, 1)
		health_bar.scale = Vector2(1.0, 0.35)
		health_bar.show_percentage = false
		health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		health_bar.z_index = 20
		add_child(health_bar)

	health_bar.min_value = 0
	health_bar.max_value = max_health
	health_bar.step = 1
	_apply_health_bar_theme()

func _ensure_name_label() -> void:
	name_label = get_node_or_null("NameLabel") as Label

	if name_label == null:
		name_label = Label.new()
		name_label.name = "NameLabel"
		name_label.position = Vector2(-42, -42)
		name_label.size = Vector2(84, 12)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 8)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.z_index = 21
		add_child(name_label)

	_update_name_label()


func set_display_name(new_display_name: String) -> void:
	display_name = new_display_name.strip_edges()
	_update_name_label()


func _update_name_label() -> void:
	if name_label == null:
		return

	name_label.text = display_name
	name_label.visible = _is_final_battle_player() and not display_name.is_empty()
	name_label.modulate = Color(1, 1, 1, 1) if alive else Color(1, 1, 1, 0.55)


func _apply_health_bar_theme() -> void:
	if health_bar == null:
		return

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.08, 0.85)

	var fill := StyleBoxFlat.new()
	fill.bg_color = _health_fill_color()

	health_bar.add_theme_stylebox_override("background", bg)
	health_bar.add_theme_stylebox_override("fill", fill)

func _update_health_ui() -> void:
	if health_bar == null:
		return

	health_bar.max_value = max_health
	health_bar.value = health if alive else 0
	health_bar.visible = _is_final_battle_player()
	_apply_health_bar_theme()
	_update_name_label()

	if alive:
		health_bar.modulate = Color(1, 1, 1, 1)
	else:
		health_bar.modulate = Color(1, 1, 1, 0.55)

func _health_fill_color() -> Color:
	var health_ratio := float(health) / float(max(max_health, 1))

	if not alive:
		return Color(0.45, 0.45, 0.45, 0.95)
	if health_ratio > 0.6:
		return Color(0.28, 0.86, 0.38, 0.95)
	if health_ratio > 0.3:
		return Color(0.96, 0.78, 0.18, 0.95)

	return Color(0.92, 0.26, 0.24, 0.95)

func _apply_alive_visuals() -> void:
	var enabled := alive
	visible = true
	modulate = Color(1, 1, 1, 1) if enabled else Color(1, 1, 1, 0.45)
	body_collision_shape.disabled = not enabled
	hit_component.monitorable = enabled
	hit_component_collision_shape.disabled = true

	if hurt_component != null:
		hurt_component.monitoring = enabled
		hurt_component.monitorable = enabled

	if hurt_component_collision_shape != null:
		hurt_component_collision_shape.disabled = not enabled

	_update_name_label()

func _cycle_tool() -> void:
	current_tool += 1
	if current_tool > DataTypes.Tools.WaterCrops:
		current_tool = DataTypes.Tools.AxeWood

	_update_hit_damage()
	_update_tool_indicator_position()

func _update_tool_indicator_position() -> void:
	if hit_component_collision_shape == null:
		return

	hit_component_collision_shape.position = _tool_offset_for_direction(player_direction)

func _tool_offset_for_direction(dir: Vector2) -> Vector2:
	if dir == Vector2.UP:
		return Vector2(0, -18)
	if dir == Vector2.RIGHT:
		return Vector2(12, -2)
	if dir == Vector2.LEFT:
		return Vector2(-12, -2)
	return Vector2(0, 6)

func _connect_tool_manager() -> void:
	var tool_manager = get_node_or_null("/root/ToolManager")
	if tool_manager == null:
		return

	if not tool_manager.tool_selected.is_connected(on_tool_selected):
		tool_manager.tool_selected.connect(on_tool_selected)
	if not tool_manager.tool_damage_changed.is_connected(on_tool_damage_changed):
		tool_manager.tool_damage_changed.connect(on_tool_damage_changed)

func _update_hit_damage() -> void:
	var tool_manager = get_node_or_null("/root/ToolManager")
	if tool_manager != null and tool_manager.has_method("get_tool_damage") and not _is_final_battle_player():
		attack_damage = tool_manager.get_tool_damage(current_tool)
	elif _is_final_battle_player() and attack_damage < 20:
		attack_damage = 20

	if hit_component != null:
		hit_component.current_tool = current_tool
		hit_component.hit_damage = attack_damage

func _is_final_battle_player() -> bool:
	if name.to_int() <= 0:
		return false

	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return false

	return tree.current_scene.scene_file_path == FINAL_BATTLE_SCENE_PATH

func _load_final_battle_health_from_player_stats() -> void:
	var player_stats: Node = get_node_or_null("/root/PlayerStats")
	if player_stats == null:
		health = max_health
		return

	max_health = max(int(player_stats.max_health), 1)
	health = clamp(int(player_stats.health), 0, max_health)

func _announce_initial_final_battle_health() -> void:
	if not _is_final_battle_player() or not _has_active_multiplayer() or not is_multiplayer_authority():
		return

	_sync_health.rpc(health, max_health)
	sync_state()

func apply_health_snapshot(new_health: int, new_max_health: int, is_alive_now: bool) -> void:
	max_health = max(new_max_health, 1)
	health = clamp(new_health, 0, max_health)
	alive = is_alive_now
	_is_respawning = not is_alive_now

	if not alive:
		velocity = Vector2.ZERO

	_apply_alive_visuals()
	_update_health_ui()

func _has_active_multiplayer() -> bool:
	return multiplayer.multiplayer_peer != null

@rpc("any_peer", "call_remote", "reliable")
func request_damage(attacker_peer_id: int, hit_damage: int, attack_token: int) -> void:
	if not is_multiplayer_authority():
		return

	var sender := multiplayer.get_remote_sender_id()
	if sender != attacker_peer_id:
		return

	_apply_incoming_hit(attacker_peer_id, hit_damage, attack_token)

@rpc("any_peer", "call_remote", "reliable")
func request_environment_damage(hit_damage: int, source_key: String = "ghost") -> void:
	if not is_multiplayer_authority():
		return

	var sender := multiplayer.get_remote_sender_id()
	if sender != 1:
		return

	apply_environment_damage(hit_damage, source_key)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _apply_state(pos: Vector2, vel: Vector2, anim_name: StringName, tool: int, dir: Vector2, synced_health: int, synced_max_health: int, synced_alive: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()

	if sender != name.to_int():
		return
	if is_multiplayer_authority():
		return

	global_position = pos
	velocity = vel
	current_tool = tool
	player_direction = dir
	apply_health_snapshot(synced_health, synced_max_health, synced_alive)
	_update_tool_indicator_position()

	if animated_sprite_2d.animation != anim_name:
		animated_sprite_2d.play(anim_name)

@rpc("any_peer", "call_remote", "reliable")
func _apply_animation(anim_name: StringName, tool: int, dir: Vector2) -> void:
	var sender := multiplayer.get_remote_sender_id()

	if sender != name.to_int():
		return
	if is_multiplayer_authority():
		return

	current_tool = tool
	player_direction = dir
	_update_tool_indicator_position()
	animated_sprite_2d.play(anim_name)

@rpc("authority", "call_remote", "reliable")
func _sync_health(new_health: int, new_max_health: int) -> void:
	max_health = max(new_max_health, 1)
	health = clamp(new_health, 0, max_health)
	_update_health_ui()

@rpc("authority", "call_local", "reliable")
func _play_hit_feedback() -> void:
	animated_sprite_2d.modulate = Color(1.0, 0.55, 0.55)
	await get_tree().create_timer(0.12).timeout

	if not is_instance_valid(animated_sprite_2d):
		return

	animated_sprite_2d.modulate = Color(1, 1, 1)

@rpc("authority", "call_remote", "reliable")
func _sync_alive_state(is_alive_now: bool) -> void:
	alive = is_alive_now
	_is_respawning = not is_alive_now

	if not alive:
		velocity = Vector2.ZERO

	_apply_alive_visuals()
	_update_health_ui()

@rpc("authority", "call_remote", "reliable")
func _sync_respawn(pos: Vector2, new_health: int, dir: Vector2, anim_name: StringName) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	health = new_health
	alive = true
	player_direction = dir
	_is_respawning = false
	_processed_attacks.clear()
	_update_tool_indicator_position()
	_apply_alive_visuals()
	_update_health_ui()
	animated_sprite_2d.play(anim_name)

@rpc("authority", "call_remote", "reliable")
func force_pos(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
