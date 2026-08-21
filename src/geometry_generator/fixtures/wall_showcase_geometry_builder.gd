class_name WallShowcaseGeometryBuilder
extends RefCounted

## Constructor geométrico procedural para Muros Rectos 3x2 de Mazmorra (Wall Showcase).
## Geometría estilizada sólida y estanca con normales y devanado CCW garantizados:
## 1. `wall_stone`: Piedra estructural principal (cuerpo, costados y fondo).
## 2. `wall_stone_trim`: Zócalos, cornisas, alféizares, ladrillos en relieve y molduras.
## 3. `wall_iron`: Rejas y barrotes de hierro forjado (ventana de celda).
## 4. `wall_foliage`: Hojas y vegetación de mazmorra.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")
const _WallShowcaseGeometryConfigScript = preload("res://src/geometry_generator/config/wall_showcase_geometry_config.gd")

func build_wall_showcase_fixture(config = null):
	if config == null:
		config = _WallShowcaseGeometryConfigScript.new()

	var asset = _GeneratedAssetScript.new()
	asset.asset_id = &"stylized_wall_showcase_3x2"

	var s: float = config.scale_mult
	var w: float = config.width * s
	var h: float = config.height * s
	var d: float = config.depth * s

	# 1. Piedra principal
	var g_stone = _GeneratedMeshScript.new()
	g_stone.component_id = 0
	var st_stone := SurfaceTool.new()
	st_stone.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 2. Molduras y Ladrillos
	var g_trim = _GeneratedMeshScript.new()
	g_trim.component_id = 1
	var st_trim := SurfaceTool.new()
	st_trim.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 3. Hierro Forjado
	var g_iron = _GeneratedMeshScript.new()
	g_iron.component_id = 2
	var st_iron := SurfaceTool.new()
	st_iron.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 4. Follaje / Vegetación
	var g_foliage = _GeneratedMeshScript.new()
	g_foliage.component_id = 3
	var st_foliage := SurfaceTool.new()
	st_foliage.begin(Mesh.PRIMITIVE_TRIANGLES)

	match config.variant:
		_WallShowcaseGeometryConfigScript.WallVariant.BARRED_WINDOW:
			_build_barred_window_wall(st_stone, st_trim, st_iron, s, w, h, d)
		_WallShowcaseGeometryConfigScript.WallVariant.CENTER_PILASTER:
			_build_center_pilaster_wall(st_stone, st_trim, s, w, h, d)
		_WallShowcaseGeometryConfigScript.WallVariant.FISSURE_BRICKS:
			_build_fissure_bricks_wall(st_stone, st_trim, st_foliage, s, w, h, d)

	# Commit Piedra Principal
	var mesh_stone := ArrayMesh.new()
	mesh_stone = st_stone.commit(mesh_stone)
	mesh_stone.surface_set_name(0, "WallStone")
	g_stone.mesh = mesh_stone

	var mat_stone := StandardMaterial3D.new()
	mat_stone.albedo_color = config.stone_color
	mat_stone.roughness = 0.85
	mat_stone.metallic = 0.0
	mat_stone.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_stone.material_slots[0] = mat_stone
	asset.add_mesh(&"wall_stone", g_stone)

	# Commit Molduras / Ladrillos
	var mesh_trim := ArrayMesh.new()
	mesh_trim = st_trim.commit(mesh_trim)
	if mesh_trim.get_surface_count() > 0:
		mesh_trim.surface_set_name(0, "WallStoneTrim")
		g_trim.mesh = mesh_trim

		var mat_trim := StandardMaterial3D.new()
		mat_trim.albedo_color = config.stone_dark_color
		mat_trim.roughness = 0.78
		mat_trim.metallic = 0.0
		mat_trim.cull_mode = BaseMaterial3D.CULL_DISABLED
		g_trim.material_slots[0] = mat_trim
		asset.add_mesh(&"wall_stone_trim", g_trim)

	# Commit Hierro Forjado
	var mesh_iron := ArrayMesh.new()
	mesh_iron = st_iron.commit(mesh_iron)
	if mesh_iron.get_surface_count() > 0:
		mesh_iron.surface_set_name(0, "WallIron")
		g_iron.mesh = mesh_iron

		var mat_iron := StandardMaterial3D.new()
		mat_iron.albedo_color = config.metal_color
		mat_iron.roughness = 0.38
		mat_iron.metallic = 0.85
		mat_iron.cull_mode = BaseMaterial3D.CULL_DISABLED
		g_iron.material_slots[0] = mat_iron
		asset.add_mesh(&"wall_iron", g_iron)

	# Commit Vegetación
	var mesh_foliage := ArrayMesh.new()
	mesh_foliage = st_foliage.commit(mesh_foliage)
	if mesh_foliage.get_surface_count() > 0:
		mesh_foliage.surface_set_name(0, "WallFoliage")
		g_foliage.mesh = mesh_foliage

		var mat_foliage := StandardMaterial3D.new()
		mat_foliage.albedo_color = config.foliage_color
		mat_foliage.roughness = 0.60
		mat_foliage.metallic = 0.0
		mat_foliage.cull_mode = BaseMaterial3D.CULL_DISABLED
		g_foliage.material_slots[0] = mat_foliage
		asset.add_mesh(&"wall_foliage", g_foliage)

	# Colisión física
	var col_shape := BoxShape3D.new()
	col_shape.size = Vector3(w, h, d + 0.16 * s)
	g_stone.add_collision_shape(col_shape, Transform3D(Basis(), Vector3(0.0, h * 0.5, 0.0)))

	return asset

