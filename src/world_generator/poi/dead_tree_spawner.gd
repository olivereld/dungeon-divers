class_name DeadTreeSpawner
extends RefCounted

## Spawner determinista de árboles muertos (dead_tree_01.glb) mediante MultiMesh.
## Distribuye ejemplares retorcidos y secos en las zonas funerarias y de corrupción.

const DEAD_TREE_GLB_PATH: String = "res://models/nature/dead_tree/dead_tree_01.glb"
const DEAD_TREE_TEX_PATH: String = "res://models/nature/dead_tree/dead_tree_01_Arbol.png"

static var _cached_mesh: Mesh = null
static var _cached_material: StandardMaterial3D = null

static func _get_mesh() -> Mesh:
	if _cached_mesh == null and ResourceLoader.exists(DEAD_TREE_GLB_PATH):
		var scn: PackedScene = load(DEAD_TREE_GLB_PATH) as PackedScene
		if scn != null:
			var inst: Node = scn.instantiate()
			for child in inst.get_children():
				if child is MeshInstance3D and child.mesh != null:
					_cached_mesh = child.mesh
					break
			inst.free()
	return _cached_mesh

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

	var mesh: Mesh = _get_mesh()
	if mesh == null:
		# Fallback a un cilindro si no se encuentra el modelo 3D
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.2
		cyl.bottom_radius = 0.4
		cyl.height = 4.0
		mesh = cyl

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

		var sc_min: float = profile.dead_tree_scale_min if "dead_tree_scale_min" in profile else 2.5
		var sc_max: float = profile.dead_tree_scale_max if "dead_tree_scale_max" in profile else 4.2
		var s: float = rng.randf_range(sc_min, sc_max)

		var t := Transform3D()
		t = t.scaled(Vector3(s, s, s))
		t = t.rotated(Vector3.UP, rng.randf() * TAU)
		# Posición relativa al nodo POI
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
