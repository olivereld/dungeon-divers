class_name BrickGeometryBuilder
extends RefCounted

## Generador procedural de geometría para ladrillos estilizados, molduras con juntas y paneles de muro.
## Garantiza orden de devanado CCW exterior y normales hacia afuera para renderizado 100% sólido en Godot 4.

## Añade un ladrillo estilizado redondeado/almohadillado (pillowed brick) con aristas biseladas suaves.
static func append_pillowed_brick(
	st: SurfaceTool,
	size: Vector3,
	transform: Transform3D,
	bevel: float = 0.030,
	uv_scale: Vector2 = Vector2.ONE
) -> void:
	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5

	var b: float = clampf(bevel, 0.001, minf(hx, minf(hy, hz)) * 0.45)
	var ix: float = hx - b
	var iy: float = hy - b
	var iz: float = hz - b

	# 1. Cara Frontal (+Z)
	_add_quad(st, transform,
		Vector3(-ix, -iy, hz), Vector3(ix, -iy, hz),
		Vector3(ix, iy, hz), Vector3(-ix, iy, hz),
		uv_scale
	)

	# 2. Cara Trasera (-Z)
	_add_quad(st, transform,
		Vector3(ix, -iy, -hz), Vector3(-ix, -iy, -hz),
		Vector3(-ix, iy, -hz), Vector3(ix, iy, -hz),
		uv_scale
	)

	# 3. Cara Derecha (+X)
	_add_quad(st, transform,
		Vector3(hx, -iy, iz), Vector3(hx, -iy, -iz),
		Vector3(hx, iy, -iz), Vector3(hx, iy, iz),
		uv_scale
	)

	# 4. Cara Izquierda (-X)
	_add_quad(st, transform,
		Vector3(-hx, -iy, -iz), Vector3(-hx, -iy, iz),
		Vector3(-hx, iy, iz), Vector3(-hx, iy, -iz),
		uv_scale
	)

	# 5. Cara Superior (+Y)
	_add_quad(st, transform,
		Vector3(-ix, hy, iz), Vector3(ix, hy, iz),
		Vector3(ix, hy, -iz), Vector3(-ix, hy, -iz),
		uv_scale
	)

	# 6. Cara Inferior (-Y)
	_add_quad(st, transform,
		Vector3(-ix, -hy, -iz), Vector3(ix, -hy, -iz),
		Vector3(ix, -hy, iz), Vector3(-ix, -hy, iz),
		uv_scale
	)

	# 7. Biseles de Aristas Horizontales Frontales y Traseras
	# Frontal Superior (+Z +Y)
	_add_quad(st, transform,
		Vector3(-ix, iy, hz), Vector3(ix, iy, hz),
		Vector3(ix, hy, iz), Vector3(-ix, hy, iz),
		uv_scale
	)
	# Frontal Inferior (+Z -Y)
	_add_quad(st, transform,
		Vector3(-ix, -hy, iz), Vector3(ix, -hy, iz),
		Vector3(ix, -iy, hz), Vector3(-ix, -iy, hz),
		uv_scale
	)
	# Trasera Superior (-Z +Y)
	_add_quad(st, transform,
		Vector3(-ix, hy, -iz), Vector3(ix, hy, -iz),
		Vector3(ix, iy, -hz), Vector3(-ix, iy, -hz),
		uv_scale
	)
	# Trasera Inferior (-Z -Y)
	_add_quad(st, transform,
		Vector3(-ix, -iy, -hz), Vector3(ix, -iy, -hz),
		Vector3(ix, -hy, -iz), Vector3(-ix, -hy, -iz),
		uv_scale
	)

	# 8. Biseles de Aristas Verticales Frontales y Traseras
	# Frontal Derecha (+X +Z)
	_add_quad(st, transform,
		Vector3(ix, -iy, hz), Vector3(hx, -iy, iz),
		Vector3(hx, iy, iz), Vector3(ix, iy, hz),
		uv_scale
	)
	# Frontal Izquierda (-X +Z)
	_add_quad(st, transform,
		Vector3(-hx, -iy, iz), Vector3(-ix, -iy, hz),
		Vector3(-ix, iy, hz), Vector3(-hx, iy, iz),
		uv_scale
	)
	# Trasera Derecha (+X -Z)
	_add_quad(st, transform,
		Vector3(hx, -iy, -iz), Vector3(ix, -iy, -hz),
		Vector3(ix, iy, -hz), Vector3(hx, iy, -iz),
		uv_scale
	)
	# Trasera Izquierda (-X -Z)
	_add_quad(st, transform,
		Vector3(-ix, -iy, -hz), Vector3(-hx, -iy, -iz),
		Vector3(-hx, iy, -iz), Vector3(-ix, iy, -hz),
		uv_scale
	)

	# 9. Biseles de Aristas Horizontales Laterales (+X y -X con +Y y -Y)
	# Lateral Derecha Superior (+X +Y)
	_add_quad(st, transform,
		Vector3(ix, hy, iz), Vector3(hx, iy, iz),
		Vector3(hx, iy, -iz), Vector3(ix, hy, -iz),
		uv_scale
	)
	# Lateral Derecha Inferior (+X -Y)
	_add_quad(st, transform,
		Vector3(hx, -iy, iz), Vector3(ix, -hy, iz),
		Vector3(ix, -hy, -iz), Vector3(hx, -iy, -iz),
		uv_scale
	)
	# Lateral Izquierda Superior (-X +Y)
	_add_quad(st, transform,
		Vector3(-hx, iy, iz), Vector3(-ix, hy, iz),
		Vector3(-ix, hy, -iz), Vector3(-hx, iy, -iz),
		uv_scale
	)
	# Lateral Izquierda Inferior (-X -Y)
	_add_quad(st, transform,
		Vector3(-ix, -hy, iz), Vector3(-hx, -iy, iz),
		Vector3(-hx, -iy, -iz), Vector3(-ix, -hy, -iz),
		uv_scale
	)

