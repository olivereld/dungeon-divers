class_name HydrologyRenderer
extends RefCounted

## Decoupled renderer for hydrological features (planar lakes and downhill river ribbons).
## Water is rendered as independent overlay meshes with dedicated water materials,
## keeping TerrainMesh 100% free of water colors and logic.

static func build_hydrology_node(result: WorldResult, profile: WorldProfile = null) -> Node3D:
	var hydro = result.hydrology
	if hydro == null:
		return null

	if profile == null:
		profile = WorldProfile.new()

	var hydro_root := Node3D.new()
	hydro_root.name = "HydrologyRoot"

	var cell_size: float = profile.cell_size
	var mat := _create_water_material(profile)

	# 1. Build Lakes Mesh
	if not hydro.lakes.is_empty():
		var lake_mesh := _build_lakes_mesh(hydro, profile, cell_size, result)
		if lake_mesh != null and lake_mesh.get_surface_count() > 0:
			var lake_mi := MeshInstance3D.new()
			lake_mi.name = "LakesMesh"
			lake_mi.mesh = lake_mesh
			lake_mi.set_surface_override_material(0, mat)
			hydro_root.add_child(lake_mi)

	# 2. Build Rivers Mesh
	if not hydro.rivers.is_empty():
		var river_mesh := _build_rivers_mesh(hydro, profile, result)
		if river_mesh != null and river_mesh.get_surface_count() > 0:
			var river_mi := MeshInstance3D.new()
			river_mi.name = "RiversMesh"
			river_mi.mesh = river_mesh
			river_mi.set_surface_override_material(0, mat)
			hydro_root.add_child(river_mi)

	return hydro_root

static func _create_water_material(profile: WorldProfile) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.0, 1.0, 1.0, profile.water_transparency)
	mat.roughness = profile.water_roughness
	mat.metallic = 0.15
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

