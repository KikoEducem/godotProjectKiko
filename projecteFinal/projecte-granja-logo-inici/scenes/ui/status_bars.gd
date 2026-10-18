extends Control

@onready var health_fill: ColorRect = $MarginContainer/VBoxContainer/HealthRow/HealthBarRoot/HealthBarBg/HealthFill
@onready var energy_fill: ColorRect = $MarginContainer/VBoxContainer/EnergyRow/EnergyBarRoot/EnergyBarBg/EnergyFill
@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthRow/HealthValue
@onready var energy_label: Label = $MarginContainer/VBoxContainer/EnergyRow/EnergyValue
@onready var timer_label: Label = $TimerPanel/TimerLabel

const HEALTH_WIDTH: float = 84.0
const ENERGY_WIDTH: float = 56.0

func _ready() -> void:
	PlayerStats.health_changed.connect(_on_health_changed)
	PlayerStats.energy_changed.connect(_on_energy_changed)
	GameTimer.time_changed.connect(_on_time_changed)
	_on_health_changed(PlayerStats.health, PlayerStats.max_health)
	_on_energy_changed(PlayerStats.energy, PlayerStats.max_energy)
	_on_time_changed(GameTimer.get_formatted_time(), GameTimer.get_seconds_left())

func _on_health_changed(current: int, max_value: int) -> void:
	var ratio: float = 0.0
	if max_value > 0:
		ratio = float(current) / float(max_value)

	health_fill.custom_minimum_size.x = round(HEALTH_WIDTH * ratio)
	health_fill.size.x = round(HEALTH_WIDTH * ratio)
	health_label.text = "%d/%d" % [current, max_value]

func _on_energy_changed(current: int, max_value: int) -> void:
	var ratio: float = 0.0
	if max_value > 0:
		ratio = float(current) / float(max_value)

	energy_fill.custom_minimum_size.x = round(ENERGY_WIDTH * ratio)
	energy_fill.size.x = round(ENERGY_WIDTH * ratio)
	energy_label.text = "%d/%d" % [current, max_value]

func _on_time_changed(formatted_time: String, _seconds_left: int) -> void:
	timer_label.text = formatted_time
