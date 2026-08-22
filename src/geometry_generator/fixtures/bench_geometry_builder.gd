class_name BenchGeometryBuilder
extends RefCounted

## Constructor geométrico procedural para Bancas y Banquetas (Bench).
## Genera banquetas alargadas para múltiples personas en 4 estilos arquitectónicos:
## 1. `CHURCH_PEW`: Banco de templo/iglesia con laterales altos, balaustres y respaldo.
## 2. `STONE_ORIOR`: Banco monumental de piedra con patas de voluta y relieves.
## 3. `TAVERN_BENCH`: Banco de taberna con respaldo arqueado, reposabrazos y cojines.
## 4. `BACKLESS_BENCH`: Banqueta corrida rústica sin respaldo.
## 100% sólido, estanco, optimizado y con normales CCW garantizadas.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")
const _BenchGeometryConfigScript = preload("res://src/geometry_generator/config/bench_geometry_config.gd")

func build_bench_fixture(config = null) -> _GeneratedAssetScript:
	if config == null:
		config = _BenchGeometryConfigScript.new()

	var asset = _GeneratedAssetScript.new()
	var s: float = config.scale_mult
	var len_x: float = config.length * s
	var dep_z: float = config.depth * s
	var seat_h: float = config.seat_height * s
	var s_thick: float = config.seat_thickness * s
	var back_h: float = config.backrest_height * s

	var g_main = _GeneratedMeshScript.new()
	g_main.component_id = 0
	var st_main := SurfaceTool.new()
	st_main.begin(Mesh.PRIMITIVE_TRIANGLES)

	var g_trim = _GeneratedMeshScript.new()
	g_trim.component_id = 1
	var st_trim := SurfaceTool.new()
	st_trim.begin(Mesh.PRIMITIVE_TRIANGLES)

	match config.style:
		_BenchGeometryConfigScript.BenchStyle.CHURCH_PEW:
			asset.asset_id = &"church_pew_bench"
			_build_church_pew(st_main, st_trim, s, len_x, dep_z, seat_h, s_thick, back_h)
		_BenchGeometryConfigScript.BenchStyle.STONE_ORIOR:
			asset.asset_id = &"stone_orior_bench"
			_build_stone_orior(st_main, st_trim, s, len_x, dep_z, seat_h, s_thick, back_h)
		_BenchGeometryConfigScript.BenchStyle.TAVERN_BENCH:
			asset.asset_id = &"tavern_hall_bench"
			_build_tavern_bench(st_main, st_trim, s, len_x, dep_z, seat_h, s_thick, back_h)
		_BenchGeometryConfigScript.BenchStyle.BACKLESS_BENCH:
			asset.asset_id = &"rustic_backless_bench"
			_build_backless_bench(st_main, st_trim, s, len_x, dep_z, seat_h, s_thick)

	# Commit material principal
	var mesh_main := ArrayMesh.new()
	mesh_main = st_main.commit(mesh_main)
	mesh_main.surface_set_name(0, "BenchMain")
	g_main.mesh = mesh_main

	var mat_main := StandardMaterial3D.new()
	if config.style == _BenchGeometryConfigScript.BenchStyle.STONE_ORIOR:
		mat_main.albedo_color = config.stone_color
		mat_main.roughness = 0.82
	else:
		mat_main.albedo_color = config.wood_color
		mat_main.roughness = 0.70
	mat_main.metallic = 0.0
	mat_main.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_main.material_slots[0] = mat_main
	asset.add_mesh(&"bench_main", g_main)

	# Commit material secundario (Trim / Cojines / Molduras)
	var mesh_trim := ArrayMesh.new()
	mesh_trim = st_trim.commit(mesh_trim)
	if mesh_trim.get_surface_count() > 0:
		mesh_trim.surface_set_name(0, "BenchTrim")
		g_trim.mesh = mesh_trim

		var mat_trim := StandardMaterial3D.new()
		if config.style == _BenchGeometryConfigScript.BenchStyle.STONE_ORIOR:
			mat_trim.albedo_color = config.stone_trim_color
			mat_trim.roughness = 0.75
		elif config.style == _BenchGeometryConfigScript.BenchStyle.TAVERN_BENCH:
			mat_trim.albedo_color = config.cushion_color
			mat_trim.roughness = 0.85
		else:
			mat_trim.albedo_color = config.wood_trim_color
			mat_trim.roughness = 0.60
		mat_trim.metallic = 0.0
		mat_trim.cull_mode = BaseMaterial3D.CULL_DISABLED
		g_trim.material_slots[0] = mat_trim
		asset.add_mesh(&"bench_trim", g_trim)

	# Colisión física
	var total_h: float = seat_h + (back_h if config.style != _BenchGeometryConfigScript.BenchStyle.BACKLESS_BENCH else 0.0)
	var col_shape := BoxShape3D.new()
	col_shape.size = Vector3(len_x, total_h, dep_z)
	g_main.add_collision_shape(col_shape, Transform3D(Basis(), Vector3(0.0, total_h * 0.5, 0.0)))

	return asset

