class_name BonePatchGenerator
extends RefCounted

## Generador determinista de parches de restos óseos (huesos y telas funerarias) en clusters orgánicos.
## Utiliza MultiMeshInstance3D con quads horizontales a ras de suelo orientados sobre el terreno.
## Implementa shaders de extracción de alpha y superposición estratificada (layering) para que
## las telarañas se posen de forma translúcida/aditiva sobre los restos óseos y el terreno sin cajas negras.

const BONE_TEXTURES: Array[String] = [
	"res://assets/texture/foliage/Bones/bones_patch_01.jpg",
	"res://assets/texture/foliage/Bones/bones_patch_02.jpg",
	"res://assets/texture/foliage/Bones/bones_patch_03.jpg",
	"res://assets/texture/foliage/Bones/bones_patch_04.jpg",
]

const WEB_TEXTURE: String = "res://assets/texture/foliage/Bones/web_patch_01.jpg"

const _BoneShader = preload("res://src/world_renderer/shaders/bone_patch.gdshader")
const _WebShader = preload("res://src/world_renderer/shaders/web_patch.gdshader")

static var _cached_bone_materials: Array[ShaderMaterial] = []
static var _cached_web_material: ShaderMaterial = null

static func _get_bone_materials() -> Array[ShaderMaterial]:
	if _cached_bone_materials.is_empty():
		for path in BONE_TEXTURES:
			var mat := ShaderMaterial.new()
			mat.shader = _BoneShader
			if ResourceLoader.exists(path):
				var tex := load(path) as Texture2D
				mat.set_shader_parameter("texture_albedo", tex)
			mat.set_shader_parameter("tint_color", Vector3(0.72, 0.70, 0.62))
			mat.set_shader_parameter("threshold", 0.06)
			mat.set_shader_parameter("softness", 0.10)
			_cached_bone_materials.append(mat)
	return _cached_bone_materials

static func _get_web_material() -> ShaderMaterial:
	if _cached_web_material == null:
		var mat := ShaderMaterial.new()
		mat.shader = _WebShader
		if ResourceLoader.exists(WEB_TEXTURE):
			var tex := load(WEB_TEXTURE) as Texture2D
			mat.set_shader_parameter("texture_albedo", tex)
		# Tinte tenue blanquecino/grisáceo con 40% de opacidad para fundirse sutilmente con el suelo
		mat.set_shader_parameter("tint_color", Vector4(0.65, 0.68, 0.72, 0.40))
		mat.set_shader_parameter("brightness_boost", 0.85)
		mat.set_shader_parameter("threshold", 0.04)
		mat.set_shader_parameter("softness", 0.15)
		_cached_web_material = mat
	return _cached_web_material

const _EvaluatorScript = preload("res://src/world_generator/poi/necropolis_influence_evaluator.gd")

