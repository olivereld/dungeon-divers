class_name CandleClusterGeometryBuilder
extends RefCounted

## Constructor geométrico procedural para Cúmulos y Agrupaciones de Velas (Candle Cluster).
## Permite generar desde pequeños grupos de 3 velas hasta grandes alfombras y santuarios de velas en el suelo.
## Características de fidelidad:
## 1. Distribución estocástica mediante agrupamiento por semillas (Poisson / Random Clustering).
## 2. Alturas, radios y sutiles inclinaciones aleatorias en cada vela.
## 3. Gotas y chorretones de cera derretida esculpidos en el fuste de las velas.
## 4. Charcos de cera fundida ("Wax Pools") que amalgaman la base en el suelo.
## 5. Llamas estilizadas en forma de gota con material emisivo cálido ("CandleFlames").

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")
const _CandleClusterGeometryConfigScript = preload("res://src/geometry_generator/config/candle_cluster_geometry_config.gd")

func build_candle_cluster_fixture(config = null):
	if config == null:
		config = _CandleClusterGeometryConfigScript.new()

	var asset = _GeneratedAssetScript.new()
	asset.asset_id = &"gothic_candle_cluster"

	var s: float = config.scale_mult
	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed

	var count: int = maxi(3, config.candle_count)
	var max_cluster_r: float = config.cluster_radius * s

	# ==========================================================================
	# 1. SUPERFICIE DE CERA (CHARCOS Y CUERPOS DE VELAS)
	# ==========================================================================
	var g_wax = _GeneratedMeshScript.new()
	g_wax.component_id = 0
	var st_wax := SurfaceTool.new()
	st_wax.begin(Mesh.PRIMITIVE_TRIANGLES)

	# ==========================================================================
	# 2. SUPERFICIE DE LLAMAS EMISIVAS
	# ==========================================================================
	var g_flames = _GeneratedMeshScript.new()
	g_flames.component_id = 1
	var st_flames := SurfaceTool.new()
	st_flames.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Generar posiciones distribuidas orgánicamente en cúmulos (sub-clusters)
	var candle_positions: Array[Vector3] = []
	var candle_radii: Array[float] = []
	var candle_heights: Array[float] = []
	var candle_tilts: Array[Basis] = []

	var sub_centers_count: int = maxi(1, int(count / 5))
	var sub_centers: Array[Vector2] = []
	for i in range(sub_centers_count):
		var dist: float = rng.randf_range(0.0, max_cluster_r * 0.6)
		var angle: float = rng.randf_range(0.0, TAU)
		sub_centers.append(Vector2(cos(angle) * dist, sin(angle) * dist))

	for i in range(count):
		var center: Vector2 = sub_centers[i % sub_centers.size()]
		var offset_dist: float = rng.randf_range(0.0, max_cluster_r * 0.45)
		var offset_angle: float = rng.randf_range(0.0, TAU)
		var c_pos_2d: Vector2 = center + Vector2(cos(offset_angle) * offset_dist, sin(offset_angle) * offset_dist)

		# Asegurar que no se salga del radio máximo
		if c_pos_2d.length() > max_cluster_r:
			c_pos_2d = c_pos_2d.normalized() * (max_cluster_r * rng.randf_range(0.8, 0.98))

		var c_radius: float = rng.randf_range(config.min_radius, config.max_radius) * s
		var c_height: float = rng.randf_range(config.min_height, config.max_height) * s

		# Inclinación orgánica sutil
		var tilt_x: float = rng.randf_range(-0.06, 0.06)
		var tilt_z: float = rng.randf_range(-0.06, 0.06)
		var c_basis := Basis.from_euler(Vector3(tilt_x, rng.randf_range(0.0, TAU), tilt_z))

		var c_pos := Vector3(c_pos_2d.x, 0.0, c_pos_2d.y)

		candle_positions.append(c_pos)
		candle_radii.append(c_radius)
		candle_heights.append(c_height)
		candle_tilts.append(c_basis)

		# 1. Construir charco de base derretida
		if config.generate_wax_pool:
			var pool_r: float = c_radius * rng.randf_range(1.4, 2.2)
			var pool_h: float = rng.randf_range(0.006, 0.014) * s
			_build_wax_pool(st_wax, c_pos, pool_r, pool_h, 8)

		# 2. Construir la vela orgánica
		var has_drips: bool = rng.randf() > 0.3
		_build_organic_candle(st_wax, c_pos, c_basis, c_radius, c_height, has_drips, rng)

		# 3. Construir la llama emisiva (95% encendidas, 5% apagadas/derretidas)
		if rng.randf() < 0.95:
			var flame_sz: float = (c_radius * 1.35) + rng.randf_range(-0.005, 0.008) * s
			var wick_top := c_pos + (c_basis * Vector3(0.0, c_height + (0.010 * s), 0.0))
			_build_teardrop_flame(st_flames, wick_top, flame_sz)

	# Finalizar y registrar superficie de cera
	st_wax.generate_tangents()
	var mesh_wax := ArrayMesh.new()
	mesh_wax = st_wax.commit(mesh_wax)
	mesh_wax.surface_set_name(0, "CandlesWax")
	g_wax.mesh = mesh_wax

	var mat_wax := StandardMaterial3D.new()
	mat_wax.albedo_color = config.wax_color
	mat_wax.roughness = 0.65
	mat_wax.metallic = 0.0
	g_wax.material_slots[0] = mat_wax
	asset.add_mesh(&"candles_wax", g_wax)

	# Finalizar y registrar superficie de llamas
	st_flames.generate_tangents()
	var mesh_flames := ArrayMesh.new()
	mesh_flames = st_flames.commit(mesh_flames)
	mesh_flames.surface_set_name(0, "CandleFlames")
	g_flames.mesh = mesh_flames

	var mat_flame := StandardMaterial3D.new()
	mat_flame.albedo_color = Color(1.0, 0.65, 0.15, 1.0)
	mat_flame.roughness = 0.1
	mat_flame.emission_enabled = true
	mat_flame.emission = Color(1.0, 0.70, 0.20, 1.0)
	mat_flame.emission_energy_multiplier = 3.8
	g_flames.material_slots[0] = mat_flame
	asset.add_mesh(&"candle_flames", g_flames)

	# Colisión cilíndrica de la base
	var col_shape := CylinderShape3D.new()
	col_shape.radius = max_cluster_r * 0.95
	col_shape.height = config.max_height * s
	g_wax.add_collision_shape(col_shape, Transform3D(Basis(), Vector3(0.0, col_shape.height * 0.5, 0.0)))

	return asset

