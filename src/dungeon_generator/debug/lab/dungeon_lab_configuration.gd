class_name DungeonLabConfiguration
extends RefCounted

const SpaceGrammarConfig = preload("res://src/dungeon_generator/config/space_grammar_config.gd")

var seed: int = 100001
var generator_type: String = "Hybrid"
var archetype_id: StringName = &"necropolis"
var grid_size: Vector2i = Vector2i(64, 64)
var mission_depth: int = 5
var hallway_width: int = 1
var floor_count: int = 1

# Spatial Composition V2
var min_room_separation: int = 2
var min_mission_edge_distance: float = 6.0
var max_mission_edge_distance: float = 24.0
var preferred_distance: float = 12.0
var distance_jitter: float = 4.0
var progression_strength: float = 1.0
var density_strength: float = 0.5
var preferred_progression_direction: Vector2 = Vector2.ZERO

var composition_candidate_count: int = 24
var anchor_distance_strength: float = 1.0
var neighbor_coherence_strength: float = 1.0
var main_path_alignment_strength: float = 1.0
var branch_lateral_strength: float = 0.75
var terminal_spacing_strength: float = 0.75

# Profile & Template Forcing Overrides
var profile_mode: StringName = &"normal" # &"normal", &"force_profile", &"force_template"
var forced_profile_id: StringName = &""
var template_mode: StringName = &"automatic" # &"automatic", &"specific", &"random_variant"
var forced_template_id: StringName = &""

func to_dungeon_config() -> DungeonConfig:
	var cfg := DungeonConfig.new()
	cfg.seed = seed
	cfg.use_fixed_seed = true
	cfg.algorithm = generator_type
	cfg.archetype_id = archetype_id
	cfg.grid_width = grid_size.x
	cfg.grid_height = grid_size.y
	cfg.mission_depth = mission_depth
	cfg.corridor_width = hallway_width
	cfg.total_floors = floor_count

	cfg.min_room_separation = min_room_separation
	cfg.min_mission_edge_distance = min_mission_edge_distance
	cfg.max_mission_edge_distance = max_mission_edge_distance
	cfg.preferred_distance = preferred_distance
	cfg.distance_jitter = distance_jitter
	cfg.progression_strength = progression_strength
	cfg.density_strength = density_strength
	cfg.preferred_progression_direction = preferred_progression_direction
	cfg.composition_candidate_count = composition_candidate_count
	cfg.anchor_distance_strength = anchor_distance_strength
	cfg.neighbor_coherence_strength = neighbor_coherence_strength
	cfg.main_path_alignment_strength = main_path_alignment_strength
	cfg.branch_lateral_strength = branch_lateral_strength
	cfg.terminal_spacing_strength = terminal_spacing_strength

	# Profile & Template Forcing Overrides
	cfg.profile_mode = profile_mode
	cfg.forced_profile_id = forced_profile_id
	cfg.template_mode = template_mode
	cfg.forced_template_id = forced_template_id

	# SpaceGrammarConfig transport & sync
	if cfg.space_grammar_config == null:
		cfg.space_grammar_config = SpaceGrammarConfig.new()
	cfg.space_grammar_config.min_room_separation = min_room_separation
	cfg.space_grammar_config.min_mission_edge_distance = min_mission_edge_distance
	cfg.space_grammar_config.max_mission_edge_distance = max_mission_edge_distance
	cfg.space_grammar_config.preferred_distance = preferred_distance
	cfg.space_grammar_config.distance_jitter = distance_jitter
	cfg.space_grammar_config.progression_strength = progression_strength
	cfg.space_grammar_config.density_strength = density_strength
	cfg.space_grammar_config.preferred_progression_direction = preferred_progression_direction
	cfg.space_grammar_config.composition_candidate_count = composition_candidate_count
	cfg.space_grammar_config.anchor_distance_strength = anchor_distance_strength
	cfg.space_grammar_config.neighbor_coherence_strength = neighbor_coherence_strength
	cfg.space_grammar_config.main_path_alignment_strength = main_path_alignment_strength
	cfg.space_grammar_config.branch_lateral_strength = branch_lateral_strength
	cfg.space_grammar_config.terminal_spacing_strength = terminal_spacing_strength

	return cfg

func validate() -> Array[String]:
	var errors: Array[String] = []
	if grid_size.x <= 0 or grid_size.y <= 0:
		errors.append("grid_size must have positive width and height")
	if floor_count <= 0:
		errors.append("floor_count must be at least 1")
	if hallway_width <= 0:
		errors.append("hallway_width must be at least 1")
	if min_room_separation < 0:
		errors.append("min_room_separation cannot be negative")
	if min_mission_edge_distance <= 0:
		errors.append("min_mission_edge_distance must be positive")
	if max_mission_edge_distance < min_mission_edge_distance:
		errors.append("max_mission_edge_distance cannot be less than min_mission_edge_distance")
	if composition_candidate_count <= 0:
		errors.append("composition_candidate_count must be positive")
	if anchor_distance_strength < 0.0:
		errors.append("anchor_distance_strength cannot be negative")
	if neighbor_coherence_strength < 0.0:
		errors.append("neighbor_coherence_strength cannot be negative")
	if main_path_alignment_strength < 0.0:
		errors.append("main_path_alignment_strength cannot be negative")
	if branch_lateral_strength < 0.0:
		errors.append("branch_lateral_strength cannot be negative")
	if terminal_spacing_strength < 0.0:
		errors.append("terminal_spacing_strength cannot be negative")
	return errors
