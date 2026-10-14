class_name DeadTreeSpawner
extends RefCounted

## Spawner determinista de árboles muertos (dead_tree_01.glb) mediante MultiMesh.
## Distribuye ejemplares retorcidos y secos en las zonas funerarias y de corrupción.
## Utiliza el mismo patrón canónico de bakeado que los pinos en WorldRenderer (_bake_pino_mesh).

const DEAD_TREE_GLB_PATH: String = "res://models/nature/dead_tree/dead_tree_01.glb"
const DEAD_TREE_TEX_PATH: String = "res://models/nature/dead_tree/dead_tree_01_Arbol.png"

static var _cached_baked_mesh: Mesh = null
static var _cached_material: StandardMaterial3D = null

static func _get_baked_mesh() -> Mesh:
	if _cached_baked_mesh != null:
		return _cached_baked_mesh

	if ResourceLoader.exists(DEAD_TREE_GLB_PATH):
		var scn: PackedScene = load(DEAD_TREE_GLB_PATH) as PackedScene
		if scn != null:
			var inst: Node = scn.instantiate()
			var mi: MeshInstance3D = null
			for child in inst.get_children():
				if child is MeshInstance3D and child.mesh != null:
					mi = child
					break
			if mi != null:
				_cached_baked_mesh = _bake_dead_tree(mi.mesh, mi.transform, 2.4)
			inst.free()

	if _cached_baked_mesh == null:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.2
		cyl.bottom_radius = 0.4
		cyl.height = 4.0
		_cached_baked_mesh = cyl

	return _cached_baked_mesh

## Hornea la malla original del GLB con su orientación y asienta las raíces en el suelo
## Idéntico al patrón _bake_pino_mesh en WorldRenderer.
static func _bake_dead_tree(orig_mesh: Mesh, xform: Transform3D, scale_factor: float = 2.4) -> ArrayMesh:
	var min_y: float = INF
	for s in range(orig_mesh.get_surface_count()):
		var arr: Array = orig_mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for v in verts:
			var tv: Vector3 = xform * v
			min_y = minf(min_y, tv.y)
	if not is_finite(min_y):
		min_y = 0.0

	# y_offset hunde las raíces 0.15m en la tierra para que queden naturalmente ancladas
	var y_offset: float = -min_y - 0.15
	var baked := ArrayMesh.new()

	for s in range(orig_mesh.get_surface_count()):
		var arr: Array = orig_mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var basis: Basis = xform.basis.orthonormalized()

		for i in range(verts.size()):
			var tv: Vector3 = xform * verts[i]
			tv.y += y_offset
			verts[i] = tv * scale_factor

		if not normals.is_empty():
			for i in range(normals.size()):
				normals[i] = (basis * normals[i]).normalized()

		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = normals
		baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

	return baked

static func _get_material() -> StandardMaterial3D:
	if _cached_material == null:
		var mat := StandardMaterial3D.new()
		if ResourceLoader.exists(DEAD_TREE_TEX_PATH):
			mat.albedo_texture = load(DEAD_TREE_TEX_PATH) as Texture2D
		mat.albedo_color = Color(0.85, 0.82, 0.80)
		mat.roughness = 0.92
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		mat.cull_mode = BaseMaterial3D.CULL_BACK
		_cached_material = mat
	return _cached_material

static func generate_dead_trees(poi: RefCounted, profile: RefCounted, world_query: Object) -> Node3D:
	var container := Node3D.new()
	container.name = "DeadTrees"

	var mesh: Mesh = _get_baked_mesh()

	var seed_val: int = poi.identity.dungeon_seed if (poi != null and "identity" in poi and poi.identity != null) else 9999
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val ^ 0xD3AD7

	var poi_pos: Vector3 = poi.world_position if (poi != null and "world_position" in poi) else Vector3.ZERO
	var clear_r: float = profile.entrance_clear_radius if "entrance_clear_radius" in profile else 4.5
	var funeral_r: float = profile.funeral_ground_radius if "funeral_ground_radius" in profile else 14.0
	var corrupt_r: float = profile.corruption_radius if "corruption_radius" in profile else 24.0
	var min_dist: float = profile.dead_tree_min_distance if "dead_tree_min_distance" in profile else 4.0

	var placed_points: Array[Vector2] = []
	var transforms: Array[Transform3D] = []

	var target_count: int = rng.randi_range(6, 10)
	var max_attempts: int = 60

	for attempt in range(max_attempts):
		if transforms.size() >= target_count:
			break

		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(clear_r + 1.5, corrupt_r)
		var wx: float = poi_pos.x + cos(angle) * dist
		var wz: float = poi_pos.z + sin(angle) * dist

		# Comprobar distancia mínima con respecto a la entrada
		if (Vector2(wx, wz) - Vector2(poi_pos.x, poi_pos.z)).length() < clear_r + 0.5:
			continue

		# Comprobar distancia mínima entre árboles muertos
		var too_close := false
		var p2 := Vector2(wx, wz)
		for existing in placed_points:
			if (existing - p2).length() < min_dist:
				too_close = true
				break
		if too_close:
			continue

		# Comprobar agua
		if world_query != null and world_query.has_method("is_water") and world_query.is_water(int(round(wx)), int(round(wz))):
			continue

		var wy: float = poi_pos.y
		if world_query != null and world_query.has_method("get_elevation"):
			wy = world_query.get_elevation(int(round(wx)), int(round(wz)))
			# Comprobar estabilidad del suelo: evitar colocar sobre escalones de acantilado
			var h_e: float = world_query.get_elevation(int(round(wx + 0.8)), int(round(wz)))
			var h_s: float = world_query.get_elevation(int(round(wx)), int(round(wz + 0.8)))
			if absf(h_e - wy) > 0.40 or absf(h_s - wy) > 0.40:
				continue

		# Factor de escala por instancia idéntico a las coníferas en WorldRenderer
		var s: float = rng.randf_range(0.85, 1.25)
		var rot_y: float = rng.randf() * TAU

		# La malla horneada ya tiene el tronco erguido y las raíces a nivel de suelo (min_y = -0.15).
		# Se coloca con rotación puramente vertical sobre Y y a cota wy, exactamente como los pinos.
		var t := Transform3D()
		t = t.scaled(Vector3.ONE * s)
		t = t.rotated(Vector3.UP, rot_y)
		t.origin = Vector3(wx - poi_pos.x, wy - poi_pos.y, wz - poi_pos.z)

		transforms.append(t)
		placed_points.append(p2)

	if not transforms.is_empty():
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "DeadTreesMultiMesh"
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = transforms.size()

		for i in range(transforms.size()):
			mm.set_instance_transform(i, transforms[i])

		mmi.multimesh = mm
		mmi.material_override = _get_material()
		mmi.set_meta("tree_transforms", transforms)
		container.add_child(mmi)

	return container
