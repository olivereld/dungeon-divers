class_name WallCornerResolver
extends RefCounted

## Calculador geométrico determinista de uniones en esquina (miters) para muros arquitectónicos.
## Su responsabilidad única es calcular la geometría matemática exacta de la unión para un set (prev, corner, next):
## direcciones tangentes, normales de muro, bisectriz, escala, vector miter de intersección exacta y tipo de esquina.
## No genera mallas ni depende de SurfaceTool / Mesh.

enum CornerType {
	STRAIGHT,     ## Segmentos colineales (~180°)
	CONVEX,       ## Giro exterior (ángulo exterior mayor a 180° en cara exterior)
	CONCAVE,      ## Giro interior (ángulo interior)
	OPEN_START,   ## Extremo inicial abierto sin unión continua previa
	OPEN_END      ## Extremo final abierto sin unión continua posterior
}

class CornerSolution extends RefCounted:
	var corner_id: int = -1
	var point: Vector3 = Vector3.ZERO
	var t_in: Vector3 = Vector3.FORWARD
	var t_out: Vector3 = Vector3.FORWARD
	var n_in: Vector3 = Vector3.RIGHT
	var n_out: Vector3 = Vector3.RIGHT
	var bisector: Vector3 = Vector3.ZERO
	var miter_dir: Vector3 = Vector3.ZERO
	var miter_scale: float = 1.0
	var miter_vector: Vector3 = Vector3.ZERO
	var corner_type: CornerType = CornerType.STRAIGHT
	var is_collinear: bool = true
	var is_open_end: bool = false
	var turn_angle_deg: float = 0.0

	# Puntos de perfil calculados exactamente una sola vez para esta esquina
	var inner_thick: Vector3 = Vector3.ZERO
	var inner_thin: Vector3 = Vector3.ZERO
	var outer_thin: Vector3 = Vector3.ZERO
	var outer_thick: Vector3 = Vector3.ZERO

	func get_offset_point(offset_distance: float) -> Vector3:
		return point + (miter_vector * offset_distance)

	func resolve_profile_points(w_thick: float, w_thin: float, d: float) -> void:
		inner_thick = point
		inner_thin = point + (miter_vector * (d * 0.5))
		outer_thin = point + (miter_vector * (w_thick - (d * 0.5)))
		outer_thick = point + (miter_vector * w_thick)

# Registro / caché opcional para esquinas compartidas
var _corner_registry: Dictionary = {}

func clear_registry() -> void:
	_corner_registry.clear()

func register_corner_solution(c_id: int, sol: CornerSolution) -> void:
	if c_id >= 0 and sol != null:
		_corner_registry[c_id] = sol

func get_registered_corner(c_id: int) -> CornerSolution:
	if c_id >= 0 and _corner_registry.has(c_id):
		return _corner_registry[c_id]
	return null

