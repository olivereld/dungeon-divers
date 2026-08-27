class_name ProfileRoomArchitecture
extends RefCounted

## Configuración arquitectónica de la sala deserializada desde el bloque "architecture" en rooms/*.json.

const _ProfileWallVariantPolicyScript = preload("res://src/dungeon_generator/profiles/profile_wall_variant_policy.gd")
const _ProfileFloorVariantPolicyScript = preload("res://src/dungeon_generator/profiles/profile_floor_variant_policy.gd")

var floor: StringName = &""
var walls: StringName = &""
var door: StringName = &""
var stairs: StringName = &""
var wall_variants: _ProfileWallVariantPolicyScript = null
var floor_variants: _ProfileFloorVariantPolicyScript = null

func _init(
	p_floor: StringName = &"",
	p_walls: StringName = &"",
	p_door: StringName = &"",
	p_stairs: StringName = &"",
	p_wall_variants: _ProfileWallVariantPolicyScript = null,
	p_floor_variants: _ProfileFloorVariantPolicyScript = null
) -> void:
	floor = p_floor
	walls = p_walls
	door = p_door
	stairs = p_stairs
	wall_variants = p_wall_variants if p_wall_variants != null else _ProfileWallVariantPolicyScript.new()
	floor_variants = p_floor_variants if p_floor_variants != null else _ProfileFloorVariantPolicyScript.new()
