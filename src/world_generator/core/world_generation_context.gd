class_name WorldGenerationContext
extends RefCounted

var master_seed: int
var profile: WorldProfile
var result: WorldResult

func _init(p_seed: int, p_profile: WorldProfile) -> void:
	master_seed = p_seed
	profile = p_profile
	result = WorldResult.new()
	result.master_seed = p_seed
	result.dimensions = Vector2i(p_profile.width, p_profile.height)
	for y in range(p_profile.height):
		for x in range(p_profile.width):
			var pos := Vector2i(x, y)
			result.cells[pos] = WorldCell.new(pos)
