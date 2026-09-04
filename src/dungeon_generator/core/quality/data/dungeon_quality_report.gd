class_name DungeonQualityReport
extends RefCounted

## Contrato de datos lógico e inmutable para el reporte de calidad de una mazmorra generada.
## Contiene las métricas espaciales (D1), de corredores (D2), de jugabilidad (D3) y de fiabilidad (D4).
## Es 100% puro y determinista. Tras llamar a seal(), queda en modo solo lectura.

var seed: String = ""
var semantic_valid: bool = false
var gameplay_valid: bool = false

var room_metrics: Dictionary = {
	"room_fill_ratio": 0.0,
	"nearest_neighbor_cv": 0.0,
	"radial_variance": 0.0,
	"edge_stretch": 0.0
}

var corridor_metrics: Dictionary = {
	"length_stats": {
		"min": 0,
		"max": 0,
		"mean": 0.0,
		"median": 0
	},
	"length_variance": 0.0,
	"short_corridor_rate": 0.0,
	"turn_count_stats": {
		"min": 0,
		"max": 0,
		"mean": 0.0,
		"total": 0
	},
	"longest_straight_run": 0
}

var gameplay_metrics: Dictionary = {
	"critical_path_length": 0.0,
	"critical_path_room_count": 0,
	"objective_spacing": 0.0,
	"key_lock_spacing": 0.0,
	"start_boss_distance": 0.0,
	"start_goal_distance": 0.0,
	"branch_count": 0,
	"optional_branch_depth": 0.0
}

var _is_sealed: bool = false

func seal() -> void:
	_is_sealed = true
	# Hacemos deep duplicate de los diccionarios para congelar estado
	room_metrics = room_metrics.duplicate(true)
	corridor_metrics = corridor_metrics.duplicate(true)
	gameplay_metrics = gameplay_metrics.duplicate(true)

func is_sealed() -> bool:
	return _is_sealed

func set_seed_val(p_seed) -> void:
	assert(not _is_sealed, "Cannot mutate DungeonQualityReport once sealed.")
	seed = str(p_seed)

func set_validity(p_semantic: bool, p_gameplay: bool) -> void:
	assert(not _is_sealed, "Cannot mutate DungeonQualityReport once sealed.")
	semantic_valid = p_semantic
	gameplay_valid = p_gameplay

func set_room_metrics(metrics: Dictionary) -> void:
	assert(not _is_sealed, "Cannot mutate DungeonQualityReport once sealed.")
	room_metrics = metrics.duplicate(true)

func set_corridor_metrics(metrics: Dictionary) -> void:
	assert(not _is_sealed, "Cannot mutate DungeonQualityReport once sealed.")
	corridor_metrics = metrics.duplicate(true)

func set_gameplay_metrics(metrics: Dictionary) -> void:
	assert(not _is_sealed, "Cannot mutate DungeonQualityReport once sealed.")
	gameplay_metrics = metrics.duplicate(true)

func to_dict() -> Dictionary:
	return {
		"seed": seed,
		"room_metrics": room_metrics.duplicate(true),
		"corridor_metrics": corridor_metrics.duplicate(true),
		"gameplay_metrics": gameplay_metrics.duplicate(true),
		"semantic_valid": semantic_valid,
		"gameplay_valid": gameplay_valid
	}

func to_json() -> String:
	return JSON.stringify(to_dict(), "\t")

func to_debug_string() -> String:
	var s: String = "=== DUNGEON QUALITY REPORT (Seed: %s) ===\n" % seed
	s += "Validity: Semantic=%s, Gameplay=%s\n" % [str(semantic_valid), str(gameplay_valid)]
	s += "Room Metrics:\n"
	for k in room_metrics:
		s += "  %s: %s\n" % [k, str(room_metrics[k])]
	s += "Corridor Metrics:\n"
	for k in corridor_metrics:
		s += "  %s: %s\n" % [k, str(corridor_metrics[k])]
	s += "Gameplay Metrics:\n"
	for k in gameplay_metrics:
		s += "  %s: %s\n" % [k, str(gameplay_metrics[k])]
	return s
