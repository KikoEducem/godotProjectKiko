extends Node2D

const LOCALHOST_ADDRESS: String = "127.0.0.1"
const SERVER_PORT: int = 4242
const DISCOVERY_PORT: int = 4243
const DISCOVERY_MAGIC: String = "PROJECTE_GRANJA_FINAL_BATTLE"
const DISCOVERY_TIMEOUT_SECONDS: float = 2.5
const CLIENT_CONNECT_TIMEOUT_SECONDS: float = 1.2
const LOCALHOST_CONNECT_TIMEOUT_SECONDS: float = 0.45
const DISCOVERY_BROADCAST_INTERVAL: float = 0.75
const FINAL_BATTLE_DURATION_SECONDS: float = 180.0
const GAME_SCREEN_SCENE := preload("res://scenes/ui/GameScreen.tscn")

@export var Player1Scene: PackedScene
@export var spawn_points: Array[Marker2D]

var _battle_finished: bool = false
var _result_layer: CanvasLayer
var _result_label: Label
var _game_screen: CanvasLayer
var _names_layer: CanvasLayer
var _name_labels: Dictionary = {}
var _player_names: Dictionary = {}

var _last_ui_health: int = -999
var _last_ui_max_health: int = -999

var _session_id: int = 0
var _discovery_sender: PacketPeerUDP
var _discovery_listener: PacketPeerUDP
var _discovery_broadcast_elapsed: float = 0.0
var _lan_join_in_progress: bool = false


func _ready() -> void:
	randomize()
	_session_id = Time.get_unix_time_from_system() * 1000 + randi_range(1, 999)
	_ensure_final_game_screen()
	_setup_final_battle_timer()
	_ensure_result_ui()
	_ensure_names_ui()
	_connect_final_tool_selection()

	if not I18n.language_changed.is_connected(_on_language_changed):
		I18n.language_changed.connect(_on_language_changed)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

	_start_network()


func _process(delta: float) -> void:
	if _battle_finished:
		return

	_process_lan_discovery(delta)
	_sync_local_player_stats_to_ui()


func _ensure_final_game_screen() -> void:
	if _game_screen != null:
		return

	var existing := get_node_or_null("GameScreen") as CanvasLayer
	if existing != null:
		_game_screen = existing
	else:
		_game_screen = GAME_SCREEN_SCENE.instantiate() as CanvasLayer
		_game_screen.name = "GameScreen"
		add_child(_game_screen)

	_layout_final_game_screen.call_deferred()


func _layout_final_game_screen() -> void:
	if _game_screen == null:
		return

	var status_bars := _game_screen.get_node_or_null("StatusBars") as Control
	if status_bars != null:
		var bars := status_bars.get_node_or_null("MarginContainer") as Control
		if bars != null:
			bars.anchor_left = 1.0
			bars.anchor_top = 0.0
			bars.anchor_right = 1.0
			bars.anchor_bottom = 0.0
			bars.offset_left = -154.0
			bars.offset_top = 8.0
			bars.offset_right = -8.0
			bars.offset_bottom = 56.0

		var timer_panel := status_bars.get_node_or_null("TimerPanel") as Control
		if timer_panel != null:
			timer_panel.anchor_left = 0.0
			timer_panel.anchor_top = 1.0
			timer_panel.anchor_right = 0.0
			timer_panel.anchor_bottom = 1.0
			timer_panel.offset_left = 8.0
			timer_panel.offset_top = -34.0
			timer_panel.offset_right = 84.0
			timer_panel.offset_bottom = -10.0

	var inventory_panel := _game_screen.get_node_or_null("InventoryPanel") as Control
	if inventory_panel != null:
		inventory_panel.anchor_left = 1.0
		inventory_panel.anchor_top = 0.0
		inventory_panel.anchor_right = 1.0
		inventory_panel.anchor_bottom = 0.0
		inventory_panel.offset_left = -52.0
		inventory_panel.offset_top = 70.0
		inventory_panel.offset_right = -8.0
		inventory_panel.offset_bottom = 372.0


