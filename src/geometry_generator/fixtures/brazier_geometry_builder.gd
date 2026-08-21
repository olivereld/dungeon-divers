class_name BrazierGeometryBuilder
extends RefCounted

## Constructor geométrico procedural de alta fidelidad para el Brasero Gótico de Pie (Brazier).
## Recrea con exactitud la topología de la referencia de Blender:
## 1. Peana/plinto octogonal escalonado con molduras achaflanadas en piedra ("Stone").
## 2. Fuste/columna central acanalada en piedra ("Stone").
## 3. Cáliz/copa acampanada superior en piedra ("Stone").
## 4. 8 Flejes y costillas de hierro forjado con corona de garras/almenas en el borde ("Iron").
## 5. Cúpula de brasas incandescentes/lava líquida emisiva ("FireEmber").
## 6. Fragmentos/rocas de carbón volcánico negro facetadas sobre las brasas ("Coals").

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")
const _BrazierGeometryConfigScript = preload("res://src/geometry_generator/config/brazier_geometry_config.gd")
const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")

func build_brazier_fixture(config = null):
	if config == null:
		config = _BrazierGeometryConfigScript.new()

	var asset = _GeneratedAssetScript.new()
	asset.asset_id = &"gothic_brazier_fixture"

	var s: float = config.scale_mult
	var num_sides: int = maxi(6, config.num_sides)
	var angles: Array[float] = []
	for i in range(num_sides):
		angles.append(float(i) * (TAU / float(num_sides)))

	# ==========================================================================
	# 1. ESTRUCTURA DE PIEDRA (BASE, FUSTE Y CÁLIZ)
	# ==========================================================================
	var g_stone = _GeneratedMeshScript.new()
	g_stone.component_id = 0
	var st_stone := SurfaceTool.new()
	st_stone.begin(Mesh.PRIMITIVE_TRIANGLES)

	# --- A. PEANA ESCALONADA (BASE TIERS) ---
	var y0: float = 0.0 * s
	var y1: float = 0.04 * s
	var y2: float = 0.07 * s
	var y3: float = 0.11 * s
	var y4: float = 0.14 * s
	var y5: float = 0.22 * s

	var r_base0: float = config.base_radius * s
	var r_base1: float = (config.base_radius * 0.94) * s
	var r_base2: float = (config.base_radius * 0.85) * s
	var r_base3: float = (config.base_radius * 0.80) * s
	var r_base4: float = (config.base_radius * 0.65) * s
	var r_shaft: float = config.shaft_radius * s

	# Fondo plano base
	_build_octagonal_cap(st_stone, y0, r_base0, angles, false)
	# Peldaño 1 (Zócalo inferior con bisel)
	_build_octagonal_frustum(st_stone, y0, y1, r_base0, r_base0, angles)
	_build_octagonal_frustum(st_stone, y1, y2, r_base0, r_base1, angles)
	# Peldaño 2 (Toro medio con bisel)
	_build_octagonal_frustum(st_stone, y2, y3, r_base1, r_base2, angles)
	_build_octagonal_frustum(st_stone, y3, y4, r_base2, r_base3, angles)
	# Transición cónica al fuste
	_build_octagonal_frustum(st_stone, y4, y5, r_base4, r_shaft, angles)

	# --- B. FUSTE / COLUMNA CENTRAL ---
	var y_shaft_top: float = 0.72 * s
	_build_octagonal_frustum(st_stone, y5, y_shaft_top, r_shaft, r_shaft, angles)

	# --- C. CÁLIZ / COPA ACAMPANADA ---
	var y_cup_mid: float = 0.86 * s
	var y_cup_top: float = 1.04 * s
	var r_cup_mid: float = (config.cup_top_radius * 0.75) * s
	var r_cup_top: float = config.cup_top_radius * s

	# Expansión inferior de la copa
	_build_octagonal_frustum(st_stone, y_shaft_top, y_cup_mid, r_shaft, r_cup_mid, angles)
	# Expansión superior y aro de la copa
	_build_octagonal_frustum(st_stone, y_cup_mid, y_cup_top, r_cup_mid, r_cup_top, angles)
	# Borde superior achaflanado de la copa
	var r_cup_in: float = (config.cup_top_radius * 0.88) * s
	_build_octagonal_hoop(st_stone, y_cup_top, y_cup_top + (0.03 * s), r_cup_top, r_cup_in, angles)

	st_stone.generate_tangents()
	var mesh_stone := ArrayMesh.new()
	mesh_stone = st_stone.commit(mesh_stone)
	mesh_stone.surface_set_name(0, "StonePedestal")
	g_stone.mesh = mesh_stone
	g_stone.material_slots[0] = _WallMaterialFactoryScript.create_panel_material()
	asset.add_mesh(&"stone_pedestal", g_stone)

	# ==========================================================================
	# 2. HERRAJE Y FLEJES DE HIERRO FORJADO CON CORONA (IRON BRACKETS & CROWN)
	# ==========================================================================
	var g_iron = _GeneratedMeshScript.new()
	g_iron.component_id = 1
	var st_iron := SurfaceTool.new()
	st_iron.begin(Mesh.PRIMITIVE_TRIANGLES)

	var strap_w: float = 0.034 * s
	var strap_thick: float = 0.022 * s

	for angle in angles:
		var dir := Vector2(cos(angle), sin(angle))
		var norm_3d := Vector3(dir.x, 0.0, dir.y)

		# 1. Pata inferior acampanada anclada a la base (Y = 0.12 a 0.22)
		var p_bot0 := Vector3(dir.x * (r_base4 + 0.015 * s), y4, dir.y * (r_base4 + 0.015 * s))
		var p_bot1 := Vector3(dir.x * (r_shaft + strap_thick * 0.5), y5, dir.y * (r_shaft + strap_thick * 0.5))
		_build_strap_segment(st_iron, p_bot0, p_bot1, strap_w, strap_thick, norm_3d)

		# 2. Fleje vertical en el fuste (Y = 0.22 a 0.72)
		var p_shaft0 := p_bot1
		var p_shaft1 := Vector3(dir.x * (r_shaft + strap_thick * 0.5), y_shaft_top, dir.y * (r_shaft + strap_thick * 0.5))
		_build_strap_segment(st_iron, p_shaft0, p_shaft1, strap_w, strap_thick, norm_3d)

		# 3. Fleje curvado abrazando la copa (Y = 0.72 a 1.04)
		var p_cup0 := p_shaft1
		var p_cup1 := Vector3(dir.x * (r_cup_mid + strap_thick * 0.5), y_cup_mid, dir.y * (r_cup_mid + strap_thick * 0.5))
		var p_cup2 := Vector3(dir.x * (r_cup_top + strap_thick * 0.5), y_cup_top, dir.y * (r_cup_top + strap_thick * 0.5))
		_build_strap_segment(st_iron, p_cup0, p_cup1, strap_w, strap_thick, norm_3d)
		_build_strap_segment(st_iron, p_cup1, p_cup2, strap_w, strap_thick, norm_3d)

		# 4. Garra / Almena de corona que sobresale del borde (Y = 1.04 a 1.14)
		var p_crown_top := Vector3(dir.x * (r_cup_top + strap_thick * 0.4), y_cup_top + (0.10 * s), dir.y * (r_cup_top + strap_thick * 0.4))
		_build_strap_segment(st_iron, p_cup2, p_crown_top, strap_w * 0.85, strap_thick, norm_3d)

	st_iron.generate_tangents()
	var mesh_iron := ArrayMesh.new()
	mesh_iron = st_iron.commit(mesh_iron)
	mesh_iron.surface_set_name(0, "IronStraps")
	g_iron.mesh = mesh_iron
	g_iron.material_slots[0] = _WallMaterialFactoryScript.create_trim_material()
	asset.add_mesh(&"iron_straps", g_iron)

	# ==========================================================================
	# 3. CAMA DE BRASAS / LAVA EMISIVA (GLOWING FIREBED DOME)
	# ==========================================================================
	var g_fire = _GeneratedMeshScript.new()
	g_fire.component_id = 2
	var st_fire := SurfaceTool.new()
	st_fire.begin(Mesh.PRIMITIVE_TRIANGLES)

	var y_fire_base: float = (y_cup_top - 0.05 * s)
	var y_fire_peak: float = (y_cup_top + 0.08 * s)
	var r_fire_base: float = r_cup_in
	var r_fire_mid: float = r_cup_in * 0.65

	# Domo de brasas incandescentes
	_build_octagonal_frustum(st_fire, y_fire_base, y_fire_base + 0.06 * s, r_fire_base, r_fire_mid, angles)
	_build_octagonal_cap_cone(st_fire, y_fire_base + 0.06 * s, y_fire_peak, r_fire_mid, angles)

	st_fire.generate_tangents()
	var mesh_fire := ArrayMesh.new()
	mesh_fire = st_fire.commit(mesh_fire)
	mesh_fire.surface_set_name(0, "GlowingFirebed")
	g_fire.mesh = mesh_fire

	# Material Emisivo Fuego / Magma
	var mat_fire := StandardMaterial3D.new()
	mat_fire.albedo_color = Color(1.0, 0.45, 0.05, 1.0)
	mat_fire.roughness = 0.2
	mat_fire.metallic = 0.1
	mat_fire.emission_enabled = true
	mat_fire.emission = Color(1.0, 0.65, 0.15, 1.0)
	mat_fire.emission_energy_multiplier = 3.8
	g_fire.material_slots[0] = mat_fire
	asset.add_mesh(&"glowing_firebed", g_fire)

	# ==========================================================================
	# 4. ROCAS DE CARBÓN VOLCÁNICO (VOLCANIC COAL CHUNKS)
	# ==========================================================================
	var g_coals = _GeneratedMeshScript.new()
	g_coals.component_id = 3
	var st_coals := SurfaceTool.new()
	st_coals.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed

	var chunk_count: int = maxi(8, config.coal_chunks_count)
	for c_idx in range(chunk_count):
		var dist: float = rng.randf_range(0.02 * s, r_fire_base * 0.85)
		var a: float = rng.randf_range(0.0, TAU)
		var rock_x: float = cos(a) * dist
		var rock_z: float = sin(a) * dist
		var norm_d: float = dist / (r_fire_base * 0.85)
		var rock_y: float = lerpf(y_fire_peak, y_fire_base + 0.04 * s, norm_d * norm_d) + rng.randf_range(-0.01, 0.01) * s

		var c_sz: float = rng.randf_range(0.035, 0.065) * s
		var rot_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).rotated(Vector3.RIGHT, rng.randf_range(-0.4, 0.4))
		var rock_xform := Transform3D(rot_basis, Vector3(rock_x, rock_y, rock_z))
		_build_faceted_coal_rock(st_coals, rock_xform, Vector3(c_sz, c_sz * 0.7, c_sz * 0.9))

	st_coals.generate_tangents()
	var mesh_coals := ArrayMesh.new()
	mesh_coals = st_coals.commit(mesh_coals)
	mesh_coals.surface_set_name(0, "CoalRocks")
	g_coals.mesh = mesh_coals

	# Material Carbón Oscuro / Basalto Volcánico
	var mat_coal := StandardMaterial3D.new()
	mat_coal.albedo_color = Color(0.12, 0.11, 0.10, 1.0)
	mat_coal.roughness = 0.92
	mat_coal.metallic = 0.05
	g_coals.material_slots[0] = mat_coal
	asset.add_mesh(&"coal_rocks", g_coals)

	# ==========================================================================
	# 5. COLISIONES FÍSICAS
	# ==========================================================================
	var col_base := CylinderShape3D.new()
	col_base.radius = r_base0 * 0.95
	col_base.height = y5
	g_stone.add_collision_shape(col_base, Transform3D(Basis(), Vector3(0.0, y5 * 0.5, 0.0)))

	var col_shaft := CylinderShape3D.new()
	col_shaft.radius = r_shaft * 1.1
	col_shaft.height = (y_shaft_top - y5)
	g_stone.add_collision_shape(col_shaft, Transform3D(Basis(), Vector3(0.0, (y5 + y_shaft_top) * 0.5, 0.0)))

	var col_cup := CylinderShape3D.new()
	col_cup.radius = r_cup_top
	col_cup.height = (y_cup_top - y_shaft_top)
	g_stone.add_collision_shape(col_cup, Transform3D(Basis(), Vector3(0.0, (y_shaft_top + y_cup_top) * 0.5, 0.0)))

	return asset

