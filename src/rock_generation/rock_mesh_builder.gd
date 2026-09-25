class_name RockMeshBuilder
extends RefCounted

const RockSizeProfile = preload("res://src/rock_generation/rock_size_profile.gd")

## Constructor de geometría procedural para rocas estilizadas Taiga.
## Utiliza una estructura de anillos irregulares con jitter determinista
## y normales por cara (flat shading) para conservar facetas nítidas y siluetas asimétricas.

static func build_rock_mesh(profile: RockSizeProfile, rock_seed: int) -> ArrayMesh:
	var rings: int = profile.rings
	var segments: int = profile.segments
	var irregularity: float = profile.irregularity
	var height_ratio: float = profile.height_ratio

	# Radio y altura base normalizados (la escala de instancia se aplicará luego)
	var base_radius: float = 1.0
	var total_height: float = 1.6 * height_ratio

	# Desplazamiento global del centro de masa para romper la simetría rotacional
	var mass_offset_angle: float = _hash_float(rock_seed, 999, 1) * TAU
	var mass_offset_dist: float = _hash_float(rock_seed, 999, 2) * 0.25 * irregularity
	var mass_offset: Vector3 = Vector3(cos(mass_offset_angle), 0.0, sin(mass_offset_angle)) * mass_offset_dist

	# Matriz de posiciones de vértices: ring_vertices[ring_index][segment_index] -> Vector3
	var ring_vertices: Array[Array] = []

	for r in range(rings):
		var ring_verts: Array[Vector3] = []
		var t: float = float(r) / float(rings - 1) # 0.0 (base) a 1.0 (cima)

		# Curvatura base del perfil de elevación y radio
		# La masa es más ancha cerca de la base (t ~ 0.25 - 0.35) y se estrecha hacia la cima
		var profile_radius_factor: float
		var ring_base_y: float

		if r == 0:
			# Anillo 0: Base ligeramente enterrada en el terreno para evitar flotación
			profile_radius_factor = 0.85
			ring_base_y = -profile.base_penetration * 0.5
		elif r == rings - 1:
			# Último anillo: Cima mesetiforme irregular amplia
			profile_radius_factor = lerp(0.50, 0.65, _hash_float(rock_seed, 888, 1))
			ring_base_y = total_height
		else:
			# Anillos intermedios
			# Perfil acampanado/abultado
			profile_radius_factor = lerp(1.15, 0.65, pow(t, 0.75))
			ring_base_y = t * total_height

		for s in range(segments):
			var base_angle: float = (TAU * float(s)) / float(segments)

			# Jitter angular determinista (mueve los vértices a lo largo del círculo)
			var angle_jitter: float = (_hash_float(rock_seed, r * 100 + s, 10) - 0.5) * (TAU / float(segments)) * 0.45 * irregularity
			var angle: float = base_angle + angle_jitter

			# Jitter radial determinista
			var r_jitter: float = (_hash_float(rock_seed, r * 100 + s, 20) - 0.5) * 0.6 * irregularity
			var current_radius: float = base_radius * profile_radius_factor * max(0.25, 1.0 + r_jitter)

			# Jitter vertical determinista (más contenido en la cima para mantener la meseta)
			var y_jitter_scale: float = 0.15 if r == rings - 1 else 0.35
			var y_jitter: float = (_hash_float(rock_seed, r * 100 + s, 30) - 0.5) * y_jitter_scale * total_height * irregularity
			var vert_y: float = ring_base_y + y_jitter

			# Deformación direccional de masa para crear un lado más empinado y otro más tendido
			var dir_dot: float = cos(angle - mass_offset_angle)
			var directional_push: float = dir_dot * mass_offset_dist * (1.0 - t * 0.5)

			var vx: float = cos(angle) * (current_radius + directional_push)
			var vz: float = sin(angle) * (current_radius + directional_push)

			ring_verts.append(Vector3(vx, vert_y, vz) + mass_offset * (1.0 - t))

		ring_vertices.append(ring_verts)

	# Vértice central de la base (para cerrar el fondo herméticamente)
	var bottom_center: Vector3 = Vector3(mass_offset.x * 0.5, -profile.base_penetration * 0.8, mass_offset.z * 0.5)

	# Vértice central de la cima: meseta plana ligeramente variada (sin pico agudo)
	var top_jitter_y: float = (_hash_float(rock_seed, 777, 40) - 0.5) * 0.08 * total_height * irregularity
	var top_center: Vector3 = Vector3(
		mass_offset.x * 0.2 + (_hash_float(rock_seed, 777, 41) - 0.5) * 0.15,
		total_height + top_jitter_y,
		mass_offset.z * 0.2 + (_hash_float(rock_seed, 777, 42) - 0.5) * 0.15
	)

	# Construir la geometría facetada con SurfaceTool
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. Base inferior (triángulos de la base hacia el anillo 0, vistos desde abajo en CCW)
	for s in range(segments):
		var next_s: int = (s + 1) % segments
		var v_center: Vector3 = bottom_center
		var v_s: Vector3 = ring_vertices[0][s]
		var v_next: Vector3 = ring_vertices[0][next_s]
		_add_flat_triangle(st, v_center, v_next, v_s)

	# 2. Paredes de anillos (vistas desde afuera en CCW estricto)
	# Quad: [v_curr_s (abajo-izq), v_curr_next (abajo-der), v_upper_next (arriba-der), v_upper_s (arriba-izq)]
	for r in range(rings - 1):
		for s in range(segments):
			var next_s: int = (s + 1) % segments
			var v_curr_s: Vector3 = ring_vertices[r][s]
			var v_curr_next: Vector3 = ring_vertices[r][next_s]
			var v_upper_s: Vector3 = ring_vertices[r + 1][s]
			var v_upper_next: Vector3 = ring_vertices[r + 1][next_s]

			# Alternar diagonal deterministamente para enriquecer el facetado
			var flip_diagonal: bool = _hash_float(rock_seed, r * 50 + s, 50) > 0.5

			if flip_diagonal:
				_add_flat_triangle(st, v_curr_s, v_curr_next, v_upper_next)
				_add_flat_triangle(st, v_curr_s, v_upper_next, v_upper_s)
			else:
				_add_flat_triangle(st, v_curr_s, v_curr_next, v_upper_s)
				_add_flat_triangle(st, v_curr_next, v_upper_next, v_upper_s)

	# 3. Cima mesetiforme (triángulos del último anillo hacia el centro de la cima, vistos desde arriba en CCW)
	var last_ring: int = rings - 1
	for s in range(segments):
		var next_s: int = (s + 1) % segments
		var v_center: Vector3 = top_center
		var v_s: Vector3 = ring_vertices[last_ring][s]
		var v_next: Vector3 = ring_vertices[last_ring][next_s]
		_add_flat_triangle(st, v_center, v_s, v_next)

	st.index()
	var mesh: ArrayMesh = st.commit()
	return mesh

