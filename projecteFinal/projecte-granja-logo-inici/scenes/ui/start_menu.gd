extends Control

const MAIN_GAME_SCENE_PATH: String = "res://scenes/test/test_sence_UI.tscn"
const LANGUAGE_CODES: Array[String] = ["ca", "es", "en"]

@onready var title_label: Label = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/SubtitleLabel
@onready var name_label: Label = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/NameLabel
@onready var name_input: LineEdit = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/NameInput
@onready var volume_label: Label = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/VolumeLabel
@onready var volume_slider: HSlider = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/VolumeRow/VolumeSlider
@onready var volume_value_label: Label = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/VolumeRow/VolumeValueLabel
@onready var language_label: Label = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/LanguageLabel
@onready var language_option: OptionButton = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/LanguageOption
@onready var start_button: Button = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/StartButton
@onready var press_space_label: Label = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/PressSpaceLabel

var _refreshing_language_options: bool = false
var _starting_game: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false

	if GameTimer.has_method("pause_timer"):
		GameTimer.pause_timer()

	name_input.text = GameSettings.player_name
	volume_slider.value = round(GameSettings.master_volume * 100.0)

	if not I18n.language_changed.is_connected(_on_language_changed):
		I18n.language_changed.connect(_on_language_changed)

	if not volume_slider.value_changed.is_connected(_on_volume_slider_value_changed):
		volume_slider.value_changed.connect(_on_volume_slider_value_changed)

	if not language_option.item_selected.is_connected(_on_language_option_item_selected):
		language_option.item_selected.connect(_on_language_option_item_selected)

	if not start_button.pressed.is_connected(_on_start_button_pressed):
		start_button.pressed.connect(_on_start_button_pressed)

	start_button.grab_focus.call_deferred()

	I18n.set_language(GameSettings.language_code)
	_refresh_texts()

	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("play_context"):
		audio_manager.play_context("menu")


func _refresh_texts() -> void:
	title_label.text = I18n.t("menu.title")
	subtitle_label.text = I18n.t("menu.subtitle")
	name_label.text = I18n.t("menu.player_name")
	name_input.placeholder_text = I18n.t("menu.player_name_placeholder")
	volume_label.text = I18n.t("menu.volume")
	language_label.text = I18n.t("menu.language")
	start_button.text = I18n.t("menu.start_button")
	press_space_label.text = I18n.t("menu.press_space")
	_update_volume_value_label()
	_rebuild_language_options()


func _rebuild_language_options() -> void:
	var selected_language := I18n.get_language()
	_refreshing_language_options = true
	language_option.clear()

	for i in range(LANGUAGE_CODES.size()):
		var language_code := LANGUAGE_CODES[i]
		language_option.add_item(I18n.t("language.%s" % language_code), i)
		if language_code == selected_language:
			language_option.select(i)

	_refreshing_language_options = false


func _on_language_changed(_language_code: String) -> void:
	_refresh_texts()


func _on_language_option_item_selected(index: int) -> void:
	if _refreshing_language_options:
		return
	if index < 0 or index >= LANGUAGE_CODES.size():
		return

	GameSettings.set_language(LANGUAGE_CODES[index])


func _on_volume_slider_value_changed(_value: float) -> void:
	GameSettings.set_master_volume(volume_slider.value / 100.0)
	_update_volume_value_label()


func _update_volume_value_label() -> void:
	volume_value_label.text = "%d%%" % int(round(volume_slider.value))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_start_game()


func _on_start_button_pressed() -> void:
	_start_game()


func _start_game() -> void:
	if _starting_game:
		return

	_starting_game = true

	var chosen_name := name_input.text.strip_edges()
	if chosen_name.is_empty():
		chosen_name = I18n.t("menu.default_player")

	var selected_index := language_option.selected
	var chosen_language := GameSettings.language_code
	if selected_index >= 0 and selected_index < LANGUAGE_CODES.size():
		chosen_language = LANGUAGE_CODES[selected_index]

	GameSettings.apply_settings(chosen_name, chosen_language, volume_slider.value / 100.0, true)
	GameTimer.auto_start_final_battle = true
	GameTimer.reset_timer(GameTimer.DEFAULT_DURATION_SECONDS)

	var err := get_tree().change_scene_to_file(MAIN_GAME_SCENE_PATH)
	if err != OK:
		_starting_game = false
		push_error("No se pudo iniciar la partida: %s" % MAIN_GAME_SCENE_PATH)
