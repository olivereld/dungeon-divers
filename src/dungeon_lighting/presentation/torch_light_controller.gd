class_name TorchLightController
extends Node

## Controlador de parpadeo orgánico (flicker) para antorchas y luces de mazmorra.
## Utiliza FastNoiseLite continuo para variar suavemente la energía lumínica sin saltos bruscos.

@export var target_light: Light3D = null
@export var secondary_light: Light3D = null
@export var base_energy: float = 2.4
@export var flicker_amplitude: float = 0.18
@export var flicker_speed: float = 6.5
@export var time_offset: float = 0.0

var _noise := FastNoiseLite.new()
var _time_accum: float = 0.0

func _ready() -> void:
	if target_light == null and get_parent() is Light3D:
		target_light = get_parent() as Light3D
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.5
	_time_accum = time_offset

func _process(delta: float) -> void:
	if target_light == null or not is_instance_valid(target_light):
		return

	_time_accum += delta * flicker_speed
	var noise_val: float = _noise.get_noise_1d(_time_accum)
	# noise_val está en el rango [-1.0, 1.0]
	var multiplier: float = 1.0 + (noise_val * flicker_amplitude)
	target_light.light_energy = maxf(0.1, base_energy * multiplier)
	if secondary_light != null and is_instance_valid(secondary_light):
		secondary_light.light_energy = maxf(0.05, (base_energy * 0.25) * multiplier)