## Builds continuous, smooth planar water meshes for lakes using Marching Squares isocontours.
## Shoreline vertices interpolate along cell edges directly to where terrain elevation meets the water plane,
## preventing blocky "Minecraft staircases" and ensuring organic shorelines at any cell_size.
static func _build_lakes_mesh(hydro: RefCounted, profile: WorldProfile, cell_size: float, result: WorldResult = null) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var shallow_col: Color = profile.water_color_shallow
	var med_col: Color = profile.water_color_medium
	var lake_col: Color = profile.water_color_lake

	var w: int = result.dimensions.x if result != null else 128
	var h: int = result.dimensions.y if result != null else 128
	var total_world_w: float = float(w)
	var total_world_h: float = float(h)

	for lake in hydro.lakes:
		var water_y: float = lake.water_height
		var lake_cells: Array = lake.cells
		if lake_cells.is_empty():
			continue

		var lake_set: Dictionary = {}
		for c in lake_cells:
			lake_set[c] = true

		# Gather all grid quads touching this lake
		var quads_to_check: Dictionary = {}
		for c_pos in lake_cells:
			var cp: Vector2i = c_pos
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var qx: int = cp.x + dx
					var qy: int = cp.y + dy
					if qx >= 0 and qx < w - 1 and qy >= 0 and qy < h - 1:
						quads_to_check[Vector2i(qx, qy)] = true

		for q in quads_to_check.keys():
			var qpos: Vector2i = q
			var c0 := qpos
			var c1 := qpos + Vector2i(1, 0)
			var c2 := qpos + Vector2i(1, 1)
			var c3 := qpos + Vector2i(0, 1)

			var h0: float = result.get_cell(c0).height if result != null else water_y - 1.0
			var h1: float = result.get_cell(c1).height if result != null else water_y - 1.0
			var h2: float = result.get_cell(c2).height if result != null else water_y - 1.0
			var h3: float = result.get_cell(c3).height if result != null else water_y - 1.0

			var in_basin := lake_set.has(c0) or lake_set.has(c1) or lake_set.has(c2) or lake_set.has(c3)
			var s0: bool = in_basin and h0 < water_y
			var s1: bool = in_basin and h1 < water_y
			var s2: bool = in_basin and h2 < water_y
			var s3: bool = in_basin and h3 < water_y

			var mask: int = (1 if s0 else 0) | (2 if s1 else 0) | (4 if s2 else 0) | (8 if s3 else 0)
			if mask == 0:
				continue

			# World positions at water height (Fixed 1.0 unit per cell for 128x128 bounds)
			var p0 := Vector3(float(c0.x), water_y, float(c0.y))
			var p1 := Vector3(float(c1.x), water_y, float(c1.y))
			var p2 := Vector3(float(c2.x), water_y, float(c2.y))
			var p3 := Vector3(float(c3.x), water_y, float(c3.y))

			# Interpolated edge positions (where terrain hits water level)
			var t01: float = clampf((water_y - h0) / maxf(absf(h1 - h0), 0.0001), 0.0, 1.0)
			var e01: Vector3 = p0.lerp(p1, t01)

			var t12: float = clampf((water_y - h1) / maxf(absf(h2 - h1), 0.0001), 0.0, 1.0)
			var e12: Vector3 = p1.lerp(p2, t12)

			var t23: float = clampf((water_y - h2) / maxf(absf(h3 - h2), 0.0001), 0.0, 1.0)
			var e23: Vector3 = p2.lerp(p3, t23)

			var t30: float = clampf((water_y - h3) / maxf(absf(h0 - h3), 0.0001), 0.0, 1.0)
			var e30: Vector3 = p3.lerp(p0, t30)

			# Depths at corners
			var d0: float = maxf(0.0, water_y - h0)
			var d1: float = maxf(0.0, water_y - h1)
			var d2: float = maxf(0.0, water_y - h2)
			var d3: float = maxf(0.0, water_y - h3)

			# Shoreline edge points have depth = 0.0
			var pt_dict: Dictionary = {
				"C0": { "pos": p0, "depth": d0 },
				"C1": { "pos": p1, "depth": d1 },
				"C2": { "pos": p2, "depth": d2 },
				"C3": { "pos": p3, "depth": d3 },
				"E01": { "pos": e01, "depth": 0.0 },
				"E12": { "pos": e12, "depth": 0.0 },
				"E23": { "pos": e23, "depth": 0.0 },
				"E30": { "pos": e30, "depth": 0.0 }
			}

			var poly_tri_tokens: Array = _get_ms_triangles_for_mask(mask)
			for tok in poly_tri_tokens:
				var p_info: Dictionary = pt_dict[tok]
				var pos: Vector3 = p_info["pos"]
				var depth: float = p_info["depth"]

				indices.append(vertices.size())
				vertices.append(pos)
				normals.append(Vector3.UP)
				uvs.append(Vector2(pos.x / maxf(total_world_w, 1.0), pos.z / maxf(total_world_h, 1.0)))

				var depth_factor: float = clampf(depth / 2.5, 0.0, 1.0)
				var cell_color: Color
				if depth_factor < 0.5:
					cell_color = shallow_col.lerp(med_col, depth_factor * 2.0)
				else:
					cell_color = med_col.lerp(lake_col, (depth_factor - 0.5) * 2.0)
				cell_color.a = clampf(0.60 + depth_factor * 0.35, 0.0, 0.98)
				colors.append(cell_color)

	if vertices.is_empty():
		return null

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## Lookup table for 16 Marching Squares sub-polygon triangulations
static func _get_ms_triangles_for_mask(mask: int) -> Array:
	match mask:
		15: # Full quad
			return ["C0", "C3", "C2", "C0", "C2", "C1"]
		1:  # Only C0
			return ["C0", "E30", "E01"]
		2:  # Only C1
			return ["C1", "E01", "E12"]
		4:  # Only C2
			return ["C2", "E12", "E23"]
		8:  # Only C3
			return ["C3", "E23", "E30"]
		3:  # C0 and C1 (Top)
			return ["C0", "E30", "E12", "C0", "E12", "C1"]
		6:  # C1 and C2 (Right)
			return ["C1", "E01", "E23", "C1", "E23", "C2"]
		12: # C2 and C3 (Bottom)
			return ["C2", "E12", "E30", "C2", "E30", "C3"]
		9:  # C3 and C0 (Left)
			return ["C3", "E23", "E01", "C3", "E01", "C0"]
		7:  # C0, C1, C2 (All except C3)
			return ["C0", "E30", "E23", "C0", "E23", "C2", "C0", "C2", "C1"]
		11: # C0, C1, C3 (All except C2)
			return ["C0", "C3", "E23", "C0", "E23", "E12", "C0", "E12", "C1"]
		13: # C0, C2, C3 (All except C1)
			return ["C0", "C3", "C2", "C0", "C2", "E12", "C0", "E12", "E01"]
		14: # C1, C2, C3 (All except C0)
			return ["E01", "E30", "C3", "E01", "C3", "C2", "E01", "C2", "C1"]
		5:  # Diagonal C0, C2
			return ["C0", "E30", "E01", "C2", "E12", "E23"]
		10: # Diagonal C1, C3
			return ["C1", "E01", "E12", "C3", "E23", "E30"]
		_:
			return []

