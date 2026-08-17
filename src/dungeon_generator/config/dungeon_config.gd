class_name DungeonConfig
extends Resource

## Configuración completa y exportable para el generador de mazmorras.

@export_group("Identificación y Semilla")
@export var dungeon_id: StringName = &"dungeon_01"
@export var floor_number: int = 1
@export var seed: int = 0
@export var use_fixed_seed: bool = false

@export_group("Dimensiones de Rejilla")
@export_range(16, 256, 1) var grid_width: int = 64
@export_range(16, 256, 1) var grid_height: int = 64
@export var cell_size: float = 2.0
@export_range(1, 4, 1) var wall_height: int = 2

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
@export_range(1, 3, 1) var corridor_width: int = 2
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

@export_group("Dificultad y Balance")
@export_range(0.1, 3.0, 0.1) var difficulty: float = 1.0

@export_group("Perfil de Bioma")
@export var biome_profile: BiomeProfile = null

func get_effective_seed() -> int:
	if use_fixed_seed or seed != 0:
		return seed
	return 1337
