class_name ProceduralRockGenerator
extends RefCounted

## Generador procedural de mallas de rocas estilizadas (low-poly hand-painted)
## Crea múltiples variantes de rocas (peñascos, lajas planas, monolitos angulares, etc.)
## deformadas mediante 3D FastNoiseLite y sombreado facetado.

const STONE_TEXTURE_01: String = "res://assets/texture/world/stone/Stone_01.png"
const STONE_TEXTURE_02: String = "res://assets/texture/world/stone/Stone_02.png"

static var _cached_variants: Array[Mesh] = []

## Configuración de arquetipo de roca procedural
class RockArchetype:
	var name: String
	var scale_dims: Vector3
	var noise_freq: float
	var noise_strength: float
	var noise_type: FastNoiseLite.NoiseType
	var bottom_flatten: float
	var shape_modifier: int # 0: Boulder, 1: Slab, 2: Crag, 3: Wedge, 4: Pyramid, 5: Twin
	var tint: Color
	var texture_path: String

	func _init(
		p_name: String,
		p_dims: Vector3,
		p_freq: float,
		p_strength: float,
		p_flatten: float,
		p_modifier: int,
		p_tint: Color,
		p_tex: String = STONE_TEXTURE_01
	) -> void:
		name = p_name
		scale_dims = p_dims
		noise_freq = p_freq
		noise_strength = p_strength
		bottom_flatten = p_flatten
		shape_modifier = p_modifier
		tint = p_tint
		texture_path = p_tex

## Devuelve la lista de variantes de mallas de roca procedurales cacheadas
static func get_rock_variants(force_refresh: bool = false) -> Array[Mesh]:
	if not _cached_variants.is_empty() and not force_refresh:
		return _cached_variants

	_cached_variants.clear()
	var archetypes: Array[RockArchetype] = _get_archetype_definitions()

	for i in range(archetypes.size()):
		var arch := archetypes[i]
		var seed_val := 1337 + i * 997
		var mesh := _generate_rock_mesh(arch, seed_val)
		_cached_variants.append(mesh)

	return _cached_variants

static func _get_archetype_definitions() -> Array[RockArchetype]:
	return [
		# 0. Peñasco redondeado clásico de taiga (Granite Boulder)
		RockArchetype.new(
			"Boulder",
			Vector3(1.15, 0.85, 1.05),
			1.4, 0.22, 0.55, 0,
			Color(0.92, 0.92, 0.94),
			STONE_TEXTURE_01
		),
		# 1. Laja plana de ribera / roca tabular (River Slab)
		RockArchetype.new(
			"RiverSlab",
			Vector3(1.45, 0.42, 1.25),
			1.8, 0.16, 0.80, 1,
			Color(0.88, 0.90, 0.92),
			STONE_TEXTURE_02
		),
		# 2. Monolito escarpado / risco angular (Sharp Crag)
		RockArchetype.new(
			"SharpCrag",
			Vector3(0.85, 1.35, 0.90),
			2.2, 0.32, 0.40, 2,
			Color(0.85, 0.86, 0.88),
			STONE_TEXTURE_01
		),
		# 3. Roca en cuña inclinada (Wedge Rock)
		RockArchetype.new(
			"WedgeRock",
			Vector3(1.30, 0.75, 0.95),
			1.6, 0.24, 0.60, 3,
			Color(0.94, 0.92, 0.89),
			STONE_TEXTURE_01
		),
		# 4. Afloramiento piramidal facetado (Pyramid Outcrop)
		RockArchetype.new(
			"PyramidOutcrop",
			Vector3(1.10, 1.05, 1.10),
			1.9, 0.28, 0.50, 4,
			Color(0.90, 0.92, 0.90),
			STONE_TEXTURE_02
		),
		# 5. Roca compuesta bífida / doble joroba (Twin Lobe)
		RockArchetype.new(
			"TwinLobe",
			Vector3(1.40, 0.78, 0.90),
			1.5, 0.25, 0.65, 5,
			Color(0.91, 0.91, 0.93),
			STONE_TEXTURE_01
		),
	]

