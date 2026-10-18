extends Node

signal health_changed(current: int, max_value: int)
signal energy_changed(current: int, max_value: int)

const EXHAUSTION_DAMAGE: int = 2
const EXHAUSTION_INTERVAL: float = 1.0

var max_health: int = 100
var health: int = 50

var max_energy: int = 100
var energy: int = 100

var exhaustion_timer: Timer

func _ready() -> void:
	exhaustion_timer = Timer.new()
	exhaustion_timer.wait_time = EXHAUSTION_INTERVAL
	exhaustion_timer.one_shot = false
	exhaustion_timer.autostart = false
	add_child(exhaustion_timer)
	exhaustion_timer.timeout.connect(_on_exhaustion_timer_timeout)
	emit_all()
	_update_exhaustion_state()

func emit_all() -> void:
	health_changed.emit(health, max_health)
	energy_changed.emit(energy, max_energy)

func heal(amount: int) -> void:
	health = clamp(health + amount, 0, max_health)
	health_changed.emit(health, max_health)

func damage(amount: int) -> void:
	health = clamp(health - amount, 0, max_health)
	health_changed.emit(health, max_health)

func recover_energy(amount: int) -> void:
	energy = clamp(energy + amount, 0, max_energy)
	energy_changed.emit(energy, max_energy)
	_update_exhaustion_state()

func spend_energy(amount: int) -> bool:
	if energy < amount:
		return false

	energy = clamp(energy - amount, 0, max_energy)
	energy_changed.emit(energy, max_energy)
	_update_exhaustion_state()
	return true

func restore_all() -> void:
	health = max_health
	energy = max_energy
	emit_all()
	_update_exhaustion_state()

func _update_exhaustion_state() -> void:
	if exhaustion_timer == null:
		return

	if energy <= 0 and health > 0:
		if exhaustion_timer.is_stopped():
			exhaustion_timer.start()
	else:
		exhaustion_timer.stop()

func _on_exhaustion_timer_timeout() -> void:
	if energy <= 0 and health > 0:
		damage(EXHAUSTION_DAMAGE)
		if health <= 0:
			exhaustion_timer.stop()
	else:
		exhaustion_timer.stop()
