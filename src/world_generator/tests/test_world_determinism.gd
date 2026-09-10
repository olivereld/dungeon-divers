extends SceneTree

func _init() -> void:
	var prof := TaigaWorldProfile.new()
	var res1 := WorldPipeline.generate(42, prof)
	var res2 := WorldPipeline.generate(42, prof)

	assert(res1.cells.size() == res2.cells.size())
	assert(res1.vegetation.size() == res2.vegetation.size())
	assert(res1.spawn_position == res2.spawn_position)

	for pos in res1.cells.keys():
		var c1: WorldCell = res1.cells[pos]
		var c2: WorldCell = res2.cells[pos]
		assert(c1.height == c2.height, "Height mismatch at %s" % str(pos))
		assert(c1.slope == c2.slope, "Slope mismatch at %s" % str(pos))
		assert(c1.forest_density == c2.forest_density, "Forest density mismatch at %s" % str(pos))
		assert(c1.is_walkable == c2.is_walkable, "Walkable mismatch at %s" % str(pos))

	print("test_world_determinism: OK")
	quit()
