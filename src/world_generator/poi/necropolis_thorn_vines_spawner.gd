class_name NecropolisThornVinesSpawner
extends RefCounted

## Spawner determinista de enredaderas y raíces con espinas (thorn vines) alrededor de la Necrópolis.
## Genera cúmulos de zarzas retorcidas y secas con textura de corteza pútrida (dead_tree_01_Arbol.png)
## en la base de la cripta, entre las rocas oscuras, los árboles muertos y la zona funeraria.

const _FoliageRendererScript = preload("res://src/world_generator/foliage/rendering/foliage_renderer.gd")
const _FoliageMultiMeshBuilderScript = preload("res://src/world_generator/foliage/rendering/foliage_multimesh_builder.gd")
const _EvaluatorScript = preload("res://src/world_generator/poi/necropolis_influence_evaluator.gd")
const _ProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")

static func generate_thorn_vines(
	poi: RefCounted,
	profile: RefCounted = null,
	world_query: Object = null
) -> Node3D:
	if profile == null:
		profile = _ProfileScript.new()

	var root := Node3D.new()
	root.name = "ThornVines"

	var seed_val: int = 12345
	if poi != null and "identity" in poi and poi.identity != null and "dungeon_seed" in poi.identity:
		seed_val = poi.identity.dungeon_seed

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + 77713

	var poi_pos: Vector3 = poi.world_position if (poi != null and "world_position" in poi) else Vector3.ZERO
	var ori_deg: float = poi.orientation_deg if (poi != null and "orientation_deg" in poi) else 0.0

	var fwd_3d: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(ori_deg))
	var right_3d: Vector3 = Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(ori_deg))

	# 4 colecciones de transforms y colores, una por cada variante de thorn_vines (1 a 4)
	var species_instances: Array[Array] = [[], [], [], []]
	var species_colors: Array[PackedColorArray] = [PackedColorArray(), PackedColorArray(), PackedColorArray(), PackedColorArray()]

	# 1. Cúmulo denso abrazando la base y laterales de la cripta (raíces trepando por la piedra)
	# La cripta mide ~3.4m ancho x 4.8m fondo.
	var crypt_perimeter_samples: int = rng.randi_range(16, 22)
	for i in range(crypt_perimeter_samples):
		var side_sign: float = -1.0 if rng.randf() < 0.5 else 1.0
		# Laterales o parte trasera de la cripta
		var local_x: float = side_sign * rng.randf_range(1.6, 2.8)
		var local_z: float = rng.randf_range(-3.2, 0.4)
		if rng.randf() < 0.35:
			# Parte trasera de la cripta
			local_x = rng.randf_range(-2.0, 2.0)
			local_z = rng.randf_range(-3.6, -2.4)

		var world_pt_3d := poi_pos + right_3d * local_x + fwd_3d * local_z
		_try_spawn_vine(
			world_pt_3d,
			poi_pos,
			ori_deg,
			rng,
			world_query,
			species_instances,
			species_colors,
			profile,
			1.3,
			2.2
		)

	# 2. Cúmulos orgánicos en el suelo funerario (alrededor de rocas oscuras y árboles muertos)
	var field_clusters: int = rng.randi_range(6, 9)
	for c in range(field_clusters):
		var c_angle := rng.randf_range(0.0, TAU)
		var c_dist := rng.randf_range(profile.entrance_clear_radius + 0.8, profile.funeral_ground_radius - 0.5)
		var c_center_x := poi_pos.x + cos(c_angle) * c_dist
		var c_center_z := poi_pos.z + sin(c_angle) * c_dist

		# Descartar si cae dentro del pasillo frontal de entrada a la cripta
		if _EvaluatorScript.is_in_frontal_corridor(Vector2(c_center_x, c_center_z), Vector2(poi_pos.x, poi_pos.z), ori_deg, 9.0, 3.2):
			continue

		var vines_in_cluster: int = rng.randi_range(5, 9)
		for v in range(vines_in_cluster):
			var r_offset := rng.randf_range(0.3, 2.2)
			var a_offset := rng.randf_range(0.0, TAU)
			var vx := c_center_x + cos(a_offset) * r_offset
			var vz := c_center_z + sin(a_offset) * r_offset

			_try_spawn_vine(
				Vector3(vx, poi_pos.y, vz),
				poi_pos,
				ori_deg,
				rng,
				world_query,
				species_instances,
				species_colors,
				profile,
				1.1,
				1.9
			)

	# 3. Zarzas dispersas en la zona de corrupción extendida (12m a 20m)
	var extended_vines: int = rng.randi_range(18, 28)
	for e in range(extended_vines):
		var e_angle := rng.randf_range(0.0, TAU)
		var e_dist := rng.randf_range(profile.funeral_ground_radius, profile.corruption_radius - 1.5)
		var ex := poi_pos.x + cos(e_angle) * e_dist
		var ez := poi_pos.z + sin(e_angle) * e_dist

		if _EvaluatorScript.is_in_frontal_corridor(Vector2(ex, ez), Vector2(poi_pos.x, poi_pos.z), ori_deg, 9.0, 3.2):
			continue

		_try_spawn_vine(
			Vector3(ex, poi_pos.y, ez),
			poi_pos,
			ori_deg,
			rng,
			world_query,
			species_instances,
			species_colors,
			profile,
			1.2,
			2.0
		)

	# Construir MultiMeshInstance3D para cada variante con instancias
	for sp_idx in range(4):
		var instances = species_instances[sp_idx]
		if instances.is_empty():
			continue

		var species = _FoliageRendererScript.create_thorn_vines_species(sp_idx + 1)
		var colors = species_colors[sp_idx]

		var mmi = _FoliageMultiMeshBuilderScript.build_multimesh(
			species,
			instances,
			colors,
			Vector3.ZERO, # Ya están en espacio local relativo a poi_pos
			0.08,
			0.8
		)
		if mmi != null:
			mmi.name = "ThornVines_0%d" % (sp_idx + 1)
			root.add_child(mmi)

	return root

