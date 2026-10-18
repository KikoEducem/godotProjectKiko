extends Area2D

@export var target_scene := "res://scenes/worlds/Dungeon_world.tscn"
@export var spawn_id := "Spawn_dungeon_entrance"

func _on_body_entered(body: Node2D) -> void:
	print("Nombre:", body.name)
	print("Clase:", body.get_class())
	print("Script:", body.get_script())

	if body is CharacterBody2D:
		GameManager.next_spawn = spawn_id
		call_deferred("changeScene")

func changeScene():
	get_tree().change_scene_to_file(target_scene)
