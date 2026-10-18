extends PanelContainer

@onready var tool_axe: Button = $MarginContainer/HBoxContainer/ToolAxe
@onready var tool_tilling: Button = $MarginContainer/HBoxContainer/ToolTill

const FOOD_ENERGY_RECOVERY: int = 25
const POTION_HEAL: int = 25

func _on_tool_axe_pressed() -> void:
	ToolManager.select_tool(DataTypes.Tools.AxeWood)

func _on_tool_till_pressed() -> void:
	ToolManager.select_tool(DataTypes.Tools.TillGround)

func _on_food_apple_pressed() -> void:
	ToolManager.select_tool(DataTypes.Tools.tool_apple)
	_use_food_apple()


func _on_potions_pressed() -> void:
	ToolManager.select_tool(DataTypes.Tools.tool_potions)
	_use_potion()


func _use_food_apple() -> void:
	if InventoryManager.spend_collectable("food", 1):
		PlayerStats.recover_energy(FOOD_ENERGY_RECOVERY)
		_notify_current_scene_consumable_used("food", FOOD_ENERGY_RECOVERY)


func _use_potion() -> void:
	if InventoryManager.spend_collectable("potion", 1):
		PlayerStats.heal(POTION_HEAL)
		_notify_current_scene_consumable_used("potion", POTION_HEAL)


func _notify_current_scene_consumable_used(collectable_name: String, amount: int) -> void:
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("on_consumable_used"):
		scene.on_consumable_used(collectable_name, amount)
