extends Node

var selected_tool: DataTypes.Tools = DataTypes.Tools.None
var tool_damage: Dictionary = {
	DataTypes.Tools.AxeWood: 1,
	DataTypes.Tools.TillGround: 1
}

signal tool_selected(tool: DataTypes.Tools)
signal enable_tool(tool: DataTypes.Tools)
signal tool_damage_changed(tool: DataTypes.Tools, damage: int)

func select_tool(tool: DataTypes.Tools) -> void:
	selected_tool = tool
	tool_selected.emit(tool)

func enable_tool_button(tool: DataTypes.Tools) -> void:
	enable_tool.emit(tool)

func get_tool_damage(tool: DataTypes.Tools) -> int:
	return tool_damage.get(tool, 1)

func upgrade_tool(tool: DataTypes.Tools, amount: int = 1) -> void:
	var new_damage: int = get_tool_damage(tool) + amount
	tool_damage[tool] = new_damage
	tool_damage_changed.emit(tool, new_damage)
