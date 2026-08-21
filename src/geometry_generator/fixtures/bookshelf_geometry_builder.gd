class_name BookshelfGeometryBuilder
extends RefCounted

## Constructor geométrico procedural para Librerías de Mazmorra (Bookshelf).
## Geometría estilizada sólida y estanca con normales y devanado CCW garantizados:
## 1. `bookshelf_wood`: Mueble principal, zócalo, laterales, estantes y panel trasero.
## 2. `bookshelf_books_red`: Tomos encuadernados en cuero rojo carmesí.
## 3. `bookshelf_books_blue`: Tomos encuadernados en cuero azul arcano.
## 4. `bookshelf_books_green`: Tomos de alquimia en cuero verde esmeralda.
## 5. `bookshelf_books_gold`: Tomos mágicos y grimorios en pergamino dorado.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")
const _BookshelfGeometryConfigScript = preload("res://src/geometry_generator/config/bookshelf_geometry_config.gd")

func build_bookshelf_fixture(config = null):
	if config == null:
		config = _BookshelfGeometryConfigScript.new()

	var asset = _GeneratedAssetScript.new()
	asset.asset_id = &"stylized_dungeon_bookshelf"

	var s: float = config.scale_mult
	var w: float = config.width * s
	var h: float = config.height * s
	var d: float = config.depth * s
	var shelves: int = config.shelf_count

	# 1. Mueble de Madera
	var g_wood = _GeneratedMeshScript.new()
	g_wood.component_id = 0
	var st_wood := SurfaceTool.new()
	st_wood.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 2. Superficies de Libros
	var st_red := SurfaceTool.new(); st_red.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_blue := SurfaceTool.new(); st_blue.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_green := SurfaceTool.new(); st_green.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_gold := SurfaceTool.new(); st_gold.begin(Mesh.PRIMITIVE_TRIANGLES)

	var book_tools = [st_red, st_blue, st_green, st_gold]

	var is_gothic: bool = (int(config.style) == int(_BookshelfGeometryConfigScript.BookshelfStyle.GOTHIC_ARCHED))
	var has_books: bool = (int(config.style) != int(_BookshelfGeometryConfigScript.BookshelfStyle.STANDARD_EMPTY))

	_build_bookshelf_frame(st_wood, s, w, h, d, shelves, is_gothic)

	if has_books:
		_populate_books(book_tools, s, w, h, d, shelves, config.seed)

	# Commit madera
	var mesh_wood := ArrayMesh.new()
	mesh_wood = st_wood.commit(mesh_wood)
	mesh_wood.surface_set_name(0, "BookshelfWood")
	g_wood.mesh = mesh_wood

	var mat_wood := StandardMaterial3D.new()
	mat_wood.albedo_color = config.wood_color
	mat_wood.roughness = 0.72
	mat_wood.metallic = 0.0
	mat_wood.cull_mode = BaseMaterial3D.CULL_DISABLED
	g_wood.material_slots[0] = mat_wood
	asset.add_mesh(&"bookshelf_wood", g_wood)

	# Commit libros
	var book_configs = [
		{"name": "BooksRed", "slot": &"bookshelf_books_red", "st": st_red, "color": Color(0.82, 0.24, 0.22, 1.0)},
		{"name": "BooksBlue", "slot": &"bookshelf_books_blue", "st": st_blue, "color": Color(0.22, 0.48, 0.86, 1.0)},
		{"name": "BooksGreen", "slot": &"bookshelf_books_green", "st": st_green, "color": Color(0.24, 0.68, 0.36, 1.0)},
		{"name": "BooksGold", "slot": &"bookshelf_books_gold", "st": st_gold, "color": Color(0.85, 0.66, 0.22, 1.0)}
	]

	for i in range(book_configs.size()):
		var b_cfg = book_configs[i]
		var st_b: SurfaceTool = b_cfg.st
		var mesh_b := ArrayMesh.new()
		mesh_b = st_b.commit(mesh_b)
		if mesh_b.get_surface_count() > 0:
			mesh_b.surface_set_name(0, b_cfg.name)
			var g_b = _GeneratedMeshScript.new()
			g_b.component_id = i + 1
			g_b.mesh = mesh_b

			var mat_b := StandardMaterial3D.new()
			mat_b.albedo_color = b_cfg.color
			mat_b.roughness = 0.58
			mat_b.metallic = 0.0
			mat_b.cull_mode = BaseMaterial3D.CULL_DISABLED
			g_b.material_slots[0] = mat_b
			asset.add_mesh(b_cfg.slot, g_b)

	# Colisión física
	var col_shape := BoxShape3D.new()
	col_shape.size = Vector3(w, h, d)
	g_wood.add_collision_shape(col_shape, Transform3D(Basis(), Vector3(0.0, h * 0.5, 0.0)))

	return asset

# ==============================================================================
# 1. ESTRUCTURA Y MARCO DEL MUEBLE
# ==============================================================================

