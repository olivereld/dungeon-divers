class_name RiverMeshBuilder
extends RefCounted

## Constructor robusto de mallas de agua longitudinales (Quad Strips).
## Topología limpia sin Catmull-Rom:
## 1. Remuestreo lineal regular por longitud de arco sobre el trazado hidrológico real.
## 2. Tangentes robustas por segmentos vecinos con miter limitado.
## 3. Exactamente dos vértices por sección y dos triángulos por segmento.
## 4. Validación geométrica de triángulos para prevenir degenerados.

const _WaterSurfaceDataScript = preload("res://src/world_generator/presentation/water/water_surface_data.gd")
const _RiverScript = preload("res://src/world_generator/hydrology/river.gd")

static func build_river_surface(
	river: Variant,
	result: WorldResult,
	profile: WorldProfile
) -> RefCounted:
	var raw_pts: Array = []
	var raw_widths: Array = []
	var raw_depths: Array = []

	if river is River:
		raw_pts = river.points
		raw_widths = river.widths
		raw_depths = river.depths
	elif river is Dictionary:
		raw_pts = river.get("points", [])
		raw_widths = river.get("widths", [])
		raw_depths = river.get("depths", [])
	else:
		return null

	if raw_pts.size() < 2:
		return null

	# ------------------------------------------------------------------
	# 1. Limpiar y remuestrear la línea central.
	#
	# NO usamos Catmull-Rom.
	#
	# La geometría hidrológica ya contiene el meandro correcto. Aquí
	# solamente necesitamos una línea suficientemente regular para
	# construir el ribbon.
	# ------------------------------------------------------------------

	var sampled := _resample_centerline(
		raw_pts,
		raw_widths,
		raw_depths,
		0.75
	)

	var pts: Array[Vector3] = sampled["points"]
	var widths: Array[float] = sampled["widths"]
	var depths: Array[float] = sampled["depths"]

	if pts.size() < 2:
		return null

	var surf = _WaterSurfaceDataScript.new()

	var cell_size: float = maxf(profile.cell_size, 0.01)
	var accumulated_dist: float = 0.0

	# ------------------------------------------------------------------
	# 2. Construir secciones left/right.
	#
	# Cada sección tiene exactamente dos vértices.
	# ------------------------------------------------------------------

	var left_indices: Array[int] = []
	var right_indices: Array[int] = []

	left_indices.resize(pts.size())
	right_indices.resize(pts.size())

	for i in range(pts.size()):
		var p: Vector3 = pts[i]

		if i > 0:
			accumulated_dist += pts[i].distance_to(pts[i - 1])

		# --------------------------------------------------------------
		# Tangente robusta.
		#
		# Usamos segmentos vecinos, pero NO una spline.
		# --------------------------------------------------------------

		var tangent: Vector3

		if i == 0:
			tangent = pts[1] - pts[0]
		elif i == pts.size() - 1:
			tangent = pts[i] - pts[i - 1]
		else:
			var prev_dir: Vector3 = (pts[i] - pts[i - 1]).normalized()
			var next_dir: Vector3 = (pts[i + 1] - pts[i]).normalized()

			# Promedio de direcciones.
			tangent = prev_dir + next_dir

			# Si la curva es extremadamente cerrada, no intentamos
			# inventar una tangente intermedia.
			if tangent.length_squared() < 0.0001:
				tangent = next_dir

		tangent.y = 0.0

		if tangent.length_squared() < 0.0001:
			tangent = Vector3.FORWARD

		tangent = tangent.normalized()

		# --------------------------------------------------------------
		# Normal lateral.
		# --------------------------------------------------------------

		var perp := Vector3(
			-tangent.z,
			0.0,
			tangent.x
		).normalized()

		# --------------------------------------------------------------
		# Miter limitado.
		#
		# En curvas fuertes, un miter normal puede dispararse a
		# distancias enormes y cruzar la orilla opuesta.
		#
		# Limitamos la longitud.
		# --------------------------------------------------------------

		if i > 0 and i < pts.size() - 1:
			var prev_dir: Vector3 = (
				pts[i] - pts[i - 1]
			).normalized()

			var next_dir: Vector3 = (
				pts[i + 1] - pts[i]
			).normalized()

			prev_dir.y = 0.0
			next_dir.y = 0.0

			if (
				prev_dir.length_squared() > 0.0001
				and next_dir.length_squared() > 0.0001
			):
				var prev_normal := Vector3(
					-prev_dir.z,
					0.0,
					prev_dir.x
				).normalized()

				var next_normal := Vector3(
					-next_dir.z,
					0.0,
					next_dir.x
				).normalized()

				var miter := prev_normal + next_normal

				if miter.length_squared() > 0.0001:
					miter = miter.normalized()

					var denom: float = absf(
						miter.dot(next_normal)
					)

					if denom > 0.15:
						var miter_scale: float = 1.0 / denom

						# Nunca permitimos un miter superior a 2x
						# el ancho lateral.
						miter_scale = minf(
							miter_scale,
							2.0
						)

						perp = miter * miter_scale

		# --------------------------------------------------------------
		# Ancho.
		# --------------------------------------------------------------

		var full_width: float = maxf(
			widths[i] / cell_size,
			0.20
		)

		var half_width: float = full_width * 0.5

		# Limitar la magnitud final de la normal.
		#
		# Esto evita que una curva extremadamente cerrada genere
		# vértices que se disparen hacia afuera.
		if perp.length_squared() > 0.0001:
			perp = perp.normalized()

		var left_x: float = p.x + perp.x * half_width
		var left_z: float = p.z + perp.z * half_width

		var right_x: float = p.x - perp.x * half_width
		var right_z: float = p.z - perp.z * half_width

		# --------------------------------------------------------------
		# Lecho y profundidad.
		# --------------------------------------------------------------

		var bed_l: float = _sample_terrain(
			result,
			left_x,
			left_z
		)

		var bed_r: float = _sample_terrain(
			result,
			right_x,
			right_z
		)

		# Muestreamos ligeramente hacia afuera del río.
		var bank_l: float = _sample_terrain(
			result,
			left_x + perp.x * 0.5,
			left_z + perp.z * 0.5
		)

		var bank_r: float = _sample_terrain(
			result,
			right_x - perp.x * 0.5,
			right_z - perp.z * 0.5
		)

		var depth: float = maxf(
			depths[i],
			0.05
		)

		var left_y: float = minf(
			bed_l + depth,
			bank_l + 0.02
		)

		var right_y: float = minf(
			bed_r + depth,
			bank_r + 0.02
		)

		# Nunca permitir que el agua quede por debajo del lecho.
		left_y = maxf(
			left_y,
			bed_l + 0.015
		)

		right_y = maxf(
			right_y,
			bed_r + 0.015
		)

		# --------------------------------------------------------------
		# Flow.
		# --------------------------------------------------------------

		var flow_dir := Vector2(
			tangent.x,
			tangent.z
		)

		if flow_dir.length_squared() > 0.0001:
			flow_dir = flow_dir.normalized()

		var uv_v: float = accumulated_dist

		var left_idx: int = surf.add_vertex(
			Vector3(left_x, left_y, left_z),
			Vector3.UP,
			Vector2(0.0, uv_v),
			flow_dir,
			profile.water_color_river
		)

		var right_idx: int = surf.add_vertex(
			Vector3(right_x, right_y, right_z),
			Vector3.UP,
			Vector2(1.0, uv_v),
			flow_dir,
			profile.water_color_river
		)

		left_indices[i] = left_idx
		right_indices[i] = right_idx

	# ------------------------------------------------------------------
	# 3. Construcción del ribbon.
	#
	# EXACTAMENTE dos triángulos por segmento.
	# ------------------------------------------------------------------

	for i in range(pts.size() - 1):
		var l0: int = left_indices[i]
		var r0: int = right_indices[i]
		var l1: int = left_indices[i + 1]
		var r1: int = right_indices[i + 1]

		# Evitar triángulos degenerados.
		if _triangle_is_valid(
			surf.vertices[l0],
			surf.vertices[r0],
			surf.vertices[l1]
		):
			surf.add_triangle(
				l0,
				r0,
				l1
			)

		if _triangle_is_valid(
			surf.vertices[r0],
			surf.vertices[r1],
			surf.vertices[l1]
		):
			surf.add_triangle(
				r0,
				r1,
				l1
			)

	return surf

