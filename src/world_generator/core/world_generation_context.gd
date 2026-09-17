class_name WorldGenerationContext
extends RefCounted

var master_seed: int
var profile: WorldProfile
var result: WorldResult

func _init(p_seed: int = 0, p_profile: WorldProfile = null, p_preallocate: bool = true) -> void:
	master_seed = p_seed
	profile = p_profile
	result = WorldResult.new()
	result.master_seed = p_seed
	if profile != null:
		result.dimensions = Vector2i(profile.width, profile.height)
		if p_preallocate:
			for y in range(profile.height):
				for x in range(profile.width):
					var pos := Vector2i(x, y)
					result.cells[pos] = WorldCell.new(pos)

func get_cell(pos: Vector2i) -> WorldCell:
	return result.get_cell(pos)

func has_cell(pos: Vector2i) -> bool:
	return result.has_cell(pos)

func get_core_bounds() -> Rect2i:
	return Rect2i(0, 0, profile.width, profile.height)

func get_generation_bounds() -> Rect2i:
	return Rect2i(0, 0, profile.width, profile.height)

func is_chunk_context() -> bool:
	return false