func _setup_final_battle_timer() -> void:
	var timer = get_node_or_null("/root/GameTimer")
	if timer == null:
		return

	timer.set("auto_start_final_battle", false)

	var callback := Callable(self, "_on_final_timer_finished")
	if timer.has_signal("timer_finished"):
		if timer.timer_finished.is_connected(callback):
			timer.timer_finished.disconnect(callback)
		timer.timer_finished.connect(callback)

	if timer.has_method("reset_timer"):
		timer.reset_timer(FINAL_BATTLE_DURATION_SECONDS)


func _on_final_timer_finished() -> void:
	if _battle_finished:
		return

	if multiplayer.is_server():
		_finish_draw()
	elif _has_active_multiplayer():
		_notify_draw.rpc_id(1)
	else:
		_finish_draw()


func _connect_final_tool_selection() -> void:
	var tool_manager = get_node_or_null("/root/ToolManager")
	if tool_manager == null:
		return

	if not tool_manager.tool_selected.is_connected(_on_final_tool_selected):
		tool_manager.tool_selected.connect(_on_final_tool_selected)


func _on_final_tool_selected(tool: DataTypes.Tools) -> void:
	var local_player := _get_local_player()
	if local_player == null:
		return

	local_player.current_tool = tool
	local_player.update_hit_damage()
	local_player.sync_state()


func on_consumable_used(collectable_name: String, _amount: int) -> void:
	if _battle_finished:
		return

	if collectable_name == "potion":
		_apply_player_stats_health_to_local_player(true)
	elif collectable_name == "food":
		# Food already updates PlayerStats energy from ToolsPanel. There is no separate
		# networked energy value on Player1, so the HUD is updated by PlayerStats.
		_sync_local_player_stats_to_ui()


func _apply_player_stats_health_to_local_player(force_sync: bool = false) -> void:
	var local_player := _get_local_player()
	if local_player == null:
		return

	var player_stats = get_node_or_null("/root/PlayerStats")
	if player_stats == null:
		return

	var stats_health: int = int(player_stats.get("health"))
	var stats_max_health: int = int(player_stats.get("max_health"))
	if stats_max_health < 1:
		stats_max_health = 1

	if not force_sync and stats_health == local_player.health and stats_max_health == local_player.max_health:
		return

	local_player.max_health = stats_max_health
	local_player.health = clamp(stats_health, 0, local_player.max_health)
	local_player.apply_health_snapshot(local_player.health, local_player.max_health, local_player.alive)
	local_player.sync_state()

	_last_ui_health = local_player.health
	_last_ui_max_health = local_player.max_health


func _sync_local_player_stats_to_ui() -> void:
	var local_player := _get_local_player()
	if local_player == null:
		return

	var player_stats = get_node_or_null("/root/PlayerStats")
	if player_stats == null:
		return

	var stats_health: int = int(player_stats.get("health"))
	if stats_health > _last_ui_health and stats_health > local_player.health:
		_apply_player_stats_health_to_local_player(true)
		return

	if local_player.health == _last_ui_health and local_player.max_health == _last_ui_max_health:
		return

	player_stats.set("max_health", local_player.max_health)
	player_stats.set("health", local_player.health)
	player_stats.emit_signal("health_changed", local_player.health, local_player.max_health)

	_last_ui_health = local_player.health
	_last_ui_max_health = local_player.max_health


func _get_local_player() -> Player1:
	var local_id := multiplayer.get_unique_id()
	if local_id <= 0:
		local_id = 1

	var node := get_node_or_null(str(local_id))
	if node is Player1:
		return node as Player1

	for child in get_children():
		if child is Player1 and child.is_multiplayer_authority():
			return child as Player1

	return null


