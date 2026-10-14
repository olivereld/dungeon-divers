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

static func generate_bone_patches(poi: RefCounted, profile: RefCounted, world_query: Object) -> Node3D:
	var container := Node3D.new()
	container.name = "BonePatches"

	var seed_val: int = poi.identity.dungeon_seed if (poi != null and "identity" in poi and poi.identity != null) else 1337
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val ^ 0xB0AE5

	var poi_pos: Vector3 = poi.world_position if (poi != null and "world_position" in poi) else Vector3.ZERO
	var bone_materials := _get_bone_materials()
	var web_material := _get_web_material()

	var bone_instances: Array[Array] = []
	for i in range(bone_materials.size()):
		bone_instances.append([])

	var web_transforms: Array[Transform3D] = []

	# 1. Generar 5 a 8 centros de clusters orgánicos dentro del cementerio
	var num_clusters: int = rng.randi_range(5, 8)
	var clear_r: float = profile.entrance_clear_radius if "entrance_clear_radius" in profile else 4.5
	var funeral_r: float = profile.funeral_ground_radius if "funeral_ground_radius" in profile else 14.0

	for c in range(num_clusters):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(clear_r + 1.2, funeral_r)
		var cluster_center_x: float = poi_pos.x + cos(angle) * dist
		var cluster_center_z: float = poi_pos.z + sin(angle) * dist

		# 2. Generar 2 a 4 parches de huesos por cluster en el plano base (capa inferior)
		var count: int = rng.randi_range(2, 4)
		for p in range(count):
			var sub_angle: float = rng.randf() * TAU
			var sub_dist: float = rng.randf_range(0.3, 1.8)
			var wx: float = cluster_center_x + cos(sub_angle) * sub_dist
			var wz: float = cluster_center_z + sin(sub_angle) * sub_dist

			# Respetar radio de despeje de la entrada
			var dist_to_entrance: float = (Vector2(wx, wz) - Vector2(poi_pos.x, poi_pos.z)).length()
			if dist_to_entrance <= clear_r:
				continue

			# Evitar generar restos dentro de cuerpos de agua
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
					# Borde de terraza o acantilado: no colocar parche aquí porque levitaría
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

		# 3. Superposición (Layering): telaraña en un plano superior sobre el cúmulo de huesos
		if rng.randf() < 0.75:
			var web_dist_to_entrance: float = (Vector2(cluster_center_x, cluster_center_z) - Vector2(poi_pos.x, poi_pos.z)).length()
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
						if web_diff > 0.25:
							continue

					var web_scale: float = rng.randf_range(0.85, 1.15)
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