# ==============================================================================
# SUB-CONSTRUCTORES AUXILIARES
# ==============================================================================

static func _build_octagonal_frustum(st: SurfaceTool, y_bot: float, y_top: float, r_bot: float, r_top: float, angles: Array[float]) -> void:
	var n: int = angles.size()
	for i in range(n):
		var i_next: int = (i + 1) % n
		var a0: float = angles[i]
		var a1: float = angles[i_next]

		var p_b0 := Vector3(cos(a0) * r_bot, y_bot, sin(a0) * r_bot)
		var p_b1 := Vector3(cos(a1) * r_bot, y_bot, sin(a1) * r_bot)
		var p_t1 := Vector3(cos(a1) * r_top, y_top, sin(a1) * r_top)
		var p_t0 := Vector3(cos(a0) * r_top, y_top, sin(a0) * r_top)

		_add_quad_direct(st, p_b0, p_b1, p_t1, p_t0)

static func _build_octagonal_cap(st: SurfaceTool, y: float, r: float, angles: Array[float], is_top: bool) -> void:
	var n: int = angles.size()
	var center := Vector3(0.0, y, 0.0)
	for i in range(n):
		var i_next: int = (i + 1) % n
		var a0: float = angles[i]
		var a1: float = angles[i_next]
		var p0 := Vector3(cos(a0) * r, y, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, y, sin(a1) * r)
		if is_top:
			_add_triangle_direct(st, center, p0, p1)
		else:
			_add_triangle_direct(st, center, p1, p0)

