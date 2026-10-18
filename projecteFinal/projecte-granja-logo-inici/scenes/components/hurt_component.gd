class_name HurtComponent
extends Area2D

@export var tool: DataTypes.Tools = DataTypes.Tools.None

signal hurt(hit_damage: int)
signal hurt_with_hit(hit_damage: int, hit_component: HitComponent)

func _on_area_entered(area: Area2D) -> void:
	var hit_component := area as HitComponent
	if hit_component == null:
		return

	if tool == hit_component.current_tool:
		hurt.emit(hit_component.hit_damage)
		hurt_with_hit.emit(hit_component.hit_damage, hit_component)
