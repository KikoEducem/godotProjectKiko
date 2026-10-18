extends Node

signal time_changed(formatted_time: String, seconds_left: int)
signal timer_finished

const DEFAULT_DURATION_SECONDS: float = 60.0
const FINAL_SCENE_PATH: String = "res://scenes/worlds/Coliseum_world.tscn"

@export var auto_start_final_battle: bool = true

var duration_seconds: float = DEFAULT_DURATION_SECONDS
var remaining_seconds: float = DEFAULT_DURATION_SECONDS
var running: bool = false
var _last_reported_second: int = -1
var _finish_emitted: bool = false
var _changing_to_final: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_emit_time_changed(true)

func _process(delta: float) -> void:
	if !running:
		return

	if remaining_seconds <= 0.0:
		_finish_timer()
		return

	remaining_seconds = max(0.0, remaining_seconds - delta)
	_emit_time_changed()

	if remaining_seconds <= 0.0:
		_finish_timer()

func start_main_countdown() -> void:
	auto_start_final_battle = true
	reset_timer(DEFAULT_DURATION_SECONDS)

func reset_timer(new_duration_seconds: float = DEFAULT_DURATION_SECONDS) -> void:
	duration_seconds = max(1.0, new_duration_seconds)
	remaining_seconds = duration_seconds
	running = true
	_finish_emitted = false
	_changing_to_final = false
	_emit_time_changed(true)

func pause_timer() -> void:
	running = false

func resume_timer() -> void:
	if _finish_emitted:
		return
	running = true
	_emit_time_changed(true)

func get_seconds_left() -> int:
	return max(0, int(ceil(remaining_seconds)))

func get_formatted_time() -> String:
	var total_seconds: int = get_seconds_left()
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

func _finish_timer() -> void:
	remaining_seconds = 0.0
	running = false
	_emit_time_changed(true)

	if _finish_emitted:
		return

	_finish_emitted = true
	timer_finished.emit()

	if auto_start_final_battle:
		_start_final_battle.call_deferred()

func _start_final_battle() -> void:
	if _changing_to_final:
		return

	var tree := get_tree()
	if tree == null:
		return

	var current_scene := tree.current_scene
	if current_scene != null and current_scene.scene_file_path == FINAL_SCENE_PATH:
		return

	_changing_to_final = true
	var err := tree.change_scene_to_file(FINAL_SCENE_PATH)
	if err != OK:
		push_error("No se pudo cargar la batalla final: %s" % FINAL_SCENE_PATH)
		_changing_to_final = false

func _emit_time_changed(force: bool = false) -> void:
	var seconds_left: int = get_seconds_left()
	if !force and seconds_left == _last_reported_second:
		return

	_last_reported_second = seconds_left
	time_changed.emit(get_formatted_time(), seconds_left)
