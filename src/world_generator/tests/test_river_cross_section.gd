extends SceneTree

const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("==================================================")
	print(" Running River Cross-Section Verification (Bloque 4)")
	print("==================================================")

	var profile = _TaigaWorldProfileScript.new()
	profile.width = 128
	profile.height = 128
	profile.hydrology_enabled = true
	profile.lake_threshold = 0.25
	profile.max_rivers = 2

	var result = _WorldPipelineScript.generate(4242, profile)
	assert(result != null and result.hydrology != null)

	var hydro = result.hydrology
	assert(not hydro.rivers.is_empty(), "Must have generated rivers")

	var river: Dictionary = hydro.rivers[0]
	var pts: Array = river.get("points", [])
	var widths: Array = river.get("widths", [])
	assert(pts.size() >= 10, "River must have points")

	# Tomar un segmento en la mitad del río
	var mid_idx: int = pts.size() / 2
	var p0: Vector3 = pts[mid_idx]
	var p1: Vector3 = pts[mid_idx + 1]
	var river_w: float = widths[mid_idx]

	var tangent := Vector2(p1.x - p0.x, p1.z - p0.z).normalized()
	var perp := Vector2(-tangent.y, tangent.x)
	var center_2d := Vector2(p0.x, p0.z)

	print(" River ID %d, segment %d -> %d, width: %.2f" % [river.get("id", 0), mid_idx, mid_idx + 1, river_w])

	# Muestrear sección transversal perpendicular al río a través del canal y taludes
	var cross_section_samples: Array[Dictionary] = []
	var span: float = maxf(river_w * 1.5, 4.0)
	var steps: int = 31

	var heights: Array[float] = []
	var distances: Array[float] = []

	for s in range(steps):
		var t_dist: float = lerpf(-span, span, float(s) / float(steps - 1))
		var sample_world: Vector2 = center_2d + perp * t_dist
		var cx: int = clampi(int(round(sample_world.x / profile.cell_size)), 0, profile.width - 1)
		var cy: int = clampi(int(round(sample_world.y / profile.cell_size)), 0, profile.height - 1)
		var cell = result.get_cell(Vector2i(cx, cy))
		if cell != null:
			heights.append(cell.height)
			distances.append(t_dist)

	# 1. Comprobar que no existen saltos verticales abruptos (paredes verticales)
	var max_step_h: float = 0.0
	for i in range(1, heights.size()):
		var dh: float = absf(heights[i] - heights[i - 1])
		if dh > max_step_h:
			max_step_h = dh

	print(" Maximum height step between adjacent samples: %.3f m" % max_step_h)
	assert(max_step_h < 1.5, "No vertical cliff jumps allowed in carved river cross-section!")

	# 2. Comprobar que el lecho central está excavado por debajo del terreno exterior
	var center_idx: int = steps / 2
	var center_h: float = heights[center_idx]
	var left_crest_h: float = heights[0]
	var right_crest_h: float = heights[-1]

	print(" Center (bed) height: %.3f m" % center_h)
	print(" Left bank height:   %.3f m" % left_crest_h)
	print(" Right bank height:  %.3f m" % right_crest_h)

	var center_cell = result.get_cell(Vector2i(int(round(center_2d.x)), int(round(center_2d.y))))
	var center_raw: float = center_cell.raw_height if center_cell != null else center_h + 1.0
	assert(center_h < center_raw - 0.15, "River center bed must be carved below natural ground")
	assert(center_h < maxf(left_crest_h, right_crest_h), "River center bed must be deeper than surrounding terrain crests")

	# 3. Representación ASCII de la sección transversal
	print("\n ASCII Cross-Section Profile (left -> center -> right):")
	var min_h: float = center_h
	var max_h: float = maxf(left_crest_h, right_crest_h)
	var h_range: float = maxf(max_h - min_h, 0.1)

	var rows: int = 8
	for r in range(rows, -1, -1):
		var target_level: float = min_h + (float(r) / float(rows)) * h_range
		var line: String = "%5.2fm |" % target_level
		for i in range(heights.size()):
			var h_norm: float = (heights[i] - min_h) / h_range
			var r_norm: float = float(r) / float(rows)
			if absf(h_norm - r_norm) < (0.5 / float(rows)):
				line += "*"
			elif h_norm > r_norm:
				line += " "
			else:
				line += " "
		print(line)

	var axis_line: String = "       +" + "-".repeat(heights.size())
	print(axis_line)
	print("        -%.0fm               Center (0m)              +%.0fm" % [span, span])

	print("\n==================================================")
	print(" RIVER CROSS-SECTION VERIFICATION: PASSED!")
	print("==================================================")
	quit(0)