## Resuelve la solución matemática de una esquina dada la tríada (prev, corner, next).
func resolve_corner(
	prev_pt: Vector3,
	corner_pt: Vector3,
	next_pt: Vector3,
	is_open_start: bool = false,
	is_open_end: bool = false,
	corner_id: int = -1
) -> CornerSolution:
	if corner_id >= 0 and _corner_registry.has(corner_id):
		return _corner_registry[corner_id]

	var diff_in: Vector3 = corner_pt - prev_pt
	var diff_out: Vector3 = next_pt - corner_pt
	var len_sq_in: float = diff_in.length_squared()
	var len_sq_out: float = diff_out.length_squared()

	var t_in: Vector3 = Vector3.ZERO
	var t_out: Vector3 = Vector3.ZERO

	if is_open_start or len_sq_in < 0.000001:
		if len_sq_out > 0.000001:
			t_out = diff_out.normalized()
			t_in = t_out
		else:
			t_in = Vector3.FORWARD
			t_out = Vector3.FORWARD
	elif is_open_end or len_sq_out < 0.000001:
		if len_sq_in > 0.000001:
			t_in = diff_in.normalized()
			t_out = t_in
		else:
			t_in = Vector3.FORWARD
			t_out = Vector3.FORWARD
	else:
		t_in = diff_in.normalized()
		t_out = diff_out.normalized()

	# Normales en el plano XZ (Y hacia arriba: normal = Vector3(t.z, 0, -t.x))
	var n_in := Vector3(t_in.z, 0.0, -t_in.x)
	var n_out := Vector3(t_out.z, 0.0, -t_out.x)

	var sol := CornerSolution.new()
	sol.corner_id = corner_id
	sol.point = corner_pt
	sol.t_in = t_in
	sol.t_out = t_out
	sol.n_in = n_in
	sol.n_out = n_out

	if is_open_start:
		sol.miter_dir = n_out
		sol.miter_scale = 1.0
		sol.miter_vector = n_out
		sol.bisector = n_out
		sol.corner_type = CornerType.OPEN_START
		sol.is_collinear = true
		sol.is_open_end = true
		if corner_id >= 0:
			_corner_registry[corner_id] = sol
		return sol

	if is_open_end:
		sol.miter_dir = n_in
		sol.miter_scale = 1.0
		sol.miter_vector = n_in
		sol.bisector = n_in
		sol.corner_type = CornerType.OPEN_END
		sol.is_collinear = true
		sol.is_open_end = true
		if corner_id >= 0:
			_corner_registry[corner_id] = sol
		return sol

	var dot_t: float = t_in.dot(t_out)
	var dot_n: float = n_in.dot(n_out)

	if dot_t > 0.9999:
		# Segmentos colineales rectos (180°)
		sol.miter_dir = n_in
		sol.miter_scale = 1.0
		sol.miter_vector = n_in
		sol.bisector = n_in
		sol.corner_type = CornerType.STRAIGHT
		sol.is_collinear = true
		sol.turn_angle_deg = 0.0
	elif dot_t < -0.9999:
		# Retorno en horquilla / inversión 180°
		sol.miter_dir = n_in
		sol.miter_scale = 1.0
		sol.miter_vector = n_in
		sol.bisector = n_in
		sol.corner_type = CornerType.STRAIGHT
		sol.is_collinear = false
		sol.turn_angle_deg = 180.0
	else:
		# Intersección matemática exacta de las líneas offset:
		# M = (n_in + n_out) / (1.0 + n_in . n_out)
		# Satisface rigurosamente M . n_in = 1.0 y M . n_out = 1.0
		var bisector := n_in + n_out
		var denom: float = 1.0 + dot_n
		if denom > 0.0001:
			sol.miter_vector = bisector / denom
			sol.miter_scale = sol.miter_vector.length()
			sol.miter_dir = sol.miter_vector.normalized()
			sol.bisector = bisector.normalized()
		else:
			sol.miter_dir = n_in
			sol.miter_scale = 1.0
			sol.miter_vector = n_in
			sol.bisector = n_in

		sol.is_collinear = false
		var cross_y: float = (t_in.x * t_out.z) - (t_in.z * t_out.x)
		if cross_y > 0.0001:
			sol.corner_type = CornerType.CONVEX
		elif cross_y < -0.0001:
			sol.corner_type = CornerType.CONCAVE
		else:
			sol.corner_type = CornerType.STRAIGHT

		sol.turn_angle_deg = rad_to_deg(acos(clampf(dot_t, -1.0, 1.0)))

	if corner_id >= 0:
		_corner_registry[corner_id] = sol

	return sol

## Resuelve una secuencia de puntos 3D de un recorrido, generando un array de CornerSolution.
func resolve_path_corners(
	pts_3d: Array[Vector3],
	is_closed: bool,
	start_neighbor_3d: Vector3 = Vector3.INF,
	end_neighbor_3d: Vector3 = Vector3.INF,
	corner_ids: Array[int] = [],
	w_thick: float = 0.0,
	w_thin: float = 0.0,
	d: float = 0.0
) -> Array[CornerSolution]:
	var solutions: Array[CornerSolution] = []
	var n: int = pts_3d.size()
	if n < 2:
		return solutions

	for i in range(n):
		var prev_pt: Vector3 = Vector3.ZERO
		var corner_pt: Vector3 = pts_3d[i]
		var next_pt: Vector3 = Vector3.ZERO
		var is_open_start: bool = false
		var is_open_end: bool = false

		if is_closed:
			prev_pt = pts_3d[(i - 1 + n) % n]
			next_pt = pts_3d[(i + 1) % n]
		else:
			if i == 0:
				if not is_inf(start_neighbor_3d.x):
					prev_pt = start_neighbor_3d
				else:
					prev_pt = corner_pt
					is_open_start = true
				next_pt = pts_3d[1]
			elif i == n - 1:
				prev_pt = pts_3d[n - 2]
				if not is_inf(end_neighbor_3d.x):
					next_pt = end_neighbor_3d
				else:
					next_pt = corner_pt
					is_open_end = true
			else:
				prev_pt = pts_3d[i - 1]
				next_pt = pts_3d[i + 1]

		var cid: int = corner_ids[i] if i < corner_ids.size() else -1
		var sol: CornerSolution = resolve_corner(
			prev_pt, corner_pt, next_pt, is_open_start, is_open_end, cid
		)

		if w_thick > 0.0:
			sol.resolve_profile_points(w_thick, w_thin, d)

		solutions.append(sol)

	return solutions