static func _build_octagonal_cap_cone(st: SurfaceTool, y_base: float, y_peak: float, r_base: float, angles: Array[float]) -> void:
	var n: int = angles.size()
	var peak := Vector3(0.0, y_peak, 0.0)
	for i in range(n):
		var i_next: int = (i + 1) % n
		var a0: float = angles[i]
		var a1: float = angles[i_next]
		var p0 := Vector3(cos(a0) * r_base, y_base, sin(a0) * r_base)
		var p1 := Vector3(cos(a1) * r_base, y_base, sin(a1) * r_base)
		_add_triangle_direct(st, peak, p0, p1)

static func _build_octagonal_hoop(st: SurfaceTool, y_bot: float, y_top: float, r_out: float, r_in: float, angles: Array[float]) -> void:
	var n: int = angles.size()
	for i in range(n):
		var i_next: int = (i + 1) % n
		var a0: float = angles[i]
		var a1: float = angles[i_next]

		# Tapa superior
		var pt_o0 := Vector3(cos(a0) * r_out, y_top, sin(a0) * r_out)
		var pt_o1 := Vector3(cos(a1) * r_out, y_top, sin(a1) * r_out)
		var pt_i1 := Vector3(cos(a1) * r_in, y_top, sin(a1) * r_in)
		var pt_i0 := Vector3(cos(a0) * r_in, y_top, sin(a0) * r_in)
		_add_quad_direct(st, pt_o0, pt_o1, pt_i1, pt_i0)

		# Pared interior
		var pb_i0 := Vector3(cos(a0) * r_in, y_bot, sin(a0) * r_in)
		var pb_i1 := Vector3(cos(a1) * r_in, y_bot, sin(a1) * r_in)
		_add_quad_direct(st, pb_i1, pb_i0, pt_i0, pt_i1)

