class_name ProfileLighting
extends RefCounted

## Configuración y presupuesto de iluminación de una sala.

const _ProfileLightingSlotScript = preload("res://src/dungeon_generator/profiles/profile_lighting_slot.gd")

var budget: float = 4.0
var wall: _ProfileLightingSlotScript = null
var floor: _ProfileLightingSlotScript = null
var hanging: _ProfileLightingSlotScript = null

func _init(
	p_budget: float = 4.0,
	p_wall: _ProfileLightingSlotScript = null,
	p_floor: _ProfileLightingSlotScript = null,
	p_hanging: _ProfileLightingSlotScript = null
) -> void:
	budget = p_budget
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