# ==============================================================================
# SUB-CONSTRUCTORES GEOMÉTRICOS
# ==============================================================================

static func _build_wax_pool(st: SurfaceTool, pos: Vector3, radius: float, height: float, sides: int = 8) -> void:
	var center_top := pos + Vector3(0.0, height, 0.0)
	var center_bot := pos

	for i in range(sides):
		var i_next: int = (i + 1) % sides
		var a0: float = float(i) * (TAU / float(sides))
		var a1: float = float(i_next) * (TAU / float(sides))

		var p_b0 := pos + Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p_b1 := pos + Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		var p_t1 := pos + Vector3(cos(a1) * (radius * 0.85), height, sin(a1) * (radius * 0.85))
		var p_t0 := pos + Vector3(cos(a0) * (radius * 0.85), height, sin(a0) * (radius * 0.85))

		# Borde achaflanado del charco
		_add_quad_direct(st, p_b0, p_b1, p_t1, p_t0)
		# Tapa superior
		_add_triangle_direct(st, center_top, p_t0, p_t1)

static func _build_organic_candle(
	st: SurfaceTool,
	pos: Vector3,
	basis: Basis,
	radius: float,
	height: float,
	has_drips: bool,
	rng: RandomNumberGenerator
) -> void:
	var sides: int = 8
	var r_base: float = radius * 1.25
	var r_top: float = radius * 0.95

	var y_skirt: float = minf(height * 0.25, 0.04)

	# Fuste de la vela en coordenadas locales transformadas
	for i in range(sides):
		var i_next: int = (i + 1) % sides
		var a0: float = float(i) * (TAU / float(sides))
		var a1: float = float(i_next) * (TAU / float(sides))

		# Falda inferior acampanada derretida
		var l_b0 := Vector3(cos(a0) * r_base, 0.0, sin(a0) * r_base)
		var l_b1 := Vector3(cos(a1) * r_base, 0.0, sin(a1) * r_base)
		var l_m1 := Vector3(cos(a1) * radius, y_skirt, sin(a1) * radius)
		var l_m0 := Vector3(cos(a0) * radius, y_skirt, sin(a0) * radius)

		var l_t1 := Vector3(cos(a1) * r_top, height, sin(a1) * r_top)
		var l_t0 := Vector3(cos(a0) * r_top, height, sin(a0) * r_top)

		_add_quad_direct(st, pos + (basis * l_b0), pos + (basis * l_b1), pos + (basis * l_m1), pos + (basis * l_m0))
		_add_quad_direct(st, pos + (basis * l_m0), pos + (basis * l_m1), pos + (basis * l_t1), pos + (basis * l_t0))

	# Tapa cóncava derretida superior con reborde
	var center_top := pos + (basis * Vector3(0.0, height - (radius * 0.25), 0.0))
	for i in range(sides):
		var i_next: int = (i + 1) % sides
		var a0: float = float(i) * (TAU / float(sides))
		var a1: float = float(i_next) * (TAU / float(sides))
		var l_t0 := Vector3(cos(a0) * r_top, height, sin(a0) * r_top)
		var l_t1 := Vector3(cos(a1) * r_top, height, sin(a1) * r_top)
		_add_triangle_direct(st, center_top, pos + (basis * l_t0), pos + (basis * l_t1))

	# Gotas y chorretones de cera en el lateral
	if has_drips:
		var drip_count: int = rng.randi_range(1, 2)
		for d in range(drip_count):
			var drip_angle: float = rng.randf_range(0.0, TAU)
			var drip_len: float = rng.randf_range(height * 0.3, height * 0.7)
			var drip_r: float = radius * 0.35
			var d_top := pos + (basis * Vector3(cos(drip_angle) * radius, height - 0.01, sin(drip_angle) * radius))
			var d_bot := pos + (basis * Vector3(cos(drip_angle) * (radius * 1.1), height - drip_len, sin(drip_angle) * (radius * 1.1)))
			_build_faceted_drip(st, d_top, d_bot, drip_r)

