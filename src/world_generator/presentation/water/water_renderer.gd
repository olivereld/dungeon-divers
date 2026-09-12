class_name WaterRenderer
extends RefCounted

## Orquestador dedicado de presentación de agua.
## Unifica ríos, lagos y confluencias en una única malla optimizada y calcula
## la máscara de proximidad a la ribera (distance_to_water).

const _WaterSurfaceDataScript = preload("res://src/world_generator/presentation/water/water_surface_data.gd")
const _RiverMeshBuilderScript = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _LakeMeshBuilderScript = preload("res://src/world_generator/presentation/water/lake_mesh_builder.gd")
const _WaterMaterialScript = preload("res://src/world_generator/presentation/water/water_material.gd")

static func build_water_node(result: WorldResult, profile: WorldProfile = null) -> Node3D:
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

	return root

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