static func _resample_centerline(
	raw_pts: Array,
	raw_widths: Array,
	raw_depths: Array,
	target_spacing: float
) -> Dictionary:
	var points: Array[Vector3] = []
	var widths: Array[float] = []
	var depths: Array[float] = []

	if raw_pts.size() < 2:
		return {
			"points": points,
			"widths": widths,
			"depths": depths
		}

	var spacing: float = maxf(
		target_spacing,
		0.25
	)

	# Primer punto.
	var current_p: Vector3 = raw_pts[0]

	points.append(current_p)
	widths.append(
		_get_array_value(
			raw_widths,
			0,
			0.8
		)
	)
	depths.append(
		_get_array_value(
			raw_depths,
			0,
			0.2
		)
	)

	var distance_accumulator: float = 0.0

	for i in range(1, raw_pts.size()):
		var a: Vector3 = raw_pts[i - 1]
		var b: Vector3 = raw_pts[i]

		var segment: Vector3 = b - a
		var segment_length: float = segment.length()

		if segment_length < 0.0001:
			continue

		var local_distance: float = 0.0

		while (
			distance_accumulator + segment_length - local_distance
			>= spacing
		):
			var remaining: float = (
				spacing
				- distance_accumulator
			)

			local_distance += remaining

			if local_distance > segment_length:
				break

			var t: float = (
				local_distance / segment_length
			)

			var p: Vector3 = a.lerp(
				b,
				t
			)

			var width_a: float = _get_array_value(
				raw_widths,
				i - 1,
				0.8
			)

			var width_b: float = _get_array_value(
				raw_widths,
				i,
				width_a
			)

			var depth_a: float = _get_array_value(
				raw_depths,
				i - 1,
				0.2
			)

			var depth_b: float = _get_array_value(
				raw_depths,
				i,
				depth_a
			)

			points.append(p)
			widths.append(
				lerpf(
					width_a,
					width_b,
					t
				)
			)
			depths.append(
				lerpf(
					depth_a,
					depth_b,
					t
				)
			)

			distance_accumulator = 0.0

		distance_accumulator += (
			segment_length - local_distance
		)

	# Último punto siempre incluido.
	var last_point: Vector3 = raw_pts[-1]

	if (
		points.is_empty()
		or points[-1].distance_to(last_point) > 0.05
	):
		points.append(last_point)

		var last_index: int = raw_pts.size() - 1

		widths.append(
			_get_array_value(
				raw_widths,
				last_index,
				0.8
			)
		)

		depths.append(
			_get_array_value(
				raw_depths,
				last_index,
				0.2
			)
		)

	return {
		"points": points,
		"widths": widths,
		"depths": depths
	}

