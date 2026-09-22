class_name ProceduralRockGenerator
extends RefCounted

## Generador procedural de mallas de rocas estilizadas (low-poly hand-painted)
## Crea múltiples variantes de rocas con grandes facetas cinceladas (bold chiseled planes)
## deformadas mediante 3D FastNoiseLite y sombreadas con shader inteligente:
## - Bordes filosos sutiles con opacidad controlada (líneas blancas suaves y finas)
## - Gradientes según orientación vertical (cielo vs suelo) y dirección solar
## - Gradientes de posición en altura (contacto con tierra vs cresta)
## - Integración de texturas hand-painted con proyección triplanar local

const STONE_TEXTURE_01: String = "res://assets/texture/world/stone/Stone_01.png"
const STONE_TEXTURE_02: String = "res://assets/texture/world/stone/Stone_02.png"
const ROCK_SHADER_PATH: String = "res://src/world_renderer/shaders/rock_stylized.gdshader"

static var _cached_variants: Array[Mesh] = []
static var _cached_shader: Shader = null

static func _get_shader() -> Shader:
	if _cached_shader == null and ResourceLoader.exists(ROCK_SHADER_PATH):
		_cached_shader = load(ROCK_SHADER_PATH) as Shader
	return _cached_shader

## Configuración de arquetipo de roca procedural
class RockArchetype:
	var name: String
	var scale_dims: Vector3
	var noise_freq: float
	var noise_strength: float
	var bottom_flatten: float
	var shape_modifier: int # 0: Boulder, 1: Slab, 2: Crag, 3: Wedge, 4: Pyramid, 5: Twin
	var texture_path: String
	var color_highlight: Color
	var color_top: Color
	var color_mid: Color
	var color_bottom: Color
	var color_crevice: Color
	var edge_width: float
	var edge_opacity: float

	func _init(
		p_name: String,
		p_dims: Vector3,
		p_freq: float,
		p_strength: float,
		p_flatten: float,
		p_modifier: int,
		p_tex: String,
		p_col_hl: Color,
		p_col_top: Color,
		p_col_mid: Color,
		p_col_bot: Color,
		p_col_crevice: Color,
		p_edge_w: float = 0.038,
		p_edge_op: float = 0.35
	) -> void:
		name = p_name
		scale_dims = p_dims
		noise_freq = p_freq
		noise_strength = p_strength
		bottom_flatten = p_flatten
		shape_modifier = p_modifier
		texture_path = p_tex
		color_highlight = p_col_hl
		color_top = p_col_top
		color_mid = p_col_mid
		color_bottom = p_col_bot
		color_crevice = p_col_crevice
		edge_width = p_edge_w
		edge_opacity = p_edge_op

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
		# 0. Peñasco redondeado facetado (Granite Boulder - Ref 1)
		RockArchetype.new(
			"Boulder",
			Vector3(1.15, 0.85, 1.05),
			1.2, 0.20, 0.55, 0,
			STONE_TEXTURE_01,
			Color(0.84, 0.89, 0.95), # Filo blanco azulado sutil
			Color(0.48, 0.54, 0.62), # Cenital
			Color(0.26, 0.30, 0.36), # Grafito medio
			Color(0.13, 0.15, 0.19), # Base en sombra
			Color(0.07, 0.08, 0.11), # Grietas
			0.038, 0.35
		),
		# 1. Laja plana de ribera / roca tabular (River Slab - Ref 1 inferior)
		RockArchetype.new(
			"RiverSlab",
			Vector3(1.50, 0.40, 1.30),
			1.4, 0.15, 0.80, 1,
			STONE_TEXTURE_02,
			Color(0.86, 0.91, 0.96),
			Color(0.50, 0.56, 0.64),
			Color(0.27, 0.31, 0.37),
			Color(0.14, 0.16, 0.20),
			Color(0.07, 0.08, 0.11),
			0.040, 0.35
		),
		# 2. Monolito escarpado / risco angular (Sharp Crag - Ref 2 acantilado)
		RockArchetype.new(
			"SharpCrag",
			Vector3(0.80, 1.40, 0.85),
			1.6, 0.28, 0.40, 2,
			STONE_TEXTURE_01,
			Color(0.90, 0.94, 0.98), # Filo ligeramente más claro
			Color(0.52, 0.58, 0.66),
			Color(0.28, 0.32, 0.39),
			Color(0.14, 0.16, 0.20),
			Color(0.08, 0.09, 0.12),
			0.035, 0.40
		),
		# 3. Roca en cuña inclinada (Wedge Rock - Ref 3 pack angular)
		RockArchetype.new(
			"WedgeRock",
			Vector3(1.30, 0.72, 0.95),
			1.3, 0.22, 0.60, 3,
			STONE_TEXTURE_01,
			Color(0.85, 0.90, 0.96),
			Color(0.48, 0.54, 0.62),
			Color(0.26, 0.30, 0.36),
			Color(0.13, 0.15, 0.19),
			Color(0.07, 0.08, 0.11),
			0.038, 0.35
		),
		# 4. Afloramiento piramidal facetado (Pyramid Outcrop - Ref 3)
		RockArchetype.new(
			"PyramidOutcrop",
			Vector3(1.10, 1.05, 1.10),
			1.5, 0.25, 0.50, 4,
			STONE_TEXTURE_02,
			Color(0.88, 0.92, 0.97),
			Color(0.50, 0.56, 0.64),
			Color(0.28, 0.32, 0.38),
			Color(0.14, 0.16, 0.20),
			Color(0.07, 0.08, 0.11),
			0.036, 0.38
		),
		# 5. Roca compuesta bífida / doble cresta (Twin Lobe)
		RockArchetype.new(
			"TwinLobe",
			Vector3(1.40, 0.76, 0.90),
			1.3, 0.22, 0.65, 5,
			STONE_TEXTURE_01,
			Color(0.84, 0.89, 0.95),
			Color(0.46, 0.52, 0.60),
			Color(0.25, 0.29, 0.35),
			Color(0.12, 0.14, 0.18),
			Color(0.06, 0.07, 0.10),
			0.040, 0.32
		),
	]