# ==============================================================================
# BASE COMÚN: ZÓCALO Y CORNISA DE 3 BLOQUES
# ==============================================================================

static func _build_base_and_cornice(
	st_s: SurfaceTool, st_t: SurfaceTool,
	s: float, w: float, h: float, d: float
) -> void:
	var plinth_h: float = 0.42 * s
	var plinth_slope: float = 0.10 * s
	var corn_h: float = 0.52 * s
	var corn_slope: float = 0.12 * s
	var overhang: float = 0.08 * s

	# 1. Cuerpo base de pared trasera y lados
	_build_solid_box(st_s, Vector3(0.0, h * 0.5, -0.02 * s), Vector3(w, h, d))

	# 2. Zócalo inferior en 3 bloques con ranuras verticales (V-grooves)
	var block_w: float = (w - 0.06 * s) / 3.0
	var z_offsets = [-block_w - 0.025 * s, 0.0, block_w + 0.025 * s]

	for bx in z_offsets:
		# Bloque inferior vertical
		_build_solid_box(st_t, Vector3(bx, (plinth_h - plinth_slope) * 0.5, overhang * 0.5), Vector3(block_w, plinth_h - plinth_slope, d + overhang))
		# Bisel superior del zócalo (chaflán)
		_build_solid_box(st_t, Vector3(bx, plinth_h - plinth_slope * 0.5, overhang * 0.25), Vector3(block_w, plinth_slope, d + overhang * 0.5))

	# 3. Cornisa superior en 3 bloques con ranuras verticales
	for bx in z_offsets:
		# Bisel inferior de la cornisa
		_build_solid_box(st_t, Vector3(bx, h - corn_h + corn_slope * 0.5, overhang * 0.25), Vector3(block_w, corn_slope, d + overhang * 0.5))
		# Bloque superior vertical
		_build_solid_box(st_t, Vector3(bx, h - (corn_h - corn_slope) * 0.5, overhang * 0.5), Vector3(block_w, corn_h - corn_slope, d + overhang))

# ==============================================================================
# 1. VARIANTE: VENTANA ENREJADA DE CELDA DE MAZMORRA (HUECA PASANTE)
# ==============================================================================

