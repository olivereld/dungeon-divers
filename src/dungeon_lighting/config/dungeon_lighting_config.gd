class_name DungeonLightingConfig
extends Resource

## Configuración y reglas de distribución de iluminación procedural para mazmorras.

@export_group("Estado General")
@export var enabled: bool = true

@export_group("Iluminación de Habitaciones")
@export_range(0, 10, 1) var min_lights_per_room: int = 1
@export_range(1, 20, 1) var max_lights_per_room: int = 4
@export_range(5.0, 50.0, 1.0) var room_area_per_light: float = 16.0 # 1 antorcha cada 16 celdas aprox.
@export_range(1.0, 10.0, 0.5) var min_light_spacing: float = 3.5    # Distancia euclidiana mínima entre antorchas

@export_group("Iluminación de Pasillos")
@export var corridor_lighting_enabled: bool = true
@export_range(3, 20, 1) var corridor_min_length: int = 8
@export_range(3, 16, 1) var corridor_spacing: int = 6
@export var prioritize_turns: bool = true

@export_group("Restricciones de Pared")
@export var avoid_door_proximity: int = 1 # Celdas de margen respecto a jambas de puertas
@export var avoid_corners: bool = true
