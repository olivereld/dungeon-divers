class_name FixtureDirective
extends RefCounted

## Directiva inmutable de colocación espacial para un fixture arquitectónico.
## Emitida por FixtureResolver para ser consumida por FixtureSpawner.
## 100% puro: no contiene nodos de escena.

const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixtureAnchorScript = preload("res://src/presentation/fixtures/fixture_anchor.gd")

var fixture_id: StringName = &""
var room_id: int = -1
var anchor: _FixtureAnchorScript.Type = _FixtureAnchorScript.Type.WALL
var cell: Vector2i = Vector2i.ZERO
var wall_side: int = 0 # 0=NORTH, 1=EAST, 2=SOUTH, 3=WEST
var world_position: Vector3 = Vector3.ZERO
var rotation_y: float = 0.0
var scale: float = 1.0
var style: _FixtureStyleScript = null

func _init(
	p_fixture_id: StringName = &"",
	p_room_id: int = -1,
	p_anchor: _FixtureAnchorScript.Type = _FixtureAnchorScript.Type.WALL,
	p_cell: Vector2i = Vector2i.ZERO,
	p_side: int = 0,
	p_world_pos: Vector3 = Vector3.ZERO,
	p_rot_y: float = 0.0,
	p_scale: float = 1.0,
	p_style: _FixtureStyleScript = null
) -> void:
	fixture_id = p_fixture_id
	room_id = p_room_id
	anchor = p_anchor
	cell = p_cell
	wall_side = p_side
	world_position = p_world_pos
	rotation_y = p_rot_y
	scale = p_scale
	style = p_style

func to_debug_string() -> String:
	return "FixtureDirective(ID: %s, Room: %d, Cell: %s, Side: %d, Pos: %s, RotY: %.2f)" % [
		str(fixture_id), room_id, str(cell), wall_side, str(world_position), rotation_y
	]