## Genera una malla de ArrayMesh de roca única a partir de un icosaedro subdividido y deformado
static func _generate_rock_mesh(arch: RockArchetype, seed_val: int) -> ArrayMesh:
	# 1. Generar icosaedro base (12 vértices normalizados, 20 triángulos)
	var phi: float = (1.0 + sqrt(5.0)) * 0.5
	var base_verts: Array[Vector3] = [
		Vector3(-1.0,  phi,  0.0).normalized(),
		Vector3( 1.0,  phi,  0.0).normalized(),
		Vector3(-1.0, -phi,  0.0).normalized(),
		Vector3( 1.0, -phi,  0.0).normalized(),
		Vector3( 0.0, -1.0,  phi).normalized(),
		Vector3( 0.0,  1.0,  phi).normalized(),
		Vector3( 0.0, -1.0, -phi).normalized(),
		Vector3( 0.0,  1.0, -phi).normalized(),
		Vector3( phi,  0.0, -1.0).normalized(),
		Vector3( phi,  0.0,  1.0).normalized(),
		Vector3(-phi,  0.0, -1.0).normalized(),
		Vector3(-phi,  0.0,  1.0).normalized(),
	]

	var base_faces: Array[Vector3i] = [
		Vector3i(0, 11, 5),  Vector3i(0, 5, 1),   Vector3i(0, 1, 7),   Vector3i(0, 7, 10),  Vector3i(0, 10, 11),
		Vector3i(1, 5, 9),   Vector3i(5, 11, 4),  Vector3i(11, 10, 2), Vector3i(10, 7, 6),  Vector3i(7, 1, 8),
		Vector3i(3, 9, 4),   Vector3i(3, 4, 2),   Vector3i(3, 2, 6),   Vector3i(3, 6, 8),   Vector3i(3, 8, 9),
		Vector3i(4, 9, 5),   Vector3i(2, 4, 11),  Vector3i(6, 2, 10),  Vector3i(8, 6, 7),   Vector3i(9, 8, 1)
	]

	# 2. Subdivisión 1 nivel (de 20 a 80 triángulos para el look low-poly estilizado perfecto)
	var verts: Array[Vector3] = base_verts.duplicate()
	var midpoint_cache: Dictionary = {}

	var sub_faces: Array[Vector3i] = []
	for tri in base_faces:
		var a: int = _get_midpoint(tri.x, tri.y, verts, midpoint_cache)
		var b: int = _get_midpoint(tri.y, tri.z, verts, midpoint_cache)
		var c: int = _get_midpoint(tri.z, tri.x, verts, midpoint_cache)

		sub_faces.append(Vector3i(tri.x, a, c))
		sub_faces.append(Vector3i(tri.y, b, a))
		sub_faces.append(Vector3i(tri.z, c, b))
		sub_faces.append(Vector3i(a, b, c))

	# 3. Configurar ruido 3D FastNoiseLite
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = arch.noise_freq
	noise.fractal_octaves = 2
	noise.fractal_gain = 0.55

	# 4. Deformación de vértices por arquetipo y ruido
	var deformed_verts: Array[Vector3] = []
	deformed_verts.resize(verts.size())

	for i in range(verts.size()):
		var v: Vector3 = verts[i]

		# Desplazamiento por ruido 3D a lo largo de la normal
		var n_disp: float = noise.get_noise_3dv(v * 2.2) * arch.noise_strength
		v += v * n_disp

		# Modificadores de forma específicos por arquetipo
		match arch.shape_modifier:
			0: # Boulder: ligero aplastamiento esferoidal
				pass
			1: # River Slab: compresión vertical y ligera concavidad superior
				v.y *= 0.50
				if v.y > 0.0:
					v.y -= (v.x * v.x + v.z * v.z) * 0.08
			2: # Sharp Crag: corte angular / facetado asimétrico suave
				var diag: float = v.x + v.z
				if diag > 0.40:
					v -= Vector3(0.707, 0.0, 0.707) * ((diag - 0.40) * 0.45)
			3: # Wedge Rock: rampa inclinada en un eje
				v.y += v.x * 0.35
			4: # Pyramid Outcrop: reducción cónica en cúspide
				var taper: float = clampf(1.15 - v.y * 0.40, 0.45, 1.45)
				v.x *= taper
				v.z *= taper
			5: # Twin Lobe: separación suave en dos jorobas simétricas continuas
				v.x += sin(v.x * 3.14159) * 0.20

		# Escala de proporciones del arquetipo
		v.x *= arch.scale_dims.x
		v.y *= arch.scale_dims.y
		v.z *= arch.scale_dims.z

		# Aplanamiento de base para apoyar sólidamente en el suelo
		if v.y < -0.05:
			v.y = lerpf(v.y, -0.22, arch.bottom_flatten)

		deformed_verts[i] = v

	# 5. Generación de mallas con Flat-Shading (facetas nítidas chiseladas)
	var final_verts := PackedVector3Array()
	var final_normals := PackedVector3Array()
	var final_uvs := PackedVector2Array()
	var final_colors := PackedColorArray()
	var final_indices := PackedInt32Array()

	var vert_count := 0
	for tri in sub_faces:
		var v0: Vector3 = deformed_verts[tri.x]
		var v1: Vector3 = deformed_verts[tri.y]
		var v2: Vector3 = deformed_verts[tri.z]

		# En Godot, el orden de vértices que define la cara frontal exterior
		# cumple que (v2 - v0).cross(v1 - v0) apunta hacia afuera del centro del objeto.
		var face_normal := (v2 - v0).cross(v1 - v0).normalized()
		var mid := (v0 + v1 + v2) / 3.0

		# Verificación geométrica estricta: si por alguna deformación la normal
		# apuntara hacia el interior, se invierten v1 y v2 para asegurar que el
		# 100% de las caras exteriores apunten hacia afuera (evitando caras transparentes).
		if face_normal.dot(mid) < 0.0:
			var tmp := v1
			v1 = v2
			v2 = tmp
			face_normal = -face_normal

		if not is_finite(face_normal.x) or face_normal.is_zero_approx():
			face_normal = mid.normalized() if not mid.is_zero_approx() else Vector3.UP

		# Asignar 3 vértices independientes por triángulo para lograr flat shading
		final_verts.append(v0)
		final_verts.append(v1)
		final_verts.append(v2)

		final_normals.append(face_normal)
		final_normals.append(face_normal)
		final_normals.append(face_normal)

		# Coordenadas UV cilíndricas/esféricas locales
		final_uvs.append(Vector2(v0.x * 0.5 + 0.5, v0.z * 0.5 + 0.5))
		final_uvs.append(Vector2(v1.x * 0.5 + 0.5, v1.z * 0.5 + 0.5))
		final_uvs.append(Vector2(v2.x * 0.5 + 0.5, v2.z * 0.5 + 0.5))

		# Sutil gradiente de oclusión en base para arraigo en el terreno
		var c0 := Color(1.0, 1.0, 1.0) * (0.80 + 0.20 * clampf(v0.y + 0.35, 0.0, 1.0))
		var c1 := Color(1.0, 1.0, 1.0) * (0.80 + 0.20 * clampf(v1.y + 0.35, 0.0, 1.0))
		var c2 := Color(1.0, 1.0, 1.0) * (0.80 + 0.20 * clampf(v2.y + 0.35, 0.0, 1.0))
		final_colors.append(c0)
		final_colors.append(c1)
		final_colors.append(c2)

		final_indices.append(vert_count)
		final_indices.append(vert_count + 1)
		final_indices.append(vert_count + 2)
		vert_count += 3

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = final_verts
	arrays[Mesh.ARRAY_NORMAL] = final_normals
	arrays[Mesh.ARRAY_TEX_UV] = final_uvs
	arrays[Mesh.ARRAY_COLOR] = final_colors
	arrays[Mesh.ARRAY_INDEX] = final_indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# 6. Material de roca con textura Stone hand-painted y Triplanar local
	var mat := StandardMaterial3D.new()
	if ResourceLoader.exists(arch.texture_path):
		var tex: Texture2D = load(arch.texture_path)
		mat.albedo_texture = tex
	mat.albedo_color = arch.tint
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = false # Local para proyectar armónicamente con la rotación de cada roca
	mat.uv1_scale = Vector3(0.60, 0.60, 0.60)
	mat.roughness = 0.88
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat.metallic = 0.0
	mat.metallic_specular = 0.05

	mesh.surface_set_material(0, mat)
	return mesh

static func _get_midpoint(i1: int, i2: int, verts: Array[Vector3], cache: Dictionary) -> int:
	var key: int = (mini(i1, i2) << 16) | maxi(i1, i2)
	if cache.has(key):
		return cache[key]

	var mid: Vector3 = ((verts[i1] + verts[i2]) * 0.5).normalized()
	verts.append(mid)
	var idx: int = verts.size() - 1
	cache[key] = idx
	return idx
