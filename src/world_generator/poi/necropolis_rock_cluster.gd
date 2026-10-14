class_name NecropolisRockCluster
extends RefCounted

const _ProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")
const _RockGenScript = preload("res://src/rock_generation/rock_generation.gd")
const _RockSizeConfigScript = preload("res://src/rock_generation/config/rock_size_config.gd")

## Genera cúmulos de rocas oscuras y erosionadas alrededor de la entrada de la Necrópolis.
## Añade atmósfera de cementerio antiguo con lajas y monolitos oscurecidos.
static func generate_dark_rocks(
	poi: RefCounted,
	profile: RefCounted = null,
	world_query: Object = null
) -> Node3D:
	if profile == null:
		profile = _ProfileScript.new()

	var root := Node3D.new()
	root.name = "DarkRocks"

	var seed_val: int = 12345
	if poi != null and "identity" in poi and poi.identity != null and "dungeon_seed" in poi.identity:
		seed_val = poi.identity.dungeon_seed

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + 31415

	var poi_pos: Vector3 = poi.world_position if poi != null and "world_position" in poi else Vector3.ZERO

	# Obtener malla de roca estilizada procedural
	var rock_gen = _RockGenScript.new(seed_val)
	var rock_mesh: Mesh = rock_gen.get_mesh(_RockSizeConfigScript.Category.MEDIUM, 0)
	if rock_mesh == null:
		var box := BoxMesh.new()
		box.size = Vector3(1.4, 0.9, 1.2)
		rock_mesh = box

	# Material oscuro de pizarra/granito funerario
	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.18, 0.17, 0.20)
	dark_mat.roughness = 0.95
	dark_mat.metallic = 0.05

	# Decidir número de rocas (entre 4 y 8)
	var rock_count: int = rng.randi_range(5, 8)
	var transforms: Array[Transform3D] = []

	# Ubicar 2-3 pequeños cúmulos alrededor de la entrada
	var num_clusters: int = 3
	var cluster_angles: Array[float] = []
	for c in range(num_clusters):
		cluster_angles.append(rng.randf_range(0.0, TAU))

	for i in range(rock_count):
		var cluster_idx: int = i % num_clusters
		var base_angle: float = cluster_angles[cluster_idx]
		var angle: float = base_angle + rng.randf_range(-0.4, 0.4)
		
		# Distancia entre clearance radius (4.5m) y funeral/corruption (16m)
		var dist: float = rng.randf_range(profile.entrance_clear_radius + 1.2, profile.funeral_ground_radius + 2.0)
		
		var lx: float = cos(angle) * dist
		var lz: float = sin(angle) * dist
		var wx: float = poi_pos.x + lx
		var wz: float = poi_pos.z + lz

		var wy: float = poi_pos.y
		if world_query != null and world_query.has_method("get_elevation"):
			wy = world_query.get_elevation(int(round(wx)), int(round(wz)))

		var ly: float = wy - poi_pos.y

		# Escala aleatoria y rotación desordenada
		var s: float = rng.randf_range(0.7, 1.6)
		var basis := Basis()
		basis = basis.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
		basis = basis.rotated(Vector3.RIGHT, rng.randf_range(-0.15, 0.15))
		basis = basis.rotated(Vector3.FORWARD, rng.randf_range(-0.15, 0.15))
		basis = basis.scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s))

		var t := Transform3D(basis, Vector3(lx, ly, lz))
		transforms.append(t)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = rock_mesh
	multimesh.instance_count = transforms.size()

	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "DarkRocksMultiMesh"
	mmi.multimesh = multimesh
	mmi.material_override = dark_mat
	mmi.set_meta("rock_transforms", transforms)

	root.add_child(mmi)
	return root
