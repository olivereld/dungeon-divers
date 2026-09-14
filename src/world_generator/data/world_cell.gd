class_name WorldCell
extends RefCounted

var position: Vector2i
## Cota final del terreno (H_terrain_final) tras todas las modificaciones geomorfológicas y tallado hidráulico.
## Inicialmente igual a raw_height; modificable únicamente por etapas autorizadas de deformación.
var height: float = 0.0

## Cota original del terreno (H_raw) producida por TerrainStage.
## Inmutable tras TerrainStage: Hidrología nunca debe modificarla.
var raw_height: float = 0.0
var normalized_height: float = 0.0
var slope: float = 0.0
var slope_category: int = 0
var is_walkable: bool = true
var hydraulic_influence: float = 0.0

# Ecology
enum CanopyZone {
	CLEARING,
	FOREST_EDGE,
	SPARSE_FOREST,
	DENSE_FOREST,
}

var forest_density: float = 0.0
var clearing_density: float = 0.0
var moisture: float = 0.0
var canopy_zone: int = CanopyZone.CLEARING

func _init(p_pos: Vector2i = Vector2i.ZERO) -> void:
	position = p_pos