# ==============================================================================
# 1. BANCO DE IGLESIA / TEMPLO (CHURCH PEW)
# ==============================================================================

static func _build_church_pew(
	st_m: SurfaceTool, st_t: SurfaceTool,
	s: float, len_x: float, dep_z: float, seat_h: float, s_thick: float, back_h: float
) -> void:
	var half_len: float = len_x * 0.5
	var half_dep: float = dep_z * 0.5
	var panel_w: float = 0.05 * s

	# 1. Tabla de Asiento
	var inner_len: float = len_x - panel_w * 2.0
	var seat_y: float = seat_h - s_thick * 0.5
	var seat_z: float = 0.02 * s
	var seat_d: float = dep_z - 0.08 * s
	_build_solid_box(st_m, Vector3(0.0, seat_y, seat_z), Vector3(inner_len, s_thick, seat_d))

	# 2. Respaldo alto inclinado de madera
	var back_t: float = 0.045 * s
	var back_center_y: float = seat_h + back_h * 0.5
	var back_z: float = -half_dep + back_t * 0.5 + 0.02 * s
	_build_solid_box(st_m, Vector3(0.0, back_center_y, back_z), Vector3(inner_len, back_h, back_t))

	# Moldura superior del respaldo (Trim)
	var cap_h: float = 0.04 * s
	var cap_d: float = back_t * 1.4
	_build_solid_box(st_t, Vector3(0.0, seat_h + back_h + cap_h * 0.5, back_z), Vector3(len_x, cap_h, cap_d))

	# 3. 2 Paneles Laterales Altos Esculpidos (+X y -X)
	var side_h: float = seat_h + back_h * 0.90
	var side_d: float = dep_z
	for ix in [-1, 1]:
		var px: float = float(ix) * (half_len - panel_w * 0.5)

		# Panel base del costado
		_build_solid_box(st_m, Vector3(px, side_h * 0.5, 0.0), Vector3(panel_w, side_h, side_d))

		# Zócalo inferior del costado
		var foot_w: float = panel_w * 1.5
		var foot_h: float = 0.04 * s
		_build_solid_box(st_t, Vector3(px, foot_h * 0.5, 0.0), Vector3(foot_w, foot_h, side_d + 0.04 * s))

		# Remate / Pomo superior del costado
		var finial_h: float = 0.10 * s
		var finial_w: float = panel_w * 1.3
		var finial_d: float = 0.12 * s
		var finial_z: float = -half_dep + finial_d * 0.5
		_build_solid_box(st_t, Vector3(px, side_h + finial_h * 0.5, finial_z), Vector3(finial_w, finial_h, finial_d))

		# Reposabrazos y balaustres (Trim)
		var arm_h: float = 0.035 * s
		var arm_d: float = side_d * 0.55
		var arm_z: float = half_dep - arm_d * 0.5
		var arm_y: float = seat_h + 0.22 * s
		_build_solid_box(st_t, Vector3(px, arm_y, arm_z), Vector3(panel_w * 1.4, arm_h, arm_d))

		# 2 Balaustres/Columnillas bajo el reposabrazos
		var bal_r: float = 0.02 * s
		var bal_h: float = arm_y - seat_h - arm_h * 0.5
		var bal_y: float = seat_h + bal_h * 0.5
		_build_solid_box(st_t, Vector3(px, bal_y, half_dep - 0.10 * s), Vector3(bal_r * 2.0, bal_h, bal_r * 2.0))
		_build_solid_box(st_t, Vector3(px, bal_y, half_dep - 0.20 * s), Vector3(bal_r * 2.0, bal_h, bal_r * 2.0))

	# 4. Pata/Soporte central bajo el asiento
	var center_leg_w: float = 0.04 * s
	var center_leg_h: float = seat_h - s_thick
	_build_solid_box(st_m, Vector3(0.0, center_leg_h * 0.5, seat_z), Vector3(center_leg_w, center_leg_h, seat_d * 0.75))