func _start_network() -> void:
	# 1) Permite forzar una IP manual si hiciera falta.
	var manual_address := _get_manual_server_address()
	if not manual_address.is_empty():
		print("Intentando conectar con IP manual: ", manual_address)
		if await _try_connect_to_server(manual_address, CLIENT_CONNECT_TIMEOUT_SECONDS):
			return
		print("No se pudo conectar con la IP manual. Se usara descubrimiento LAN automatico.")

	# 2) Mantiene el comportamiento anterior para dos ejecuciones en el mismo PC.
	if await _try_connect_to_server(LOCALHOST_ADDRESS, LOCALHOST_CONNECT_TIMEOUT_SECONDS):
		return

	# 3) Busca en la red local si ya hay un host anunciandose por UDP broadcast.
	var discovered_address := await _discover_lan_host()
	if not discovered_address.is_empty():
		print("Host LAN encontrado en ", discovered_address)
		if await _try_connect_to_server(discovered_address, CLIENT_CONNECT_TIMEOUT_SECONDS):
			return
		print("El host descubierto no respondio. Se creara un host local.")

	# 4) Si no hay servidor, esta instancia se convierte en host y se anuncia en la LAN.
	_start_host()


func _try_connect_to_server(address: String, timeout_seconds: float) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, SERVER_PORT)
	if err != OK:
		return false

	multiplayer.multiplayer_peer = peer
	await get_tree().create_timer(timeout_seconds).timeout

	if multiplayer.multiplayer_peer == null:
		return false

	if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		return true

	multiplayer.multiplayer_peer = null
	return false


func _discover_lan_host() -> String:
	var udp := PacketPeerUDP.new()
	var err := udp.bind(DISCOVERY_PORT, "0.0.0.0")
	if err != OK:
		print("No se pudo abrir el puerto UDP de descubrimiento ", DISCOVERY_PORT, ". Se omite busqueda LAN.")
		return ""

	udp.set_broadcast_enabled(true)
	var timeout_at := Time.get_ticks_msec() + int(DISCOVERY_TIMEOUT_SECONDS * 1000.0)

	while Time.get_ticks_msec() < timeout_at:
		while udp.get_available_packet_count() > 0:
			var text := udp.get_packet().get_string_from_utf8()
			var sender_ip := udp.get_packet_ip()
			if _is_valid_discovery_packet(text):
				udp.close()
				return sender_ip

		await get_tree().create_timer(0.1).timeout

	udp.close()
	return ""


func _start_host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(SERVER_PORT, 32)

	if err != OK:
		print("Puerto ocupado, reintentando como cliente local/LAN...")
		await get_tree().create_timer(0.5).timeout
		_start_network()
		return

	multiplayer.multiplayer_peer = peer
	print("HOST iniciado en puerto ", SERVER_PORT)
	_start_lan_discovery_services()

	_set_player_name(1, _get_local_settings_name(1))
	_create_player(1)
	_sync_player_name.rpc(1, _get_player_display_name(1))


func _start_lan_discovery_services() -> void:
	if _discovery_sender == null:
		_discovery_sender = PacketPeerUDP.new()
		_discovery_sender.set_broadcast_enabled(true)

	if _discovery_listener == null:
		_discovery_listener = PacketPeerUDP.new()
		var err := _discovery_listener.bind(DISCOVERY_PORT, "0.0.0.0")
		if err != OK:
			# No es fatal: el host podra anunciarse, aunque no podra detectar otro host simultaneo.
			_discovery_listener = null
			print("Aviso: no se pudo escuchar el puerto UDP de descubrimiento ", DISCOVERY_PORT)

	_broadcast_lan_host()


func _process_lan_discovery(delta: float) -> void:
	if not multiplayer.is_server():
		return

	_discovery_broadcast_elapsed += delta
	if _discovery_broadcast_elapsed >= DISCOVERY_BROADCAST_INTERVAL:
		_discovery_broadcast_elapsed = 0.0
		_broadcast_lan_host()

	_check_for_older_lan_host()


func _broadcast_lan_host() -> void:
	if _discovery_sender == null:
		return

	var packet := "%s|%d|%d" % [DISCOVERY_MAGIC, SERVER_PORT, _session_id]
	_discovery_sender.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_discovery_sender.put_packet(packet.to_utf8_buffer())


