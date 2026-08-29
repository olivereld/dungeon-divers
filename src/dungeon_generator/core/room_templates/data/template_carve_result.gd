class_name TemplateCarveResult
extends RefCounted

## Resultado estructurado y exhaustivo del tallado espacial de un RoomTemplate.
## Contiene la malla de zonas, celdas talladas, coordenadas resueltas de anclajes (anchors),
## orientación seleccionada y diagnóstico de ejecución.

var is_success: bool = false
var zone_map: RoomTemplateZoneMap = null
var carved_cells: Array[Vector2i] = []
var reserved_cells: Array[Vector2i] = []
var resolved_anchors: Dictionary = {} # StringName -> Vector2i
var orientation: int = 0 # 0: NORTH, 1: EAST, 2: SOUTH, 3: WEST
var diagnostics: Dictionary = {}

func _init(
	p_success: bool = false,
	p_zone_map: RoomTemplateZoneMap = null,
	p_carved: Array[Vector2i] = [],
	p_reserved: Array[Vector2i] = [],
	p_anchors: Dictionary = {},
	p_orientation: int = 0,
	p_diag: Dictionary = {}
) -> void:
	is_success = p_success
	zone_map = p_zone_map
	carved_cells = p_carved
	reserved_cells = p_reserved
	resolved_anchors = p_anchors
	orientation = p_orientation
	diagnostics = p_diag

func get_anchor_position(anchor_id: StringName) -> Vector2i:
	return resolved_anchors.get(anchor_id, Vector2i(-1, -1))

func has_anchor(anchor_id: StringName) -> bool:
	return resolved_anchors.has(anchor_id)