## Añade una moldura/viga con ranura divisoria vertical (notch).
static func append_trim_beam_with_notch(
	st: SurfaceTool,
	length: float,
	height: float,
	depth: float,
	transform: Transform3D,
	notch_width: float = 0.035,
	bevel: float = 0.015
) -> void:
	var half_len: float = length * 0.5
	var half_notch: float = notch_width * 0.5
	var seg_w: float = half_len - half_notch

	if seg_w <= 0.05:
		append_beveled_box(st, Vector3(length, height, depth), transform, bevel)
		return

	# Bloque izquierdo
	var left_center_x: float = -(half_notch + (seg_w * 0.5))
	var left_t := transform * Transform3D(Basis(), Vector3(left_center_x, 0.0, 0.0))
	append_beveled_box(st, Vector3(seg_w, height, depth), left_t, bevel)

	# Bloque derecho
	var right_center_x: float = half_notch + (seg_w * 0.5)
	var right_t := transform * Transform3D(Basis(), Vector3(right_center_x, 0.0, 0.0))
	append_beveled_box(st, Vector3(seg_w, height, depth), right_t, bevel)

## Añade una caja estándar con bisel suave.
static func append_beveled_box(
	st: SurfaceTool,
	size: Vector3,
	transform: Transform3D,
	bevel: float = 0.015,
	uv_scale: Vector2 = Vector2.ONE
) -> void:
	append_pillowed_brick(st, size, transform, bevel, uv_scale)

## Añade un cuadrilátero garantizando orden de devanado CCW exterior y normales hacia afuera.
static func _add_quad(
	st: SurfaceTool,
	transform: Transform3D,
	p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
	uv_scale: Vector2
) -> void:
	var w0: Vector3 = transform * p0
	var w1: Vector3 = transform * p1
	var w2: Vector3 = transform * p2
	var w3: Vector3 = transform * p3

	# Normal geométrica exterior para devanado CCW (w1 - w0) x (w2 - w0)
	var normal: Vector3 = (w1 - w0).cross(w2 - w0).normalized()

	# Comprobar que apunta hacia afuera del centro de la pieza
	var local_center: Vector3 = (p0 + p1 + p2 + p3) * 0.25
	if local_center.length_squared() > 0.0001:
		var world_center_dir: Vector3 = (transform.basis * local_center).normalized()
		if normal.dot(world_center_dir) < -0.05:
			normal = -normal
			var temp: Vector3 = w1
			w1 = w3
			w3 = temp

	# Triángulo 1: w0 -> w1 -> w2 (CCW exterior)
	st.set_normal(normal)
	st.set_uv(Vector2(0.0, 0.0) * uv_scale)
	st.add_vertex(w0)

	st.set_normal(normal)
	st.set_uv(Vector2(1.0, 0.0) * uv_scale)
	st.add_vertex(w1)

	st.set_normal(normal)
	st.set_uv(Vector2(1.0, 1.0) * uv_scale)
	st.add_vertex(w2)

	# Triángulo 2: w0 -> w2 -> w3 (CCW exterior)
	st.set_normal(normal)
	st.set_uv(Vector2(0.0, 0.0) * uv_scale)
	st.add_vertex(w0)

	st.set_normal(normal)
	st.set_uv(Vector2(1.0, 1.0) * uv_scale)
	st.add_vertex(w2)

	st.set_normal(normal)
	st.set_uv(Vector2(0.0, 1.0) * uv_scale)
	st.add_vertex(w3)