static func generate_bone_patches(poi: RefCounted, profile: RefCounted, world_query: Object) -> Node3D:
	var container := Node3D.new()
	container.name = "BonePatches"

	var seed_val: int = poi.identity.dungeon_seed if (poi != null and "identity" in poi and poi.identity != null) else 1337
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val ^ 0xB0AE5

	var poi_pos: Vector3 = poi.world_position if (poi != null and "world_position" in poi) else Vector3.ZERO
	var ori_deg: float = poi.orientation_deg if (poi != null and "orientation_deg" in poi) else 0.0
	var fwd_3d: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(ori_deg))
	var fwd_angle: float = atan2(fwd_3d.z, fwd_3d.x)

	var bone_materials := _get_bone_materials()
	var web_material := _get_web_material()

	var bone_instances: Array[Array] = []
	for i in range(bone_materials.size()):
		bone_instances.append([])

	var web_transforms: Array[Transform3D] = []

	var clear_r: float = profile.entrance_clear_radius if "entrance_clear_radius" in profile else 5.5

	# Clusters organizados con intención narrativa y focal:
	# 1. Dos túmulos osarios principales flanqueando las escaleras de la cripta (alta concentración)
	# 2. Cúmulos secundarios en el cementerio (Ring 2) junto a árboles muertos y monolitos
	# 3. Pequeños fragmentos aislados en la transición exterior
	var cluster_configs: Array[Dictionary] = [
		# Osario Mayor Izquierdo (flanco frontal de la cripta)
		{ "angle_offset": deg_to_rad(-65.0), "dist_min": 5.6, "dist_max": 7.0, "count": rng.randi_range(5, 7), "web_prob": 1.0, "sub_radius": 1.4 },
		# Osario Mayor Derecho (flanco frontal de la cripta)
		{ "angle_offset": deg_to_rad(66.0),  "dist_min": 5.8, "dist_max": 7.2, "count": rng.randi_range(5, 7), "web_prob": 1.0, "sub_radius": 1.4 },
		# Cúmulos cementerio lateral/trasera
		{ "angle_offset": deg_to_rad(-115.0),"dist_min": 8.0, "dist_max": 11.0,"count": rng.randi_range(3, 4), "web_prob": 0.8, "sub_radius": 1.8 },
		{ "angle_offset": deg_to_rad(112.0), "dist_min": 8.5, "dist_max": 11.5,"count": rng.randi_range(3, 4), "web_prob": 0.8, "sub_radius": 1.8 },
		{ "angle_offset": deg_to_rad(162.0), "dist_min": 9.0, "dist_max": 12.5,"count": rng.randi_range(2, 3), "web_prob": 0.6, "sub_radius": 1.6 },
		# Acentos aislados en borde
		{ "angle_offset": deg_to_rad(-140.0),"dist_min": 12.5,"dist_max": 15.5,"count": 1, "web_prob": 0.3, "sub_radius": 0.8 },
		{ "angle_offset": deg_to_rad(140.0), "dist_min": 13.0,"dist_max": 16.0,"count": 1, "web_prob": 0.3, "sub_radius": 0.8 }
	]

	for cfg in cluster_configs:
		var base_angle: float = fwd_angle + cfg.angle_offset + rng.randf_range(-0.15, 0.15)
		var dist: float = rng.randf_range(cfg.dist_min, cfg.dist_max)
		var cluster_center_x: float = poi_pos.x + cos(base_angle) * dist
		var cluster_center_z: float = poi_pos.z + sin(base_angle) * dist

		var count: int = cfg.count
		for p in range(count):
			var sub_angle: float = rng.randf() * TAU
			var sub_dist: float = rng.randf_range(0.2, cfg.sub_radius)
			var wx: float = cluster_center_x + cos(sub_angle) * sub_dist
			var wz: float = cluster_center_z + sin(sub_angle) * sub_dist
			var p2 := Vector2(wx, wz)

			# Despeje estricto: NUNCA en el corredor frontal de entrada
			if _EvaluatorScript.is_in_frontal_corridor(p2, Vector2(poi_pos.x, poi_pos.z), ori_deg, 8.0, 3.2):
				continue
			var dist_to_entrance: float = (p2 - Vector2(poi_pos.x, poi_pos.z)).length()
			if dist_to_entrance <= clear_r:
				continue

			if world_query != null and world_query.has_method("is_water") and world_query.is_water(int(round(wx)), int(round(wz))):
				continue

			var wy: float = poi_pos.y
			var h_e := wy
			var h_w := wy
			var h_s := wy
			var h_n := wy
			if world_query != null and world_query.has_method("get_elevation"):
				wy = world_query.get_elevation(int(round(wx)), int(round(wz)))
				h_e = world_query.get_elevation(int(round(wx + 0.6)), int(round(wz)))
				h_w = world_query.get_elevation(int(round(wx - 0.6)), int(round(wz)))
				h_s = world_query.get_elevation(int(round(wx)), int(round(wz + 0.6)))
				h_n = world_query.get_elevation(int(round(wx)), int(round(wz - 0.6)))
				var max_diff: float = maxf(maxf(absf(h_e - wy), absf(h_w - wy)), maxf(absf(h_s - wy), absf(h_n - wy)))
				if max_diff > 0.25:
					continue

			var sc_min: float = profile.bone_patch_scale_min if "bone_patch_scale_min" in profile else 0.7
			var sc_max: float = profile.bone_patch_scale_max if "bone_patch_scale_max" in profile else 1.15
			var patch_scale: float = rng.randf_range(sc_min, sc_max)

			var ground_normal := Vector3(h_w - h_e, 1.2, h_n - h_s).normalized()
			var patch_basis := Basis()
			if ground_normal.dot(Vector3.UP) < 0.999:
				var rot_axis := Vector3.UP.cross(ground_normal).normalized()
				var rot_angle := acos(clampf(Vector3.UP.dot(ground_normal), -1.0, 1.0))
				patch_basis = patch_basis.rotated(rot_axis, rot_angle)
			patch_basis = patch_basis.rotated(ground_normal, rng.randf() * TAU)
			patch_basis = patch_basis.scaled(Vector3(patch_scale, 1.0, patch_scale))

			# Plano base de huesos: rasante a +0.012m para estar al ras del suelo
			var bone_elevation: float = (wy - poi_pos.y) + 0.012
			var xf := Transform3D(patch_basis, Vector3(wx - poi_pos.x, bone_elevation, wz - poi_pos.z))

			var tex_idx: int = rng.randi() % bone_materials.size()
			bone_instances[tex_idx].append(xf)

		# Superposición (Layering): telaraña translúcida en un plano superior sobre el cúmulo
		if rng.randf() < cfg.web_prob:
			var web_p2 := Vector2(cluster_center_x, cluster_center_z)
			if not _EvaluatorScript.is_in_frontal_corridor(web_p2, Vector2(poi_pos.x, poi_pos.z), ori_deg, 8.0, 3.2):
				var web_dist_to_entrance: float = (web_p2 - Vector2(poi_pos.x, poi_pos.z)).length()
				if web_dist_to_entrance > clear_r:
					if not (world_query != null and world_query.has_method("is_water") and world_query.is_water(int(round(cluster_center_x)), int(round(cluster_center_z)))):
						var web_wy: float = poi_pos.y
						var wh_e := web_wy
						var wh_w := web_wy
						var wh_s := web_wy
						var wh_n := web_wy
						if world_query != null and world_query.has_method("get_elevation"):
							web_wy = world_query.get_elevation(int(round(cluster_center_x)), int(round(cluster_center_z)))
							wh_e = world_query.get_elevation(int(round(cluster_center_x + 0.6)), int(round(cluster_center_z)))
							wh_w = world_query.get_elevation(int(round(cluster_center_x - 0.6)), int(round(cluster_center_z)))
							wh_s = world_query.get_elevation(int(round(cluster_center_x)), int(round(cluster_center_z + 0.6)))
							wh_n = world_query.get_elevation(int(round(cluster_center_x)), int(round(cluster_center_z - 0.6)))
							var web_diff: float = maxf(maxf(absf(wh_e - web_wy), absf(wh_w - web_wy)), maxf(absf(wh_s - web_wy), absf(wh_n - web_wy)))
							if web_diff <= 0.25:
								var web_scale: float = rng.randf_range(0.85, 1.25)
								var web_normal := Vector3(wh_w - wh_e, 1.2, wh_n - wh_s).normalized()
								var web_basis := Basis()
								if web_normal.dot(Vector3.UP) < 0.999:
									var rot_axis := Vector3.UP.cross(web_normal).normalized()
									var rot_angle := acos(clampf(Vector3.UP.dot(web_normal), -1.0, 1.0))
									web_basis = web_basis.rotated(rot_axis, rot_angle)
								web_basis = web_basis.rotated(web_normal, rng.randf() * TAU)
								web_basis = web_basis.scaled(Vector3(web_scale, 1.0, web_scale))

								# Plano superior de telarañas: rasante a +0.020m sobre los restos
								var web_elevation: float = (web_wy - poi_pos.y) + 0.020
								var web_xf := Transform3D(web_basis, Vector3(cluster_center_x - poi_pos.x, web_elevation, cluster_center_z - poi_pos.z))
								web_transforms.append(web_xf)

	# 4. Crear MultiMeshInstance3D para cada grupo de huesos
	var bone_quad_mesh := QuadMesh.new()
	bone_quad_mesh.size = Vector2(1.1, 1.1)
	bone_quad_mesh.orientation = QuadMesh.FACE_Y

	for i in range(bone_materials.size()):
		var transforms: Array = bone_instances[i]
		if transforms.is_empty():
			continue

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "BonesGroup_%d" % i
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = bone_quad_mesh
		mm.instance_count = transforms.size()

		for j in range(transforms.size()):
			mm.set_instance_transform(j, transforms[j])

		mmi.multimesh = mm
		mmi.material_override = bone_materials[i]
		mmi.set_meta("patch_transforms", transforms)
		mmi.set_meta("is_web", false)
		container.add_child(mmi)

	# 5. Crear MultiMeshInstance3D para las telarañas translúcidas superpuestas
	if not web_transforms.is_empty():
		var web_quad_mesh := QuadMesh.new()
		web_quad_mesh.size = Vector2(1.3, 1.3)
		web_quad_mesh.orientation = QuadMesh.FACE_Y

		var web_mmi := MultiMeshInstance3D.new()
		web_mmi.name = "WebsGroup"
		var web_mm := MultiMesh.new()
		web_mm.transform_format = MultiMesh.TRANSFORM_3D
		web_mm.mesh = web_quad_mesh
		web_mm.instance_count = web_transforms.size()

		for j in range(web_transforms.size()):
			web_mm.set_instance_transform(j, web_transforms[j])

		web_mmi.multimesh = web_mm
		web_mmi.material_override = web_material
		web_mmi.set_meta("patch_transforms", web_transforms)
		web_mmi.set_meta("is_web", true)
		container.add_child(web_mmi)

	return container
