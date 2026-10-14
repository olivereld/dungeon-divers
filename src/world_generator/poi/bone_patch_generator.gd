class_name BonePatchGenerator
extends RefCounted

## Generador determinista de parches de restos óseos (huesos y telas funerarias) en clusters orgánicos.
## Utiliza MultiMeshInstance3D con quads horizontales a ras de suelo orientados sobre el terreno.

const BONE_TEXTURES: Array[String] = [
	"res://assets/texture/foliage/Bones/bones_patch_01.jpg",
	"res://assets/texture/foliage/Bones/bones_patch_02.jpg",
	"res://assets/texture/foliage/Bones/bones_patch_03.jpg",
	"res://assets/texture/foliage/Bones/bones_patch_04.jpg",
	"res://assets/texture/foliage/Bones/web_patch_01.jpg",
]

static var _cached_materials: Array[StandardMaterial3D] = []

static func _get_materials() -> Array[StandardMaterial3D]:
	if _cached_materials.is_empty():
		for path in BONE_TEXTURES:
			var mat := StandardMaterial3D.new()
			if ResourceLoader.exists(path):
				var tex := load(path) as Texture2D
				mat.albedo_texture = tex
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.alpha_scissor_threshold = 0.25
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.roughness = 0.95
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			_cached_materials.append(mat)
	return _cached_materials

static func generate_bone_patches(poi: RefCounted, profile: RefCounted, world_query: Object) -> Node3D:
	var container := Node3D.new()
	container.name = "BonePatches"

	var seed_val: int = poi.identity.dungeon_seed if (poi != null and "identity" in poi and poi.identity != null) else 1337
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val ^ 0xB0AE5

	var poi_pos: Vector3 = poi.world_position if (poi != null and "world_position" in poi) else Vector3.ZERO
	var materials := _get_materials()
	var instances_by_tex: Array[Array] = []
	for i in range(materials.size()):
		instances_by_tex.append([])

	# 1. Generar 5 a 8 centros de clusters orgánicos dentro del cementerio
	var num_clusters: int = rng.randi_range(5, 8)
	var clear_r: float = profile.entrance_clear_radius if "entrance_clear_radius" in profile else 4.5
	var funeral_r: float = profile.funeral_ground_radius if "funeral_ground_radius" in profile else 14.0

	for c in range(num_clusters):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(clear_r + 1.2, funeral_r)
		var cluster_center_x: float = poi_pos.x + cos(angle) * dist
		var cluster_center_z: float = poi_pos.z + sin(angle) * dist

		# 2. Generar 3 a 5 parches por cluster
		var count: int = rng.randi_range(3, 5)
		for p in range(count):
			var sub_angle: float = rng.randf() * TAU
			var sub_dist: float = rng.randf_range(0.3, 2.4)
			var wx: float = cluster_center_x + cos(sub_angle) * sub_dist
			var wz: float = cluster_center_z + sin(sub_angle) * sub_dist

			# Respetar radio de despeje de la entrada
			var dist_to_entrance: float = (Vector2(wx, wz) - Vector2(poi_pos.x, poi_pos.z)).length()
			if dist_to_entrance <= clear_r:
				continue

			var wy: float = poi_pos.y
			if world_query != null and world_query.has_method("get_elevation"):
				wy = world_query.get_elevation(int(round(wx)), int(round(wz)))

			var sc_min: float = profile.bone_patch_scale_min if "bone_patch_scale_min" in profile else 0.8
			var sc_max: float = profile.bone_patch_scale_max if "bone_patch_scale_max" in profile else 1.6
			var patch_scale: float = rng.randf_range(sc_min, sc_max)

			var xf := Transform3D()
			xf = xf.scaled(Vector3(patch_scale, 1.0, patch_scale))
			xf = xf.rotated(Vector3.UP, rng.randf() * TAU)
			# Posición relativa al nodo POI (o absoluta si poi_pos es el centro)
			xf.origin = Vector3(wx - poi_pos.x, (wy - poi_pos.y) + 0.04, wz - poi_pos.z)

			var tex_idx: int = rng.randi() % materials.size()
			instances_by_tex[tex_idx].append(xf)

	# 3. Crear MultiMeshInstance3D por cada textura
	var quad := QuadMesh.new()
	quad.size = Vector2(2.2, 2.2)
	quad.orientation = QuadMesh.FACE_Y

	for i in range(materials.size()):
		var transforms: Array = instances_by_tex[i]
		if transforms.is_empty():
			continue

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "BonesGroup_%d" % i
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = quad
		mm.instance_count = transforms.size()

		for j in range(transforms.size()):
			mm.set_instance_transform(j, transforms[j])

		mmi.multimesh = mm
		mmi.material_override = materials[i]
		container.add_child(mmi)

	return container
