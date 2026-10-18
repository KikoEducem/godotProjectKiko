extends PanelContainer

@onready var log_label: Label = $MarginContainer/VBoxContainer/Logs/LogLabel
@onready var stone_label: Label = $MarginContainer/VBoxContainer/Stone/StoneLabel
@onready var gold_label: Label = $MarginContainer/VBoxContainer/Gold/GoldLabel
@onready var rubi_label: Label = $MarginContainer/VBoxContainer/Rubi/RubiLabel
@onready var diamond_label: Label = $MarginContainer/VBoxContainer/Diamond/DiamondLabel
@onready var mushroom_label: Label = $MarginContainer/VBoxContainer/Mushroom/MushroomLabel
@onready var food_label: Label = $MarginContainer/VBoxContainer/Food/FoodLabel
@onready var potion_label: Label = $MarginContainer/VBoxContainer/Potion/PotionLabel

func _ready() -> void:
	InventoryManager.inventory_changed.connect(on_inventory_changed)
	on_inventory_changed()

func on_inventory_changed() -> void:
	var inventory: Dictionary = InventoryManager.inventory

	log_label.text = str(inventory.get("log", 0))
	stone_label.text = str(inventory.get("stone", 0))
	gold_label.text = str(inventory.get("gold", 0))
	rubi_label.text = str(inventory.get("rubi", 0))
	diamond_label.text = str(inventory.get("diamond", 0))
	mushroom_label.text = str(inventory.get("mushroom", 0))
	food_label.text = str(inventory.get("food", 0))
	potion_label.text = str(inventory.get("potion", 0))