# ==============================================================================
# 2. BANCO MONUMENTAL DE PIEDRA (STONE ORIOR)
# ==============================================================================

static func _build_stone_orior(
	st_m: SurfaceTool, st_t: SurfaceTool,
	s: float, len_x: float, dep_z: float, seat_h: float, s_thick: float, back_h: float
) -> void:
	var half_len: float = len_x * 0.5
	var half_dep: float = dep_z * 0.5

	# 1. Losa gruesa de asiento de piedra con bisel
	var slab_t: float = s_thick * 1.5
	var slab_y: float = seat_h - slab_t * 0.5
	_build_solid_box(st_m, Vector3(0.0, slab_y, 0.0), Vector3(len_x, slab_t, dep_z))

	# Reborde moldurado exterior del asiento (Trim)
	var trim_t: float = 0.02 * s
	_build_solid_box(st_t, Vector3(0.0, slab_y, half_dep + trim_t * 0.5), Vector3(len_x + 0.02 * s, slab_t * 0.8, trim_t))
	_build_solid_box(st_t, Vector3(0.0, slab_y, -half_dep - trim_t * 0.5), Vector3(len_x + 0.02 * s, slab_t * 0.8, trim_t))

	# 2. Patas de piedra esculpida en voluta (3 patas: Izquierda, Centro, Derecha)
	var leg_w: float = 0.08 * s
	var leg_h: float = seat_h - slab_t
	var leg_d: float = dep_z * 0.80

	for pos_x in [-half_len + 0.16 * s, 0.0, half_len - 0.16 * s]:
		# Pilar principal de la pata
		_build_solid_box(st_m, Vector3(pos_x, leg_h * 0.5, 0.0), Vector3(leg_w, leg_h, leg_d))

		# Pie de voluta / zapata inferior ensanchada (Trim)
		var foot_h: float = 0.06 * s
		_build_solid_box(st_t, Vector3(pos_x, foot_h * 0.5, 0.0), Vector3(leg_w * 1.3, foot_h, leg_d + 0.08 * s))

		# Capitel superior bajo la losa
		_build_solid_box(st_t, Vector3(pos_x, leg_h - foot_h * 0.5, 0.0), Vector3(leg_w * 1.25, foot_h, leg_d + 0.04 * s))

	# 3. Respaldo de piedra esculpida
	var back_t: float = 0.06 * s
	var back_y: float = seat_h + back_h * 0.5
	var back_z: float = -half_dep + back_t * 0.5
	_build_solid_box(st_m, Vector3(0.0, back_y, back_z), Vector3(len_x, back_h, back_t))

	# Relieves decorativos góticos / crestas en el respaldo (Trim)
	var crest_h: float = 0.08 * s
	_build_solid_box(st_t, Vector3(0.0, seat_h + back_h + crest_h * 0.5, back_z), Vector3(len_x * 0.70, crest_h, back_t * 1.1))

	# 2 Remates / Finials superiores en los extremos del respaldo
	var fin_w: float = 0.09 * s
	var fin_h: float = 0.12 * s
	_build_solid_box(st_t, Vector3(-half_len + fin_w * 0.5, seat_h + back_h + fin_h * 0.5, back_z), Vector3(fin_w, fin_h, fin_w))
	_build_solid_box(st_t, Vector3(half_len - fin_w * 0.5, seat_h + back_h + fin_h * 0.5, back_z), Vector3(fin_w, fin_h, fin_w))

