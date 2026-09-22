extends SceneTree

func _init() -> void:
	var pipeline := WorldPipeline.new()
	var profile := TaigaWorldProfile.new()
	profile.width = 128
	profile.height = 128
	var res: WorldResult = pipeline.generate(12345, profile)
	var spawn_pos := Vector2i(int(round(res.spawn_position.x)), int(round(res.spawn_position.z)))
	var spawn_c: WorldCell = res.get_cell(spawn_pos)
	var total_walkable := 0
	var level_counts := {}
	for p in res.cells:
		var c: WorldCell = res.cells[p]
		if c.is_walkable:
			total_walkable += 1
			level_counts[c.elevation_level] = level_counts.get(c.elevation_level, 0) + 1
	
	# BFS on same level
	var visited := {}
	var q: Array[Vector2i] = [spawn_pos]
	visited[spawn_pos] = true
	var reached := 0
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		var cur_c: WorldCell = res.cells[cur]
		reached += 1
		for o in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n: Vector2i = cur + o
			if not visited.has(n) and res.cells.has(n):
				var nc: WorldCell = res.cells[n]
				if nc.is_walkable and nc.elevation_level == cur_c.elevation_level:
					visited[n] = true
					q.append(n)
	print("128x128 Seed 12345: total_walkable=%d, spawn_level=%d, spawn_plateau_reach=%d (%.1f%% of total walkable, %.1f%% of its level: %d)" % [
		total_walkable, spawn_c.elevation_level, reached,
		float(reached)/float(total_walkable)*100.0,
		float(reached)/float(level_counts.get(spawn_c.elevation_level, 1))*100.0,
		level_counts.get(spawn_c.elevation_level, 1)
	])
	quit()