func _check_for_older_lan_host() -> void:
	if _discovery_listener == null or _lan_join_in_progress:
		return

	while _discovery_listener.get_available_packet_count() > 0:
		var text := _discovery_listener.get_packet().get_string_from_utf8()
		var sender_ip := _discovery_listener.get_packet_ip()
		if not _is_valid_discovery_packet(text):
			continue

		var other_session := _get_discovery_session_id(text)
		if other_session <= 0 or other_session == _session_id:
			continue

		# Si dos PCs arrancan a la vez, el host mas nuevo se reconvierte en cliente del mas antiguo.
		if other_session < _session_id and multiplayer.get_peers().is_empty():
			_lan_join_in_progress = true
			_join_older_lan_host.call_deferred(sender_ip)
			return


func _join_older_lan_host(address: String) -> void:
	print("Otro host LAN mas antiguo encontrado en ", address, ". Cambiando a cliente...")
	_stop_lan_discovery_services()
	for child in get_children():
		if child is Player1:
			child.queue_free()
	multiplayer.multiplayer_peer = null
	await get_tree().create_timer(0.2).timeout
	await _try_connect_to_server(address, CLIENT_CONNECT_TIMEOUT_SECONDS)
	_lan_join_in_progress = false


func _stop_lan_discovery_services() -> void:
	if _discovery_sender != null:
		_discovery_sender.close()
		_discovery_sender = null
	if _discovery_listener != null:
		_discovery_listener.close()
		_discovery_listener = null


func _is_valid_discovery_packet(text: String) -> bool:
	var parts := text.split("|")
	if parts.size() < 3:
		return false
	if parts[0] != DISCOVERY_MAGIC:
		return false
	return int(parts[1]) == SERVER_PORT


func _get_discovery_session_id(text: String) -> int:
	var parts := text.split("|")
	if parts.size() < 3:
		return 0
	return int(parts[2])


func _get_manual_server_address() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--server-ip="):
			return arg.trim_prefix("--server-ip=").strip_edges()
		if arg.begins_with("--join="):
			return arg.trim_prefix("--join=").strip_edges()

	var env_address := OS.get_environment("GODOT_FARM_SERVER_IP").strip_edges()
	return env_address


func _on_connected_to_server() -> void:
	print("Conectado al servidor, pidiendo players...")

	var local_id := multiplayer.get_unique_id()
	_set_player_name(local_id, _get_local_settings_name(local_id))
	_register_player_name.rpc_id(1, _get_player_display_name(local_id))
	_request_players.rpc_id(1)


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		print("Cliente conectado: ", id)
		_set_player_name(id, _get_player_display_name(id))
		_create_player(id)
		_sync_player_name.rpc(id, _get_player_display_name(id))


func _on_peer_disconnected(id: int) -> void:
	var node := get_node_or_null(str(id))
	if node != null:
		node.queue_free()

	_player_names.erase(id)
	_refresh_names_ui()


func register_player_defeated(defeated_peer_id: int) -> void:
	if _battle_finished:
		return

	if multiplayer.is_server():
		_finish_battle(defeated_peer_id)
	else:
		_notify_defeat.rpc_id(1, defeated_peer_id)


func _finish_battle(defeated_peer_id: int) -> void:
	if _battle_finished:
		return

	_battle_finished = true
	_pause_final_timer()

	var winner_peer_id := 1
	for child in get_children():
		if child is CharacterBody2D:
			var pid := child.name.to_int()
			if pid > 0 and pid != defeated_peer_id:
				winner_peer_id = pid

	_stop_all_players()
	_show_battle_result.rpc(winner_peer_id, defeated_peer_id)


func _finish_draw() -> void:
	if _battle_finished:
		return

	_battle_finished = true
	_pause_final_timer()
	_stop_all_players()
	_show_draw_result.rpc()


func _pause_final_timer() -> void:
	var timer = get_node_or_null("/root/GameTimer")
	if timer != null and timer.has_method("pause_timer"):
		timer.pause_timer()


