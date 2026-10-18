extends Sprite2D

@onready var sleep_area: Area2D = $SleepArea
@onready var prompt_label: Label = $PromptLabel

var player_inside: bool = false
var _is_showing_rested_message: bool = false


func _ready() -> void:
	prompt_label.visible = false
	_update_prompt_text()

	if not I18n.language_changed.is_connected(_on_language_changed):
		I18n.language_changed.connect(_on_language_changed)

	sleep_area.body_entered.connect(_on_sleep_area_body_entered)
	sleep_area.body_exited.connect(_on_sleep_area_body_exited)


func _process(_delta: float) -> void:
	if player_inside and Input.is_action_just_pressed("interact"):
		PlayerStats.restore_all()
		_is_showing_rested_message = true
		prompt_label.text = I18n.t("bed.rested")
		prompt_label.visible = true


func _on_sleep_area_body_entered(body: Node2D) -> void:
	if body is Player1:
		player_inside = true
		_is_showing_rested_message = false
		_update_prompt_text()
		prompt_label.visible = true


func _on_sleep_area_body_exited(body: Node2D) -> void:
	if body is Player1:
		player_inside = false
		_is_showing_rested_message = false
		_update_prompt_text()
		prompt_label.visible = false


func _on_language_changed(_language_code: String) -> void:
	_update_prompt_text()


func _update_prompt_text() -> void:
	if _is_showing_rested_message:
		prompt_label.text = I18n.t("bed.rested")
	else:
		prompt_label.text = I18n.t("bed.prompt")
