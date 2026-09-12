extends SceneTree

const _TaigaWorldProfile = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipeline = preload("res://src/world_generator/facade/world_pipeline.gd")
const _JunctionValidator = preload("res://src/world_generator/validation/junction_validator.gd")
const _RiverMeshBuilder = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _RiverNetwork = preload("res://src/world_generator/hydrology/river_network.gd")

func advance_along_polyline(pts: Array, start_idx: int, dist: float) -> Dictionary:
	var curr_idx = start_idx
	var rem_dist = dist
	while curr_idx < pts.size() - 1:
		var p0: Vector3 = pts[curr_idx]
		var p1: Vector3 = pts[curr_idx + 1]
		var d: float = p0.distance_to(p1)
		if rem_dist <= d or curr_idx == pts.size() - 2:
			var t = clampf(rem_dist / maxf(d, 0.001), 0.0, 1.0)
			var pos = p0.lerp(p1, t)
			var dir = (p1 - p0).normalized()
			return {"pos": pos, "dir": dir, "idx": curr_idx}
		rem_dist -= d
		curr_idx += 1
	var last_p: Vector3 = pts[-1]
	var prev_p: Vector3 = pts[-2]
	return {"pos": last_p, "dir": (last_p - prev_p).normalized(), "idx": pts.size() - 1}

func _init() -> void:
	var profile = _TaigaWorldProfile.new()
	profile.width = 64
	profile.height = 64
	profile.hydrology_enabled = true

	var result = _WorldPipeline.generate(777, profile)
	var hydro = result.hydrology
	var network = hydro.get_river_network()
	var confs: Array = hydro.confluences

	for conf in confs:
		var c_pos = conf["position"]
		var conf_world = Vector3(c_pos.x + 0.5, 0.0, c_pos.y + 0.5)
		var down_river = network.get_river(conf["downstream_river"])
		var u_river = network.get_river(conf["upstream_rivers"][0])
		var u_st = _RiverMeshBuilder._get_river_boundary_station(u_river, false, 1.0, result)

		var best_idx = 0
		var best_d2 = INF
		for j in range(down_river.points.size()):
			var d2 = Vector2(down_river.points[j].x - conf_world.x, down_river.points[j].z - conf_world.z).length_squared()
			if d2 < best_d2:
				best_d2 = d2
				best_idx = j

		print("==========================================")
		print("CONF: ", c_pos)
		for test_trim in [1.5, 2.0, 2.5, 3.0, 3.5, 4.0]:
			var adv = advance_along_polyline(down_river.points, best_idx, test_trim)
			var d_center: Vector3 = adv["pos"]
			var d_dir: Vector3 = adv["dir"]
			d_dir.y = 0.0
			d_dir = d_dir.normalized()
			var d_norm = Vector3(-d_dir.z, 0.0, d_dir.x).normalized()
			var d_w = 4.8
			var d_hw = d_w * 0.5
			var d_l = d_center + d_norm * d_hw
			var d_r = d_center - d_norm * d_hw

			var m_steps = 3
			var all_ok = true
			for m in range(m_steps):
				var tm0 = float(m) / float(m_steps)
				var tm1 = float(m + 1) / float(m_steps)
				var q_l0 = u_st.left.lerp(d_l, tm0)
				var q_r0 = u_st.right.lerp(d_r, tm0)
				var q_l1 = u_st.left.lerp(d_l, tm1)
				var q_r1 = u_st.right.lerp(d_r, tm1)

				var val = _JunctionValidator.validate_quad(q_l0, q_r0, q_l1, q_r1)
				if not val["valid"]:
					all_ok = false
					break
			print("  Trim %.1f: all_valid=%s" % [test_trim, all_ok])
	quit(0)
