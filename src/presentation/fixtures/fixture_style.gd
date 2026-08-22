class_name FixtureStyle
extends Resource

## Definición de estilo y propiedades arquitectónicas de un Fixture (antorcha, brasero, farol, etc.).
## 100% puro: no contiene nodos 3D ni lógica de colocación.

enum Type {
	TORCH = 0,
	BRAZIER = 1,
	LANTERN = 2,
	CANDLE = 3
}

@export var id: StringName = &"gothic_torch"
@export var fixture_type: Type = Type.TORCH
@export var scale: float = 1.0
@export var offset: Vector3 = Vector3.ZERO
@export var collision_mode: int = 0 # FixtureCollisionMode.Mode
@export var custom_scene: PackedScene = null # Escena alternativa si no es procedural

# Propiedades de Iluminación Local
@export var has_light: bool = true
@export var light_color: Color = Color(1.0, 0.65, 0.28, 1.0)
@export var light_energy: float = 1.2
@export var light_range: float = 6.0

func _init(
	p_id: StringName = &"gothic_torch",
	p_type: Type = Type.TORCH,
	p_scale: float = 1.0,
	p_offset: Vector3 = Vector3.ZERO,
	p_col_mode: int = 0,
	p_has_light: bool = true,
	p_light_color: Color = Color(1.0, 0.65, 0.28, 1.0),
	p_light_energy: float = 1.2,
	p_light_range: float = 6.0,
	p_scene: PackedScene = null
) -> void:
	id = p_id
	fixture_type = p_type
	scale = p_scale
	offset = p_offset
	collision_mode = p_col_mode
	has_light = p_has_light
	light_color = p_light_color
	light_energy = p_light_energy
	light_range = p_light_range
	custom_scene = p_scene
