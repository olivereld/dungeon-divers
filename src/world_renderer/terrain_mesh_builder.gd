class_name TerrainMeshBuilder
extends RefCounted

const _TerrainColorResolverScript = preload("res://src/world_generator/presentation/terrain_color_resolver.gd")

static func build_mesh(result: WorldResult, cell_size: float = 1.0, profile: WorldProfile = null) -> ArrayMesh:
	var w := result.dimensions.x
	var h := result.dimensions.y

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	# Grid vertices (Fixed 1.0 unit per cell for 128x128 level bounds)
	for y in range(h):
		for x in range(w):
			var cell := result.get_cell(Vector2i(x, y))
			var pos := Vector3(float(x), cell.height, float(y))
			vertices.append(pos)
			uvs.append(Vector2(float(x) / float(w), float(y) / float(h)))

			# Resolve procedural terrain albedo color from profile and cell ecology/topography
			var col: Color = _TerrainColorResolverScript.resolve_vertex_color(cell, profile)
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
