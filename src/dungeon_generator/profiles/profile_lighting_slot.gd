class_name ProfileLightingSlot
extends RefCounted

## Ranura de iluminación (wall, floor, hanging).

const _ProfileLightSettingsScript = preload("res://src/dungeon_generator/profiles/profile_light_settings.gd")

var min_count: int = 0
var max_count: int = 0
var allowed: Array[StringName] = []
var lighting_override: _ProfileLightSettingsScript = null
var asset_overrides: Dictionary = {} # StringName -> ProfileLightSettings

func _init(
	p_min: int = 0,
	p_max: int = 0,
	p_allowed: Array[StringName] = [],
	p_override: _ProfileLightSettingsScript = null,
	p_asset_overrides: Dictionary = {}
) -> void:
	min_count = p_min
	max_count = p_max
	allowed = p_allowed
	lighting_override = p_override
	asset_overrides = p_asset_overrides

func get_override_for_asset(asset_id: StringName) -> _ProfileLightSettingsScript:
	if asset_overrides.has(asset_id):
		return asset_overrides[asset_id]
	return lighting_override
