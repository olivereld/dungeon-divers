class_name WaterRenderer
extends RefCounted

## Orquestador dedicado de presentación de agua.
## Unifica ríos, lagos y confluencias en una única malla optimizada y calcula
## la máscara de proximidad a la ribera (distance_to_water).

const _WaterSurfaceDataScript = preload("res://src/world_generator/presentation/water/water_surface_data.gd")
const _RiverMeshBuilderScript = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _LakeMeshBuilderScript = preload("res://src/world_generator/presentation/water/lake_mesh_builder.gd")
const _WaterMaterialScript = preload("res://src/world_generator/presentation/water/water_material.gd")

static func build_water_node(result: WorldResult, profile: WorldProfile = null, show_wireframe: bool = false) -> Node3D:
	if result == null or result.hydrology == null:
		return null
	if profile == null:
		profile = WorldProfile.new()

	# Flujo canónico: Hydrology -> RiverNetwork -> RiverMeshBuilder -> WaterSurfaceData -> Presentation
	var hydro = result.hydrology
	var combined_surf = _WaterSurfaceDataScript.new()

	# 1. Hydrology -> RiverNetwork -> RiverMeshBuilder -> WaterSurfaceData (Generación Única)
	var river_surf: WaterSurfaceData = null
	if "cached_water_surface" in result and result.cached_water_surface != null and result.cached_water_surface is _WaterSurfaceDataScript:
		river_surf = result.cached_water_surface as WaterSurfaceData
	else:
		var river_network = hydro.get_river_network()
		river_surf = _RiverMeshBuilderScript.build_network_mesh(river_network, result, profile)
		if "cached_water_surface" in result:
			result.cached_water_surface = river_surf
	if river_surf != null:
		combined_surf.append_surface(river_surf)

	# 2. Construir lagos
	for lake in hydro.lakes:
		var l_surf = _LakeMeshBuilderScript.build_lake_surface(lake, result, profile)
		if l_surf != null:
			combined_surf.append_surface(l_surf)

	var mesh: ArrayMesh = combined_surf.to_array_mesh()
	if mesh == null:
		return null

	var root := Node3D.new()
	root.name = "WaterRoot"

	var mi := MeshInstance3D.new()
	mi.name = "UnifiedWaterSurface"
	mi.mesh = mesh
	mi.set_surface_override_material(0, _WaterMaterialScript.create_water_material(profile, true))
	root.add_child(mi)

	# 3. Malla Wireframe de inspección de aristas y vértices (Ríos y Lagos)
	var wire_overlay = build_wireframe_node(combined_surf)
	if wire_overlay != null:
		wire_overlay.visible = show_wireframe
		root.add_child(wire_overlay)

	return root

## Construye una malla de alambre y puntos de inspección para visualizar la triangulación y vértices del agua
static func build_wireframe_node(combined_surf: RefCounted) -> Node3D:
	if combined_surf == null or combined_surf.vertices.is_empty() or combined_surf.indices.is_empty():
		return null

	var wire_root := Node3D.new()
	wire_root.name = "WaterWireframeOverlay"

	var verts: PackedVector3Array = combined_surf.vertices
	var indices: PackedInt32Array = combined_surf.indices
	var num_tris: int = indices.size() / 3

	# 1. Malla de aristas (PRIMITIVE_LINES)
	var line_verts := PackedVector3Array()
	var line_colors := PackedColorArray()
	line_verts.resize(num_tris * 6)
	line_colors.resize(num_tris * 6)
	var edge_col := Color(0.12, 0.90, 1.0, 0.90)

	var write_idx: int = 0
	for t in range(num_tris):
		var v0: Vector3 = verts[indices[t * 3]] + Vector3(0.0, 0.015, 0.0)
		var v1: Vector3 = verts[indices[t * 3 + 1]] + Vector3(0.0, 0.015, 0.0)
		var v2: Vector3 = verts[indices[t * 3 + 2]] + Vector3(0.0, 0.015, 0.0)

		# Arista 0-1
		line_verts[write_idx] = v0
		line_colors[write_idx] = edge_col
		write_idx += 1
		line_verts[write_idx] = v1
		line_colors[write_idx] = edge_col
		write_idx += 1

		# Arista 1-2
		line_verts[write_idx] = v1
		line_colors[write_idx] = edge_col
		write_idx += 1
		line_verts[write_idx] = v2
		line_colors[write_idx] = edge_col
		write_idx += 1

		# Arista 2-0
		line_verts[write_idx] = v2
		line_colors[write_idx] = edge_col
		write_idx += 1
		line_verts[write_idx] = v0
		line_colors[write_idx] = edge_col
		write_idx += 1

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

	var line_mi := MeshInstance3D.new()
	line_mi.name = "WireframeEdges"
	line_mi.mesh = line_mesh
	line_mi.set_surface_override_material(0, line_mat)
	wire_root.add_child(line_mi)

	# 2. Malla de vértices (PRIMITIVE_POINTS)
	var pt_verts := PackedVector3Array()
	var pt_colors := PackedColorArray()
	var num_pts: int = verts.size()
	pt_verts.resize(num_pts)
	pt_colors.resize(num_pts)
	var dot_col := Color(1.0, 0.85, 0.20, 1.0)

	for p_idx in range(num_pts):
		pt_verts[p_idx] = verts[p_idx] + Vector3(0.0, 0.020, 0.0)
		pt_colors[p_idx] = dot_col

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
	pt_mat.point_size = 5.0
	pt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pt_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var pt_mi := MeshInstance3D.new()
	pt_mi.name = "WireframeVertices"
	pt_mi.mesh = pt_mesh
	pt_mi.set_surface_override_material(0, pt_mat)
	wire_root.add_child(pt_mi)

	return wire_root

## Calcula un mapa de distancias mínimas en celdas a la masa de agua más cercana (ribera)
static func compute_distance_to_water(result: WorldResult) -> Dictionary:
	var dist_map: Dictionary = {}
	if result == null or result.hydrology == null:
		return dist_map

	var hydro = result.hydrology
	var w: int = result.dimensions.x
	var h: int = result.dimensions.y

	var queue: Array[Vector2i] = []
	for pos in hydro.water_cells.keys():
		dist_map[pos] = 0.0
		queue.append(pos)

	var offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]

	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		var d: float = dist_map[curr]
		if d >= 12.0:
			continue

		for off in offsets:
			var n: Vector2i = curr + off
			if n.x >= 0 and n.x < w and n.y >= 0 and n.y < h:
				if not dist_map.has(n):
					dist_map[n] = d + 1.0
					queue.append(n)

	return dist_map
