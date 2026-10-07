class_name WorldCell
extends RefCounted

var position: Vector2i
# --- Contrato de Elevación y Autoridad de Terreno ---

## Cota física final del terreno (H_terrain_final) para rendering, colisiones y física.
## Inicialmente calculada en TerrainStage: height = base_height + elevation_level * elevation_step_height.
## Modificable posteriormente únicamente por etapas autorizadas de deformación (p. ej. tallado en HydrologyStage).
var height: float = 0.0

## Señal procedural continua original (H_raw) producida por el campo de ruido y domain warp en TerrainStage.
## Inmutable tras TerrainStage: señal continua preservada internamente para evitar destrucción de información.
var raw_height: float = 0.0

## Autoridad discreta: Nivel entero de elevación cuantizada generado por TerrainStage.
## Única fuente de verdad del nivel de terraza/escalón para todos los sistemas subsiguientes
## (evita que otros sistemas deban re-inferir el nivel a partir de height).
var elevation_level: int = 0
var normalized_height: float = 0.0

## Alias semántico de la elevación normalizada [0.0, 1.0] para Climate y Biome selection.
var elevation_normalized: float:
	get:
		return normalized_height
	set(value):
		normalized_height = value

var slope: float = 0.0
var slope_category: int = 0
var is_walkable: bool = true
var hydraulic_influence: float = 0.0

# --- Clima y Bioma ---
## Temperatura macro ambiental en rango [0.0, 1.0] (0 = gélido/polar, 1 = tórrido/cálido).
var temperature: float = 0.5

## Humedad ambiental en rango [0.0, 1.0] (0 = árido/seco, 1 = saturado/húmedo).
var moisture: float = 0.5

## Identificador del bioma asignado según reglas de selección climática (T/M/E).
var biome_id: StringName = &"taiga"

# Ecology
enum CanopyZone {
	CLEARING,
	FOREST_EDGE,
	SPARSE_FOREST,
	DENSE_FOREST,
}

var forest_density: float = 0.0
var clearing_density: float = 0.0
var canopy_zone: int = CanopyZone.CLEARING

func _init(p_pos: Vector2i = Vector2i.ZERO) -> void:
	position = p_pos

## Consulta si esta celda puede transicionar a otra según la regla de terreno escalonado:
## same level -> transitable según reglas existentes; different level -> no transitable.
func can_transition_to(other: WorldCell) -> bool:
	if other == null:
		return false
	if elevation_level != other.elevation_level:
		return false
	return is_walkable and other.is_walkable

