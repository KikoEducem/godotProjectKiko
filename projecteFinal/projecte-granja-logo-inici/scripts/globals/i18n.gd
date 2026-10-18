extends Node

signal language_changed(language_code: String)
signal remote_translations_loaded(language_code: String)
signal remote_translations_failed(language_code: String, error_message: String)

const DEFAULT_LANGUAGE: String = "ca"
const FALLBACK_LANGUAGE: String = "es"
const FINAL_FALLBACK_LANGUAGE: String = "en"
const AVAILABLE_LANGUAGES: Array[String] = ["ca", "es", "en"]

# Raspberry Pi API. Change this IP if the Raspberry changes address.
const API_BASE_URL: String = "http://10.0.4.177:8080"
const USE_REMOTE_TRANSLATIONS: bool = true

var current_language: String = DEFAULT_LANGUAGE
var _http_request: HTTPRequest
var _pending_language: String = ""

var translations: Dictionary = {
	"ca": {
		"language.ca": "Català",
		"language.es": "Castellà",
		"language.en": "Anglès",
		"main_menu.title": "Projecte Granja",
		"main_menu.subtitle": "Aventura, recursos i batalla final",
		"main_menu.start_button": "Iniciar",
		"main_menu.hint": "Prem ESPAI o ENTER per continuar",
		"menu.title": "Projecte Granja",
		"menu.subtitle": "Configura la partida abans de començar",
		"menu.player_name": "Nom del personatge",
		"menu.player_name_placeholder": "Escriu el teu nom",
		"menu.volume": "Volum general",
		"menu.language": "Idioma",
		"menu.start_button": "Guardar i començar",
		"menu.press_space": "Prem ESPAI per començar",
		"menu.default_player": "Jugador",
		"trader.title": "Comerciant",
		"trader.prompt": "[E] Comerciar",
		"trader.info.overworld": "Canvia recursos per consumibles",
		"trader.info.dungeon": "Canvia minerals per millores",
		"trader.status.log": "Tens %d fusta",
		"trader.status.mushroom": "Tens %d bolets",
		"trader.status.axe_damage": "Mal de la destral: %d",
		"trader.status.till_damage": "Mal del pic: %d",
		"trader.trade.log_food": "1 Fusta = 1 Poma",
		"trader.trade.mushroom_potion": "1 Bolet = 1 Poció",
		"trader.trade.gold_axe": "1 Or = +1 Destral",
		"trader.trade.rubi_till": "1 Rubí = +1 Pic",
		"trader.cost.food": "Pomes: %d",
		"trader.cost.potion": "Pocions: %d",
		"trader.cost.gold": "Tens %d or",
		"trader.cost.rubi": "Tens %d robins",
		"trader.button.exchange": "Canviar",
		"trader.button.buy": "Comprar",
		"trader.message.resources": "Apropa't al comerciant i canvia recursos",
		"trader.message.upgrades": "Apropa't al comerciant i compra millores",
		"trader.message.got_apple": "+1 poma",
		"trader.message.got_potion": "+1 poció",
		"trader.message.axe_upgraded": "+1 mal a la destral",
		"trader.message.till_upgraded": "+1 mal al pic",
		"trader.message.not_enough_log": "No tens prou fusta",
		"trader.message.not_enough_mushroom": "No tens prou bolets",
		"trader.message.not_enough_gold": "No tens prou or",
		"trader.message.not_enough_rubi": "No tens prou robins",
		"ui.close": "Tancar",
		"bed.prompt": "[E] Dormir",
		"bed.rested": "Descansat!",
		"battle.player_line": "Jugador %d: %s",
		"battle.default_player": "Jugador %d",
		"battle.waiting": "Esperant rival...",
		"battle.win": "%s ha guanyat!\n%s derrotat",
		"battle.draw": "EMPAT!\nTemps esgotat"
	},
	"es": {
		"language.ca": "Catalán",
		"language.es": "Castellano",
		"language.en": "Inglés",
		"main_menu.title": "Proyecto Granja",
		"main_menu.subtitle": "Aventura, recursos y batalla final",
		"main_menu.start_button": "Iniciar",
		"main_menu.hint": "Pulsa ESPACIO o ENTER para continuar",
		"menu.title": "Proyecto Granja",
		"menu.subtitle": "Configura la partida antes de empezar",
		"menu.player_name": "Nombre del personaje",
		"menu.player_name_placeholder": "Escribe tu nombre",
		"menu.volume": "Volumen general",
		"menu.language": "Idioma",
		"menu.start_button": "Guardar y empezar",
		"menu.press_space": "Pulsa ESPACIO para empezar",
		"menu.default_player": "Jugador",
		"trader.title": "Comerciante",
		"trader.prompt": "[E] Comerciar",
		"trader.info.overworld": "Cambia recursos por consumibles",
		"trader.info.dungeon": "Cambia minerales por mejoras",
		"trader.status.log": "Tienes %d madera",
		"trader.status.mushroom": "Tienes %d setas",
		"trader.status.axe_damage": "Daño del hacha: %d",
		"trader.status.till_damage": "Daño del pico: %d",
		"trader.trade.log_food": "1 Madera = 1 Manzana",
		"trader.trade.mushroom_potion": "1 Seta = 1 Poción",
		"trader.trade.gold_axe": "1 Oro = +1 Hacha",
		"trader.trade.rubi_till": "1 Rubí = +1 Pico",
		"trader.cost.food": "Manzanas: %d",
		"trader.cost.potion": "Pociones: %d",
		"trader.cost.gold": "Tienes %d oro",
		"trader.cost.rubi": "Tienes %d rubíes",
		"trader.button.exchange": "Cambiar",
		"trader.button.buy": "Comprar",
		"trader.message.resources": "Acércate al comerciante y cambia recursos",
		"trader.message.upgrades": "Acércate al comerciante y compra mejoras",
		"trader.message.got_apple": "+1 manzana",
		"trader.message.got_potion": "+1 poción",
		"trader.message.axe_upgraded": "+1 daño al hacha",
		"trader.message.till_upgraded": "+1 daño al pico",
		"trader.message.not_enough_log": "No tienes suficiente madera",
		"trader.message.not_enough_mushroom": "No tienes suficientes setas",
		"trader.message.not_enough_gold": "No tienes suficiente oro",
		"trader.message.not_enough_rubi": "No tienes suficientes rubíes",
		"ui.close": "Cerrar",
		"bed.prompt": "[E] Dormir",
		"bed.rested": "¡Descansado!",
		"battle.player_line": "Jugador %d: %s",
		"battle.default_player": "Jugador %d",
		"battle.waiting": "Esperando rival...",
		"battle.win": "¡%s ha ganado!\n%s derrotado",
		"battle.draw": "¡EMPATE!\nTiempo agotado"
	},
	"en": {
		"language.ca": "Catalan",
		"language.es": "Spanish",
		"language.en": "English",
		"main_menu.title": "Farm Project",
		"main_menu.subtitle": "Adventure, resources and final battle",
		"main_menu.start_button": "Start",
		"main_menu.hint": "Press SPACE or ENTER to continue",
		"menu.title": "Farm Project",
		"menu.subtitle": "Set up the match before starting",
		"menu.player_name": "Character name",
		"menu.player_name_placeholder": "Write your name",
		"menu.volume": "Master volume",
		"menu.language": "Language",
		"menu.start_button": "Save and start",
		"menu.press_space": "Press SPACE to start",
		"menu.default_player": "Player",
		"trader.title": "Trader",
		"trader.prompt": "[E] Trade",
		"trader.info.overworld": "Trade resources for consumables",
		"trader.info.dungeon": "Trade minerals for upgrades",
		"trader.status.log": "You have %d wood",
		"trader.status.mushroom": "You have %d mushrooms",
		"trader.status.axe_damage": "Axe damage: %d",
		"trader.status.till_damage": "Pickaxe damage: %d",
		"trader.trade.log_food": "1 Wood = 1 Apple",
		"trader.trade.mushroom_potion": "1 Mushroom = 1 Potion",
		"trader.trade.gold_axe": "1 Gold = +1 Axe",
		"trader.trade.rubi_till": "1 Ruby = +1 Pickaxe",
		"trader.cost.food": "Apples: %d",
		"trader.cost.potion": "Potions: %d",
		"trader.cost.gold": "You have %d gold",
		"trader.cost.rubi": "You have %d rubies",
		"trader.button.exchange": "Exchange",
		"trader.button.buy": "Buy",
		"trader.message.resources": "Go near the trader and exchange resources",
		"trader.message.upgrades": "Go near the trader and buy upgrades",
		"trader.message.got_apple": "+1 apple",
		"trader.message.got_potion": "+1 potion",
		"trader.message.axe_upgraded": "+1 axe damage",
		"trader.message.till_upgraded": "+1 pickaxe damage",
		"trader.message.not_enough_log": "Not enough wood",
		"trader.message.not_enough_mushroom": "Not enough mushrooms",
		"trader.message.not_enough_gold": "Not enough gold",
		"trader.message.not_enough_rubi": "Not enough rubies",
		"ui.close": "Close",
		"bed.prompt": "[E] Sleep",
		"bed.rested": "Rested!",
		"battle.player_line": "Player %d: %s",
		"battle.default_player": "Player %d",
		"battle.waiting": "Waiting for opponent...",
		"battle.win": "%s wins!\n%s defeated",
		"battle.draw": "DRAW!\nTime is over"
	}
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_http_request()

	var settings = get_node_or_null("/root/GameSettings")
	if settings != null:
		current_language = _normalize_language(str(settings.language_code))

	language_changed.emit(current_language)
	load_remote_language(current_language)


func set_language(language_code: String) -> void:
	var normalized_language := _normalize_language(language_code)
	current_language = normalized_language
	language_changed.emit(current_language)
	load_remote_language(current_language)


func load_remote_language(language_code: String) -> void:
	if not USE_REMOTE_TRANSLATIONS:
		return

	var normalized_language := _normalize_language(language_code)
	_ensure_http_request()

	if _http_request == null:
		return

	if _http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_http_request.cancel_request()

	_pending_language = normalized_language
	var url := "%s/translations/%s" % [API_BASE_URL, normalized_language]
	var err := _http_request.request(url)
	if err != OK:
		remote_translations_failed.emit(normalized_language, "No s'ha pogut iniciar la peticio HTTP")
		push_warning("No s'ha pogut demanar traduccions a la Raspberry: %s" % url)


func t(key: String, values: Array = []) -> String:
	var text := _lookup(key)
	if values.size() > 0:
		return _format_text(text, values)
	return text


func _format_text(text: String, values: Array) -> String:
	var formatted := text

	# SQLite/API can return either Godot percent placeholders (%s/%d)
	# or brace placeholders ({0}, {1}). Support both to avoid crashes.
	if formatted.find("{") >= 0:
		for i in range(values.size()):
			formatted = formatted.replace("{%d}" % i, str(values[i]))
		return formatted

	if formatted.find("%") >= 0:
		return formatted % values

	return formatted


func get_language() -> String:
	return current_language


func get_available_languages() -> Array[String]:
	return AVAILABLE_LANGUAGES.duplicate()


func _ensure_http_request() -> void:
	if _http_request != null:
		return

	_http_request = HTTPRequest.new()
	_http_request.name = "TranslationsHTTPRequest"
	_http_request.timeout = 3.0
	add_child(_http_request)
	_http_request.request_completed.connect(_on_remote_translations_completed)


func _on_remote_translations_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var language := _pending_language
	_pending_language = ""

	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		remote_translations_failed.emit(language, "HTTP %d" % response_code)
		push_warning("No s'han carregat traduccions remotes. Es fan servir les locals. HTTP %d" % response_code)
		return

	var text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		remote_translations_failed.emit(language, "JSON invalid")
		push_warning("Resposta JSON invalida de la Raspberry")
		return

	var payload := parsed as Dictionary
	var remote_language := _normalize_language(str(payload.get("language", language)))
	var remote_translations = payload.get("translations", {})
	if not remote_translations is Dictionary:
		remote_translations_failed.emit(remote_language, "translations no es Dictionary")
		push_warning("El JSON de la Raspberry no conte un camp translations valid")
		return

	if not translations.has(remote_language):
		translations[remote_language] = {}

	var target_table: Dictionary = translations[remote_language]
	for key in (remote_translations as Dictionary).keys():
		target_table[str(key)] = str((remote_translations as Dictionary)[key])

	translations[remote_language] = target_table
	remote_translations_loaded.emit(remote_language)

	if current_language == remote_language:
		language_changed.emit(current_language)

	print("Traduccions carregades des de Raspberry: ", remote_language, " (", target_table.size(), " claus)")


func _lookup(key: String) -> String:
	var language_table: Dictionary = translations.get(current_language, {})
	if language_table.has(key):
		return str(language_table[key])

	var fallback_table: Dictionary = translations.get(FALLBACK_LANGUAGE, {})
	if fallback_table.has(key):
		return str(fallback_table[key])

	var final_fallback_table: Dictionary = translations.get(FINAL_FALLBACK_LANGUAGE, {})
	if final_fallback_table.has(key):
		return str(final_fallback_table[key])

	return key


func _normalize_language(value: String) -> String:
	if AVAILABLE_LANGUAGES.has(value):
		return value
	return DEFAULT_LANGUAGE
