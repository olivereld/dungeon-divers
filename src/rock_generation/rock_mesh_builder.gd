class_name RockMeshBuilder
extends RefCounted

const RockSizeProfile = preload("res://src/rock_generation/rock_size_profile.gd")

## Constructor de geometría procedural para rocas estilizadas Taiga.
## Utiliza una estructura de anillos irregulares con jitter determinista
## y normales por cara (flat shading) para conservar facetas nítidas y siluetas asimétricas.

static func build_rock_mesh(profile: Variant, rock_seed: int) -> ArrayMesh:
	var rings: int = int(profile.rings)
	var segments: int = int(profile.segments)
	var irregularity: float = float(profile.irregularity)
	var height_ratio: float = float(profile.height_ratio)
	var base_penetration: float = float(profile.base_penetration)

	# Parámetros de silueta con fallbacks retrocompatibles
	var base_radius_factor: float = float(profile.get("base_radius_factor")) if profile.get("base_radius_factor") != null else 0.85
	var body_bulge_factor: float = float(profile.get("body_bulge_factor")) if profile.get("body_bulge_factor") != null else 1.15
	var taper_power: float = float(profile.get("taper_power")) if profile.get("taper_power") != null else 0.75
	var peak_convergence_min: float = float(profile.get("peak_convergence_min")) if profile.get("peak_convergence_min") != null else 0.15
	var peak_convergence_max: float = float(profile.get("peak_convergence_max")) if profile.get("peak_convergence_max") != null else 0.30
	var apex_elevation_min: float = float(profile.get("apex_elevation_min")) if profile.get("apex_elevation_min") != null else 0.10
	var apex_elevation_max: float = float(profile.get("apex_elevation_max")) if profile.get("apex_elevation_max") != null else 0.25

	# Parámetros de deformación con fallbacks retrocompatibles
	var radial_jitter_scale: float = float(profile.get("radial_jitter")) if profile.get("radial_jitter") != null else 0.60
	var vertical_jitter_scale: float = float(profile.get("vertical_jitter")) if profile.get("vertical_jitter") != null else 0.35
	var top_ring_y_jitter_scale: float = float(profile.get("top_ring_y_jitter")) if profile.get("top_ring_y_jitter") != null else 0.30
	var mass_offset_strength: float = float(profile.get("mass_offset_strength")) if profile.get("mass_offset_strength") != null else 0.20
	var diagonal_alternation: bool = bool(profile.get("diagonal_alternation")) if profile.get("diagonal_alternation") != null else true

	# Radio y altura base normalizados (la escala de instancia se aplicará luego)
	var base_radius: float = 1.0
	var total_height: float = 1.6 * height_ratio

	# Desplazamiento global del centro de masa para romper la simetría rotacional
	var mass_offset_angle: float = _hash_float(rock_seed, 999, 1) * TAU
	var mass_offset_dist: float = _hash_float(rock_seed, 999, 2) * mass_offset_strength * irregularity
	var mass_offset: Vector3 = Vector3(cos(mass_offset_angle), 0.0, sin(mass_offset_angle)) * mass_offset_dist

	# Matriz de posiciones de vértices: ring_vertices[ring_index][segment_index] -> Vector3
	var ring_vertices: Array[Array] = []

	for r in range(rings):
		var ring_verts: Array[Vector3] = []
		var t: float = float(r) / float(rings - 1) # 0.0 (base) a 1.0 (cima)

		# Curvatura base del perfil de elevación y radio
		var profile_radius_factor: float
		var ring_base_y: float

		if r == 0:
			# Anillo 0: Base ligeramente enterrada en el terreno para evitar flotación
			profile_radius_factor = base_radius_factor
			ring_base_y = -base_penetration * 0.5
		elif r == rings - 1:
			# Último anillo: Convergencia hacia la cúspide irregular (NO meseta)
			profile_radius_factor = lerp(peak_convergence_min, peak_convergence_max, _hash_float(rock_seed, 888, 1))
			ring_base_y = total_height + _hash_float(rock_seed, 888, 2) * apex_elevation_min * total_height
		else:
			# Anillos intermedios: Perfil acampanado y taper hacia la cima
			profile_radius_factor = lerp(body_bulge_factor, peak_convergence_max * 2.0, pow(t, taper_power))
			ring_base_y = t * total_height

		for s in range(segments):
			var base_angle: float = (TAU * float(s)) / float(segments)

			# Jitter angular determinista (mueve los vértices a lo largo del círculo)
			var angle_jitter: float = (_hash_float(rock_seed, r * 100 + s, 10) - 0.5) * (TAU / float(segments)) * 0.45 * irregularity
			var angle: float = base_angle + angle_jitter

			# Jitter radial determinista
			var r_jitter: float = (_hash_float(rock_seed, r * 100 + s, 20) - 0.5) * radial_jitter_scale * irregularity
			var current_radius: float = base_radius * profile_radius_factor * max(0.25, 1.0 + r_jitter)

			# Jitter vertical determinista
			var y_jitter_scale: float = top_ring_y_jitter_scale if r == rings - 1 else vertical_jitter_scale
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
	var bottom_center: Vector3 = Vector3(mass_offset.x * 0.5, -base_penetration * 0.8, mass_offset.z * 0.5)

	# Apex se eleva sobre total_height según los límites de la silueta configurada
	var apex_elevation: float = lerp(apex_elevation_min, apex_elevation_max, _hash_float(rock_seed, 777, 40)) * total_height
	var top_jitter_y: float = (_hash_float(rock_seed, 777, 43) - 0.5) * 0.06 * total_height * irregularity
	var top_center: Vector3 = Vector3(
		mass_offset.x * 0.12 + (_hash_float(rock_seed, 777, 41) - 0.5) * 0.10,
		total_height + apex_elevation + top_jitter_y,
		mass_offset.z * 0.12 + (_hash_float(rock_seed, 777, 42) - 0.5) * 0.10
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
			var flip_diagonal: bool = (_hash_float(rock_seed, r * 50 + s, 50) > 0.5) if diagonal_alternation else false

			if flip_diagonal:
				_add_flat_triangle(st, v_curr_s, v_curr_next, v_upper_next)
				_add_flat_triangle(st, v_curr_s, v_upper_next, v_upper_s)
			else:
				_add_flat_triangle(st, v_curr_s, v_curr_next, v_upper_s)
				_add_flat_triangle(st, v_curr_next, v_upper_next, v_upper_s)

	# 3. Cima en cúpula/pico (triángulos del último anillo convergiendo al apex, vistos desde arriba en CCW)
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

## Añade un triángulo con flat-shading estricto y orden de vértices frontal (Clockwise para Godot).
static func _add_flat_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# En Godot, las caras frontales usan orden horario (Clockwise).
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
	st.set_uv(uv_b)
	st.add_vertex(b)

	st.set_normal(face_normal)
	st.set_uv(uv_c)
	st.add_vertex(c)

## Función hash pseudoaleatoria determinista en el rango [0.0, 1.0]
static func _hash_float(seed_val: int, idx: int, salt: int) -> float:
	var h: int = (seed_val * 73856093) ^ (idx * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(abs(h) % 100000) / 100000.0
