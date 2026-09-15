class_name WaterRenderer
extends RefCounted

## Orquestador dedicado de presentación de agua (BLOQUE 10).
## Convierte WaterRenderer en un orquestador simple y desacoplado de la geometría.
## Flujo canónico:
##   WorldRenderer -> WaterRenderer -> WaterMeshBuilder -> ArrayMesh -> MeshInstance3D
##
## No contiene ninguna lógica geométrica propia ni dependencias productivas de
## RiverMeshBuilder, LakeMeshBuilder o WaterField.

const _WaterMeshBuilderScript = preload("res://src/world_generator/presentation/water/water_mesh_builder.gd")
const _WaterMaterialScript = preload("res://src/world_generator/presentation/water/water_material.gd")

## API canónica de presentación: crea el nodo 3D de agua para WorldRenderer
static func build_water_node(result: WorldResult, profile: WorldProfile = null, show_wireframe: bool = false) -> Node3D:
	if result == null or result.hydrology == null:
		return null
	if profile == null:
		profile = WorldProfile.new()

	# Orquestación pura: delega exclusivamente la geometría a WaterMeshBuilder
	var mesh: ArrayMesh = _WaterMeshBuilderScript.build_mesh(result, profile)
	if mesh == null or mesh.get_surface_count() == 0:
		return null

	var root := Node3D.new()
	root.name = "WaterRoot"

	# Único MeshInstance3D para toda la masa de agua unificada del mundo
	var mi := MeshInstance3D.new()
	mi.name = "UnifiedWaterSurface"
	mi.mesh = mesh
	var water_mat = _WaterMaterialScript.create_water_material(profile, true)
	mi.material_override = water_mat
	mi.set_surface_override_material(0, water_mat)
	root.add_child(mi)

	# Overlay de depuración wireframe (adjunto siempre para toggle instantáneo)
	var wire_overlay = build_wireframe_node(mesh)
	if wire_overlay != null:
		wire_overlay.visible = show_wireframe
		root.add_child(wire_overlay)

	return root

## Construye una malla de alambre y puntos de inspección a partir de ArrayMesh o WaterSurfaceData
static func build_wireframe_node(mesh_or_surf: RefCounted) -> Node3D:
	if mesh_or_surf == null:
		return null

	var verts: PackedVector3Array
	var indices: PackedInt32Array
	var colors: PackedColorArray

	if mesh_or_surf is ArrayMesh:
		if mesh_or_surf.get_surface_count() == 0:
			return null
		var arrays: Array = mesh_or_surf.surface_get_arrays(0)
		verts = arrays[Mesh.ARRAY_VERTEX]
		indices = arrays[Mesh.ARRAY_INDEX]
		if arrays.size() > Mesh.ARRAY_COLOR and arrays[Mesh.ARRAY_COLOR] != null:
			colors = arrays[Mesh.ARRAY_COLOR]
	elif "vertices" in mesh_or_surf and "indices" in mesh_or_surf:
		verts = mesh_or_surf.vertices
		indices = mesh_or_surf.indices
		if "colors" in mesh_or_surf:
			colors = mesh_or_surf.colors
	else:
		return null

	if verts.is_empty() or indices.is_empty():
		return null

	var has_colors: bool = not colors.is_empty() and colors.size() == verts.size()
	var wire_root := Node3D.new()
	wire_root.name = "WaterWireframeOverlay"

	var num_tris: int = indices.size() / 3

	# 1. Malla de aristas (PRIMITIVE_LINES)
	var line_verts := PackedVector3Array()
	var line_colors := PackedColorArray()
	var edge_col := Color(0.12, 0.90, 1.0, 0.95)

	for t in range(num_tris):
		var i0: int = indices[t * 3]
		var i1: int = indices[t * 3 + 1]
		var i2: int = indices[t * 3 + 2]


		var v0: Vector3 = verts[i0] + Vector3(0.0, 0.035, 0.0)
		var v1: Vector3 = verts[i1] + Vector3(0.0, 0.035, 0.0)
		var v2: Vector3 = verts[i2] + Vector3(0.0, 0.035, 0.0)

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
		line_mat.render_priority = 10

		var line_mi := MeshInstance3D.new()
		line_mi.name = "WireframeEdges"
		line_mi.mesh = line_mesh
		line_mi.set_surface_override_material(0, line_mat)
		wire_root.add_child(line_mi)

	# 2. Malla de vértices (PRIMITIVE_POINTS)
	var pt_verts := PackedVector3Array()
	var pt_colors := PackedColorArray()
	var num_pts: int = verts.size()
	var dot_col := Color(1.0, 0.85, 0.20, 1.0)

	for p_idx in range(num_pts):
		pt_verts.append(verts[p_idx] + Vector3(0.0, 0.040, 0.0))
		var is_water_pt: bool = (not has_colors) or (colors[p_idx].a >= 0.5)
		pt_colors.append(dot_col if is_water_pt else Color(0.12, 0.75, 0.95, 0.60))

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
		pt_mat.render_priority = 11

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
