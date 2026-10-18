extends Node

signal settings_changed
signal volume_changed(volume: float)
signal player_name_changed(player_name: String)
signal language_changed(language_code: String)

const CONFIG_PATH: String = "user://settings.cfg"
const DEFAULT_PLAYER_NAME: String = "Jugador"
const DEFAULT_LANGUAGE: String = "ca"
const AVAILABLE_LANGUAGES: Array[String] = ["ca", "es", "en"]
const API_BASE_URL: String = "http://10.0.4.177:8080"


var player_name: String = DEFAULT_PLAYER_NAME
var language_code: String = DEFAULT_LANGUAGE
var master_volume: float = 0.8
var game_started: bool = false
var _settings_http_request: HTTPRequest


func _ready() -> void:
	load_settings()
	_apply_master_volume()
	_ensure_settings_http_request()


func apply_settings(new_player_name: String, new_language_code: String, new_master_volume: float, save_to_disk: bool = true) -> void:
	set_player_name(new_player_name)
	set_language(new_language_code)
	set_master_volume(new_master_volume)
	game_started = true

	if save_to_disk:
		save_settings()

	settings_changed.emit()
	save_settings_to_raspberry()


func set_player_name(new_player_name: String) -> void:
	var clean_name := new_player_name.strip_edges()
	if clean_name.is_empty():
		clean_name = DEFAULT_PLAYER_NAME

	player_name = clean_name
	player_name_changed.emit(player_name)


func set_language(new_language_code: String) -> void:
	language_code = _normalize_language(new_language_code)
	language_changed.emit(language_code)

	var i18n = get_node_or_null("/root/I18n")
	if i18n != null and i18n.has_method("set_language"):
		i18n.set_language(language_code)


func set_master_volume(new_master_volume: float) -> void:
	master_volume = clamp(new_master_volume, 0.0, 1.0)
	_apply_master_volume()
	volume_changed.emit(master_volume)

	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("set_master_volume"):
		audio_manager.set_master_volume(master_volume)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "player_name", player_name)
	config.set_value("settings", "language_code", language_code)
	config.set_value("settings", "master_volume", master_volume)

	var err := config.save(CONFIG_PATH)
	if err != OK:
		push_warning("No se pudo guardar la configuracion del juego en %s" % CONFIG_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)
	if err != OK:
		return

	player_name = str(config.get_value("settings", "player_name", DEFAULT_PLAYER_NAME)).strip_edges()
	if player_name.is_empty():
		player_name = DEFAULT_PLAYER_NAME

	language_code = _normalize_language(str(config.get_value("settings", "language_code", DEFAULT_LANGUAGE)))
	master_volume = clamp(float(config.get_value("settings", "master_volume", 0.8)), 0.0, 1.0)


func get_safe_player_name(peer_id: int = 1) -> String:
	var clean_name := player_name.strip_edges()
	if clean_name.is_empty():
		return "%s %d" % [DEFAULT_PLAYER_NAME, peer_id]
	return clean_name


func save_settings_to_raspberry(player_id: String = "player1") -> void:
	_ensure_settings_http_request()
	if _settings_http_request == null:
		return

	if _settings_http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_settings_http_request.cancel_request()

	var payload := {
		"player_name": player_name,
		"language": language_code,
		"volume": master_volume
	}

	var json_body := JSON.stringify(payload)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var url := "%s/settings/%s" % [API_BASE_URL, player_id]
	var err := _settings_http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		push_warning("No s'ha pogut guardar la configuracio a la Raspberry")


func _ensure_settings_http_request() -> void:
	if _settings_http_request != null:
		return

	_settings_http_request = HTTPRequest.new()
	_settings_http_request.name = "SettingsHTTPRequest"
	_settings_http_request.timeout = 3.0
	add_child(_settings_http_request)
	_settings_http_request.request_completed.connect(_on_save_settings_to_raspberry_completed)


func _on_save_settings_to_raspberry_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		push_warning("La Raspberry no ha confirmat la configuracio. HTTP %d" % response_code)
		return

	print("Configuracio guardada a la Raspberry: ", player_name, " / ", language_code)


func _normalize_language(value: String) -> String:
	if AVAILABLE_LANGUAGES.has(value):
		return value
	return DEFAULT_LANGUAGE


func _apply_master_volume() -> void:
	var master_bus_index := AudioServer.get_bus_index("Master")
	if master_bus_index < 0:
		return

	var volume_db := -80.0
	if master_volume > 0.0:
		volume_db = linear_to_db(master_volume)

	AudioServer.set_bus_volume_db(master_bus_index, volume_db)
