class_name MovementProfile
extends Resource

## Configuración y restricciones físicas/lógicas de movimiento para un tipo de actor.
## No almacena estado runtime.

enum WaterMode {
	LAND, ## No puede entrar en agua
	SWIM, ## Puede navegar en agua
	FLY   ## Ignora agua y diferencias de elevación de terreno
}

enum DiagonalCornerRule {
	NONE,         ## Permite transiciones diagonales sin verificar esquinas ortogonales
	BOTH_BLOCKED, ## Bloquea la diagonal si las dos celdas ortogonales adyacentes bloquean el paso
	STRICT        ## Bloquea la diagonal si cualquiera de las celdas ortogonales adyacentes bloquea el paso
}

## Velocidad en celdas por segundo. Determina duration = 1.0 / cells_per_second.
@export var cells_per_second: float = 4.0

## Direcciones permitidas para el actor (por defecto 8 direcciones nativas).
@export var allowed_directions: Array[Vector2i] = [
	# 4 Cardinales
	Vector2i(0, -1),  # Norte / -Z
	Vector2i(1, 0),   # Este / +X
	Vector2i(0, 1),   # Sur / +Z
	Vector2i(-1, 0),  # Oeste / -X
	# 4 Diagonales
	Vector2i(1, -1),  # Noreste (+X, -Z)
	Vector2i(1, 1),   # Sureste (+X, +Z)
	Vector2i(-1, 1),  # Suroeste (-X, +Z)
	Vector2i(-1, -1)  # Noroeste (-X, -Z)
]

## Regla de validación para esquinas ortogonales en movimientos diagonales.
@export var diagonal_corner_rule: DiagonalCornerRule = DiagonalCornerRule.BOTH_BLOCKED

## Desnivel de elevación ascendente transitable automáticamente caminando sin saltar.
## Por defecto 0: cualquier elevación vertical requiere salto manual.
@export var max_walk_step_up: int = 0

## Máximo desnivel de elevación ascendente permitido mediante salto (JUMP_UP, hasta 3 bloques).
@export var max_jump_up: int = 3

## Desnivel de elevación descendente transitable automáticamente caminando sin saltar.
## Por defecto 0: cualquier borde o risco requiere salto manual.
@export var max_walk_step_down: int = 0

## Desnivel físico métrico máximo transitable automáticamente caminando sin saltar hacia arriba.
## Por defecto 0.0: no se camina ningún desnivel físico hacia arriba sin saltar.
@export var max_walk_step_height: float = 0.0

## Máxima altura física métrica permitida mediante salto ascendente (JUMP_UP, hasta 6m / 3 bloques de 2m).
@export var max_jump_height: float = 6.0

## Desnivel físico métrico máximo transitable automáticamente caminando sin saltar hacia abajo.
## Por defecto 0.0: cualquier borde físico requiere salto manual.
@export var max_walk_step_down_height: float = 0.0

## Máxima altura física métrica permitida para un descenso controlado (DROP, hasta 8m / 4 bloques de 2m).
@export var max_drop_height: float = 8.0

## Si es true, el movimiento normal por input no cambia de nivel automáticamente en los bordes (fuerza max_walk=0).
@export var require_jump_for_elevation: bool = false

## Retorna la altura física efectiva transitable caminando hacia arriba, respetando max_walk_step_up si max_walk_step_height no fue configurado explícitamente.
func get_effective_walk_step_up_height() -> float:
	if max_walk_step_height > 0.0:
		return max_walk_step_height
	if max_walk_step_up > 0:
		return float(max_walk_step_up) * 2.0
	return 0.0

## Retorna la altura física máxima efectiva para JUMP_UP.
func get_effective_jump_up_height() -> float:
	if max_jump_height > 0.0:
		return max_jump_height
	return float(max_jump_up) * 2.0

## Retorna la altura física efectiva transitable caminando hacia abajo.
func get_effective_walk_step_down_height() -> float:
	if max_walk_step_down_height > 0.0:
		return max_walk_step_down_height
	if max_walk_step_down > 0:
		return float(max_walk_step_down) * 2.0
	return 0.0

## Retorna la altura física máxima efectiva para DROP.
func get_effective_drop_height() -> float:
	if max_drop_height > 0.0:
		return max_drop_height
	return float(max_drop_distance) * 2.0

## Alias de retrocompatibilidad para max_jump_up.
var max_step_up: int:
	get:
		return max_jump_up
	set(val):
		max_jump_up = val

## Alias de retrocompatibilidad para max_walk_step_down.
var max_step_down: int:
	get:
		return max_walk_step_down
	set(val):
		max_walk_step_down = val

## Permite o bloquea descensos controlados en arco (DROP) hacia celdas inferiores.
@export var can_drop: bool = false

## Máximo desnivel de elevación permitido para un descenso controlado (DROP).
@export var max_drop_distance: int = 4

## Altura del arco parabólico visual durante la transición DROP.
@export var drop_arc_height: float = 0.35

## Multiplicador de velocidad de avance para la trayectoria en arco de DROP (si drop_flight_time == 0).
@export var drop_speed_multiplier: float = 1.2

## Tiempo de preparación/anticipación estático en el borde antes de despegar en DROP (en segundos).
@export var drop_windup_time: float = 0.0

## Tiempo fijo de vuelo en el aire durante DROP (en segundos). Si > 0, es independiente del input de carrera/caminar.
@export var drop_flight_time: float = 0.0

## Multiplicador de velocidad de avance para saltos hacia arriba (JUMP_UP) si jump_up_flight_time == 0.
@export var jump_up_speed_multiplier: float = 1.0

## Tiempo fijo de vuelo en el aire durante JUMP_UP (en segundos). Si == 0 y drop_flight_time > 0, hereda drop_flight_time.
@export var jump_up_flight_time: float = 0.0

## Tiempo de preparación estático antes de despegar en JUMP_UP (en segundos). Por defecto 0.0.
@export var jump_up_windup_time: float = 0.0

## Permite o bloquea caídas hacia celdas inferiores que excedan max_step_down.
@export var can_fall: bool = true

## Máximo desnivel de niveles de elevación permitidos para una caída segura.
## Desniveles mayores a este valor son letales/infranqueables y se rechazan (REASON_FALL_TOO_HIGH).
@export var max_fall_height: int = 6

## Multiplicador de velocidad de caída para el avance vertical en caída.
@export var fall_speed_multiplier: float = 1.4

## Modalidad de interacción con celdas de agua.
@export var water_mode: WaterMode = WaterMode.LAND

## Huella en celdas del actor (por defecto 1x1).
@export var footprint: Vector2i = Vector2i(1, 1)

## Velocidad angular de orientación visual hacia la dirección de avance.
@export var turn_speed: float = 14.0

func is_direction_allowed(dir: Vector2i) -> bool:
	return allowed_directions.has(dir)