static func _build_faceted_drip(st: SurfaceTool, p_top: Vector3, p_bot: Vector3, radius: float) -> void:
	var dir := (p_bot - p_top).normalized()
	var right := Vector3(dir.z, 0.0, -dir.x).normalized()
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	var out := right.cross(dir).normalized()

	var p0 := p_top + (right * radius * 0.5)
	var p1 := p_top - (right * radius * 0.5)
	var p2 := p_bot - (right * radius) + (out * radius)
	var p3 := p_bot + (right * radius) + (out * radius)
	var p_tip := p_bot + (out * radius * 1.3)

	_add_quad_direct(st, p0, p1, p2, p3)
	_add_triangle_direct(st, p_tip, p2, p3)

static func _build_teardrop_flame(st: SurfaceTool, pos: Vector3, size: float) -> void:
	var hx: float = size * 0.45
	var hy: float = size
	var hz: float = size * 0.45

	var peak := pos + Vector3(0.0, hy, 0.0)
	var bot := pos
	var mid_y := pos.y + hy * 0.35

	var v0 := Vector3(pos.x + hx, mid_y, pos.z)
	var v1 := Vector3(pos.x, mid_y, pos.z + hz)
	var v2 := Vector3(pos.x - hx, mid_y, pos.z)
	var v3 := Vector3(pos.x, mid_y, pos.z - hz)

	# Cono superior hacia la punta
	_add_triangle_direct(st, peak, v0, v1)
	_add_triangle_direct(st, peak, v1, v2)
	_add_triangle_direct(st, peak, v2, v3)
	_add_triangle_direct(st, peak, v3, v0)

	# Cono inferior redondeado
	_add_triangle_direct(st, bot, v1, v0)
	_add_triangle_direct(st, bot, v2, v1)
	_add_triangle_direct(st, bot, v3, v2)
	_add_triangle_direct(st, bot, v0, v3)

static func _add_quad_direct(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	_add_triangle_direct(st, p0, p1, p2)
	_add_triangle_direct(st, p0, p2, p3)

static func _add_triangle_direct(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3) -> void:
	var normal: Vector3 = (p1 - p0).cross(p2 - p0).normalized()
	st.set_normal(normal)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(p0)
	st.set_normal(normal)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(p1)
	st.set_normal(normal)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(p2)
