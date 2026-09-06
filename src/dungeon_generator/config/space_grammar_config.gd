class_name SpaceGrammarConfig
extends Resource

## Configuración para Composición Espacial Global (Spatial Composition V2).

# Spatial Constraints & Boundaries
@export var min_room_separation: int = 2 ## Minimum empty cells between room boundaries (hard constraint).
@export var min_mission_edge_distance: float = 6.0 ## Minimum allowed center-to-center distance between connected mission rooms (hard constraint).
@export var max_mission_edge_distance: float = 24.0 ## Soft reference distance used for spatial scoring; not a hard placement constraint.

# Distance & Candidates
@export var preferred_distance: float = 12.0 ## Preferred distance (cells) between connected rooms.
@export var distance_jitter: float = 4.0 ## Tolerance radius around preferred_distance for candidates.
@export var composition_candidate_count: int = 24 ## Number of candidate positions evaluated per room.

# Direction & Scoring Weights
@export var preferred_progression_direction: Vector2 = Vector2.ZERO ## Global direction vector (if Vector2.ZERO, randomized per seed deterministically).
@export var progression_strength: float = 1.0 ## Weight for advancing along the dungeon spatial progression path (soft scoring).
@export var density_strength: float = 0.5 ## Weight for penalizing excessive clustering or empty void gaps (soft scoring).
@export var anchor_distance_strength: float = 1.0
@export var neighbor_coherence_strength: float = 1.0
@export var main_path_alignment_strength: float = 1.0
@export var branch_lateral_strength: float = 0.75
@export var terminal_spacing_strength: float = 0.75

func duplicate_config() -> SpaceGrammarConfig:
	var copy: SpaceGrammarConfig = (get_script() as GDScript).new()
	copy.min_room_separation = min_room_separation
	copy.min_mission_edge_distance = min_mission_edge_distance
	copy.max_mission_edge_distance = max_mission_edge_distance
	copy.preferred_distance = preferred_distance
	copy.distance_jitter = distance_jitter
	copy.composition_candidate_count = composition_candidate_count
	copy.preferred_progression_direction = preferred_progression_direction
	copy.progression_strength = progression_strength
	copy.density_strength = density_strength
	copy.anchor_distance_strength = anchor_distance_strength
	copy.neighbor_coherence_strength = neighbor_coherence_strength
	copy.main_path_alignment_strength = main_path_alignment_strength
	copy.branch_lateral_strength = branch_lateral_strength
	copy.terminal_spacing_strength = terminal_spacing_strength
	return copy
