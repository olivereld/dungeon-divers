class_name ArchitecturalPresentationProfile
extends RefCounted

## Contrato de datos inmutable que encapsula los estilos arquitectónicos resueltos
## para una habitación o zona del dungeon (Suelo, Muro, Puerta, Escaleras, Luminaria, Paleta).
## 100% puro: no depende de nodos de escena ni mallas 3D.

const _ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")

var floor_style: _ArchitecturalStyleScript.FloorStyle = _ArchitecturalStyleScript.FloorStyle.GENERIC_STONE
var wall_style: _ArchitecturalStyleScript.WallStyle = _ArchitecturalStyleScript.WallStyle.GENERIC_STONE
var door_style: _ArchitecturalStyleScript.DoorStyle = _ArchitecturalStyleScript.DoorStyle.STONE_ARCH
var stairs_style: _ArchitecturalStyleScript.StairsStyle = _ArchitecturalStyleScript.StairsStyle.STONE
var fixture_style: _ArchitecturalStyleScript.FixtureStyle = _ArchitecturalStyleScript.FixtureStyle.TORCH
var decoration_palette: int = _ArchitecturalStyleScript.DecorationPalette.GENERIC
var wall_variants = null # ProfileWallVariantPolicy o WallVariantPolicy

func _init(
	p_floor: _ArchitecturalStyleScript.FloorStyle = _ArchitecturalStyleScript.FloorStyle.GENERIC_STONE,
	p_wall: _ArchitecturalStyleScript.WallStyle = _ArchitecturalStyleScript.WallStyle.GENERIC_STONE,
	p_door: _ArchitecturalStyleScript.DoorStyle = _ArchitecturalStyleScript.DoorStyle.STONE_ARCH,
	p_stairs: _ArchitecturalStyleScript.StairsStyle = _ArchitecturalStyleScript.StairsStyle.STONE,
	p_fixture: _ArchitecturalStyleScript.FixtureStyle = _ArchitecturalStyleScript.FixtureStyle.TORCH,
	p_palette: int = _ArchitecturalStyleScript.DecorationPalette.GENERIC
) -> void:
	floor_style = p_floor
	wall_style = p_wall
	door_style = p_door
	stairs_style = p_stairs
	fixture_style = p_fixture
	decoration_palette = p_palette

func to_debug_string() -> String:
	return "ArchProfile(Floor: %s, Wall: %s, Door: %s, Stairs: %s, Fixture: %s, Palette: %s)" % [
		_ArchitecturalStyleScript.floor_to_name(floor_style),
		_ArchitecturalStyleScript.wall_to_name(wall_style),
		_ArchitecturalStyleScript.door_to_name(door_style),
		_ArchitecturalStyleScript.stairs_to_name(stairs_style),
		_ArchitecturalStyleScript.fixture_to_name(fixture_style),
		_ArchitecturalStyleScript.palette_to_name(decoration_palette)
	]

func to_dict() -> Dictionary:
	return {
		"floor_style": int(floor_style),
		"floor_name": _ArchitecturalStyleScript.floor_to_name(floor_style),
		"wall_style": int(wall_style),
		"wall_name": _ArchitecturalStyleScript.wall_to_name(wall_style),
		"door_style": int(door_style),
		"door_name": _ArchitecturalStyleScript.door_to_name(door_style),
		"stairs_style": int(stairs_style),
		"stairs_name": _ArchitecturalStyleScript.stairs_to_name(stairs_style),
		"fixture_style": int(fixture_style),
		"fixture_name": _ArchitecturalStyleScript.fixture_to_name(fixture_style),
		"decoration_palette": int(decoration_palette),
		"palette_name": _ArchitecturalStyleScript.palette_to_name(decoration_palette)
	}

func equals(other: ArchitecturalPresentationProfile) -> bool:
	if other == null:
		return false
	return floor_style == other.floor_style \
		and wall_style == other.wall_style \
		and door_style == other.door_style \
		and stairs_style == other.stairs_style \
		and fixture_style == other.fixture_style \
		and decoration_palette == other.decoration_palette