static func _build_barred_window_wall(
	st_s: SurfaceTool, st_t: SurfaceTool, st_i: SurfaceTool,
	s: float, w: float, h: float, d: float
) -> void:
	var plinth_h: float = 0.42 * s
	var plinth_slope: float = 0.10 * s
	var corn_h: float = 0.52 * s
	var corn_slope: float = 0.12 * s
	var overhang: float = 0.08 * s

	# 1. Zócalo inferior (3 bloques)
	var block_w: float = (w - 0.06 * s) / 3.0
	var z_offsets = [-block_w - 0.025 * s, 0.0, block_w + 0.025 * s]
	for bx in z_offsets:
		_build_solid_box(st_t, Vector3(bx, (plinth_h - plinth_slope) * 0.5, overhang * 0.5), Vector3(block_w, plinth_h - plinth_slope, d + overhang))
		_build_solid_box(st_t, Vector3(bx, plinth_h - plinth_slope * 0.5, overhang * 0.25), Vector3(block_w, plinth_slope, d + overhang * 0.5))

	# 2. Cornisa superior (3 bloques)
	for bx in z_offsets:
		_build_solid_box(st_t, Vector3(bx, h - corn_h + corn_slope * 0.5, overhang * 0.25), Vector3(block_w, corn_slope, d + overhang * 0.5))
		_build_solid_box(st_t, Vector3(bx, h - (corn_h - corn_slope) * 0.5, overhang * 0.5), Vector3(block_w, corn_h - corn_slope, d + overhang))

	# 3. Dimensiones del vano central hueco
	var win_w: float = 1.54 * s
	var sill_y: float = 1.15 * s
	var sill_h: float = 0.14 * s
	var win_bot_y: float = sill_y + sill_h * 0.5
	var win_top_y: float = 2.85 * s
	var wall_mid_h: float = h - plinth_h - corn_h
	var wall_mid_cy: float = plinth_h + wall_mid_h * 0.5

	# 4. Paneles de Muro con Hueco Central Pasante (Sin tapar la ventana)
	var side_wall_w: float = (w - win_w) * 0.5
	var left_wall_x: float = -w * 0.5 + side_wall_w * 0.5
	var right_wall_x: float = w * 0.5 - side_wall_w * 0.5

	# Paño lateral izquierdo
	_build_solid_box(st_s, Vector3(left_wall_x, wall_mid_cy, 0.0), Vector3(side_wall_w, wall_mid_h, d))
	# Paño lateral derecho
	_build_solid_box(st_s, Vector3(right_wall_x, wall_mid_cy, 0.0), Vector3(side_wall_w, wall_mid_h, d))
	# Antepecho inferior bajo la ventana
	var under_h: float = sill_y - plinth_h
	_build_solid_box(st_s, Vector3(0.0, plinth_h + under_h * 0.5, 0.0), Vector3(win_w, under_h, d))
	# Dintel superior sobre la ventana
	var over_h: float = (h - corn_h) - win_top_y
	_build_solid_box(st_s, Vector3(0.0, win_top_y + over_h * 0.5, 0.0), Vector3(win_w, over_h, d))

	# 5. Alféizar de piedra pasante
	var sill_d: float = d + 0.16 * s
	_build_solid_box(st_t, Vector3(0.0, sill_y, 0.0), Vector3(win_w + 0.32 * s, sill_h, sill_d))

	# 6. Jambas laterales de piedra (enmarcan la ventana por delante y por detrás)
	var jamba_w: float = 0.16 * s
	var jamba_h: float = win_top_y - win_bot_y - 0.65 * s
	var jamba_cy: float = win_bot_y + jamba_h * 0.5
	var jamba_d: float = d + 0.10 * s

	_build_solid_box(st_t, Vector3(-win_w * 0.5 + jamba_w * 0.1, jamba_cy, 0.0), Vector3(jamba_w, jamba_h, jamba_d))
	_build_solid_box(st_t, Vector3(win_w * 0.5 - jamba_w * 0.1, jamba_cy, 0.0), Vector3(jamba_w, jamba_h, jamba_d))

	# 7. Arco denso de dovelas de piedra (13 dovelas radiales trabadas)
	var arc_cy: float = win_bot_y + jamba_h
	var r_in: float = win_w * 0.5 - jamba_w * 0.5
	var r_out: float = r_in + 0.24 * s
	var arc_d: float = d + 0.12 * s
	var dovelas: int = 13

	for i in range(dovelas):
		var a0: float = PI - float(i) * (PI / float(dovelas))
		var a1: float = PI - float(i + 1) * (PI / float(dovelas))
		var mid_a: float = (a0 + a1) * 0.5

		var r_mid: float = (r_in + r_out) * 0.5
		var arc_px: float = cos(mid_a) * r_mid
		var arc_py: float = arc_cy + sin(mid_a) * r_mid

		var rad_thick: float = r_out - r_in
		var tan_w: float = (r_in * (PI / float(dovelas))) * 1.08

		# La dovela central (clave) es un poco más prominente
		if i == 6:
			rad_thick *= 1.15
			arc_py += 0.02 * s

		var b := Basis.from_euler(Vector3(0.0, 0.0, mid_a - PI * 0.5))
		_build_oriented_solid_box(st_t, Transform3D(b, Vector3(arc_px, arc_py, 0.0)), Vector3(tan_w, rad_thick, arc_d))

	# 8. Reja de Hierro Forjado en el Centro del Hueco (Completamente Pasante)
	var bar_thick: float = 0.036 * s
	var grate_h: float = win_top_y - win_bot_y
	var grate_w: float = win_w - jamba_w * 0.8

	# Barrotes verticales (4 barras continuas de hierro)
	var vert_xs = [-grate_w * 0.38, -grate_w * 0.13, grate_w * 0.13, grate_w * 0.38]
	for vx in vert_xs:
		var bh := grate_h * 0.94
		_build_solid_box(st_i, Vector3(vx, win_bot_y + bh * 0.5, 0.0), Vector3(bar_thick, bh, bar_thick))

	# Barrotes horizontales (4 barras continuas de hierro)
	var horiz_ys = [win_bot_y + 0.30 * s, win_bot_y + 0.62 * s, win_bot_y + 0.94 * s, win_bot_y + 1.26 * s]
	for hy in horiz_ys:
		_build_solid_box(st_i, Vector3(0.0, hy, 0.0), Vector3(grate_w, bar_thick, bar_thick))

	# 9. Ladrillos en Relieve Estilizados (Panel frontal y posterior)
	var bricks = [
		# Izquierda
		Vector3(-2.15 * s, 2.75 * s, d * 0.5 + 0.02 * s), Vector3(0.48 * s, 0.22 * s, 0.06 * s),
		Vector3(-1.90 * s, 2.45 * s, d * 0.5 + 0.02 * s), Vector3(0.56 * s, 0.22 * s, 0.06 * s),
		Vector3(-2.05 * s, 0.85 * s, d * 0.5 + 0.02 * s), Vector3(0.50 * s, 0.22 * s, 0.06 * s),
		# Derecha
		Vector3(2.20 * s, 2.85 * s, d * 0.5 + 0.02 * s), Vector3(0.24 * s, 0.22 * s, 0.06 * s),
		Vector3(2.05 * s, 2.55 * s, d * 0.5 + 0.02 * s), Vector3(0.52 * s, 0.22 * s, 0.06 * s),
		Vector3(2.10 * s, 1.25 * s, d * 0.5 + 0.02 * s), Vector3(0.46 * s, 0.20 * s, 0.06 * s),
		Vector3(1.95 * s, 0.95 * s, d * 0.5 + 0.02 * s), Vector3(0.42 * s, 0.20 * s, 0.06 * s)
	]

	for i in range(0, bricks.size(), 2):
		_build_solid_box(st_t, bricks[i], bricks[i + 1])

	# 10. Pequeños guijarros en el zócalo
	_build_solid_box(st_t, Vector3(-0.25 * s, 0.44 * s, d * 0.5 + 0.04 * s), Vector3(0.10 * s, 0.08 * s, 0.08 * s))
	_build_solid_box(st_t, Vector3(0.20 * s, 0.44 * s, d * 0.5 + 0.04 * s), Vector3(0.12 * s, 0.09 * s, 0.09 * s))