func _stop_all_players() -> void:
	for child in get_children():
		if child is CharacterBody2D:
			child.velocity = Vector2.ZERO

			if child is Player1:
				child.alive = false
				child.apply_health_snapshot(child.health, child.max_health, false)


func _ensure_result_ui() -> void:
	if _result_label != null:
		return

	_result_layer = CanvasLayer.new()
	_result_layer.name = "BattleResultLayer"
	_result_layer.layer = 100
	add_child(_result_layer)

	_result_label = Label.new()
	_result_label.name = "BattleResultLabel"
	_result_label.visible = false
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_label.anchor_right = 1.0
	_result_label.anchor_bottom = 1.0
	_result_label.offset_left = 0.0
	_result_label.offset_top = 0.0
	_result_label.offset_right = 0.0
	_result_label.offset_bottom = 0.0
	_result_label.add_theme_font_size_override("font_size", 28)
	_result_layer.add_child(_result_label)


func _ensure_names_ui() -> void:
	if _names_layer != null:
		return

	_names_layer = CanvasLayer.new()
	_names_layer.name = "BattleNamesLayer"
	_names_layer.layer = 55
	add_child(_names_layer)

	# Slot 0 = primer jugador conocido. Slot 1 = rival.
	# No dependemos de que el peer remoto sea exactamente 2, porque en LAN puede variar.
	_name_labels[0] = _create_hud_name_label(Vector2(8, 8), HORIZONTAL_ALIGNMENT_LEFT)
	_name_labels[1] = _create_hud_name_label(Vector2(400, 58), HORIZONTAL_ALIGNMENT_RIGHT)
	_refresh_names_ui()


