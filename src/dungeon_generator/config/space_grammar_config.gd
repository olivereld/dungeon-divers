class_name SpaceGrammarConfig
extends Resource

## Configuración para colocación de salas guiada por el grafo de misiones (Mission-Aware) y Restricciones Espaciales v1.

@export var use_mission_aware_placement: bool = false ## If true, uses MissionGraph-guided placement. Else, current behavior (random).
@export var mission_aware_preferred_distance: float = 12.0 ## Preferred distance (cells) between a room and its placed neighbors.
@export var mission_aware_candidate_count: int = 15 ## Number of candidates generated per room before accepting the best.
@export var mission_aware_distance_jitter: float = 4.0 ## Tolerance radius around preferred_distance for candidates.

# Spatial Constraints v1
@export var min_room_separation: int = 2 ## Minimum empty cells between room boundaries (hard constraint).
@export var min_mission_edge_distance: float = 6.0 ## Minimum allowed center-to-center distance between connected mission rooms (hard constraint).
@export var max_mission_edge_distance: float = 24.0 ## Maximum allowed center-to-center distance between connected mission rooms (hard constraint).
@export var progression_strength: float = 1.0 ## Weight for advancing along the dungeon spatial progression path (soft scoring).
@export var density_strength: float = 0.5 ## Weight for penalizing excessive clustering or empty void gaps (soft scoring).
@export var preferred_progression_direction: Vector2 = Vector2.ZERO ## Global direction vector (if Vector2.ZERO, randomized per seed deterministically).

func duplicate_config() -> SpaceGrammarConfig:
	var copy: SpaceGrammarConfig = (get_script() as GDScript).new()
	copy.use_mission_aware_placement = use_mission_aware_placement
	copy.mission_aware_preferred_distance = mission_aware_preferred_distance
	copy.mission_aware_candidate_count = mission_aware_candidate_count
	copy.mission_aware_distance_jitter = mission_aware_distance_jitter
	copy.min_room_separation = min_room_separation
	copy.min_mission_edge_distance = min_mission_edge_distance
	copy.max_mission_edge_distance = max_mission_edge_distance
	copy.progression_strength = progression_strength
	copy.density_strength = density_strength
	copy.preferred_progression_direction = preferred_progression_direction
	return copy