# ==============================================================================
# 3. BANCO ESTILIZADO DE TABERNA CON COJINES (TAVERN BENCH)
# ==============================================================================

static func _build_tavern_bench(
	st_m: SurfaceTool, st_t: SurfaceTool,
	s: float, len_x: float, dep_z: float, seat_h: float, s_thick: float, back_h: float
) -> void:
	var half_len: float = len_x * 0.5
	var half_dep: float = dep_z * 0.5

	# 1. Armazón de madera del asiento
	var seat_y: float = seat_h - s_thick * 0.5
	_build_solid_box(st_m, Vector3(0.0, seat_y, 0.0), Vector3(len_x, s_thick, dep_z))

	# 2. Dos cojines acolchados mullidos sobre el asiento (Trim)
	var cush_w: float = (len_x - 0.12 * s) * 0.5
	var cush_d: float = dep_z - 0.08 * s
	var cush_h: float = 0.045 * s
	var cush_y: float = seat_h + cush_h * 0.5

	_build_solid_box(st_t, Vector3(-cush_w * 0.5 - 0.02 * s, cush_y, 0.02 * s), Vector3(cush_w, cush_h, cush_d))
	_build_solid_box(st_t, Vector3(cush_w * 0.5 + 0.02 * s, cush_y, 0.02 * s), Vector3(cush_w, cush_h, cush_d))

	# 3. Respaldo arqueado con barrotes de madera
	var back_t: float = 0.04 * s
	var back_z: float = -half_dep + back_t * 0.5
	var crest_h: float = back_h * 0.40
	var crest_y: float = seat_h + back_h - crest_h * 0.5

	# Cresta superior arqueada
	_build_solid_box(st_m, Vector3(0.0, crest_y, back_z), Vector3(len_x, crest_h, back_t))

	# Barrotes verticales entre el asiento y la cresta
	var num_slats: int = 6
	var slat_w: float = 0.04 * s
	var slat_h: float = back_h - crest_h
	var slat_y: float = seat_h + slat_h * 0.5
	var slat_spacing: float = (len_x - 0.20 * s) / float(num_slats - 1)

	for i in range(num_slats):
		var sx: float = -half_len + 0.10 * s + float(i) * slat_spacing
		_build_solid_box(st_m, Vector3(sx, slat_y, back_z), Vector3(slat_w, slat_h, back_t * 0.8))

	# 4. 4 Patas torneadas y reposabrazos
	var leg_w: float = 0.06 * s
	var leg_h: float = seat_h - s_thick
	var lx: float = half_len - leg_w * 0.7
	var lz: float = half_dep - leg_w * 0.7

	for ix in [-1, 1]:
		for iz in [-1, 1]:
			var px: float = float(ix) * lx
			var pz: float = float(iz) * lz
			_build_solid_box(st_m, Vector3(px, leg_h * 0.5, pz), Vector3(leg_w, leg_h, leg_w))

		# Reposabrazos laterales
		var px_arm: float = float(ix) * (half_len - leg_w * 0.5)
		var arm_h: float = 0.04 * s
		var arm_d: float = dep_z * 0.70
		var arm_y: float = seat_h + 0.22 * s
		_build_solid_box(st_m, Vector3(px_arm, arm_y, 0.0), Vector3(leg_w, arm_h, arm_d))

		# Poste frontal del reposabrazos
		var post_h: float = arm_y - seat_h
		_build_solid_box(st_m, Vector3(px_arm, seat_h + post_h * 0.5, half_dep - 0.06 * s), Vector3(leg_w * 0.9, post_h, leg_w * 0.9))

