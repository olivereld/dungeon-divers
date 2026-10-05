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

## Máximo desnivel de elevación ascendente permitido (+levels).
@export var max_step_up: int = 1

## Máximo desnivel de elevación descendente permitido caminando (-levels).
@export var max_step_down: int = 1

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
