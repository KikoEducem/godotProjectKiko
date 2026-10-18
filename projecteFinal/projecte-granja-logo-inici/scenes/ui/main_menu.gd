extends Control

const SETTINGS_SCENE_PATH: String = "res://scenes/ui/start_menu.tscn"

@onready var title_label: Label = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/SubtitleLabel
@onready var start_button: Button = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/StartButton
@onready var hint_label: Label = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/HintLabel

var _changing_scene: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false

	if GameTimer.has_method("pause_timer"):
		GameTimer.pause_timer()

	if not I18n.language_changed.is_connected(_on_language_changed):
		I18n.language_changed.connect(_on_language_changed)

	if not start_button.pressed.is_connected(_on_start_button_pressed):
		start_button.pressed.connect(_on_start_button_pressed)

	I18n.set_language(GameSettings.language_code)
	_refresh_texts()
	start_button.grab_focus.call_deferred()

	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("play_context"):
		audio_manager.play_context("menu")


func _refresh_texts() -> void:
	title_label.text = I18n.t("main_menu.title")
	subtitle_label.text = I18n.t("main_menu.subtitle")
	start_button.text = I18n.t("main_menu.start_button")
	hint_label.text = I18n.t("main_menu.hint")


func _on_language_changed(_language_code: String) -> void:
	_refresh_texts()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_go_to_settings()


func _on_start_button_pressed() -> void:
	_go_to_settings()


func _go_to_settings() -> void:
	if _changing_scene:
		return

	_changing_scene = true
	var err := get_tree().change_scene_to_file(SETTINGS_SCENE_PATH)
	if err != OK:
		_changing_scene = false
		push_error("No se pudo abrir la pantalla de ajustes: %s" % SETTINGS_SCENE_PATH)
