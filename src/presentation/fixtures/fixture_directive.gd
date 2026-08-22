class_name FixtureDirective
extends RefCounted

## Directiva inmutable de colocación espacial para un fixture arquitectónico.
## Emitida por FixtureResolver para ser consumida por FixtureSpawner.
## 100% puro: no contiene nodos de escena.

const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixturePlacementScript = preload("res://src/presentation/fixtures/fixture_placement.gd")

var fixture_id: StringName = &""
var room_id: int = -1
var style: _FixtureStyleScript = null
var placement: _FixturePlacementScript = null
var scale: float = 1.0

# Propiedades de conveniencia delegadas a placement
var cell: Vector2i:
	get:
		return placement.cell if placement != null else Vector2i.ZERO

var world_position: Vector3:
	get:
		return placement.position if placement != null else Vector3.ZERO

var rotation_y: float:
	get:
		return placement.rotation_y if placement != null else 0.0

var wall_side: int:
	get:
		return placement.wall_side if placement != null else -1

var placement_mode: int:
	get:
		return placement.mode if placement != null else 0

func _init(
	p_fixture_id: StringName = &"",
	p_room_id: int = -1,
	p_style: _FixtureStyleScript = null,
	p_placement: _FixturePlacementScript = null,
	p_scale: float = 1.0
) -> void:
	fixture_id = p_fixture_id
	room_id = p_room_id
	style = p_style
	placement = p_placement
	scale = p_scale

func to_debug_string() -> String:
	return "FixtureDirective(ID: %s, Room: %d, %s, Scale: %.2f)" % [
		str(fixture_id), room_id, placement.to_debug_string() if placement != null else "NoPlacement", scale
	]