# ==============================================================================
# 2. VARIANTE: PILASTRA / PILAR CENTRAL DE REFUERZO
# ==============================================================================

static func _build_center_pilaster_wall(
	st_s: SurfaceTool, st_t: SurfaceTool,
	s: float, w: float, h: float, d: float
) -> void:
	_build_base_and_cornice(st_s, st_t, s, w, h, d)

	# 1. Pilar central saliente continuo
	var pil_w: float = 0.82 * s
	var pil_proj: float = 0.16 * s
	var pil_h: float = h - 0.94 * s
	var pil_cy: float = h * 0.5

	# Fuste central saliente
	_build_solid_box(st_s, Vector3(0.0, pil_cy, d * 0.5 + pil_proj * 0.5), Vector3(pil_w, pil_h, pil_proj))

	# Chaflanes a 45° a izquierda y derecha del pilar central
	var chamfer_w: float = 0.18 * s
	var b_left := Basis.from_euler(Vector3(0.0, deg_to_rad(-45.0), 0.0))
	_build_oriented_solid_box(st_s, Transform3D(b_left, Vector3(-pil_w * 0.5 - 0.04 * s, pil_cy, d * 0.5 + pil_proj * 0.35)), Vector3(chamfer_w, pil_h, 0.06 * s))

	var b_right := Basis.from_euler(Vector3(0.0, deg_to_rad(45.0), 0.0))
	_build_oriented_solid_box(st_s, Transform3D(b_right, Vector3(pil_w * 0.5 + 0.04 * s, pil_cy, d * 0.5 + pil_proj * 0.35)), Vector3(chamfer_w, pil_h, 0.06 * s))

	# 2. Moldura / Faja horizontal a media altura en el pilar
	var belt_y: float = 2.05 * s
	var belt_h: float = 0.12 * s
	_build_solid_box(st_t, Vector3(0.0, belt_y, d * 0.5 + pil_proj * 0.65), Vector3(pil_w * 1.08, belt_h, pil_proj * 0.45))

	# 3. Zócalo y Cornisa reforzados en el pilar central
	_build_solid_box(st_t, Vector3(0.0, 0.25 * s, d * 0.5 + pil_proj * 0.5), Vector3(pil_w * 1.08, 0.42 * s, pil_proj))
	_build_solid_box(st_t, Vector3(0.0, h - 0.26 * s, d * 0.5 + pil_proj * 0.5), Vector3(pil_w * 1.08, 0.52 * s, pil_proj))

	# 4. Ladrillos en Relieve a ambos lados del pilar
	var bricks = [
		# Izquierda
		Vector3(-2.10 * s, 2.70 * s, d * 0.5 + 0.02 * s), Vector3(0.48 * s, 0.22 * s, 0.06 * s),
		Vector3(-1.80 * s, 2.38 * s, d * 0.5 + 0.02 * s), Vector3(0.54 * s, 0.22 * s, 0.06 * s),
		Vector3(-2.00 * s, 1.25 * s, d * 0.5 + 0.02 * s), Vector3(0.50 * s, 0.22 * s, 0.06 * s),
		Vector3(-1.75 * s, 0.95 * s, d * 0.5 + 0.02 * s), Vector3(0.46 * s, 0.20 * s, 0.06 * s),
		# Derecha
		Vector3(1.85 * s, 2.80 * s, d * 0.5 + 0.02 * s), Vector3(0.38 * s, 0.20 * s, 0.06 * s),
		Vector3(2.10 * s, 2.50 * s, d * 0.5 + 0.02 * s), Vector3(0.50 * s, 0.22 * s, 0.06 * s),
		Vector3(2.15 * s, 1.30 * s, d * 0.5 + 0.02 * s), Vector3(0.36 * s, 0.20 * s, 0.06 * s),
		Vector3(1.95 * s, 0.98 * s, d * 0.5 + 0.02 * s), Vector3(0.48 * s, 0.22 * s, 0.06 * s)
	]

	for i in range(0, bricks.size(), 2):
		_build_solid_box(st_t, bricks[i], bricks[i + 1])

