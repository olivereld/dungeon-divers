class_name NecropolisRockCluster
extends RefCounted

const _ProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")
const _RockGenScript = preload("res://src/rock_generation/rock_generation.gd")
const _RockSizeConfigScript = preload("res://src/rock_generation/config/rock_size_config.gd")
const _RockMaterialScript = preload("res://src/rock_generation/rock_material.gd")
const _EvaluatorScript = preload("res://src/world_generator/poi/necropolis_influence_evaluator.gd")

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

	# Material estilizado con gradiente de facetas y matiz frío/oscuro de pizarra antigua
	var dark_mat: ShaderMaterial = _RockMaterialScript.create_rock_material(
		null,
		-0.35,
		1.9,
		0.94,
		Color(0.36, 0.34, 0.42)
	)

	var ori_deg: float = poi.orientation_deg if (poi != null and "orientation_deg" in poi) else 0.0
	var fwd_3d: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(ori_deg))
	var fwd_angle: float = atan2(fwd_3d.z, fwd_3d.x)

	# Ubicar rocas agrupadas deliberadamente en los flancos y trasera (tipo megalitos funerarios)
	var cluster_offsets: Array[float] = [
		deg_to_rad(-85.0), # Flanco izquierdo
		deg_to_rad(80.0),  # Flanco derecho
		deg_to_rad(165.0)  # Trasera profunda
	]

	var rock_count: int = rng.randi_range(5, 7)
	var transforms: Array[Transform3D] = []

	for i in range(rock_count):
		var base_offset: float = cluster_offsets[i % cluster_offsets.size()]
		var angle: float = fwd_angle + base_offset + rng.randf_range(-0.35, 0.35)
		
		# Distancia en Ring 2 (Graveyard: 6.5m - 12.0m)
		var dist: float = rng.randf_range(profile.entrance_clear_radius + 1.2, profile.funeral_ground_radius - 0.5)
		
		var lx: float = cos(angle) * dist
		var lz: float = sin(angle) * dist
		var wx: float = poi_pos.x + lx
		var wz: float = poi_pos.z + lz
		var p2 := Vector2(wx, wz)

		# Evitar corredor frontal de entrada y Crypt Core
		if _EvaluatorScript.is_in_frontal_corridor(p2, Vector2(poi_pos.x, poi_pos.z), ori_deg, 8.5, 3.5):
			continue
		if (p2 - Vector2(poi_pos.x, poi_pos.z)).length() < profile.entrance_clear_radius:
			continue

		# Evitar agua
		if world_query != null and world_query.has_method("is_water") and world_query.is_water(int(round(wx)), int(round(wz))):
			continue

		var wy: float = poi_pos.y
		if world_query != null and world_query.has_method("get_elevation"):
			wy = world_query.get_elevation(int(round(wx)), int(round(wz)))
			var h_e: float = world_query.get_elevation(int(round(wx + 0.8)), int(round(wz)))
			var h_s: float = world_query.get_elevation(int(round(wx)), int(round(wz + 0.8)))
			if absf(h_e - wy) > 0.40 or absf(h_s - wy) > 0.40:
				continue

		# Asentar la base de la roca ligeramente en el suelo (-0.08m)
		var ly: float = (wy - poi_pos.y) - 0.08

		# Escala aleatoria y rotación desordenada
		var s: float = rng.randf_range(0.75, 1.45)
		var basis := Basis()
		basis = basis.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
		basis = basis.rotated(Vector3.RIGHT, rng.randf_range(-0.15, 0.15))
		basis = basis.rotated(Vector3.FORWARD, rng.randf_range(-0.15, 0.15))
		basis = basis.scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s))

		var t := Transform3D(basis, Vector3(lx, ly, lz))
		transforms.append(t)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = rock_mesh
	multimesh.instance_count = transforms.size()

	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_custom_data(i, Color(rng.randf_range(0.2, 0.8), 0.0, 0.0, 1.0))

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "DarkRocksMultiMesh"
	mmi.multimesh = multimesh
	mmi.material_override = dark_mat
	mmi.set_meta("rock_transforms", transforms)

	root.add_child(mmi)
	return root
