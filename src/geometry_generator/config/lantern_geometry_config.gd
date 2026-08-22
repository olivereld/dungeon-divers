class_name LanternGeometryConfig
extends Resource

## Configuración procedural para el Farol Colgante Gótico (Hanging Lantern).

@export var scale_mult: float = 1.0
@export var radius: float = 0.20
@export var height: float = 0.65
@export var num_sides: int = 6
@export var is_wall_mounted: bool = false
@export var glass_color: Color = Color(0.85, 0.25, 0.95, 1.0) # Púrpura/Magenta o Cálido según variante
@export var glass_emission_energy: float = 3.2
@export var chain_links: int = 5
@export var has_ceiling_mount: bool = true
@export var seed: int = 1337

func _init(
	p_scale_mult: float = 1.0,
	p_num_sides: int = 6,
	p_is_wall_mounted: bool = false,
	p_glass_color: Color = Color(0.85, 0.25, 0.95, 1.0),
	p_seed: int = 1337,
	p_chain_links: int = 5,
	p_has_ceiling_mount: bool = true
) -> void:
	scale_mult = p_scale_mult
	num_sides = p_num_sides
	is_wall_mounted = p_is_wall_mounted
	glass_color = p_glass_color
	seed = p_seed
	chain_links = p_chain_links
	has_ceiling_mount = p_has_ceiling_mount