static func _build_strap_segment(st: SurfaceTool, p_start: Vector3, p_end: Vector3, width: float, depth: float, normal: Vector3) -> void:
	var tangent := normal.cross(Vector3.UP).normalized()
	var h_w := width * 0.5
	var h_d := depth * 0.5

	var p0 := p_start - (tangent * h_w) + (normal * h_d)
	var p1 := p_start + (tangent * h_w) + (normal * h_d)
	var p2 := p_end + (tangent * h_w) + (normal * h_d)
	var p3 := p_end - (tangent * h_w) + (normal * h_d)

	# Cara frontal exterior
	_add_quad_direct(st, p0, p1, p2, p3)

	# Caras laterales
	var p0_in := p_start - (tangent * h_w) - (normal * h_d)
	var p1_in := p_start + (tangent * h_w) - (normal * h_d)
	var p2_in := p_end + (tangent * h_w) - (normal * h_d)
	var p3_in := p_end - (tangent * h_w) - (normal * h_d)

	_add_quad_direct(st, p0_in, p0, p3, p3_in)
	_add_quad_direct(st, p1, p1_in, p2_in, p2)

static func _build_faceted_coal_rock(st: SurfaceTool, xform: Transform3D, size: Vector3) -> void:
	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5

	# Octaedro / roca facetada
	var top := Vector3(0, hy, 0)
	var bot := Vector3(0, -hy, 0)
	var v0 := Vector3(hx, 0, 0)
	var v1 := Vector3(0, 0, hz)
	var v2 := Vector3(-hx, 0, 0)
	var v3 := Vector3(0, 0, -hz)

	_add_tri_xform(st, xform, top, v0, v1)
	_add_tri_xform(st, xform, top, v1, v2)
	_add_tri_xform(st, xform, top, v2, v3)
	_add_tri_xform(st, xform, top, v3, v0)

	_add_tri_xform(st, xform, bot, v1, v0)
	_add_tri_xform(st, xform, bot, v2, v1)
	_add_tri_xform(st, xform, bot, v3, v2)
	_add_tri_xform(st, xform, bot, v0, v3)

static func _add_tri_xform(st: SurfaceTool, xform: Transform3D, p0: Vector3, p1: Vector3, p2: Vector3) -> void:
	_add_triangle_direct(st, xform * p0, xform * p1, xform * p2)

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
