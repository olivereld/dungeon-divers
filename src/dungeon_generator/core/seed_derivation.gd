class_name SeedDerivation
extends RefCounted

## Algoritmo Canónico de Derivación de Semillas Versionado (v1) para la Fase 10 y 11.
## Garantiza reproducibilidad bit a bit e independencia estadística entre pisos y dominios.

const VERSION_TAG: String = "v1"

const DOMAIN_FLOOR: String = "floor"
const DOMAIN_SEMANTIC: String = "semantic"
const DOMAIN_STAIRS: String = "stairs"
const DOMAIN_DOORS: String = "doors"
const DOMAIN_WALL_MESH: String = "wall_mesh"

## Deriva una semilla determinista a partir de una semilla maestra, dominio e índice.
static func derive_seed(master_seed: int, domain: String, index: int) -> int:
	var hash_input: String = "%s:%d:%s:%d" % [VERSION_TAG, master_seed, domain, index]
	return int(hash_input.hash()) & 0x7FFFFFFF

## Deriva la semilla del core topológico para un piso específico.
static func derive_floor_seed(master_seed: int, floor_number: int) -> int:
	return derive_seed(master_seed, DOMAIN_FLOOR, floor_number)

## Deriva la semilla del modelo semántico para un piso específico.
static func derive_semantic_seed(master_seed: int, floor_number: int) -> int:
	return derive_seed(master_seed, DOMAIN_SEMANTIC, floor_number)

## Deriva la semilla del planificador de escaleras para un piso específico.
static func derive_stairs_seed(master_seed: int, floor_number: int) -> int:
	return derive_seed(master_seed, DOMAIN_STAIRS, floor_number)

## Deriva la semilla de decoración de mallas de pared para un piso específico.
static func derive_wall_mesh_seed(master_seed: int, floor_number: int) -> int:
	return derive_seed(master_seed, DOMAIN_WALL_MESH, floor_number)

## Construye la traza completa de derivación de semillas para auditoría y golden fixtures.
static func build_multi_floor_seed_trace(master_seed: int, floor_numbers: Array[int]) -> Dictionary:
	var trace := {
		"version": VERSION_TAG,
		"master_seed": master_seed,
		"floors": {}
	}
	for f in floor_numbers:
		trace["floors"][f] = {
			"core_seed": derive_floor_seed(master_seed, f),
			"semantic_seed": derive_semantic_seed(master_seed, f),
			"stairs_seed": derive_stairs_seed(master_seed, f),
			"wall_mesh_seed": derive_wall_mesh_seed(master_seed, f)
		}
	return trace
