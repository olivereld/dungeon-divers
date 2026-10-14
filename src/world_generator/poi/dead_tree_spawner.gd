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
				_cached_baked_mesh = _bake_dead_tree(mi.mesh, mi.transform, 5.8)
			inst.free()

	if _cached_baked_mesh == null:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.3
		cyl.bottom_radius = 0.8
		cyl.height = 5.8
		_cached_baked_mesh = cyl

	return _cached_baked_mesh

## Hornea la malla original del GLB con su orientación, escalada a tamaño de conífera (~5.8m)
## y asienta las raíces en el suelo. Idéntico al patrón _bake_pino_mesh en WorldRenderer.
static func _bake_dead_tree(orig_mesh: Mesh, xform: Transform3D, scale_factor: float = 5.8) -> ArrayMesh:
	var min_y: float = INF
	for s in range(orig_mesh.get_surface_count()):
		var arr: Array = orig_mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for v in verts:
			var tv: Vector3 = xform * v
			min_y = minf(min_y, tv.y)
	if not is_finite(min_y):
		min_y = 0.0

	var ground_embed_m: float = 0.20 # Asienta 20cm en el suelo para raíces firmes
	var baked := ArrayMesh.new()

	for s in range(orig_mesh.get_surface_count()):
		var arr: Array = orig_mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var basis: Basis = xform.basis.orthonormalized()

		for i in range(verts.size()):
			var tv: Vector3 = xform * verts[i]
			verts[i] = Vector3(tv.x * scale_factor, (tv.y - min_y) * scale_factor - ground_embed_m, tv.z * scale_factor)

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

const _EvaluatorScript = preload("res://src/world_generator/poi/necropolis_influence_evaluator.gd")

static func generate_dead_trees(poi: RefCounted, profile: RefCounted, world_query: Object) -> Node3D:
	var container := Node3D.new()
	container.name = "DeadTrees"

	var mesh: Mesh = _get_baked_mesh()

	var seed_val: int = poi.identity.dungeon_seed if (poi != null and "identity" in poi and poi.identity != null) else 9999
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val ^ 0xD3AD7

	var poi_pos: Vector3 = poi.world_position if (poi != null and "world_position" in poi) else Vector3.ZERO
	var ori_deg: float = poi.orientation_deg if (poi != null and "orientation_deg" in poi) else 0.0
	var fwd_3d: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(ori_deg))
	var fwd_angle: float = atan2(fwd_3d.z, fwd_3d.x)

	var clear_r: float = profile.entrance_clear_radius if "entrance_clear_radius" in profile else 5.5
	var min_dist: float = profile.dead_tree_min_distance if "dead_tree_min_distance" in profile else 3.8

	var placed_points: Array[Vector2] = []
	var transforms: Array[Transform3D] = []

	# Sectores de encuadre asimétrico (como bambalinas teatrales) para siluetear la cripta:
	# Flanco izquierdo cercano, flanco derecho retrasado, trasera izquierda, trasera derecha y fondo
	var framing_sectors: Array[Dictionary] = [
		{ "angle_offset": deg_to_rad(-82.0),  "dist_min": 6.0, "dist_max": 8.5,  "scale_min": 0.95, "scale_max": 1.25 },
		{ "angle_offset": deg_to_rad(76.0),   "dist_min": 7.5, "dist_max": 10.5, "scale_min": 0.90, "scale_max": 1.20 },
		{ "angle_offset": deg_to_rad(-145.0), "dist_min": 8.5, "dist_max": 12.5, "scale_min": 1.00, "scale_max": 1.30 },
		{ "angle_offset": deg_to_rad(152.0),  "dist_min": 9.5, "dist_max": 13.5, "scale_min": 0.90, "scale_max": 1.20 },
		{ "angle_offset": deg_to_rad(-115.0), "dist_min": 7.8, "dist_max": 11.2, "scale_min": 0.85, "scale_max": 1.15 },
		{ "angle_offset": deg_to_rad(178.0),  "dist_min": 10.0,"dist_max": 14.5, "scale_min": 0.95, "scale_max": 1.25 }
	]

	var target_count: int = rng.randi_range(4, 5)

	for sector in framing_sectors:
		if transforms.size() >= target_count:
			break

		var placed := false
		for attempt in range(8):
			var angle: float = fwd_angle + sector.angle_offset + rng.randf_range(-0.16, 0.16)
			var dist: float = rng.randf_range(sector.dist_min, sector.dist_max)
			var wx: float = poi_pos.x + cos(angle) * dist
			var wz: float = poi_pos.z + sin(angle) * dist
			var p2 := Vector2(wx, wz)

			# 1. Clearance estricto: NUNCA en el corredor frontal ni dentro del Crypt Core
			if _EvaluatorScript.is_in_frontal_corridor(p2, Vector2(poi_pos.x, poi_pos.z), ori_deg, 8.5, 3.5):
				continue
			if (p2 - Vector2(poi_pos.x, poi_pos.z)).length() < clear_r + 0.3:
				continue

			# 2. Distancia mínima entre árboles para evitar solapamientos
			var too_close := false
			for existing in placed_points:
				if (existing - p2).length() < min_dist:
					too_close = true
					break
			if too_close:
				continue

			# 3. Comprobar que no esté en agua
			if world_query != null and world_query.has_method("is_water") and world_query.is_water(int(round(wx)), int(round(wz))):
				continue

			var wy: float = poi_pos.y
			if world_query != null and world_query.has_method("get_elevation"):
				wy = world_query.get_elevation(int(round(wx)), int(round(wz)))
				var h_e: float = world_query.get_elevation(int(round(wx + 0.8)), int(round(wz)))
				var h_s: float = world_query.get_elevation(int(round(wx)), int(round(wz + 0.8)))
				if absf(h_e - wy) > 0.40 or absf(h_s - wy) > 0.40:
					continue

			var s: float = rng.randf_range(sector.scale_min, sector.scale_max)
			var rot_y: float = rng.randf() * TAU

			var t := Transform3D()
			t = t.scaled(Vector3.ONE * s)
			t = t.rotated(Vector3.UP, rot_y)
			t.origin = Vector3(wx - poi_pos.x, wy - poi_pos.y, wz - poi_pos.z)

			transforms.append(t)
			placed_points.append(p2)
			placed = true
			break

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
