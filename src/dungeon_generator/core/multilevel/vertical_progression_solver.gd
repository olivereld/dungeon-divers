extends RefCounted

## Resuelve y distribuye la progresión semántica vertical y roles a través de los pisos (Fase 10 / M8).
## Define formalmente la asignación de roles:
## - Piso 0: Spawn del jugador, transición a piso inferior, sin Boss (si total_floors > 1).
## - Pisos Intermedios: Tránsito bidireccional (Stairs Up y Down), desafíos y llaves/puzzles.
## - Piso Final (N-1): Boss de mazmorra, meta / cofre legendario, sin escaleras descendentes.

const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")

class FloorProgressionRole extends RefCounted:
	var floor_number: int = 0
	var total_floors: int = 1
	var is_entry_floor: bool = false
	var is_boss_floor: bool = false
	var requires_stair_down: bool = false
	var requires_stair_up: bool = false
	var boss_enabled: bool = false

## Resuelve el perfil de progresión para cada piso de la mazmorra.
func solve_progression_roles(config: DungeonConfig) -> Array[FloorProgressionRole]:
	var roles: Array[FloorProgressionRole] = []
	var total: int = maxi(1, config.total_floors if config != null else 1)

	for f in range(total):
		var role := FloorProgressionRole.new()
		role.floor_number = f
		role.total_floors = total
		role.is_entry_floor = (f == 0)
		role.is_boss_floor = (f == total - 1)
		role.requires_stair_down = (f < total - 1)
		role.requires_stair_up = (f > 0)
		role.boss_enabled = (role.is_boss_floor and (config == null or config.boss_enabled))
		roles.append(role)

	return roles

## Configura un DungeonConfig derivado para un piso específico garantizando sus restricciones semánticas.
func create_floor_config(base_config: DungeonConfig, role: FloorProgressionRole, floor_seed: int) -> DungeonConfig:
	var floor_cfg: DungeonConfig = (base_config.duplicate() if base_config != null else _DungeonConfigScript.new()) as DungeonConfig
	floor_cfg.floor_number = role.floor_number
	floor_cfg.total_floors = role.total_floors
	floor_cfg.seed = floor_seed
	floor_cfg.use_fixed_seed = true
	floor_cfg.boss_enabled = role.boss_enabled

	return floor_cfg