## Añade un triángulo con flat-shading estricto y orden de vértices CCW exterior.
static func _add_flat_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# En el sistema de coordenadas de Godot (XZ), invertir para orden CCW exterior
	var edge1: Vector3 = c - a
	var edge2: Vector3 = b - a
	var face_normal: Vector3 = edge1.cross(edge2).normalized()

	if face_normal.is_zero_approx():
		face_normal = Vector3.UP

	var uv_a: Vector2 = Vector2(a.x * 0.5 + 0.5, a.z * 0.5 + 0.5)
	var uv_b: Vector2 = Vector2(b.x * 0.5 + 0.5, b.z * 0.5 + 0.5)
	var uv_c: Vector2 = Vector2(c.x * 0.5 + 0.5, c.z * 0.5 + 0.5)

	st.set_normal(face_normal)
	st.set_uv(uv_a)
	st.add_vertex(a)

	st.set_normal(face_normal)
	st.set_uv(uv_c)
	st.add_vertex(c)

	st.set_normal(face_normal)
	st.set_uv(uv_b)
	st.add_vertex(b)

## Función hash pseudoaleatoria determinista en el rango [0.0, 1.0]
static func _hash_float(seed_val: int, idx: int, salt: int) -> float:
	var h: int = (seed_val * 73856093) ^ (idx * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(abs(h) % 100000) / 100000.0
