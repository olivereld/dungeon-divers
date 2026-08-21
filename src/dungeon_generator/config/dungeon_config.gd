class_name DungeonConfig
extends Resource

## Configuración completa y exportable para el generador de mazmorras.

@export_group("Identificación y Semilla")
@export var dungeon_id: StringName = &"dungeon_01"
@export var floor_number: int = 1
@export var total_floors: int = 1
@export var floor_height: float = 6.0
@export var seed: int = 0
@export var use_fixed_seed: bool = false
@export var dungeon_archetype: int = 0 ## DungeonArchetype.Type (0 = GENERIC, 1 = MAUSOLEUM, 2 = FORTRESS, 3 = TEMPLE, 4 = MINE)

@export_group("Dimensiones de Rejilla")
@export_range(16, 256, 1) var grid_width: int = 64
@export_range(16, 256, 1) var grid_height: int = 64
@export var cell_size: float = 2.0
@export_range(1, 4, 1) var wall_height: int = 2

@export_group("Densidad y Rango de Salas")
@export_range(4, 50, 1) var min_target_rooms: int = 5
@export_range(4, 50, 1) var max_target_rooms: int = 15

@export_group("Gramática de Misión")
@export_range(2, 20, 1) var mission_depth: int = 5
@export_range(5, 100, 1) var max_grammar_iterations: int = 25
@export_range(0.0, 1.0, 0.05) var lock_key_frequency: float = 0.35
@export_range(0.0, 1.0, 0.05) var optional_branch_chance: float = 0.25
@export var boss_enabled: bool = true

@export_group("Algoritmo de Construcción")
@export_enum("CellularAutomata", "BSP", "Hybrid") var algorithm: String = "Hybrid"
@export_range(0.3, 0.6, 0.01) var ca_fill_chance: float = 0.45
@export_range(1, 8, 1) var ca_iterations: int = 4
@export var bsp_min_room: Vector2i = Vector2i(6, 6)
@export var bsp_max_room: Vector2i = Vector2i(14, 14)

@export_group("Corredores")
@export_enum("L-Shaped", "Straight", "Organic", "AStar") var corridor_style: String = "AStar"
@export_range(1, 4, 1) var corridor_width: int = 2
@export_range(0.0, 0.5, 0.05) var extra_loop_chance: float = 0.15
@export var use_astar_carver: bool = true

@export_group("Resolución de Entradas (Fase 4)")
@export_range(0, 4, 1) var corner_margin: int = 1
@export_range(1, 6, 1) var minimum_entrance_spacing: int = 2
@export_range(0.1, 10.0, 0.1) var entrance_distance_weight: float = 1.0
@export_range(0.1, 10.0, 0.1) var entrance_alignment_weight: float = 2.0
@export_range(0.0, 50.0, 1.0) var entrance_corner_penalty: float = 5.0
@export_range(10.0, 500.0, 10.0) var entrance_conflict_penalty: float = 100.0

@export_group("Tallado A* (Fase 5)")
@export_range(0.5, 10.0, 0.5) var corridor_cost_corridor: float = 1.0
@export_range(5.0, 50.0, 1.0) var corridor_cost_wall: float = 15.0
@export_range(10.0, 100.0, 5.0) var corridor_cost_room_floor: float = 35.0
@export_range(100.0, 5000.0, 100.0) var corridor_cost_other_room: float = 1000.0
@export_range(0, 3, 1) var corridor_bottleneck_distance: int = 1

@export_group("Calidad de Corredores (Fase Refined)")
@export_range(0.0, 50.0, 0.5) var corridor_turn_penalty: float = 10.0
@export_range(0.0, 20.0, 0.5) var corridor_proximity_penalty: float = 3.0
@export_range(0, 4, 1) var corridor_max_preferred_turns: int = 2
@export var prefer_orthogonal_routes: bool = true
@export var allow_astar_fallback: bool = true

@export_group("Calidad de Puertas (Fase Refined)")
@export_range(2, 16, 1) var minimum_corridor_door_spacing: int = 5
@export_range(0.0, 100.0, 1.0) var same_side_door_penalty: float = 30.0
@export_range(0.0, 100.0, 1.0) var corridor_door_proximity_penalty: float = 50.0
@export var distribute_room_doors_across_sides: bool = true

@export_group("Política de Puertas (Fase Reforced)")
@export var min_corridor_length_for_double_doors: int = 6
@export var short_corridor_single_door_threshold: int = 3
@export_range(0.0, 1.0, 0.05) var door_open_passage_chance: float = 0.25
@export_range(0.0, 1.0, 0.05) var door_single_door_chance: float = 0.65
@export_range(0.0, 1.0, 0.05) var door_double_door_chance: float = 0.10

@export_group("Dificultad y Balance")
@export_range(0.1, 3.0, 0.1) var difficulty: float = 1.0

@export_group("Perfil de Bioma")
@export var biome_profile: BiomeProfile = null

@export_group("Generación de Suelos Procedurales")
@export var floor_tile_config: Resource = null

@export_group("Iluminación Procedural")
@export var lighting_config: Resource = null

func get_effective_seed() -> int:
	if use_fixed_seed or seed != 0:
		return seed
	return 1337

## Preset Compacto (32x32)
func apply_preset_compact() -> void:
	grid_width = 32
	grid_height = 32
	mission_depth = 3
	min_target_rooms = 4
	max_target_rooms = 8
	corridor_width = 1

## Preset Estándar (64x64)
func apply_preset_standard() -> void:
	grid_width = 64
	grid_height = 64
	mission_depth = 5
	min_target_rooms = 6
	max_target_rooms = 14
	corridor_width = 2

## Preset Amplio (96x96)
func apply_preset_large() -> void:
	grid_width = 96
	grid_height = 96
	mission_depth = 8
	min_target_rooms = 10
	max_target_rooms = 22
	corridor_width = 2

## Preset Monumental (128x128)
func apply_preset_massive() -> void:
	grid_width = 128
	grid_height = 128
	mission_depth = 12
	min_target_rooms = 15
	max_target_rooms = 32
	corridor_width = 3

func duplicate_config() -> DungeonConfig:
	var c := DungeonConfig.new()
	c.dungeon_id = dungeon_id
	c.floor_number = floor_number
	c.total_floors = total_floors
	c.floor_height = floor_height
	c.seed = seed
	c.use_fixed_seed = use_fixed_seed
	c.dungeon_archetype = dungeon_archetype
	c.grid_width = grid_width
	c.grid_height = grid_height
	c.cell_size = cell_size
	c.wall_height = wall_height
	c.min_target_rooms = min_target_rooms
	c.max_target_rooms = max_target_rooms
	c.mission_depth = mission_depth
	c.max_grammar_iterations = max_grammar_iterations
	c.lock_key_frequency = lock_key_frequency
	c.optional_branch_chance = optional_branch_chance
	c.boss_enabled = boss_enabled
	c.algorithm = algorithm
	c.ca_fill_chance = ca_fill_chance
	c.ca_iterations = ca_iterations
	c.bsp_min_room = bsp_min_room
	c.bsp_max_room = bsp_max_room
	c.corridor_style = corridor_style
	c.corridor_width = corridor_width
	c.extra_loop_chance = extra_loop_chance
	c.use_astar_carver = use_astar_carver
	return c
