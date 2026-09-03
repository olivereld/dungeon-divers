class_name SpaceGrammarConfig
extends Resource

## Configuración para colocación de salas guiada por el grafo de misiones (Mission-Aware).

@export var use_mission_aware_placement: bool = false ## If true, uses MissionGraph-guided placement. Else, current behavior (random).
@export var mission_aware_preferred_distance: float = 12.0 ## Preferred distance (cells) between a room and its placed neighbors.
@export var mission_aware_candidate_count: int = 15 ## Number of candidates generated per room before accepting the best.
@export var mission_aware_distance_jitter: float = 4.0 ## Tolerance radius around preferred_distance for candidates.

func duplicate_config() -> SpaceGrammarConfig:
	var copy: SpaceGrammarConfig = (get_script() as GDScript).new()
	copy.use_mission_aware_placement = use_mission_aware_placement
	copy.mission_aware_preferred_distance = mission_aware_preferred_distance
	copy.mission_aware_candidate_count = mission_aware_candidate_count
	copy.mission_aware_distance_jitter = mission_aware_distance_jitter
	return copy
