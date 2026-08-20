class_name FloorNoiseField
extends RefCounted

## Modulador de ruido espacial continuo de baja frecuencia (Fase V2).
## Genera gradientes espaciales suaves para sesgar tamaños de losas, desgaste, grietas y micro-tonos entre salas y pasillos.

var _noise: FastNoiseLite
var seed_val: int = 1337

func _init(p_seed: int = 1337, p_frequency: float = 0.05) -> void:
	seed_val = p_seed
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.seed = p_seed
	_noise.frequency = p_frequency
	_noise.fractal_octaves = 2
	_noise.fractal_gain = 0.5

## Muestrea el ruido continuo en coordenadas continuas de mundo [-1.0, 1.0]
func sample_noise(world_x: float, world_y: float) -> float:
	return _noise.get_noise_2d(world_x, world_y)

## Muestrea el ruido normalizado [0.0, 1.0]
func sample_noise_norm(world_x: float, world_y: float) -> float:
	var raw := _noise.get_noise_2d(world_x, world_y)
	return clampf((raw + 1.0) * 0.5, 0.0, 1.0)

## Retorna un sesgo de tamaño de losa preferido según la zona espacial
func get_preferred_size_bias(world_x: float, world_y: float) -> int:
	var n := sample_noise_norm(world_x, world_y)
	if n < 0.32:
		return 0 # SMALL / Dense Pavers
	elif n > 0.68:
		return 2 # LARGE / Megalith / Dominant slabs
	return 1 # MEDIUM / Standard balanced

## Retorna el factor de desgaste o propensión de grietas de la zona [0.0, 1.0]
func get_wear_factor(world_x: float, world_y: float) -> float:
	# Muestreo secundario con ligero desfase espacial
	var n := _noise.get_noise_2d(world_x + 31.415, world_y + 17.89)
	return clampf((n + 1.0) * 0.5, 0.0, 1.0)

## Retorna un desplazamiento suave de tono para transiciones naturales de color entre salas
func get_tone_offset(world_x: float, world_y: float, max_variation: float = 0.06) -> float:
	var n := sample_noise(world_x * 0.5, world_y * 0.5)
	return n * max_variation
