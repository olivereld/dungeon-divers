class_name PropStyle
extends Resource

## Configuración y especificación declarativa para un Room Prop.
## Representa QUÉ es un prop (tipo, huella, colocación, colisión y escena/generador),
## sin buscar celdas, sin instanciar Nodes en lógica pura y sin mutar CellGrid.

const _PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")
const _PropCollisionModeScript = preload("res://src/presentation/props/prop_collision_mode.gd")
const _PropFootprintScript = preload("res://src/presentation/props/prop_footprint.gd")
const _DecorationRoleScript = preload("res://src/presentation/decoration/decoration_role.gd")

enum Type {
	SARCOPHAGUS = 0,
	TOMBSTONE = 1,
	URN = 2,
	ALTAR = 3,
	BENCH = 4,
	TABLE = 5,
	CHAIR = 6,
	BOOKSHELF = 7,
	CHEST = 8,
	CRATE = 9,
	BARREL = 10,
	RUBBLE = 11,
	SACK = 12
}

@export var id: StringName = &""
@export var prop_type: Type = Type.SARCOPHAGUS
@export var placement_mode: int = _PropPlacementModeScript.Mode.FLOOR
@export var collision_mode: int = _PropCollisionModeScript.Mode.BLOCKING
@export var role: int = _DecorationRoleScript.Role.SUPPORT
@export var footprint: _PropFootprintScript = null
@export var scale: float = 1.0
@export var offset: Vector3 = Vector3.ZERO
@export var generator_id: StringName = &""
@export var generator_params: Dictionary = {}
@export var custom_scene: PackedScene = null

func _init(
	p_id: StringName = &"",
	p_type: Type = Type.SARCOPHAGUS,
	p_placement: int = _PropPlacementModeScript.Mode.FLOOR,
	p_collision: int = _PropCollisionModeScript.Mode.BLOCKING,
	p_footprint: _PropFootprintScript = null,
	p_generator_id: StringName = &"",
	p_params: Dictionary = {},
	p_role: int = _DecorationRoleScript.Role.SUPPORT
) -> void:
	id = p_id
	prop_type = p_type
	placement_mode = p_placement
	collision_mode = p_collision
	footprint = p_footprint if p_footprint != null else _PropFootprintScript.new(Vector2i.ONE)
	generator_id = p_generator_id
	generator_params = p_params
	role = p_role

