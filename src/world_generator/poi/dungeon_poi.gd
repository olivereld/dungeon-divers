class_name DungeonPOI
extends RefCounted

## Representación de la entidad POI de mazmorra dentro del mundo exterior.
## Encapsula la identidad canónica, posición 3D, orientación, arquetipo y huella de exclusión.
## Desacoplado de los chunks: chunk_coord no se almacena como autoridad primaria,
## sino que se deriva dinámicamente según la resolución de chunk requerida.

const _DungeonIdentityScript = preload("res://src/world_generator/poi/dungeon_identity.gd")

var identity: RefCounted = null
var world_position: Vector3 = Vector3.ZERO
var entrance_transform: Transform3D = Transform3D.IDENTITY
var archetype_id: StringName = &""
var tier: int = 1
var total_floors: int = 1
var orientation_deg: float = 0.0
var bounding_rect: Rect2i = Rect2i()

func _init(
	p_identity: RefCounted = null,
	p_pos: Vector3 = Vector3.ZERO,
	p_transform: Transform3D = Transform3D.IDENTITY,
	p_archetype: StringName = &"",
	p_tier: int = 1,
	p_floors: int = 1,
	p_orientation: float = 0.0,
	p_bounds: Rect2i = Rect2i()
) -> void:
	identity = p_identity
	world_position = p_pos
	entrance_transform = p_transform
	archetype_id = p_archetype
	tier = p_tier
	total_floors = p_floors
	orientation_deg = p_orientation
	bounding_rect = p_bounds

## Deriva la coordenada del chunk en runtime a partir de world_position
func get_chunk_coord(chunk_size: int = 16) -> Vector2i:
	var cx: int = int(floor(world_position.x / float(chunk_size)))
	var cz: int = int(floor(world_position.z / float(chunk_size)))
	return Vector2i(cx, cz)
