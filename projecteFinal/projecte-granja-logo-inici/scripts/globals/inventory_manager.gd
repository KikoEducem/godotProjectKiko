extends Node

var inventory: Dictionary = {
	"log": 0,
	"stone": 0,
	"gold": 0,
	"rubi": 0,
	"diamond": 0,
	"mushroom": 0,
	"food": 0,
	"potion": 0
}

signal inventory_changed

func add_collectable(collectable_name: String, amount: int = 1) -> void:
	if inventory.has(collectable_name):
		inventory[collectable_name] += amount
		inventory_changed.emit()

func remove_collectable(collectable_name: String, amount: int = 1) -> void:
	if inventory.has(collectable_name) and inventory[collectable_name] >= amount:
		inventory[collectable_name] -= amount
		inventory_changed.emit()

func get_count(collectable_name: String) -> int:
	return inventory.get(collectable_name, 0)

func has_collectable(collectable_name: String, amount: int = 1) -> bool:
	return get_count(collectable_name) >= amount

func spend_collectable(collectable_name: String, amount: int = 1) -> bool:
	if !has_collectable(collectable_name, amount):
		return false

	remove_collectable(collectable_name, amount)
	return true
