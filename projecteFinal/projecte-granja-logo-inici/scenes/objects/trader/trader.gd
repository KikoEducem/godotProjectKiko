extends Sprite2D

@onready var trade_area: Area2D = $TradeArea
@onready var prompt_label: Label = $PromptLabel

@export_enum("dungeon", "overworld") var trade_mode: String = "dungeon"

var player_inside: bool = false


func _ready() -> void:
	prompt_label.visible = false
	_update_prompt_text()

	if not I18n.language_changed.is_connected(_on_language_changed):
		I18n.language_changed.connect(_on_language_changed)

	trade_area.body_entered.connect(_on_trade_area_body_entered)
	trade_area.body_exited.connect(_on_trade_area_body_exited)


func _process(_delta: float) -> void:
	if player_inside and Input.is_action_just_pressed("interact"):
		var trade_panel := get_tree().get_first_node_in_group("trade_panel")
		if trade_panel:
			trade_panel.open_panel(trade_mode)


func _on_trade_area_body_entered(body: Node2D) -> void:
	if body is Player1:
		player_inside = true
		_update_prompt_text()
		prompt_label.visible = true


func _on_trade_area_body_exited(body: Node2D) -> void:
	if body is Player1:
		player_inside = false
		prompt_label.visible = false
		var trade_panel := get_tree().get_first_node_in_group("trade_panel")
		if trade_panel:
			trade_panel.close_panel()


func _on_language_changed(_language_code: String) -> void:
	_update_prompt_text()


func _update_prompt_text() -> void:
	prompt_label.text = I18n.t("trader.prompt")