static func _build_bookshelf_frame(
	st_w: SurfaceTool,
	s: float, w: float, h: float, d: float,
	shelves: int, is_gothic: bool
) -> void:
	var wall_t: float = 0.045 * s
	var plinth_h: float = 0.08 * s
	var corn_h: float = 0.07 * s
	var back_t: float = 0.025 * s

	# 1. Zócalo base
	_build_solid_box(st_w, Vector3(0.0, plinth_h * 0.5, 0.0), Vector3(w + 0.04 * s, plinth_h, d + 0.04 * s))

	# 2. Costados laterales izquierdo y derecho
	var side_h: float = h - plinth_h - corn_h
	var side_cy: float = plinth_h + side_h * 0.5
	var side_x: float = (w - wall_t) * 0.5

	_build_solid_box(st_w, Vector3(-side_x, side_cy, 0.0), Vector3(wall_t, side_h, d))
	_build_solid_box(st_w, Vector3(side_x, side_cy, 0.0), Vector3(wall_t, side_h, d))

	# 3. Fondo / Panel trasero
	var back_z: float = -d * 0.5 + back_t * 0.5
	_build_solid_box(st_w, Vector3(0.0, side_cy, back_z), Vector3(w - wall_t * 2.0, side_h, back_t))

	# 4. Tapa superior / Cornisa
	var top_cy: float = h - corn_h * 0.5
	_build_solid_box(st_w, Vector3(0.0, top_cy, 0.0), Vector3(w + 0.06 * s, corn_h, d + 0.06 * s))

	# Copete gótico si aplica
	if is_gothic:
		_build_solid_box(st_w, Vector3(0.0, h + 0.09 * s, 0.0), Vector3(w * 0.85, 0.16 * s, d * 0.85))
		_build_solid_box(st_w, Vector3(0.0, h + 0.20 * s, 0.0), Vector3(w * 0.40, 0.08 * s, d * 0.70))

	# 5. Baldes / Estantes horizontales
	var inner_h: float = side_h
	var shelf_t: float = 0.038 * s
	var inner_w: float = w - wall_t * 2.0
	var shelf_d: float = d - back_t - 0.01 * s
	var shelf_cz: float = back_z + back_t * 0.5 + shelf_d * 0.5

	var shelf_spacing: float = inner_h / float(shelves)
	for i in range(shelves + 1):
		var sy: float = plinth_h + float(i) * shelf_spacing
		if i == shelves:
			sy = plinth_h + inner_h - shelf_t * 0.5
		_build_solid_box(st_w, Vector3(0.0, sy, shelf_cz), Vector3(inner_w, shelf_t, shelf_d))

# ==============================================================================
# 2. GENERACIÓN Y DISTRIBUCIÓN DE LIBROS
# ==============================================================================

static func _populate_books(
	tools: Array,
	s: float, w: float, h: float, d: float,
	shelves: int, seed_val: int
) -> void:
	var wall_t: float = 0.045 * s
	var plinth_h: float = 0.08 * s
	var corn_h: float = 0.07 * s
	var back_t: float = 0.025 * s
	var inner_h: float = h - plinth_h - corn_h
	var shelf_spacing: float = inner_h / float(shelves)
	var shelf_d: float = d - back_t - 0.01 * s
	var back_z: float = -d * 0.5 + back_t
	var max_span: float = w - wall_t * 2.0 - 0.04 * s

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	for shelf_idx in range(shelves):
		var shelf_base_y: float = plinth_h + float(shelf_idx) * shelf_spacing + 0.038 * s * 0.5
		var cur_x: float = -max_span * 0.5 + 0.02 * s

		# Variación de contenido por balda
		var pattern_mode: int = shelf_idx % 3

		while cur_x < max_span * 0.5 - 0.06 * s:
			var tool_idx: int = rng.randi() % tools.size()
			var st_b: SurfaceTool = tools[tool_idx]

			var b_thick: float = rng.randf_range(0.032, 0.062) * s
			var b_height: float = rng.randf_range(0.20, minf(0.34, shelf_spacing * 0.85)) * s
			var b_depth: float = rng.randf_range(0.20, shelf_d * 0.88) * s
			var b_z: float = back_z + b_depth * 0.5 + 0.015 * s

			# A. Pila de libros horizontales (apilados)
			if pattern_mode == 1 and rng.randf() < 0.25 and cur_x < max_span * 0.5 - 0.16 * s:
				var stack_count: int = rng.randi_range(2, 3)
				var stack_w: float = rng.randf_range(0.18, 0.24) * s
				var stack_d: float = rng.randf_range(0.18, shelf_d * 0.85) * s
				var stack_cur_y: float = shelf_base_y

				for stack_i in range(stack_count):
					var s_thick: float = rng.randf_range(0.040, 0.055) * s
					var s_tool: SurfaceTool = tools[(tool_idx + stack_i) % tools.size()]
					var b_cy: float = stack_cur_y + s_thick * 0.5
					_build_solid_box(s_tool, Vector3(cur_x + stack_w * 0.5, b_cy, back_z + stack_d * 0.5 + 0.02 * s), Vector3(stack_w, s_thick, stack_d))
					stack_cur_y += s_thick + 0.002 * s

				cur_x += stack_w + rng.randf_range(0.02, 0.04) * s
				continue

			# B. Libro inclinado (leaning)
			if rng.randf() < 0.18 and cur_x < max_span * 0.5 - 0.10 * s:
				var lean_ang: float = rng.randf_range(16.0, 24.0)
				var basis := Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(-lean_ang)))
				var lean_pos := Vector3(cur_x + 0.04 * s, shelf_base_y + b_height * 0.46, b_z)
				_build_oriented_solid_box(st_b, Transform3D(basis, lean_pos), Vector3(b_thick, b_height, b_depth))
				cur_x += b_thick + 0.06 * s
				continue

			# C. Libro vertical clásico en hilera
			var b_cy: float = shelf_base_y + b_height * 0.5
			_build_solid_box(st_b, Vector3(cur_x + b_thick * 0.5, b_cy, b_z), Vector3(b_thick, b_height, b_depth))
			cur_x += b_thick + rng.randf_range(0.003, 0.012) * s

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
	_add_quad_facing(st, Vector3(x0, y0, z0), Vector3(x0, y0, z0 + size.z), Vector3(x0, y1, z0 + size.z), Vector3(x0, y1, z0), Vector3(-1, 0, 0))
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
