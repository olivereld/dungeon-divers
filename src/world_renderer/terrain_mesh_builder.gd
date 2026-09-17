class_name TerrainMeshBuilder
extends RefCounted

const _TerrainColorResolverScript = preload("res://src/world_generator/presentation/terrain_color_resolver.gd")
const _ShorelineResolverScript = preload("res://src/world_generator/presentation/water/shoreline_resolver.gd")
const _WaterTopologyScript = preload("res://src/world_generator/presentation/water/water_topology.gd")
const _WorldVegetationItemScript = preload("res://src/world_generator/data/world_vegetation_item.gd")

static func build_mesh(result: WorldResult, cell_size: float = 1.0, profile: WorldProfile = null) -> ArrayMesh:
	var w := result.dimensions.x
	var h := result.dimensions.y

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	# Obtener o computar el campo de distancia SDF de la orilla (Shoreline Distance Field)
	var shore_sdf: PackedFloat32Array = PackedFloat32Array()
	var hydro: HydrologyResult = result.hydrology
	if hydro != null and not hydro.water_cells.is_empty():
		if not hydro.shoreline_sdf.is_empty() and hydro.shoreline_sdf.size() == w * h:
			shore_sdf = hydro.shoreline_sdf
		else:
			var topo: WaterTopology = _WaterTopologyScript.analyze(hydro.water_cells, w, h)
			var shore_off: float = float(profile.shoreline_offset) if (profile != null and "shoreline_offset" in profile) else 0.0
			shore_sdf = _ShorelineResolverScript.compute(
				hydro.water_cells, topo, w, h, result.master_seed,
				_ShorelineResolverScript.DEFAULT_ORGANIC_AMPLITUDE, shore_off
			)
			hydro.shoreline_sdf = shore_sdf

	# Máscara continua de influencia de copas de árboles (bajo árboles: Grass_03 + Dirt_04)
	var tree_mask := PackedFloat32Array()
	tree_mask.resize(w * h)
	tree_mask.fill(0.0)

	if result.vegetation != null and not result.vegetation.is_empty():
		for item in result.vegetation:
			var is_tree := false
			if "type" in item:
				is_tree = (item.type == _WorldVegetationItemScript.Type.CONIFER)
			if not is_tree:
				continue

			var tree_x: float = item.position.x
			var tree_z: float = item.position.z
			var tree_scale: float = item.scale if ("scale" in item and item.scale > 0.0) else 1.0
			var radius: float = 2.6 * tree_scale

			var min_x: int = clampi(int(floor(tree_x - radius)), 0, w - 1)
			var max_x: int = clampi(int(ceil(tree_x + radius)), 0, w - 1)
			var min_y: int = clampi(int(floor(tree_z - radius)), 0, h - 1)
			var max_y: int = clampi(int(ceil(tree_z + radius)), 0, h - 1)

			for gy in range(min_y, max_y + 1):
				for gx in range(min_x, max_x + 1):
					var dx: float = float(gx) - tree_x
					var dy: float = float(gy) - tree_z
					var dist: float = sqrt(dx * dx + dy * dy)
					if dist < radius:
						var infl: float = smoothstep(radius, 0.4 * tree_scale, dist)
						var idx: int = gy * w + gx
						tree_mask[idx] = maxf(tree_mask[idx], infl)

	# Grid vertices (Fixed 1.0 unit per cell for level bounds)
	for y in range(h):
		for x in range(w):
			var cell := result.get_cell(Vector2i(x, y))
			var pos := Vector3(float(x), cell.height, float(y))
			vertices.append(pos)
			uvs.append(Vector2(float(x) / float(w), float(y) / float(h)))
			uv2s.append(Vector2(tree_mask[y * w + x], 0.0))

			# Resolve procedural terrain albedo color from profile and cell ecology/topography
			var col: Color = _TerrainColorResolverScript.resolve_vertex_color(cell, profile)
			if not shore_sdf.is_empty():
				col.a = shore_sdf[y * w + x]
			else:
				col.a = 0.0
			colors.append(col)

	# Compute indices
	for y in range(h - 1):
		for x in range(w - 1):
			var i0 := y * w + x
			var i1 := y * w + (x + 1)
			var i2 := (y + 1) * w + x
			var i3 := (y + 1) * w + (x + 1)

			# Quad triangles
			indices.append(i0)
			indices.append(i1)
			indices.append(i2)

			indices.append(i1)
			indices.append(i3)
			indices.append(i2)

	# Compute normals
	normals.resize(vertices.size())
	for i in range(normals.size()):
		normals[i] = Vector3.UP

	for i in range(0, indices.size(), 3):
		var v0 := vertices[indices[i]]
		var v1 := vertices[indices[i + 1]]
		var v2 := vertices[indices[i + 2]]
		var n := (v1 - v0).cross(v2 - v0).normalized()
		normals[indices[i]] += n
		normals[indices[i + 1]] += n
		normals[indices[i + 2]] += n

	for i in range(normals.size()):
		normals[i] = normals[i].normalized()

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## Construye una malla de alambre y puntos de inspección para el terreno
## Utiliza Naranja Cálido para aristas y Magenta/Fucsia para vértices (alto contraste con el agua)
static func build_wireframe_node(mesh: ArrayMesh) -> Node3D:
	if mesh == null or mesh.get_surface_count() == 0:
		return null

	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	if verts.is_empty() or indices.is_empty():
		return null

	var wire_root := Node3D.new()
	wire_root.name = "TerrainWireframeOverlay"

	var num_tris: int = indices.size() / 3

	# 1. Malla de aristas (PRIMITIVE_LINES) — Naranja Cálido Neón (diferente al cyan del agua)
	var line_verts := PackedVector3Array()
	var line_colors := PackedColorArray()
	var edge_col := Color(1.0, 0.45, 0.08, 0.95)

	for t in range(num_tris):
		var i0: int = indices[t * 3]
		var i1: int = indices[t * 3 + 1]
		var i2: int = indices[t * 3 + 2]

		var v0: Vector3 = verts[i0] + Vector3(0.0, 0.020, 0.0)
		var v1: Vector3 = verts[i1] + Vector3(0.0, 0.020, 0.0)
		var v2: Vector3 = verts[i2] + Vector3(0.0, 0.020, 0.0)

		# Arista 0-1
		line_verts.append(v0)
		line_colors.append(edge_col)
		line_verts.append(v1)
		line_colors.append(edge_col)

		# Arista 1-2
		line_verts.append(v1)
		line_colors.append(edge_col)
		line_verts.append(v2)
		line_colors.append(edge_col)

		# Arista 2-0
		line_verts.append(v2)
		line_colors.append(edge_col)
		line_verts.append(v0)
		line_colors.append(edge_col)

	if not line_verts.is_empty():
		var line_arr := []
		line_arr.resize(Mesh.ARRAY_MAX)
		line_arr[Mesh.ARRAY_VERTEX] = line_verts
		line_arr[Mesh.ARRAY_COLOR] = line_colors

		var line_mesh := ArrayMesh.new()
		line_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, line_arr)

		var line_mat := StandardMaterial3D.new()
		line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		line_mat.vertex_color_use_as_albedo = true
		line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		line_mat.render_priority = 8

		var line_mi := MeshInstance3D.new()
		line_mi.name = "WireframeEdges"
		line_mi.mesh = line_mesh
		line_mi.set_surface_override_material(0, line_mat)
		wire_root.add_child(line_mi)

	# 2. Malla de vértices (PRIMITIVE_POINTS) — Magenta / Fucsia Vivo (diferente al amarillo del agua)
	var pt_verts := PackedVector3Array()
	var pt_colors := PackedColorArray()
	var num_pts: int = verts.size()
	var dot_col := Color(0.96, 0.18, 0.62, 1.0)

	for p_idx in range(num_pts):
		pt_verts.append(verts[p_idx] + Vector3(0.0, 0.025, 0.0))
		pt_colors.append(dot_col)

	if not pt_verts.is_empty():
		var pt_arr := []
		pt_arr.resize(Mesh.ARRAY_MAX)
		pt_arr[Mesh.ARRAY_VERTEX] = pt_verts
		pt_arr[Mesh.ARRAY_COLOR] = pt_colors

		var pt_mesh := ArrayMesh.new()
		pt_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, pt_arr)

		var pt_mat := StandardMaterial3D.new()
		pt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pt_mat.vertex_color_use_as_albedo = true
		pt_mat.use_point_size = true
		pt_mat.point_size = 6.0
		pt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pt_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		pt_mat.render_priority = 9

		var pt_mi := MeshInstance3D.new()
		pt_mi.name = "WireframeVertices"
		pt_mi.mesh = pt_mesh
		pt_mi.set_surface_override_material(0, pt_mat)
		wire_root.add_child(pt_mi)

	return wire_root