# ==============================================================================
# 3. VARIANTE: GRIETA DIAGONAL, LADRILLOS Y VEGETACIÓN
# ==============================================================================

static func _build_fissure_bricks_wall(
	st_s: SurfaceTool, st_t: SurfaceTool, st_f: SurfaceTool,
	s: float, w: float, h: float, d: float
) -> void:
	_build_base_and_cornice(st_s, st_t, s, w, h, d)

	# 1. Grieta diagonal tallada profunda
	# Tramo 1: (-2.6, 1.85) -> (-0.5, 1.40)
	var p0 := Vector3(-2.6 * s, 1.85 * s, d * 0.5 + 0.01 * s)
	var p1 := Vector3(-0.5 * s, 1.40 * s, d * 0.5 + 0.01 * s)
	var mid1 := (p0 + p1) * 0.5
	var len1 := (p1 - p0).length()
	var ang1 := atan2(p1.y - p0.y, p1.x - p0.x)
	var b1 := Basis.from_euler(Vector3(0.0, 0.0, ang1))
	_build_oriented_solid_box(st_t, Transform3D(b1, mid1), Vector3(len1, 0.06 * s, 0.05 * s))

	# Tramo 2: (-0.5, 1.40) -> (2.6, 2.15)
	var p2 := Vector3(2.6 * s, 2.15 * s, d * 0.5 + 0.01 * s)
	var mid2 := (p1 + p2) * 0.5
	var len2 := (p2 - p1).length()
	var ang2 := atan2(p2.y - p1.y, p2.x - p1.x)
	var b2 := Basis.from_euler(Vector3(0.0, 0.0, ang2))
	_build_oriented_solid_box(st_t, Transform3D(b2, mid2), Vector3(len2, 0.06 * s, 0.05 * s))

	# 2. Grupos de ladrillos estilizados en 4 cuadrantes
	var bricks = [
		# Cuadrante Superior Izquierdo
		Vector3(-2.10 * s, 2.90 * s, d * 0.5 + 0.02 * s), Vector3(0.48 * s, 0.22 * s, 0.06 * s),
		Vector3(-0.80 * s, 2.70 * s, d * 0.5 + 0.02 * s), Vector3(0.56 * s, 0.22 * s, 0.06 * s),
		Vector3(-1.05 * s, 2.40 * s, d * 0.5 + 0.02 * s), Vector3(0.46 * s, 0.20 * s, 0.06 * s),
		# Cuadrante Inferior Izquierdo
		Vector3(-2.00 * s, 0.95 * s, d * 0.5 + 0.02 * s), Vector3(0.48 * s, 0.22 * s, 0.06 * s),
		# Cuadrante Superior Derecho
		Vector3(2.00 * s, 2.90 * s, d * 0.5 + 0.02 * s), Vector3(0.38 * s, 0.20 * s, 0.06 * s),
		Vector3(1.70 * s, 2.60 * s, d * 0.5 + 0.02 * s), Vector3(0.50 * s, 0.22 * s, 0.06 * s),
		# Cuadrante Inferior Derecho
		Vector3(1.60 * s, 1.05 * s, d * 0.5 + 0.02 * s), Vector3(0.44 * s, 0.20 * s, 0.06 * s),
		Vector3(2.05 * s, 1.05 * s, d * 0.5 + 0.02 * s), Vector3(0.40 * s, 0.20 * s, 0.06 * s),
		Vector3(1.85 * s, 0.75 * s, d * 0.5 + 0.02 * s), Vector3(0.56 * s, 0.22 * s, 0.06 * s)
	]

	for i in range(0, bricks.size(), 2):
		_build_solid_box(st_t, bricks[i], bricks[i + 1])

	# 3. Ramilletes de Hojas / Vegetación
	# Ramillete en la base izquierda del zócalo
	_build_foliage_cluster(st_f, Vector3(-2.10 * s, 0.44 * s, d * 0.5 + 0.06 * s), 0.16 * s)
	# Ramillete en la base derecha del zócalo
	_build_foliage_cluster(st_f, Vector3(2.10 * s, 0.44 * s, d * 0.5 + 0.06 * s), 0.18 * s)
	# Brote en el vértice de la grieta
	_build_foliage_cluster(st_f, Vector3(-0.50 * s, 1.40 * s, d * 0.5 + 0.04 * s), 0.12 * s)