## Genera una malla de ArrayMesh de roca estilizada con grandes facetas cinceladas (20 caras audaces)
static func _generate_rock_mesh(arch: RockArchetype, seed_val: int) -> ArrayMesh:
	# 1. 20 facetas de icosaedro base (proporciona planos amplios tipo roca tallada en vez de domo geodésico)
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

	var faces: Array[Vector3i] = [
		Vector3i(0, 11, 5),  Vector3i(0, 5, 1),   Vector3i(0, 1, 7),   Vector3i(0, 7, 10),  Vector3i(0, 10, 11),
		Vector3i(1, 5, 9),   Vector3i(5, 11, 4),  Vector3i(11, 10, 2), Vector3i(10, 7, 6),  Vector3i(7, 1, 8),
		Vector3i(3, 9, 4),   Vector3i(3, 4, 2),   Vector3i(3, 2, 6),   Vector3i(3, 6, 8),   Vector3i(3, 8, 9),
		Vector3i(4, 9, 5),   Vector3i(2, 4, 11),  Vector3i(6, 2, 10),  Vector3i(8, 6, 7),   Vector3i(9, 8, 1)
	]

	# 2. Configurar ruido 3D FastNoiseLite
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = arch.noise_freq
	noise.fractal_octaves = 2
	noise.fractal_gain = 0.50

	# 3. Deformación de vértices por arquetipo y ruido
	var deformed_verts: Array[Vector3] = []
	deformed_verts.resize(base_verts.size())

	for i in range(base_verts.size()):
		var v: Vector3 = base_verts[i]

		# Desplazamiento por ruido 3D a lo largo de la normal
		var n_disp: float = noise.get_noise_3dv(v * 2.0) * arch.noise_strength
		v += v * n_disp

		# Modificadores de forma específicos por arquetipo
		match arch.shape_modifier:
			0: # Boulder: ligero achatamiento esferoidal
				pass
			1: # River Slab: compresión vertical pronunciada para laja plana
				v.y *= 0.42
				if v.y > 0.0:
					v.y -= (v.x * v.x + v.z * v.z) * 0.06
			2: # Sharp Crag: corte angular escarpado vertical
				var diag: float = v.x + v.z
				if diag > 0.35:
					v -= Vector3(0.707, 0.0, 0.707) * ((diag - 0.35) * 0.40)
			3: # Wedge Rock: rampa inclinada en un eje
				v.y += v.x * 0.32
			4: # Pyramid Outcrop: reducción cónica hacia la cúspide
				var taper: float = clampf(1.15 - v.y * 0.38, 0.45, 1.40)
				v.x *= taper
				v.z *= taper
			5: # Twin Lobe: separación suave en dos crestas
				v.x += sin(v.x * 3.14159) * 0.18

		# Escala de proporciones del arquetipo
		v.x *= arch.scale_dims.x
		v.y *= arch.scale_dims.y
		v.z *= arch.scale_dims.z

		# Aplanamiento de base para apoyar sólidamente en el suelo
		if v.y < -0.05:
			v.y = lerpf(v.y, -0.22, arch.bottom_flatten)

		deformed_verts[i] = v

	# 4. Precomputar normales de cara y calcular agudeza diédrica de aristas
	var face_normals: Array[Vector3] = []
	face_normals.resize(faces.size())
	for f_idx in range(faces.size()):
		var tri: Vector3i = faces[f_idx]
		var v0: Vector3 = deformed_verts[tri.x]
		var v1: Vector3 = deformed_verts[tri.y]
		var v2: Vector3 = deformed_verts[tri.z]
		var fn: Vector3 = (v2 - v0).cross(v1 - v0).normalized()
		var mid: Vector3 = (v0 + v1 + v2) / 3.0
		if fn.dot(mid) < 0.0:
			fn = -fn
		if not is_finite(fn.x) or fn.is_zero_approx():
			fn = mid.normalized() if not mid.is_zero_approx() else Vector3.UP
		face_normals[f_idx] = fn

	# Mapa de aristas a caras adyacentes para detectar cantos vivos
	var edge_to_faces: Dictionary = {}
	for f_idx in range(faces.size()):
		var tri: Vector3i = faces[f_idx]
		var e0: int = (mini(tri.x, tri.y) << 16) | maxi(tri.x, tri.y)
		var e1: int = (mini(tri.y, tri.z) << 16) | maxi(tri.y, tri.z)
		var e2: int = (mini(tri.z, tri.x) << 16) | maxi(tri.z, tri.x)
		for e in [e0, e1, e2]:
			if not edge_to_faces.has(e):
				edge_to_faces[e] = []
			edge_to_faces[e].append(f_idx)

	var edge_sharpness_map: Dictionary = {}
	for edge_key in edge_to_faces.keys():
		var fl: Array = edge_to_faces[edge_key]
		if fl.size() >= 2:
			var nA: Vector3 = face_normals[fl[0]]
			var nB: Vector3 = face_normals[fl[1]]
			var cos_ang: float = clampf(nA.dot(nB), -1.0, 1.0)
			# Solo cantos diédricos vivos (ángulo > ~25 grados) reciben resalte:
			var sharpness: float = 0.0
			if cos_ang < 0.88:
				sharpness = smoothstep(0.88, 0.45, cos_ang)
			edge_sharpness_map[edge_key] = sharpness
		else:
			edge_sharpness_map[edge_key] = 0.5

	# Rango de altura vertical local para el gradiente de oclusión/suelo
	var min_y: float = INF
	var max_y: float = -INF
	for v in deformed_verts:
		min_y = minf(min_y, v.y)
		max_y = maxf(max_y, v.y)
	var height_range: float = maxf(max_y - min_y, 0.001)

	# 5. Generación de mallas con Flat-Shading, atributos de canto y coordenadas baricéntricas
	var final_verts := PackedVector3Array()
	var final_normals := PackedVector3Array()
	var final_uvs := PackedVector2Array()
	var final_uv2s := PackedVector2Array()
	var final_colors := PackedColorArray()
	var final_indices := PackedInt32Array()

	var vert_count := 0
	for f_idx in range(faces.size()):
		var tri: Vector3i = faces[f_idx]
		var idx0: int = tri.x
		var idx1: int = tri.y
		var idx2: int = tri.z

		var v0: Vector3 = deformed_verts[idx0]
		var v1: Vector3 = deformed_verts[idx1]
		var v2: Vector3 = deformed_verts[idx2]

		# En Godot, el orden de vértices para cara frontal exterior cumple (v2 - v0) x (v1 - v0) > 0
		var face_normal := (v2 - v0).cross(v1 - v0).normalized()
		var mid := (v0 + v1 + v2) / 3.0

		if face_normal.dot(mid) < 0.0:
			var tmp_v := v1
			v1 = v2
			v2 = tmp_v

			var tmp_idx := idx1
			idx1 = idx2
			idx2 = tmp_idx

			face_normal = -face_normal

		if not is_finite(face_normal.x) or face_normal.is_zero_approx():
			face_normal = mid.normalized() if not mid.is_zero_approx() else Vector3.UP

		# Aristas actuales:
		# Arista 0: entre v0 e v1 (distancia baricéntrica bary.z)
		# Arista 1: entre v1 e v2 (distancia baricéntrica bary.x)
		# Arista 2: entre v2 e v0 (distancia baricéntrica bary.y)
		var k01: int = (mini(idx0, idx1) << 16) | maxi(idx0, idx1)
		var k12: int = (mini(idx1, idx2) << 16) | maxi(idx1, idx2)
		var k20: int = (mini(idx2, idx0) << 16) | maxi(idx2, idx0)

		var s0: float = edge_sharpness_map.get(k01, 0.0)
		var s1: float = edge_sharpness_map.get(k12, 0.0)
		var s2: float = edge_sharpness_map.get(k20, 0.0)

		var h0: float = clampf((v0.y - min_y) / height_range, 0.0, 1.0)
		var h1: float = clampf((v1.y - min_y) / height_range, 0.0, 1.0)
		var h2: float = clampf((v2.y - min_y) / height_range, 0.0, 1.0)

		# 3 vértices independientes por triángulo para lograr facetas planas nítidas
		final_verts.append(v0)
		final_verts.append(v1)
		final_verts.append(v2)

		final_normals.append(face_normal)
		final_normals.append(face_normal)
		final_normals.append(face_normal)

		final_uvs.append(Vector2(v0.x * 0.5 + 0.5, v0.z * 0.5 + 0.5))
		final_uvs.append(Vector2(v1.x * 0.5 + 0.5, v1.z * 0.5 + 0.5))
		final_uvs.append(Vector2(v2.x * 0.5 + 0.5, v2.z * 0.5 + 0.5))

		# Baricéntricas en UV2 para calcular distancia analítica a cada arista
		final_uv2s.append(Vector2(1.0, 0.0)) # v0: bary = (1, 0, 0)
		final_uv2s.append(Vector2(0.0, 1.0)) # v1: bary = (0, 1, 0)
		final_uv2s.append(Vector2(0.0, 0.0)) # v2: bary = (0, 0, 1)

		# COLOR codifica: R=s0, G=s1, B=s2, A=altura local
		final_colors.append(Color(s0, s1, s2, h0))
		final_colors.append(Color(s0, s1, s2, h1))
		final_colors.append(Color(s0, s1, s2, h2))

		final_indices.append(vert_count)
		final_indices.append(vert_count + 1)
		final_indices.append(vert_count + 2)
		vert_count += 3

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = final_verts
	arrays[Mesh.ARRAY_NORMAL] = final_normals
	arrays[Mesh.ARRAY_TEX_UV] = final_uvs
	arrays[Mesh.ARRAY_TEX_UV2] = final_uv2s
	arrays[Mesh.ARRAY_COLOR] = final_colors
	arrays[Mesh.ARRAY_INDEX] = final_indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# 6. Material Inteligente ShaderMaterial para rocas estilizadas
	var shader := _get_shader()
	if shader != null:
		var sm := ShaderMaterial.new()
		sm.shader = shader
		if ResourceLoader.exists(arch.texture_path):
			sm.set_shader_parameter("stone_texture", load(arch.texture_path))
		sm.set_shader_parameter("color_highlight", arch.color_highlight)
		sm.set_shader_parameter("color_top", arch.color_top)
		sm.set_shader_parameter("color_mid", arch.color_mid)
		sm.set_shader_parameter("color_bottom", arch.color_bottom)
		sm.set_shader_parameter("color_crevice", arch.color_crevice)
		sm.set_shader_parameter("edge_width", arch.edge_width)
		sm.set_shader_parameter("edge_opacity", arch.edge_opacity)
		sm.set_shader_parameter("triplanar_scale", 0.90)
		sm.set_shader_parameter("orientation_contrast", 1.30)
		sm.set_shader_parameter("height_gradient_strength", 0.65)
		mesh.surface_set_material(0, sm)
	else:
		var mat := StandardMaterial3D.new()
		if ResourceLoader.exists(arch.texture_path):
			mat.albedo_texture = load(arch.texture_path)
		mat.albedo_color = arch.color_mid
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = false
		mat.uv1_scale = Vector3(0.60, 0.60, 0.60)
		mat.roughness = 0.88
		mat.cull_mode = BaseMaterial3D.CULL_BACK
		mesh.surface_set_material(0, mat)

	return mesh
