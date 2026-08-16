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

@export_group("Dificultad y Balance")
@export_range(0.1, 3.0, 0.1) var difficulty: float = 1.0

@export_group("Perfil de Bioma")
@export var biome_profile: BiomeProfile = null

func get_effective_seed() -> int:
	if use_fixed_seed or seed != 0:
		return seed
	return 1337