# ==============================================================================
# SUB-CONSTRUCTORES GEOMÉTRICOS CON NORMALES DIRIGIDAS
# ==============================================================================

static func _build_foliage_cluster(st: SurfaceTool, center: Vector3, radius: float) -> void:
	var leaf_count: int = 5
	for i in range(leaf_count):
		var ang: float = float(i) * (TAU / float(leaf_count))
		var b := Basis.from_euler(Vector3(deg_to_rad(30.0), 0.0, ang))
		var l_pos := center + Vector3(cos(ang) * radius * 0.4, sin(ang) * radius * 0.4, 0.0)
		_build_oriented_solid_box(st, Transform3D(b, l_pos), Vector3(radius * 0.55, radius * 0.22, 0.02))

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

static func _build_oriented_solid_box(st: SurfaceTool, xform: Transform3D, size: Vector3) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5

	var v_bl_f := xform * Vector3(-hx, -hy, hz)
	var v_br_f := xform * Vector3(hx, -hy, hz)
	var v_tr_f := xform * Vector3(hx, hy, hz)
	var v_tl_f := xform * Vector3(-hx, hy, hz)

	var v_bl_b := xform * Vector3(-hx, -hy, -hz)
	var v_br_b := xform * Vector3(hx, -hy, -hz)
	var v_tr_b := xform * Vector3(hx, hy, -hz)
	var v_tl_b := xform * Vector3(-hx, hy, -hz)

	var n_front := xform.basis.z.normalized()
	var n_back := -xform.basis.z.normalized()
	var n_right := xform.basis.x.normalized()
	var n_left := -xform.basis.x.normalized()
	var n_top := xform.basis.y.normalized()
	var n_bot := -xform.basis.y.normalized()

	_add_quad_facing(st, v_bl_f, v_br_f, v_tr_f, v_tl_f, n_front)
	_add_quad_facing(st, v_br_b, v_bl_b, v_tl_b, v_tr_b, n_back)
	_add_quad_facing(st, v_br_f, v_br_b, v_tr_b, v_tr_f, n_right)
	_add_quad_facing(st, v_bl_b, v_bl_f, v_tl_f, v_tl_b, n_left)
	_add_quad_facing(st, v_tl_f, v_tr_f, v_tr_b, v_tl_b, n_top)
	_add_quad_facing(st, v_bl_b, v_br_b, v_br_f, v_bl_f, n_bot)

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
