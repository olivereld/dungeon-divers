class_name DungeonLabConfiguration
extends RefCounted

var seed: int = 100001
var generator_type: String = "Hybrid"
var archetype_id: StringName = &"necropolis"
var grid_size: Vector2i = Vector2i(64, 64)
var mission_depth: int = 5
var hallway_width: int = 2
var floor_count: int = 1

# Mission-Aware Room Placement
var use_mission_aware_placement: bool = true
var mission_aware_preferred_distance: float = 12.0
var mission_aware_candidate_count: int = 15
var mission_aware_distance_jitter: float = 4.0

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
	cfg.use_mission_aware_placement = use_mission_aware_placement
	cfg.mission_aware_preferred_distance = mission_aware_preferred_distance
	cfg.mission_aware_candidate_count = mission_aware_candidate_count
	cfg.mission_aware_distance_jitter = mission_aware_distance_jitter
	return cfg

func validate() -> Array[String]:
	var errors: Array[String] = []
	if grid_size.x <= 0 or grid_size.y <= 0:
		errors.append("grid_size must have positive width and height")
	if floor_count <= 0:
		errors.append("floor_count must be at least 1")
	if hallway_width <= 0:
		errors.append("hallway_width must be at least 1")
	if template_mode == &"specific" and forced_template_id == &"":
		errors.append("template_mode 'specific' requires forced_template_id")
	if profile_mode == &"force_profile" and forced_profile_id == &"":
		errors.append("profile_mode 'force_profile' requires forced_profile_id")
	return errors
