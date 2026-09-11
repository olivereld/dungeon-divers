class_name HydrologyValidation
extends RefCounted

## Validador formal estructural para la red hidrológica y ríos.
## Verifica las garantías topológicas, hidrológicas y contratos de lagos.

static func validate(result: WorldResult, profile: WorldProfile = null) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	if result == null:
		return {"valid": false, "errors": ["WorldResult is null"], "warnings": [], "metrics": {}}

	var hydro: HydrologyResult = result.hydrology
	if hydro == null:
		return {"valid": false, "errors": ["HydrologyResult is null"], "warnings": [], "metrics": {}}

	var network = hydro.get_river_network()
	if network == null and hydro.rivers.is_empty():
		return {
			"valid": true,
			"errors": [],
			"warnings": ["No rivers generated in HydrologyResult"],
			"metrics": {"river_count": 0, "confluence_count": 0, "lake_count": hydro.lakes.size()}
		}

	var rivers: Array = []
	var sources: Array = []
	var confluences: Array = []
	var lakes: Array = hydro.lakes
	var outlets: Array = []

	if network is RiverNetwork:
		rivers = network.rivers
		sources = network.sources
		confluences = network.confluences
		outlets = network.outlets
	elif network is Dictionary:
		rivers = network.get("rivers", [])
		sources = network.get("sources", [])
		confluences = network.get("confluences", [])
		outlets = network.get("outlets", [])
	else:
		rivers = hydro.rivers
		confluences = hydro.confluences

	var flow_to: Dictionary = hydro.get_debug_value("flow_to", Vector2i(-999, -999), {})
	if flow_to.is_empty() and hydro.debug_layers.has("flow_to"):
		flow_to = hydro.debug_layers["flow_to"]

	var dims: Vector2i = result.dimensions
	var river_ids: Dictionary = {}
	var rivers_by_id: Dictionary = {}
	var max_strahler: int = 1
	var total_length: float = 0.0
	var monotonic_elevation_failures: int = 0
	var dead_end_failures: int = 0
	var cycle_detected: bool = false

	# Indexar ríos y validar IDs únicos
	for r in rivers:
		var r_id: int = r.id if (r is River or "id" in r) else r.get("index", -1)
		if river_ids.has(r_id):
			errors.append("Duplicate river ID: %d" % r_id)
		river_ids[r_id] = true
		rivers_by_id[r_id] = r

	# Validar cada río
	for r in rivers:
		var r_id: int = r.id if (r is River or "id" in r) else r.get("index", -1)
		var r_path: Array = r.path if (r is River or "path" in r) else r.get("cells", [])
		var r_source: Vector2i = r.source if (r is River or "source" in r) else (r_path[0] if not r_path.is_empty() else Vector2i(-1, -1))
		var r_order: int = r.order if (r is River or "order" in r) else r.get("order", 1)
		var r_acc_start: float = r.accumulation_start if (r is River or "accumulation_start" in r) else r.get("accumulation_start", 1.0)
		var r_acc_end: float = r.accumulation_end if (r is River or "accumulation_end" in r) else r.get("accumulation_end", 1.0)
		var r_downstream: int = r.downstream_river if (r is River or "downstream_river" in r) else r.get("downstream_river", -1)
		var r_upstream: Array = r.upstream_rivers if (r is River or "upstream_rivers" in r) else r.get("upstream_rivers", [])
		var r_pts: Array = r.points if (r is River or "points" in r) else r.get("points", [])
		var r_widths: Array = r.widths if (r is River or "widths" in r) else r.get("widths", [])
		var r_depths: Array = r.depths if (r is River or "depths" in r) else r.get("depths", [])
		var r_is_outflow: bool = r.is_outflow if (r is River or "is_outflow" in r) else r.get("is_outflow", false)

		if r_order > max_strahler:
			max_strahler = r_order
		total_length += float(r_path.size())

		# 1. Longitud mínima
		if r_path.size() < 2:
			errors.append("River %d has length < 2 (size: %d)" % [r_id, r_path.size()])
			continue

		# 2. Source in Path
		if r_path[0] != r_source:
			errors.append("River %d source mismatch: source is %s, path[0] is %s" % [r_id, str(r_source), str(r_path[0])])

		# 3. Path cells within bounds
		for pt in r_path:
			if pt.x < 0 or pt.x >= dims.x or pt.y < 0 or pt.y >= dims.y:
				errors.append("River %d cell out of bounds: %s (bounds: %s)" % [r_id, str(pt), str(dims)])
				break

		# 4. Flow Coherence (consecutive cells follow flow_to if available)
		if not flow_to.is_empty():
			for k in range(r_path.size() - 1):
				var curr: Vector2i = r_path[k]
				var next_cell: Vector2i = r_path[k + 1]
				if flow_to.has(curr):
					var target: Vector2i = flow_to[curr]
					# El siguiente debe ser target o debe estar a distancia Chebyshev 1 si hubo salto de lago
					if target != next_cell and not hydro.is_lake(curr) and not hydro.is_lake(next_cell):
						var d: Vector2i = (next_cell - curr).abs()
						if d.x > 1 or d.y > 1:
							errors.append("River %d flow disconnect between %s and %s (flow_to is %s)" % [r_id, str(curr), str(next_cell), str(target)])
							break

		# 5. Monotonic Flow Accumulation
		if r_acc_end < r_acc_start - 0.01:
			warnings.append("River %d accumulation decreases from source (%.1f) to end (%.1f)" % [r_id, r_acc_start, r_acc_end])

		# 6. Monotonic Visual Elevation
		if r_pts.size() >= 2:
			for i in range(r_pts.size() - 1):
				var p0: Vector3 = r_pts[i]
				var p1: Vector3 = r_pts[i + 1]
				if p1.y > p0.y + 0.0005:
					monotonic_elevation_failures += 1
					errors.append("River %d points not monotonic downhill: pts[%d].y=%.4f < pts[%d].y=%.4f" % [r_id, i, p0.y, i + 1, p1.y])
					break

		# 7. Positive Physical Dimensions
		for w in r_widths:
			if w <= 0.0:
				errors.append("River %d contains non-positive width: %f" % [r_id, w])
				break
		for d in r_depths:
			if d <= 0.0:
				errors.append("River %d contains non-positive depth: %f" % [r_id, d])
				break

		# 8. No internal dead ends: terminal node must reach border, lake, or valid confluence
		var term_pos: Vector2i = r_path[-1]
		var is_at_border: bool = (term_pos.x <= 0 or term_pos.x >= dims.x - 1 or term_pos.y <= 0 or term_pos.y >= dims.y - 1)
		var is_at_lake: bool = hydro.is_lake(term_pos)
		var has_confluence: bool = (r_downstream != -1 and rivers_by_id.has(r_downstream))

		if not is_at_border and not is_at_lake and not has_confluence:
			dead_end_failures += 1
			errors.append("River %d has internal dead-end at %s (not at border, not at lake, no downstream river)" % [r_id, str(term_pos)])

		# 9. Acyclic DAG check (follow downstream chain)
		var visited_chain: Dictionary = {r_id: true}
		var curr_down: int = r_downstream
		var step_count: int = 0
		while curr_down != -1 and step_count < 200:
			step_count += 1
			if visited_chain.has(curr_down):
				cycle_detected = true
				errors.append("Cycle detected in river DAG involving river %d and %d" % [r_id, curr_down])
				break
			visited_chain[curr_down] = true
			if rivers_by_id.has(curr_down):
				var next_r = rivers_by_id[curr_down]
				curr_down = next_r.downstream_river if (next_r is River or "downstream_river" in next_r) else next_r.get("downstream_river", -1)
			else:
				break

	# Validar Confluencias
	for conf in confluences:
		var c_pos: Vector2i = conf.get("position", Vector2i(-1, -1))
		var c_upstream: Array = conf.get("upstream_rivers", [])
		var c_downstream: int = conf.get("downstream_river", -1)

		if not rivers_by_id.has(c_downstream):
			errors.append("Confluence at %s references invalid downstream river %d" % [str(c_pos), c_downstream])
		else:
			var down_r = rivers_by_id[c_downstream]
			var down_path: Array = down_r.path if (down_r is River or "path" in down_r) else down_r.get("cells", [])
			if not down_path.has(c_pos):
				warnings.append("Confluence position %s not found directly in downstream river %d path" % [str(c_pos), c_downstream])

		for up_id in c_upstream:
			if not rivers_by_id.has(up_id):
				errors.append("Confluence at %s references invalid upstream river %d" % [str(c_pos), up_id])
			else:
				var up_r = rivers_by_id[up_id]
				var up_path: Array = up_r.path if (up_r is River or "path" in up_r) else up_r.get("cells", [])
				if not up_path.is_empty() and up_path[-1] != c_pos:
					warnings.append("Upstream river %d terminal %s != confluence position %s" % [up_id, str(up_path[-1]), str(c_pos)])

	# Validar Lagos y Emisarios (Spillways)
	for lake in lakes:
		var lake_h: float = lake.get("water_height", 0.0)
		var spillway_pos: Vector2i = lake.get("spillway_pos", Vector2i(-1, -1))
		var spillway_h: float = lake.get("spillway_height", 0.0)

		if spillway_pos != Vector2i(-1, -1):
			if absf(spillway_h - lake_h) > 0.05:
				warnings.append("Lake %s spillway height (%.3f) diverges from lake surface (%.3f)" % [str(lake.get("id", -1)), spillway_h, lake_h])

	var is_valid: bool = errors.is_empty()
	var metrics: Dictionary = {
		"river_count": rivers.size(),
		"confluence_count": confluences.size(),
		"lake_count": lakes.size(),
		"max_strahler_order": max_strahler,
		"total_river_length": total_length,
		"monotonic_elevation_failures": monotonic_elevation_failures,
		"dead_end_failures": dead_end_failures,
		"cycle_detected": cycle_detected
	}

	return {
		"valid": is_valid,
		"errors": errors,
		"warnings": warnings,
		"metrics": metrics
	}
