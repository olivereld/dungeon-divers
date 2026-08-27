class_name ProfileLighting
extends RefCounted

## Configuración, presupuesto y defaults de iluminación de una sala.

const _ProfileLightingSlotScript = preload("res://src/dungeon_generator/profiles/profile_lighting_slot.gd")
const _ProfileLightSettingsScript = preload("res://src/dungeon_generator/profiles/profile_light_settings.gd")

var budget: float = 4.0
var defaults: _ProfileLightSettingsScript = null
var wall: _ProfileLightingSlotScript = null
var floor: _ProfileLightingSlotScript = null
var hanging: _ProfileLightingSlotScript = null

func _init(
	p_budget: float = 4.0,
	p_defaults: _ProfileLightSettingsScript = null,
	p_wall: _ProfileLightingSlotScript = null,
	p_floor: _ProfileLightingSlotScript = null,
	p_hanging: _ProfileLightingSlotScript = null
) -> void:
	budget = p_budget
	defaults = p_defaults if p_defaults != null else _ProfileLightSettingsScript.new()
	wall = p_wall if p_wall != null else _ProfileLightingSlotScript.new()
	floor = p_floor if p_floor != null else _ProfileLightingSlotScript.new()
	hanging = p_hanging if p_hanging != null else _ProfileLightingSlotScript.new()

func get_all_allowed_fixture_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	if wall != null:
		for fid in wall.allowed:
			if not result.has(fid):
				result.append(fid)
	if floor != null:
		for fid in floor.allowed:
			if not result.has(fid):
				result.append(fid)
	if hanging != null:
		for fid in hanging.allowed:
			if not result.has(fid):
				result.append(fid)
	return result

## Resuelve los settings efectivos para un fixture según la jerarquía:
## 1. Asset override -> 2. Slot override -> 3. Room defaults -> 4. Fallback (Style)
func resolve_settings_for_fixture(
	mode_name: StringName,
	asset_id: StringName,
	style_color: Color = Color.WHITE,
	style_energy: float = 1.0,
	style_range: float = 4.0
) -> _ProfileLightSettingsScript:
	var slot: _ProfileLightingSlotScript = null
	match str(mode_name).to_lower():
		"wall":
			slot = wall
		"floor":
			slot = floor
		"hanging":
			slot = hanging

	var resolved_color := style_color
	var resolved_energy := style_energy
	var resolved_range := style_range

	# 3. Room defaults
	if defaults != null:
		if defaults.has_color():
			resolved_color = defaults.color
		if defaults.has_energy():
			resolved_energy = defaults.energy
		if defaults.has_range():
			resolved_range = defaults.light_range

	# 2. Slot override
	if slot != null and slot.lighting_override != null:
		if slot.lighting_override.has_color():
			resolved_color = slot.lighting_override.color
		if slot.lighting_override.has_energy():
			resolved_energy = slot.lighting_override.energy
		if slot.lighting_override.has_range():
			resolved_range = slot.lighting_override.light_range

	# 1. Asset override
	if slot != null and slot.asset_overrides.has(asset_id):
		var a_ov: _ProfileLightSettingsScript = slot.asset_overrides[asset_id]
		if a_ov != null:
			if a_ov.has_color():
				resolved_color = a_ov.color
			if a_ov.has_energy():
				resolved_energy = a_ov.energy
			if a_ov.has_range():
				resolved_range = a_ov.light_range

	return _ProfileLightSettingsScript.new(resolved_color, resolved_energy, resolved_range)
