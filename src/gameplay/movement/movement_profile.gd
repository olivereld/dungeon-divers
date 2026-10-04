class_name MovementProfile
extends Resource

## Configuración y restricciones físicas/lógicas de movimiento para un tipo de actor.
## No almacena estado runtime.

enum WaterMode {
	LAND, ## No puede entrar en agua
	SWIM, ## Puede navegar en agua
	FLY   ## Ignora agua y diferencias de elevación de terreno
}

## Velocidad en celdas por segundo. Determina duration = 1.0 / cells_per_second.
@export var cells_per_second: float = 4.0

## Direcciones permitidas para el actor (por defecto 4 direcciones cardinales).
@export var allowed_directions: Array[Vector2i] = [
	Vector2i(0, 1),   # Sur / +Z
	Vector2i(0, -1),  # Norte / -Z
	Vector2i(1, 0),   # Este / +X
	Vector2i(-1, 0)   # Oeste / -X
]

## Máximo desnivel de elevación ascendente permitido (+levels).
@export var max_step_up: int = 1

## Máximo desnivel de elevación descendente permitido (-levels).
@export var max_step_down: int = 1

## Modalidad de interacción con celdas de agua.
@export var water_mode: WaterMode = WaterMode.LAND

## Huella en celdas del actor (por defecto 1x1).
@export var footprint: Vector2i = Vector2i(1, 1)

## Velocidad angular de orientación visual hacia la dirección de avance.
@export var turn_speed: float = 14.0

func is_direction_allowed(dir: Vector2i) -> bool:
	return allowed_directions.has(dir)
