extends SceneTree

func _init() -> void:
	var pipeline := WorldPipeline.new()
	var profile := TaigaWorldProfile.new()
	var result: WorldResult = pipeline.generate(12345, profile)

	var height_diff_same_level := 0
	var height_diff_with_water := 0
	var height_diff_dry := 0

	var hydro = result.hydrology

	for pos in result.cells:
		var c: WorldCell = result.cells[pos]
		var neighbors := [pos + Vector2i(1, 0), pos + Vector2i(0, 1)]
		for n_pos in neighbors:
			if result.cells.has(n_pos):
				var nc: WorldCell = result.cells[n_pos]
				if c.elevation_level == nc.elevation_level:
					if not is_equal_approx(c.height, nc.height):
						height_diff_same_level += 1
						var is_w: bool = false
						if hydro != null and hydro.has_method("is_water"):
							is_w = hydro.is_water(pos) or hydro.is_water(n_pos)
						if is_w:
							height_diff_with_water += 1
						else:
							height_diff_dry += 1

	print("Total edges where level_a == level_b but height_a != height_b: %d (water: %d, dry: %d)" % [
		height_diff_same_level, height_diff_with_water, height_diff_dry
	])
	quit()
