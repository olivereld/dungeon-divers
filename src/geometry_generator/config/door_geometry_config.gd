class_name DoorGeometryConfig
extends Resource

## Configuración paramétrica para la generación de hojas de puerta de madera y herrajes.

@export_group("Dimensiones de la Hoja")
@export var door_width: float = 1.06
@export var door_height: float = 2.49
@export var door_thickness: float = 0.12
@export var door_plank_count: int = 3
@export var door_batten_depth: float = 0.035
@export var door_knocker_radius: float = 0.065
@export var centered_origin: bool = true
@export var seed: int = 1337

func duplicate_config():
	var c = get_script().new()
	c.door_width = door_width
	c.door_height = door_height
	c.door_thickness = door_thickness
	c.door_plank_count = door_plank_count
	c.door_batten_depth = door_batten_depth
	c.door_knocker_radius = door_knocker_radius
	c.centered_origin = centered_origin
	c.seed = seed
	return c
