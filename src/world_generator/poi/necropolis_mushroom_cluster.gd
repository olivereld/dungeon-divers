class_name NecropolisMushroomCluster
extends RefCounted

## Generador de micro-racimos de hongos corruptos/necróticos (0.15m–0.60m)
## para acentuar tocones, troncos caídos y rocas oscuras de la Necrópolis.

const _ScattererScript = preload("res://src/world_generator/poi/poi_ground_decoration_spawner.gd")
const MUSHROOM_TEX_PATH: String = "res://assets/texture/foliage/mushrooms/mushroom_budge_1.jpg"

static var _cached_mesh: Mesh = null
static var _cached_mat: StandardMaterial3D = null

static func get_mushroom_mesh() -> Mesh:
	if _cached_mesh != null:
		return _cached_mesh

	# Crear quad vertical doble cruzado (estilo billboard foliage de bajo perfil)
	var arr_mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	var w: float = 0.40
	var h: float = 0.35

	# Plano 1 (Z)
	verts.append(Vector3(-w * 0.5, 0.0, 0.0))
	verts.append(Vector3(w * 0.5, 0.0, 0.0))
	verts.append(Vector3(w * 0.5, h, 0.0))
	verts.append(Vector3(-w * 0.5, h, 0.0))
	for _i in range(4):
		normals.append(Vector3.UP)
	uvs.append(Vector2(0, 1))
	uvs.append(Vector2(1, 1))
	uvs.append(Vector2(1, 0))
	uvs.append(Vector2(0, 0))
	indices.append_array([0, 1, 2, 0, 2, 3])

	# Plano 2 (X) cruzado a 90°
	verts.append(Vector3(0.0, 0.0, -w * 0.5))
	verts.append(Vector3(0.0, 0.0, w * 0.5))
	verts.append(Vector3(0.0, h, w * 0.5))
	verts.append(Vector3(0.0, h, -w * 0.5))
	for _i in range(4):
		normals.append(Vector3.UP)
	uvs.append(Vector2(0, 1))
	uvs.append(Vector2(1, 1))
	uvs.append(Vector2(1, 0))
	uvs.append(Vector2(0, 0))
	indices.append_array([4, 5, 6, 4, 6, 7])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cached_mesh = arr_mesh
	return _cached_mesh

static func get_material() -> StandardMaterial3D:
	if _cached_mat != null:
		return _cached_mat
	var mat := StandardMaterial3D.new()
	if ResourceLoader.exists(MUSHROOM_TEX_PATH):
		mat.albedo_texture = load(MUSHROOM_TEX_PATH) as Texture2D
	mat.albedo_color = Color(0.68, 0.65, 0.72) # Matiz pálido/micótico frío
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.35
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_cached_mat = mat
	return _cached_mat

static func build_specs(profile: RefCounted, anchor_points: Array = []) -> Array:
	var spec := _ScattererScript.DecorationSpec.new()
	spec.id = "necropolis_mushrooms"
	spec.mesh = get_mushroom_mesh()
	spec.material = get_material()
	spec.density = profile.mushroom_density if "mushroom_density" in profile else 0.08
	spec.min_distance = 1.0
	spec.scale_min = profile.mushroom_scale_min if "mushroom_scale_min" in profile else 0.65
	spec.scale_max = profile.mushroom_scale_max if "mushroom_scale_max" in profile else 1.15
	spec.radius_min = profile.entrance_clear_radius + 0.8
	spec.radius_max = profile.corruption_radius + 6.0
	spec.forbidden_radius = profile.entrance_clear_radius
	spec.ground_embed_m = 0.02
	spec.align_to_terrain = true
	spec.cluster_anchor_points = anchor_points
	spec.cluster_bias = 0.65 # Fuerte atracción hacia tocones, troncos y rocas

	return [spec]
