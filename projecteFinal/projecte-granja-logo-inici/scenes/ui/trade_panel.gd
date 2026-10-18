class_name TradePanel
extends PanelContainer

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var info_label: Label = $MarginContainer/VBoxContainer/InfoLabel
@onready var first_status_label: Label = $MarginContainer/VBoxContainer/AxeDamageLabel
@onready var second_status_label: Label = $MarginContainer/VBoxContainer/TillDamageLabel
@onready var first_trade_text_label: Label = $MarginContainer/VBoxContainer/GoldTrade/GoldTextLabel
@onready var first_trade_cost_label: Label = $MarginContainer/VBoxContainer/GoldTrade/GoldCostLabel
@onready var first_trade_button: Button = $MarginContainer/VBoxContainer/GoldTrade/BuyAxeButton
@onready var second_trade_text_label: Label = $MarginContainer/VBoxContainer/RubiTrade/RubiTextLabel
@onready var second_trade_cost_label: Label = $MarginContainer/VBoxContainer/RubiTrade/RubiCostLabel
@onready var second_trade_button: Button = $MarginContainer/VBoxContainer/RubiTrade/BuyTillButton
@onready var message_label: Label = $MarginContainer/VBoxContainer/MessageLabel
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton

const AXE_COST: int = 1
const TILL_COST: int = 1
const FOOD_COST_LOG: int = 1
const POTION_COST_MUSHROOM: int = 1

var current_mode: String = "dungeon"
var message_key: String = "trader.message.upgrades"


func _ready() -> void:
	visible = false
	add_to_group("trade_panel")
	_center_panel.call_deferred()

	InventoryManager.inventory_changed.connect(update_ui)
	ToolManager.tool_damage_changed.connect(_on_tool_damage_changed)

	if not I18n.language_changed.is_connected(_on_language_changed):
		I18n.language_changed.connect(_on_language_changed)

	update_ui()


func open_panel(trade_mode: String = "dungeon") -> void:
	current_mode = trade_mode
	message_key = "trader.message.resources" if current_mode == "overworld" else "trader.message.upgrades"
	visible = true
	update_ui()
	_center_panel.call_deferred()


func close_panel() -> void:
	visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_center_panel.call_deferred()


func _center_panel() -> void:
	var viewport_size := get_viewport_rect().size
	var panel_size := size

	if panel_size.x <= 1.0 or panel_size.y <= 1.0:
		panel_size = Vector2(320.0, 230.0)

	position = Vector2(
		round((viewport_size.x - panel_size.x) * 0.5),
		round((viewport_size.y - panel_size.y) * 0.5)
	)


func _trade_text(trade_key: String, cost: int) -> String:
	# These four cost labels are generated from the real constants so the UI always
	# matches the actual trade cost, even if the Raspberry still has old text.
	var language := I18n.get_language()

	match trade_key:
		"log_food":
			if language == "es":
				return "%d Madera = 1 Manzana" % cost
			if language == "en":
				return "%d Wood = 1 Apple" % cost
			return "%d Fusta = 1 Poma" % cost
		"mushroom_potion":
			if language == "es":
				return "%d Seta = 1 Poción" % cost
			if language == "en":
				return "%d Mushroom = 1 Potion" % cost
			return "%d Bolet = 1 Poció" % cost
		"gold_axe":
			if language == "es":
				return "%d Oro = +1 Hacha" % cost
			if language == "en":
				return "%d Gold = +1 Axe" % cost
			return "%d Or = +1 Destral" % cost
		"rubi_till":
			if language == "es":
				return "%d Rubí = +1 Pico" % cost
			if language == "en":
				return "%d Ruby = +1 Pickaxe" % cost
			return "%d Rubí = +1 Pic" % cost

	return ""


func update_ui() -> void:
	title_label.text = I18n.t("trader.title")
	close_button.text = I18n.t("ui.close")

	if current_mode == "overworld":
		info_label.text = I18n.t("trader.info.overworld")
		first_status_label.text = I18n.t("trader.status.log", [InventoryManager.get_count("log")])
		second_status_label.text = I18n.t("trader.status.mushroom", [InventoryManager.get_count("mushroom")])
		first_trade_text_label.text = _trade_text("log_food", FOOD_COST_LOG)
		first_trade_cost_label.text = I18n.t("trader.cost.food", [InventoryManager.get_count("food")])
		first_trade_button.text = I18n.t("trader.button.exchange")
		second_trade_text_label.text = _trade_text("mushroom_potion", POTION_COST_MUSHROOM)
		second_trade_cost_label.text = I18n.t("trader.cost.potion", [InventoryManager.get_count("potion")])
		second_trade_button.text = I18n.t("trader.button.exchange")
	elif current_mode == "dungeon":
		info_label.text = I18n.t("trader.info.dungeon")
		first_status_label.text = I18n.t("trader.status.axe_damage", [ToolManager.get_tool_damage(DataTypes.Tools.AxeWood)])
		second_status_label.text = I18n.t("trader.status.till_damage", [ToolManager.get_tool_damage(DataTypes.Tools.TillGround)])
		first_trade_text_label.text = _trade_text("gold_axe", AXE_COST)
		first_trade_cost_label.text = I18n.t("trader.cost.gold", [InventoryManager.get_count("gold")])
		first_trade_button.text = I18n.t("trader.button.buy")
		second_trade_text_label.text = _trade_text("rubi_till", TILL_COST)
		second_trade_cost_label.text = I18n.t("trader.cost.rubi", [InventoryManager.get_count("rubi")])
		second_trade_button.text = I18n.t("trader.button.buy")

	message_label.text = I18n.t(message_key)


func _on_language_changed(_language_code: String) -> void:
	update_ui()


func _on_tool_damage_changed(_tool: DataTypes.Tools, _damage: int) -> void:
	update_ui()


func _on_buy_axe_button_pressed() -> void:
	if current_mode == "overworld":
		if InventoryManager.spend_collectable("log", FOOD_COST_LOG):
			InventoryManager.add_collectable("food", 1)
			message_key = "trader.message.got_apple"
		else:
			message_key = "trader.message.not_enough_log"
	else:
		if InventoryManager.spend_collectable("gold", AXE_COST):
			ToolManager.upgrade_tool(DataTypes.Tools.AxeWood, 1)
			message_key = "trader.message.axe_upgraded"
		else:
			message_key = "trader.message.not_enough_gold"

	update_ui()


func _on_buy_till_button_pressed() -> void:
	if current_mode == "overworld":
		if InventoryManager.spend_collectable("mushroom", POTION_COST_MUSHROOM):
			InventoryManager.add_collectable("potion", 1)
			message_key = "trader.message.got_potion"
		else:
			message_key = "trader.message.not_enough_mushroom"
	else:
		if InventoryManager.spend_collectable("rubi", TILL_COST):
			ToolManager.upgrade_tool(DataTypes.Tools.TillGround, 1)
			message_key = "trader.message.till_upgraded"
		else:
			message_key = "trader.message.not_enough_rubi"

	update_ui()


func _on_close_button_pressed() -> void:
	close_panel()
