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
		var lake_mesh := _build_lakes_mesh(hydro, profile, cell_size)
		if lake_mesh != null and lake_mesh.get_surface_count() > 0:
			var lake_mi := MeshInstance3D.new()
			lake_mi.name = "LakesMesh"
			lake_mi.mesh = lake_mesh
			lake_mi.set_surface_override_material(0, mat)
			hydro_root.add_child(lake_mi)

	# 2. Build Rivers Mesh
	if not hydro.rivers.is_empty():
		var river_mesh := _build_rivers_mesh(hydro, profile)
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
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.88)
	mat.roughness = profile.water_roughness
	mat.metallic = 0.15
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

static func _build_lakes_mesh(hydro: RefCounted, profile: WorldProfile, cell_size: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var shallow_col: Color = profile.water_color_shallow
	var deep_col: Color = profile.water_color_deep

	for lake in hydro.lakes:
		var water_y: float = lake.water_height
		var lake_cells: Array = lake.cells

		for cell_pos in lake_cells:
			var c_pos: Vector2i = cell_pos
			var c_data: Dictionary = hydro.get_cell_data(c_pos)
			var depth: float = c_data.get("depth", 0.5)
			var depth_factor: float = clampf(depth / 2.5, 0.0, 1.0)
			var cell_color: Color = shallow_col.lerp(deep_col, depth_factor)
			cell_color.a = clampf(0.70 + depth_factor * 0.25, 0.0, 0.95)

			var x0: float = float(c_pos.x) * cell_size
			var z0: float = float(c_pos.y) * cell_size
			var x1: float = x0 + cell_size
			var z1: float = z0 + cell_size

			var base_idx: int = vertices.size()

			# 4 quad corners at planar lake water height
			vertices.append(Vector3(x0, water_y, z0))
			vertices.append(Vector3(x1, water_y, z0))
			vertices.append(Vector3(x0, water_y, z1))
			vertices.append(Vector3(x1, water_y, z1))

			for i in range(4):
				normals.append(Vector3.UP)
				colors.append(cell_color)

			uvs.append(Vector2(0.0, 0.0))
			uvs.append(Vector2(1.0, 0.0))
			uvs.append(Vector2(0.0, 1.0))
			uvs.append(Vector2(1.0, 1.0))

			# 2 triangles per quad
			indices.append(base_idx + 0)
			indices.append(base_idx + 1)
			indices.append(base_idx + 2)

			indices.append(base_idx + 1)
			indices.append(base_idx + 3)
			indices.append(base_idx + 2)

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

static func _build_rivers_mesh(hydro: RefCounted, profile: WorldProfile) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var shallow_col: Color = profile.water_color_shallow
	var deep_col: Color = profile.water_color_deep

	for river in hydro.rivers:
		var pts: Array = river.points
		var widths: Array = river.widths
		if pts.size() < 2:
			continue

		var river_start_idx: int = vertices.size()

		for i in range(pts.size()):
			var p: Vector3 = pts[i]
			var w: float = widths[i] if i < widths.size() else 1.0

			# Tangent calculation
			var tangent: Vector3
			if i == 0:
				tangent = (pts[1] - pts[0]).normalized()
			elif i == pts.size() - 1:
				tangent = (pts[i] - pts[i - 1]).normalized()
			else:
				tangent = (pts[i + 1] - pts[i - 1]).normalized()

			# Perpendicular in XZ plane
			var perp := Vector3(-tangent.z, 0.0, tangent.x).normalized()
			var left_pt := p + perp * (w * 0.5)
			var right_pt := p - perp * (w * 0.5)

			var progress: float = float(i) / float(maxi(pts.size() - 1, 1))
			var col: Color = shallow_col.lerp(deep_col, progress * 0.5)
			col.a = 0.82

			vertices.append(left_pt)
			vertices.append(right_pt)

			normals.append(Vector3.UP)
			normals.append(Vector3.UP)

			colors.append(col)
			colors.append(col)

			uvs.append(Vector2(0.0, progress))
			uvs.append(Vector2(1.0, progress))

		# Connect adjacent segments
		for i in range(pts.size() - 1):
			var v0: int = river_start_idx + (i * 2)
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
