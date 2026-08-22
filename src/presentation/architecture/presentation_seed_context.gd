class_name PresentationSeedContext
extends RefCounted

## Contexto de derivación centralizada de semillas deterministas para una habitación o zona.
## Evita colisiones de generador de números pseudoaleatorios (RNG) entre distintos subsistemas
## mediante multiplicadores primos ortogonales garantizados.

var master_seed: int = 1337
var room_id: int = 0

var composition_seed: int = 0
var fixture_seed: int = 0
var prop_seed: int = 0
var variant_seed: int = 0
var lighting_seed: int = 0

func _init(p_master_seed: int = 1337, p_room_id: int = 0) -> void:
	master_seed = p_master_seed
	room_id = p_room_id
	_derive_seeds()

func _derive_seeds() -> void:
	# Primos ortogonales para desacoplar las secuencias RNG
	var base_room := master_seed + room_id * 10007
	composition_seed = (base_room * 7331 + 19) & 0x7FFFFFFF
	fixture_seed     = (base_room * 9157 + 37) & 0x7FFFFFFF
	prop_seed        = (base_room * 11897 + 53) & 0x7FFFFFFF
	variant_seed     = (base_room * 13337 + 71) & 0x7FFFFFFF
	lighting_seed    = (base_room * 15427 + 89) & 0x7FFFFFFF

static func for_room(p_master_seed: int, p_room_id: int) -> PresentationSeedContext:
	return PresentationSeedContext.new(p_master_seed, p_room_id)