static func _get_array_value(
	values: Array,
	index: int,
	fallback: float
) -> float:
	if index < 0 or index >= values.size():
		return fallback

	return float(values[index])

static func _triangle_is_valid(
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> bool:
	var ab: Vector3 = b - a
	var ac: Vector3 = c - a

	var cross: Vector3 = ab.cross(ac)

	# Área doble.
	var area_squared: float = cross.length_squared()

	return (
		is_finite(a.x)
		and is_finite(a.y)
		and is_finite(a.z)
		and is_finite(b.x)
		and is_finite(b.y)
		and is_finite(b.z)
		and is_finite(c.x)
		and is_finite(c.y)
		and is_finite(c.z)
		and area_squared > 0.000001
	)

static func build_confluence_patch(
	conf: Dictionary,
	result: WorldResult,
	profile: WorldProfile
) -> RefCounted:
	var c_pos: Vector2i = conf.get("position", Vector2i(-1, -1))
	if c_pos == Vector2i(-1, -1):
		return null

	var surf = _WaterSurfaceDataScript.new()
	var center_y: float = _sample_terrain(result, float(c_pos.x), float(c_pos.y)) + 0.03
	var center := Vector3(float(c_pos.x), center_y, float(c_pos.y))

	var radius: float = (profile.river_max_width * 0.75) / maxf(profile.cell_size, 0.01)
	var num_pts: int = 8
	var center_idx: int = surf.add_vertex(center, Vector3.UP, Vector2(center.x, center.z), Vector2(0, 1), profile.water_color_river)

	for k in range(num_pts + 1):
		var angle: float = float(k) * (TAU / float(num_pts))
		var px: float = center.x + cos(angle) * radius
		var pz: float = center.z + sin(angle) * radius
		var py: float = _sample_terrain(result, px, pz) + 0.025
		surf.add_vertex(Vector3(px, py, pz), Vector3.UP, Vector2(px, pz), Vector2(cos(angle), sin(angle)), profile.water_color_river)
		if k > 0:
			surf.add_triangle(center_idx, center_idx + k, center_idx + k + 1)

	return surf

static func _sample_terrain(result: WorldResult, wx: float, wz: float) -> float:
	if result == null:
		return 0.0
	var w: int = result.dimensions.x
	var h: int = result.dimensions.y
	var x0: int = clampi(int(floor(wx)), 0, w - 2)
	var z0: int = clampi(int(floor(wz)), 0, h - 2)
	var u: float = clampf(wx - float(x0), 0.0, 1.0)
	var v: float = clampf(wz - float(z0), 0.0, 1.0)

	var c00 = result.get_cell(Vector2i(x0, z0))
	var c10 = result.get_cell(Vector2i(x0 + 1, z0))
	var c01 = result.get_cell(Vector2i(x0, z0 + 1))
	var c11 = result.get_cell(Vector2i(x0 + 1, z0 + 1))

	var h00: float = c00.height if c00 != null else 0.0
	var h10: float = c10.height if c10 != null else 0.0
	var h01: float = c01.height if c01 != null else 0.0
	var h11: float = c11.height if c11 != null else 0.0

	if u + v <= 1.0:
		return h00 + u * (h10 - h00) + v * (h01 - h00)
	else:
		return h11 + (1.0 - u) * (h01 - h11) + (1.0 - v) * (h10 - h11)
