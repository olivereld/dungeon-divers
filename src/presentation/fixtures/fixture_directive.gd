class_name FixtureDirective
extends RefCounted

## Directiva inmutable de colocación espacial para un fixture arquitectónico.
## Emitida por FixtureResolver para ser consumida por FixtureSpawner.
## 100% puro: no contiene nodos de escena.

const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixturePlacementScript = preload("res://src/presentation/fixtures/fixture_placement.gd")

enum SourceType {
	AMBIENT = 0,
	PROP_RELATION = 1
}

var fixture_id: StringName = &""
var room_id: int = -1
var style: _FixtureStyleScript = null
var placement: _FixturePlacementScript = null
var scale: float = 1.0
var source_type: int = SourceType.AMBIENT
var source_prop_id: StringName = &""
var relation_id: StringName = &""
var relation_type: int = 0

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
	p_scale: float = 1.0,
	p_source_type: int = SourceType.AMBIENT,
	p_source_prop: StringName = &"",
	p_relation_id: StringName = &"",
	p_relation_type: int = 0
) -> void:
	fixture_id = p_fixture_id
	room_id = p_room_id
	style = p_style
	placement = p_placement
	scale = p_scale
	source_type = p_source_type
	source_prop_id = p_source_prop
	relation_id = p_relation_id
	relation_type = p_relation_type

func to_debug_string() -> String:
	return "FixtureDirective(ID: %s, Room: %d, %s, Scale: %.2f, Source: %s, Rel: %s)" % [
		str(fixture_id), room_id, placement.to_debug_string() if placement != null else "NoPlacement",
		scale, "PROP_RELATION" if source_type == SourceType.PROP_RELATION else "AMBIENT", str(relation_id)
	]
