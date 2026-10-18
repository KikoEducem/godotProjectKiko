extends Node

const MUSIC_PATHS := {
	"menu": "res://assets/audio/music/menu_tranquil.mp3",
	"normal": "res://assets/audio/music/normal_tranquil.mp3",
	"dungeon": "res://assets/audio/music/dungeon_danger.mp3",
	"final": "res://assets/audio/music/final_battle_epic.mp3"
}

var _music_player: AudioStreamPlayer
var _current_music_key: String = ""
var _current_scene_path: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = "Master"
	add_child(_music_player)

	_apply_volume_from_settings()

	print("AudioManager carregat correctament")


func _process(_delta: float) -> void:
	if get_tree() == null:
		return

	if get_tree().current_scene == null:
		return

	var scene_path := get_tree().current_scene.scene_file_path

	if scene_path == _current_scene_path:
		return

	_current_scene_path = scene_path
	print("Escena actual detectada: ", scene_path)

	play_music_for_scene(scene_path)


func _apply_volume_from_settings() -> void:
	var volume := 1.0

	if has_node("/root/GameSettings"):
		volume = float(get_node("/root/GameSettings").master_volume)

	set_master_volume(volume)


func set_master_volume(volume: float) -> void:
	volume = clamp(volume, 0.0, 1.0)

	var bus_index := AudioServer.get_bus_index("Master")

	if bus_index >= 0:
		AudioServer.set_bus_volume_db(
			bus_index,
			linear_to_db(max(volume, 0.001))
		)


func play_music(music_key: String) -> void:
	if _music_player == null:
		return

	if music_key == _current_music_key and _music_player.playing:
		return

	if not MUSIC_PATHS.has(music_key):
		push_warning("No existeix la musica amb clau: " + music_key)
		return

	var path: String = MUSIC_PATHS[music_key]

	if not ResourceLoader.exists(path):
		push_warning("No s'ha trobat el fitxer de musica: " + path)
		return

	var stream := load(path) as AudioStream

	if stream == null:
		push_warning("No s'ha pogut carregar la musica: " + path)
		return

	_current_music_key = music_key

	_music_player.stop()
	_music_player.stream = stream
	_music_player.volume_db = 0.0
	_music_player.play()

	print("Reproduint musica: ", music_key, " -> ", path)


func stop_music() -> void:
	_current_music_key = ""

	if _music_player != null:
		_music_player.stop()


func play_music_for_scene(scene_path: String) -> void:
	scene_path = scene_path.to_lower()

	if "start_menu" in scene_path:
		play_music("menu")
	elif "coliseum" in scene_path:
		play_music("final")
	elif "dungeon" in scene_path:
		play_music("dungeon")
	else:
		play_music("normal")
