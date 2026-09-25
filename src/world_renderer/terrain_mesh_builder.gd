class_name TerrainMeshBuilder
extends RefCounted

const _TerrainColorResolverScript = preload("res://src/world_generator/presentation/terrain_color_resolver.gd")
const _ShorelineResolverScript = preload("res://src/world_generator/presentation/water/shoreline_resolver.gd")
const _WaterTopologyScript = preload("res://src/world_generator/presentation/water/water_topology.gd")
const _WorldVegetationItemScript = preload("res://src/world_generator/data/world_vegetation_item.gd")

static func build_mesh(result: WorldResult, cell_size: float = 1.0, profile: WorldProfile = null) -> ArrayMesh:
	var w := result.dimensions.x
	var h := result.dimensions.y

	var is_chunk: bool = ("seam_cells" in result) or (result.has_method("get_core_bounds")) or (result.has_method("is_chunk") and result.is_chunk())
	var origin := Vector2i.ZERO
	if "core_bounds" in result:
		origin = result.core_bounds.position
	elif is_chunk and "origin" in result:
		origin = result.origin
	elif is_chunk and "chunk_position" in result:
		origin = result.chunk_position

	var macro_w: int = profile.width if profile != null else w
	var macro_h: int = profile.height if profile != null else h

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
		if not hydro.shoreline_sdf.is_empty() and hydro.shoreline_sdf.size() == macro_w * macro_h:
			shore_sdf = hydro.shoreline_sdf
		elif not is_chunk:
			# Solo en macro Lab calculamos y guardamos el macro SDF global
			var topo: WaterTopology = _WaterTopologyScript.analyze(hydro.water_cells, macro_w, macro_h)
			var shore_off: float = float(profile.shoreline_offset) if (profile != null and "shoreline_offset" in profile) else 0.0
			shore_sdf = _ShorelineResolverScript.compute(
				hydro.water_cells, topo, macro_w, macro_h, result.master_seed,
				_ShorelineResolverScript.DEFAULT_ORGANIC_AMPLITUDE, shore_off
			)
			hydro.shoreline_sdf = shore_sdf

	var cells_w: int = w
	var cells_h: int = h

	# Máscara continua de influencia de copas de árboles (bajo árboles: Grass_03 + Dirt_04)
	var tree_mask := PackedFloat32Array()
	tree_mask.resize(cells_w * cells_h)
	tree_mask.fill(0.0)

	var trees_source: Array = result.canopy_trees if ("canopy_trees" in result and result.canopy_trees != null and not result.canopy_trees.is_empty()) else result.vegetation
	if trees_source != null and not trees_source.is_empty():
		for item in trees_source:
			var is_tree := false
			if "type" in item:
				is_tree = (item.type == _WorldVegetationItemScript.Type.CONIFER)
			if not is_tree:
				continue

			var tree_x: float = item.position.x
			var tree_z: float = item.position.z
			var tree_scale: float = item.scale if ("scale" in item and item.scale > 0.0) else 1.0
			var radius: float = 2.6 * tree_scale

			var min_x: int = clampi(int(floor(tree_x - radius)) - origin.x, 0, cells_w - 1)
			var max_x: int = clampi(int(ceil(tree_x + radius)) - origin.x, 0, cells_w - 1)
			var min_y: int = clampi(int(floor(tree_z - radius)) - origin.y, 0, cells_h - 1)
			var max_y: int = clampi(int(ceil(tree_z + radius)) - origin.y, 0, cells_h - 1)

			for gy in range(min_y, max_y + 1):
				for gx in range(min_x, max_x + 1):
					var dx: float = (float(gx + origin.x) + 0.5) - tree_x
					var dy: float = (float(gy + origin.y) + 0.5) - tree_z
					var dist: float = sqrt(dx * dx + dy * dy)
					if dist < radius:
						var infl: float = smoothstep(radius, 0.4 * tree_scale, dist)
						var idx: int = gy * cells_w + gx
						tree_mask[idx] = maxf(tree_mask[idx], infl)

	var rock_col: Color = profile.terrain_rock_color if profile != null else Color(0.28, 0.28, 0.30)

	# Generación de geometría escalonada:
	# 1. TOP QUAD horizontal por cada celda a cota Y = cell.height
	# 2. CLIFF QUADS verticales en los bordes donde exista desnivel hacia una celda vecina inferior
	for y in range(cells_h):
		for x in range(cells_w):
			var pos_2i := origin + Vector2i(x, y)
			var cell: WorldCell = null
			if is_chunk and result.has_method("get_cell_or_seam"):
				cell = result.get_cell_or_seam(pos_2i)
			else:
				cell = result.get_cell(pos_2i)

			if cell == null:
				continue

			var h_top: float = cell.height
			var x0: float = float(x) * cell_size
			var x1: float = float(x + 1) * cell_size
			var z0: float = float(y) * cell_size
			var z1: float = float(y + 1) * cell_size

			# -----------------------------------------------------------------
			# 1. CARA SUPERIOR (TOP QUAD) - Completamente plana, normal UP
			# -----------------------------------------------------------------
			var top_idx: int = vertices.size()
			var p0 := Vector3(x0, h_top, z0)
			var p1 := Vector3(x1, h_top, z0)
			var p2 := Vector3(x0, h_top, z1)
			var p3 := Vector3(x1, h_top, z1)

			vertices.append(p0)
			vertices.append(p1)
			vertices.append(p2)
			vertices.append(p3)

			normals.append(Vector3.UP)
			normals.append(Vector3.UP)
			normals.append(Vector3.UP)
			normals.append(Vector3.UP)

			var uv0 := Vector2(float(pos_2i.x) / float(macro_w), float(pos_2i.y) / float(macro_h))
			var uv1 := Vector2(float(pos_2i.x + 1) / float(macro_w), float(pos_2i.y) / float(macro_h))
			var uv2 := Vector2(float(pos_2i.x) / float(macro_w), float(pos_2i.y + 1) / float(macro_h))
			var uv3 := Vector2(float(pos_2i.x + 1) / float(macro_w), float(pos_2i.y + 1) / float(macro_h))
			uvs.append(uv0)
			uvs.append(uv1)
			uvs.append(uv2)
			uvs.append(uv3)

			var t_factor: float = tree_mask[y * cells_w + x]
			var uv2_val := Vector2(t_factor, 0.0)
			uv2s.append(uv2_val)
			uv2s.append(uv2_val)
			uv2s.append(uv2_val)
			uv2s.append(uv2_val)

			var col_top: Color = _TerrainColorResolverScript.resolve_vertex_color(cell, profile)
			if is_chunk:
				col_top.a = hydro.get_shoreline_sdf_at(pos_2i, macro_w, macro_h) if hydro != null else 0.0
			else:
				if not shore_sdf.is_empty() and y < h and x < w:
					col_top.a = shore_sdf[y * w + x]
				else:
					col_top.a = 0.0

			colors.append(col_top)
			colors.append(col_top)
			colors.append(col_top)
			colors.append(col_top)

			# Triangulación de la cara superior (normal hacia arriba Vector3.UP)
			indices.append(top_idx + 0)
			indices.append(top_idx + 1)
			indices.append(top_idx + 2)

			indices.append(top_idx + 1)
			indices.append(top_idx + 3)
			indices.append(top_idx + 2)

			# -----------------------------------------------------------------
			# 2. CARAS VERTICALES (CLIFF QUADS) - Regla de generación de paredes
			# Si cell.height > neighbor.height: se genera pared vertical cubriendo
			# min(height_a, height_b) -> max(height_a, height_b).
			# Emitida únicamente por la celda superior hacia la inferior para evitar
			# duplicación y z-fighting, garantizando una malla 100% estanca (watertight)
			# tanto en cliffs entre niveles como en desniveles de hidrología / riberas.
			# -----------------------------------------------------------------
			var col_cliff := rock_col
			col_cliff.a = col_top.a

			# Borde Oeste (-X)
			var n_pos_w := origin + Vector2i(x - 1, y)
			var n_cell_w: WorldCell = result.get_cell_or_seam(n_pos_w) if is_chunk and result.has_method("get_cell_or_seam") else result.get_cell(n_pos_w)
			if n_cell_w != null and (cell.height - n_cell_w.height > 0.0001):
				var h_hi: float = cell.height
				var h_lo: float = n_cell_w.height
				if h_hi > h_lo:
					var idx := vertices.size()
					vertices.append(Vector3(x0, h_hi, z1))
					vertices.append(Vector3(x0, h_hi, z0))
					vertices.append(Vector3(x0, h_lo, z1))
					vertices.append(Vector3(x0, h_lo, z0))

					normals.append(Vector3.LEFT)
					normals.append(Vector3.LEFT)
					normals.append(Vector3.LEFT)
					normals.append(Vector3.LEFT)

					uvs.append(uv2)
					uvs.append(uv0)
					uvs.append(uv2)
					uvs.append(uv0)

					uv2s.append(Vector2(0.0, 0.0))
					uv2s.append(Vector2(0.0, 0.0))
					uv2s.append(Vector2(0.0, h_hi - h_lo))
					uv2s.append(Vector2(0.0, h_hi - h_lo))

					colors.append(col_cliff)
					colors.append(col_cliff)
					colors.append(col_cliff)
					colors.append(col_cliff)

					indices.append(idx + 0)
					indices.append(idx + 2)
					indices.append(idx + 1)

					indices.append(idx + 1)
					indices.append(idx + 2)
					indices.append(idx + 3)

			# Borde Este (+X)
			var n_pos_e := origin + Vector2i(x + 1, y)
			var n_cell_e: WorldCell = result.get_cell_or_seam(n_pos_e) if is_chunk and result.has_method("get_cell_or_seam") else result.get_cell(n_pos_e)
			if n_cell_e != null and (cell.height - n_cell_e.height > 0.0001):
				var h_hi: float = cell.height
				var h_lo: float = n_cell_e.height
				if h_hi > h_lo:
					var idx := vertices.size()
					vertices.append(Vector3(x1, h_hi, z0))
					vertices.append(Vector3(x1, h_hi, z1))
					vertices.append(Vector3(x1, h_lo, z0))
					vertices.append(Vector3(x1, h_lo, z1))

					normals.append(Vector3.RIGHT)
					normals.append(Vector3.RIGHT)
					normals.append(Vector3.RIGHT)
					normals.append(Vector3.RIGHT)

					uvs.append(uv1)
					uvs.append(uv3)
					uvs.append(uv1)
					uvs.append(uv3)

					uv2s.append(Vector2(0.0, 0.0))
					uv2s.append(Vector2(0.0, 0.0))
					uv2s.append(Vector2(0.0, h_hi - h_lo))
					uv2s.append(Vector2(0.0, h_hi - h_lo))

					colors.append(col_cliff)
					colors.append(col_cliff)
					colors.append(col_cliff)
					colors.append(col_cliff)

					indices.append(idx + 0)
					indices.append(idx + 2)
					indices.append(idx + 1)

					indices.append(idx + 1)
					indices.append(idx + 2)
					indices.append(idx + 3)

			# Borde Norte (-Z)
			var n_pos_n := origin + Vector2i(x, y - 1)
			var n_cell_n: WorldCell = result.get_cell_or_seam(n_pos_n) if is_chunk and result.has_method("get_cell_or_seam") else result.get_cell(n_pos_n)
			if n_cell_n != null and (cell.height - n_cell_n.height > 0.0001):
				var h_hi: float = cell.height
				var h_lo: float = n_cell_n.height
				if h_hi > h_lo:
					var idx := vertices.size()
					vertices.append(Vector3(x0, h_hi, z0))
					vertices.append(Vector3(x1, h_hi, z0))
					vertices.append(Vector3(x0, h_lo, z0))
					vertices.append(Vector3(x1, h_lo, z0))

					normals.append(Vector3.FORWARD)
					normals.append(Vector3.FORWARD)
					normals.append(Vector3.FORWARD)
					normals.append(Vector3.FORWARD)

					uvs.append(uv0)
					uvs.append(uv1)
					uvs.append(uv0)
					uvs.append(uv1)

					uv2s.append(Vector2(0.0, 0.0))
					uv2s.append(Vector2(0.0, 0.0))
					uv2s.append(Vector2(0.0, h_hi - h_lo))
					uv2s.append(Vector2(0.0, h_hi - h_lo))

					colors.append(col_cliff)
					colors.append(col_cliff)
					colors.append(col_cliff)
					colors.append(col_cliff)

					indices.append(idx + 0)
					indices.append(idx + 2)
					indices.append(idx + 1)

					indices.append(idx + 1)
					indices.append(idx + 2)
					indices.append(idx + 3)

			# Borde Sur (+Z)
			var n_pos_s := origin + Vector2i(x, y + 1)
			var n_cell_s: WorldCell = result.get_cell_or_seam(n_pos_s) if is_chunk and result.has_method("get_cell_or_seam") else result.get_cell(n_pos_s)
			if n_cell_s != null and (cell.height - n_cell_s.height > 0.0001):
				var h_hi: float = cell.height
				var h_lo: float = n_cell_s.height
				if h_hi > h_lo:
					var idx := vertices.size()
					vertices.append(Vector3(x1, h_hi, z1))
					vertices.append(Vector3(x0, h_hi, z1))
					vertices.append(Vector3(x1, h_lo, z1))
					vertices.append(Vector3(x0, h_lo, z1))

					normals.append(Vector3.BACK)
					normals.append(Vector3.BACK)
					normals.append(Vector3.BACK)
					normals.append(Vector3.BACK)

					uvs.append(uv3)
					uvs.append(uv2)
					uvs.append(uv3)
					uvs.append(uv2)

					uv2s.append(Vector2(0.0, 0.0))
					uv2s.append(Vector2(0.0, 0.0))
					uv2s.append(Vector2(0.0, h_hi - h_lo))
					uv2s.append(Vector2(0.0, h_hi - h_lo))

					colors.append(col_cliff)
					colors.append(col_cliff)
					colors.append(col_cliff)
					colors.append(col_cliff)

					indices.append(idx + 0)
					indices.append(idx + 2)
					indices.append(idx + 1)

					indices.append(idx + 1)
					indices.append(idx + 2)
					indices.append(idx + 3)


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
