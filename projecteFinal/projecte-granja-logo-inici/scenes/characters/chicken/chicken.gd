extends CharacterBody2D

@export var potion_scene: PackedScene
@export var drop_interval: float = 20.0
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 0.20

@onready var drop_timer: Timer = Timer.new()

func _ready() -> void:
	randomize()

	drop_timer.wait_time = drop_interval
	drop_timer.one_shot = false
	drop_timer.autostart = true
	drop_timer.timeout.connect(_on_drop_timer_timeout)
	add_child(drop_timer)

func _on_drop_timer_timeout() -> void:
	if potion_scene == null:
		return

	if randf() <= drop_chance:
		var potion = potion_scene.instantiate()
		potion.global_position = global_position + Vector2(0, 10)

		if get_parent():
			get_parent().add_child(potion)
		else:
			get_tree().current_scene.add_child(potion)