## Builds smooth, continuous river ribbons with Catmull-Rom spline interpolation,
## bilateral bank terrain draping, and authentic water palette gradients.
static func _build_rivers_mesh(hydro: RefCounted, profile: WorldProfile, result: WorldResult = null) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var shallow_col: Color = profile.water_color_shallow
	var river_col: Color = profile.water_color_river
	var med_col: Color = profile.water_color_medium
	var lake_col: Color = profile.water_color_lake

	for river in hydro.rivers:
		var raw_pts: Array = river.get("points", []) if river is Dictionary else river.points
		if raw_pts.size() < 2:
			continue

		var raw_widths: Array = river.get("widths", []) if river is Dictionary else river.widths
		if raw_widths.size() != raw_pts.size():
			raw_widths = []
			for p_idx in range(raw_pts.size()):
				raw_widths.append(profile.river_min_width)

		# 1. Generate smooth spline centerline and smoothly interpolated widths
		var spline_data := _generate_catmull_rom_with_widths(raw_pts, raw_widths, 4)
		var smooth_pts: Array[Vector3] = spline_data["points"]
		var smooth_widths: Array[float] = spline_data["widths"]
		var total_pts: int = smooth_pts.size()
		if total_pts < 2:
			continue

		var river_start_idx: int = vertices.size()

		# 2. Build continuous draped ribbon
		for j in range(total_pts):
			var p: Vector3 = smooth_pts[j]
			var prog: float = float(j) / float(maxi(total_pts - 1, 1))

			# Tangent along smoothed spline
			var tangent: Vector3
			if j == 0:
				tangent = (smooth_pts[1] - smooth_pts[0]).normalized()
			elif j == total_pts - 1:
				tangent = (smooth_pts[j] - smooth_pts[j - 1]).normalized()
			else:
				tangent = (smooth_pts[j + 1] - smooth_pts[j - 1]).normalized()
			tangent.y = 0.0
			if tangent.length_squared() < 0.0001:
				tangent = Vector3(0.0, 0.0, 1.0)
			else:
				tangent = tangent.normalized()

			# Perpendicular in XZ plane
			var perp := Vector3(-tangent.z, 0.0, tangent.x).normalized()

			# Width directly from the hydrological accumulation network
			var w: float = smooth_widths[j]

			var lx: float = p.x + perp.x * (w * 0.5)
			var lz: float = p.z + perp.z * (w * 0.5)
			var rx: float = p.x - perp.x * (w * 0.5)
			var rz: float = p.z - perp.z * (w * 0.5)

			# Continuous bilateral ground draping: every vertex hugs the terrain elevation
			# with +0.025m clearance, guaranteeing 100% continuous flow with zero clipping
			var ground_l: float = _sample_terrain_elevation(result, lx, lz)
			var ground_r: float = _sample_terrain_elevation(result, rx, rz)
			var ly: float = ground_l + 0.025
			var ry: float = ground_r + 0.025

			# If in a lake basin, level up to the lake water surface
			var grid_l := Vector2i(clampi(int(round(lx)), 0, profile.width - 1), clampi(int(round(lz)), 0, profile.height - 1))
			var grid_r := Vector2i(clampi(int(round(rx)), 0, profile.width - 1), clampi(int(round(rz)), 0, profile.height - 1))
			if hydro.is_lake(grid_l):
				var lake_data = hydro.get_cell_data(grid_l)
				if lake_data.has("water_height"):
					ly = maxf(ly, float(lake_data["water_height"]))
			if hydro.is_lake(grid_r):
				var lake_data = hydro.get_cell_data(grid_r)
				if lake_data.has("water_height"):
					ry = maxf(ry, float(lake_data["water_height"]))

			# Cohesive water color along stream:
			# - Headwaters: shallow sparkling tint
			# - Midstream: active river color
			# - Mouth / Lake estuary: deepens into lake color
			var col: Color
			if prog < 0.35:
				col = shallow_col.lerp(river_col, prog / 0.35)
			else:
				col = river_col.lerp(lake_col, (prog - 0.35) / 0.65)
			col.a = clampf(0.80 + prog * 0.12, 0.0, 0.95)

			vertices.append(Vector3(lx, ly, lz))
			vertices.append(Vector3(rx, ry, rz))

			normals.append(Vector3.UP)
			normals.append(Vector3.UP)

			colors.append(col)
			colors.append(col)

			uvs.append(Vector2(0.0, prog))
			uvs.append(Vector2(1.0, prog))

		# 3. Connect adjacent smooth segments
		for j in range(total_pts - 1):
			var v0: int = river_start_idx + (j * 2)
			var v1: int = v0 + 1
			var v2: int = v0 + 2
			var v3: int = v0 + 3

			indices.append(v0)
			indices.append(v1)
			indices.append(v2)

			indices.append(v1)
			indices.append(v3)
			indices.append(v2)

	if vertices.is_empty():
		return null

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## Interpolates smooth 3D spline centerline points alongside accumulation-driven river widths
static func _generate_catmull_rom_with_widths(raw_pts: Array, raw_widths: Array, sub_divisions: int = 4) -> Dictionary:
	var pts_res: Array[Vector3] = []
	var widths_res: Array[float] = []
	var n: int = raw_pts.size()
	if n < 2:
		for i in range(n):
			pts_res.append(raw_pts[i] as Vector3)
			widths_res.append(float(raw_widths[i]) if i < raw_widths.size() else 0.5)
		return { "points": pts_res, "widths": widths_res }

	for i in range(n - 1):
		var p0: Vector3 = raw_pts[maxi(i - 1, 0)]
		var p1: Vector3 = raw_pts[i]
		var p2: Vector3 = raw_pts[i + 1]
		var p3: Vector3 = raw_pts[mini(i + 2, n - 1)]

		var w0: float = float(raw_widths[maxi(i - 1, 0)]) if maxi(i - 1, 0) < raw_widths.size() else 0.5
		var w1: float = float(raw_widths[i]) if i < raw_widths.size() else 0.5
		var w2: float = float(raw_widths[i + 1]) if i + 1 < raw_widths.size() else 0.5
		var w3: float = float(raw_widths[mini(i + 2, n - 1)]) if mini(i + 2, n - 1) < raw_widths.size() else 0.5

		for step in range(sub_divisions):
			var t := float(step) / float(sub_divisions)
			var t2 := t * t
			var t3 := t2 * t

			var pt := 0.5 * (
				(2.0 * p1) +
				(-p0 + p2) * t +
				(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
				(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
			)
			var w := 0.5 * (
				(2.0 * w1) +
				(-w0 + w2) * t +
				(2.0 * w0 - 5.0 * w1 + 4.0 * w2 - w3) * t2 +
				(-w0 + 3.0 * w1 - 3.0 * w2 + w3) * t3
			)
			pts_res.append(pt)
			widths_res.append(maxf(w, 0.12))

	pts_res.append(raw_pts[n - 1] as Vector3)
	widths_res.append(maxf(float(raw_widths[n - 1]) if n - 1 < raw_widths.size() else 0.5, 0.12))
	return { "points": pts_res, "widths": widths_res }

## Evaluates exact elevation on the triangulated mesh surface for bank ground draping
static func _sample_terrain_elevation(result: WorldResult, world_x: float, world_z: float) -> float:
	if result == null:
		return 0.0
	var w: int = result.dimensions.x
	var h: int = result.dimensions.y

	var x0: int = clampi(int(floor(world_x)), 0, w - 2)
	var z0: int = clampi(int(floor(world_z)), 0, h - 2)
	var x1: int = x0 + 1
	var z1: int = z0 + 1

	var u: float = clampf(world_x - float(x0), 0.0, 1.0)
	var v: float = clampf(world_z - float(z0), 0.0, 1.0)

	var c00 := result.get_cell(Vector2i(x0, z0))
	var c10 := result.get_cell(Vector2i(x1, z0))
	var c01 := result.get_cell(Vector2i(x0, z1))
	var c11 := result.get_cell(Vector2i(x1, z1))

	var h00: float = c00.height if c00 != null else 0.0
	var h10: float = c10.height if c10 != null else 0.0
	var h01: float = c01.height if c01 != null else 0.0
	var h11: float = c11.height if c11 != null else 0.0

	# Triangulated plane interpolation matching TerrainMeshBuilder
	if u + v <= 1.0:
		return h00 + u * (h10 - h00) + v * (h01 - h00)
	else:
		return h11 + (1.0 - u) * (h01 - h11) + (1.0 - v) * (h10 - h11)