static func _try_spawn_vine(
	target_pos: Vector3,
	poi_pos: Vector3,
	ori_deg: float,
	rng: RandomNumberGenerator,
	world_query: Object,
	species_instances: Array[Array],
	species_colors: Array[PackedColorArray],
	profile: RefCounted,
	min_scale: float,
	max_scale: float
) -> void:
	var p2 := Vector2(target_pos.x, target_pos.z)
	var poi_p2 := Vector2(poi_pos.x, poi_pos.z)

	if _EvaluatorScript.is_in_frontal_corridor(p2, poi_p2, ori_deg, 8.5, 3.0):
		return

	if world_query != null and world_query.has_method("is_water") and world_query.is_water(int(round(target_pos.x)), int(round(target_pos.z))):
		return

	var wy: float = poi_pos.y
	if world_query != null and world_query.has_method("get_elevation"):
		wy = world_query.get_elevation(int(round(target_pos.x)), int(round(target_pos.z)))

	# Altura relativa al nodo raíz del POI
	var rel_pos := Vector3(target_pos.x - poi_pos.x, wy - poi_pos.y, target_pos.z - poi_pos.z)

	var rot_y := rng.randf_range(0.0, TAU)
	var s := rng.randf_range(min_scale, max_scale)
	var scale_vec := Vector3(s, s * rng.randf_range(0.85, 1.15), s)

	# Inclinación sutil para dar aspecto enredado y rastrero
	var tilt_x := rng.randf_range(-0.12, 0.12)
	var tilt_z := rng.randf_range(-0.12, 0.12)
	var basis := Basis.from_euler(Vector3(tilt_x, rot_y, tilt_z)).scaled(scale_vec)

	var xf := Transform3D(basis, rel_pos)

	var chosen_sp: int = rng.randi() % 4
	species_instances[chosen_sp].append(xf)

	# Tinte sutil marrón leñoso cálido para realzar el contraste sobre la corrupción oscura
	var tint_lum := rng.randf_range(0.95, 1.10)
	var col := Color(tint_lum * 1.05, tint_lum * 0.98, tint_lum * 0.90, 1.0)
	species_colors[chosen_sp].append(col)
