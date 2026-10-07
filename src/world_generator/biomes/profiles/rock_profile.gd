class_name RockProfile
extends Resource

## Parámetros de distribución y tamaños de rocas para un bioma.

@export var rock_density: float = 0.15
@export var min_slope_degrees: float = 15.0
@export var max_slope_degrees: float = 55.0
@export var category_weights: Dictionary = {
	"large": 0.20,
	"medium": 0.45,
	"small": 0.35
}
@export var clustering: Dictionary = {}