func _create_hud_name_label(pos: Vector2, alignment: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = Vector2(232, 20)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.visible = true
	_names_layer.add_child(label)
	return label


func _refresh_names_ui() -> void:
	var ordered_peer_ids := _get_ordered_player_ids()

	for slot in _name_labels.keys():
		var label := _name_labels[slot] as Label
		if label == null:
			continue

		var slot_index := int(slot)
		if slot_index < ordered_peer_ids.size():
			var peer_id := int(ordered_peer_ids[slot_index])
			label.text = I18n.t("battle.player_line", [slot_index + 1, _get_player_display_name(peer_id)])
			label.visible = true
		else:
			label.text = I18n.t("battle.waiting")
			label.visible = slot_index == 1


func _get_ordered_player_ids() -> Array[int]:
	var ids: Array[int] = []

	for child in get_children():
		if child is Player1:
			var pid := child.name.to_int()
			if pid > 0 and not ids.has(pid):
				ids.append(pid)

	for peer_id in _player_names.keys():
		var pid := int(peer_id)
		if pid > 0 and not ids.has(pid):
			ids.append(pid)

	ids.sort()
	return ids


func _set_player_name(peer_id: int, player_name: String) -> void:
	_player_names[peer_id] = _clean_player_name(player_name, peer_id)
	_refresh_names_ui()
	_apply_player_display_name(peer_id)


func _clean_player_name(player_name: String, peer_id: int) -> String:
	var clean_name := player_name.strip_edges()
	if clean_name.is_empty():
		return I18n.t("battle.default_player", [peer_id])
	return clean_name


func _get_player_display_name(peer_id: int) -> String:
	var stored_name := str(_player_names.get(peer_id, "")).strip_edges()
	if stored_name.is_empty():
		return I18n.t("battle.default_player", [peer_id])
	return stored_name


func _get_local_settings_name(peer_id: int) -> String:
	var settings = get_node_or_null("/root/GameSettings")
	if settings != null and settings.has_method("get_safe_player_name"):
		return settings.get_safe_player_name(peer_id)
	return I18n.t("battle.default_player", [peer_id])


func _apply_player_display_name(peer_id: int) -> void:
	var node := get_node_or_null(str(peer_id))
	if node != null and node.has_method("set_display_name"):
		node.set_display_name(_get_player_display_name(peer_id))


func _on_language_changed(_language_code: String) -> void:
	_refresh_names_ui()
	if _result_label != null and _result_label.visible:
		# El resultado se actualiza al generarse. Si el idioma cambia despues, mantenemos el texto actual.
		return


@rpc("any_peer", "call_remote", "reliable")
func _notify_defeat(defeated_peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	_finish_battle(defeated_peer_id)


@rpc("any_peer", "call_remote", "reliable")
func _notify_draw() -> void:
	if not multiplayer.is_server():
		return

	_finish_draw()


@rpc("any_peer", "call_remote", "reliable")
func _register_player_name(player_name: String) -> void:
	if not multiplayer.is_server():
		return

	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return

	_set_player_name(sender, player_name)
	_sync_player_name.rpc(sender, _get_player_display_name(sender))


@rpc("authority", "call_local", "reliable")
func _sync_player_name(peer_id: int, player_name: String) -> void:
	_set_player_name(peer_id, player_name)


@rpc("authority", "call_local", "reliable")
func _show_battle_result(winner_peer_id: int, defeated_peer_id: int) -> void:
	_battle_finished = true
	_pause_final_timer()
	_ensure_result_ui()

	var winner_name := _get_player_display_name(winner_peer_id)
	var defeated_name := _get_player_display_name(defeated_peer_id)
	_result_label.text = I18n.t("battle.win", [winner_name, defeated_name])
	_result_label.visible = true

	_stop_all_players()


@rpc("authority", "call_local", "reliable")
func _show_draw_result() -> void:
	_battle_finished = true
	_pause_final_timer()
	_ensure_result_ui()

	_result_label.text = I18n.t("battle.draw")
	_result_label.visible = true

	_stop_all_players()


@rpc("any_peer", "call_remote", "reliable")
func _request_players() -> void:
	if not multiplayer.is_server():
		return

	var sender := multiplayer.get_remote_sender_id()
	for child in get_children():
		if child is CharacterBody2D:
			var pid := child.name.to_int()
			if pid > 0:
				var initial_health := 100
				var initial_max_health := 100
				var initial_alive := true

				if child is Player1:
					initial_health = child.health
					initial_max_health = child.max_health
					initial_alive = child.alive

				print("Enviando player ", pid, " al cliente ", sender)
				_receive_player.rpc_id(
					sender,
					pid,
					initial_health,
					initial_max_health,
					initial_alive,
					_get_player_display_name(pid)
				)


@rpc("authority", "call_remote", "reliable")
func _receive_player(
	peer_id: int,
	initial_health: int,
	initial_max_health: int,
	initial_alive: bool,
	initial_player_name: String
) -> void:
	print("Recibido player: ", peer_id)
	_set_player_name(peer_id, initial_player_name)

	var player: Node2D = _create_player(peer_id)
	if player is Player1:
		var player1: Player1 = player as Player1
		player1.set_display_name(_get_player_display_name(peer_id))

		if not player1.is_multiplayer_authority():
			player1.apply_health_snapshot(initial_health, initial_max_health, initial_alive)


func _create_player(peer_id: int) -> Node2D:
	if has_node(str(peer_id)):
		var existing_player := get_node(str(peer_id)) as Node2D
		_apply_player_display_name(peer_id)
		return existing_player

	if Player1Scene == null:
		push_error("Player1Scene es null")
		return null

	var p: Node2D = Player1Scene.instantiate() as Node2D
	if p == null:
		push_error("Player1Scene no instancia un Node2D")
		return null

	p.name = str(peer_id)
	p.set_multiplayer_authority(peer_id, true)

	var idx := 0 if peer_id == 1 else 1
	var pos := get_viewport_rect().size / 2.0
	if spawn_points.size() > idx and spawn_points[idx] != null:
		pos = spawn_points[idx].position

	p.position = pos
	add_child(p, true)
	_apply_player_display_name(peer_id)

	print(
		"Player ",
		peer_id,
		" en: ",
		p.position,
		" | authority: ",
		p.get_multiplayer_authority(),
		" | name: ",
		_get_player_display_name(peer_id)
	)

	return p


func _has_active_multiplayer() -> bool:
	return multiplayer.multiplayer_peer != null
