extends CharacterBody2D

@export var speed: float = 40.0
@export var detection_radius: float = 250.0
@export var touch_damage: int = 5
@export var touch_cooldown: float = 0.7

var player_target: Node2D = null
var _touch_cooldowns: Dictionary = {}

@onready var touch_area: Area2D = $TouchArea
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if animated_sprite_2d != null:
		animated_sprite_2d.play("walk")

func _physics_process(_delta: float) -> void:
	# IA solo corre en el servidor para evitar desincronizacion
	if not multiplayer.is_server():
		return
		
	_find_closest_player()
	
	if player_target:
		var dist = global_position.distance_to(player_target.global_position)
		if dist < detection_radius:
			var dir = (player_target.global_position - global_position).normalized()
			velocity = dir * speed
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
	_damage_touching_players()

func _find_closest_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	var closest = null
	var min_dist = INF
	
	for p in players:
		if not is_instance_valid(p):
			continue
		if p.has_method("can_control") and not p.alive:
			continue
		var d = global_position.distance_to(p.global_position)
		if d < min_dist:
			min_dist = d
			closest = p
	player_target = closest

func _damage_touching_players() -> void:
	if touch_area == null:
		return

	for body in touch_area.get_overlapping_bodies():
		if body == null or not is_instance_valid(body):
			continue
		if not body.is_in_group("player"):
			continue
		if body.has_method("apply_environment_damage") and not body.alive:
			continue

		var peer_id := body.name.to_int()
		if peer_id <= 0:
			continue

		var now := Time.get_ticks_msec() / 1000.0
		var next_allowed := float(_touch_cooldowns.get(peer_id, 0.0))
		if now < next_allowed:
			continue
		_touch_cooldowns[peer_id] = now + touch_cooldown

		if body.is_multiplayer_authority():
			body.apply_environment_damage(touch_damage, "ghost")
		else:
			body.request_environment_damage.rpc_id(peer_id, touch_damage, "ghost")
