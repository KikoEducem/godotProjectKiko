extends Sprite2D

@onready var hurt_component: HurtComponent = $HurtComponentPic
@onready var damage_component: DamageComponent = $DamageComponent

var mini_mushroom_scene = preload("res://scenes/objects/mushroom/mini_mushroom.tscn")

func _ready() -> void:
	hurt_component.hurt.connect(on_hurt)
	damage_component.max_damaged_reached.connect(on_max_damage_reached)

func on_hurt(hit_damage: int) -> void:
	damage_component.apply_damage(hit_damage)

func on_max_damage_reached() -> void:
	call_deferred("add_mini_mushroom_scene")
	queue_free()

func add_mini_mushroom_scene() -> void:
	var mushroom_instance = mini_mushroom_scene.instantiate() as Node2D
	mushroom_instance.global_position = global_position
	get_parent().add_child(mushroom_instance)
