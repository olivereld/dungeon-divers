class_name ArchitecturalPresentationProfile
extends RefCounted

## Contrato de datos inmutable que encapsula los estilos arquitectónicos resueltos
## para una habitación o zona del dungeon (Suelo, Muro, Puerta, Escaleras, Luminaria, Paleta).
## 100% puro: no depende de nodos de escena ni mallas 3D y utiliza StringName exclusivamente.

var floor_style: StringName = &"generic_stone"
var wall_style: StringName = &"generic_stone"
var door_style: StringName = &"stone_arch"
var stairs_style: StringName = &"stone"
var fixture_style: StringName = &"torch"
var decoration_palette: StringName = &"generic"
var wall_variants = null # ProfileWallVariantPolicy o WallVariantPolicy
var floor_variants = null # ProfileFloorVariantPolicy

func _init(
	p_floor: Variant = &"generic_stone",
	p_wall: Variant = &"generic_stone",
	p_door: Variant = &"stone_arch",
	p_stairs: Variant = &"stone",
	p_fixture: Variant = &"torch",
	p_palette: Variant = &"generic"
) -> void:
	floor_style = _normalize_id(p_floor, &"generic_stone")
	wall_style = _normalize_id(p_wall, &"generic_stone")
	door_style = _normalize_id(p_door, &"stone_arch")
	stairs_style = _normalize_id(p_stairs, &"stone")
	fixture_style = _normalize_id(p_fixture, &"torch")
	decoration_palette = _normalize_id(p_palette, &"generic")

static func _normalize_id(val: Variant, default_val: StringName) -> StringName:
	if val is StringName:
		return val if not val.is_empty() else default_val
	if val is String:
		var s := (val as String).strip_edges().to_lower()
		return StringName(s) if not s.is_empty() else default_val
	return default_val

func to_debug_string() -> String:
	return "ArchProfile(Floor: %s, Wall: %s, Door: %s, Stairs: %s, Fixture: %s, Palette: %s)" % [
		str(floor_style),
		str(wall_style),
		str(door_style),
		str(stairs_style),
		str(fixture_style),
		str(decoration_palette)
	]

func to_dict() -> Dictionary:
	return {
		"floor_style": str(floor_style),
		"floor_name": str(floor_style).to_upper(),
		"wall_style": str(wall_style),
		"wall_name": str(wall_style).to_upper(),
		"door_style": str(door_style),
		"door_name": str(door_style).to_upper(),
		"stairs_style": str(stairs_style),
		"stairs_name": str(stairs_style).to_upper(),
		"fixture_style": str(fixture_style),
		"fixture_name": str(fixture_style).to_upper(),
		"decoration_palette": str(decoration_palette),
		"palette_name": str(decoration_palette).to_upper()
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