# ==============================================================================
# 4. BANQUETA CORRIDA RÚSTICA SIN RESPALDO (BACKLESS BENCH)
# ==============================================================================

static func _build_backless_bench(
	st_m: SurfaceTool, st_t: SurfaceTool,
	s: float, len_x: float, dep_z: float, seat_h: float, s_thick: float
) -> void:
	var half_len: float = len_x * 0.5
	var half_dep: float = dep_z * 0.5

	# 1. Tablón grueso del asiento
	var seat_y: float = seat_h - s_thick * 0.5
	_build_solid_box(st_m, Vector3(0.0, seat_y, 0.0), Vector3(len_x, s_thick, dep_z))

	# Refuerzos de listón en los extremos (Trim)
	var strap_w: float = 0.05 * s
	var strap_t: float = 0.015 * s
	_build_solid_box(st_t, Vector3(-half_len + strap_w * 0.5, seat_y, 0.0), Vector3(strap_w, s_thick + strap_t * 2.0, dep_z + strap_t * 2.0))
	_build_solid_box(st_t, Vector3(half_len - strap_w * 0.5, seat_y, 0.0), Vector3(strap_w, s_thick + strap_t * 2.0, dep_z + strap_t * 2.0))

	# 2. 4 Patas robustas cuadradas
	var leg_w: float = 0.07 * s
	var leg_h: float = seat_h - s_thick
	var lx: float = half_len - leg_w * 1.1
	var lz: float = half_dep - leg_w * 1.1

	for ix in [-1, 1]:
		for iz in [-1, 1]:
			var px: float = float(ix) * lx
			var pz: float = float(iz) * lz
			_build_solid_box(st_m, Vector3(px, leg_h * 0.5, pz), Vector3(leg_w, leg_h, leg_w))

	# 3. Travesaño longitudinal inferior de refuerzo
	var beam_h: float = 0.045 * s
	var beam_w: float = len_x - leg_w * 2.5
	var beam_d: float = 0.04 * s
	var beam_y: float = leg_h * 0.40
	_build_solid_box(st_m, Vector3(0.0, beam_y, 0.0), Vector3(beam_w, beam_h, beam_d))

# ==============================================================================
# SUB-CONSTRUCTORES GEOMÉTRICOS CON NORMALES DIRIGIDAS
# ==============================================================================

static func _build_solid_box(st: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5

	var x0 := center.x - hx; var x1 := center.x + hx
	var y0 := center.y - hy; var y1 := center.y + hy
	var z0 := center.z - hz; var z1 := center.z + hz

	# 1. Frontal (+Z) -> Normal (0, 0, 1)
	_add_quad_facing(st, Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3(0, 0, 1))

	# 2. Trasera (-Z) -> Normal (0, 0, -1)
	_add_quad_facing(st, Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(0, 0, -1))

	# 3. Derecha (+X) -> Normal (1, 0, 0)
	_add_quad_facing(st, Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(1, 0, 0))

	# 4. Izquierda (-X) -> Normal (-1, 0, 0)
	_add_quad_facing(st, Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3(-1, 0, 0))

	# 5. Superior (+Y) -> Normal (0, 1, 0)
	_add_quad_facing(st, Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3(0, 1, 0))

	# 6. Inferior (-Y) -> Normal (0, -1, 0)
	_add_quad_facing(st, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3(0, -1, 0))

static func _add_quad_facing(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, expected_normal: Vector3) -> void:
	var n: Vector3 = (p1 - p0).cross(p2 - p0)
	if n.dot(expected_normal) >= 0.0:
		_add_tri_facing(st, p0, p1, p2, expected_normal)
		_add_tri_facing(st, p0, p2, p3, expected_normal)
	else:
		_add_tri_facing(st, p0, p3, p2, expected_normal)
		_add_tri_facing(st, p0, p2, p1, expected_normal)

static func _add_tri_facing(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, normal: Vector3) -> void:
	st.set_normal(normal)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(p0)
	st.set_normal(normal)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(p1)
	st.set_normal(normal)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(p2)
