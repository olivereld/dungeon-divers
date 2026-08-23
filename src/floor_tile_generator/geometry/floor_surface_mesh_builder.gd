class_name FloorSurfaceMeshBuilder
extends RefCounted

## Constructor de mallas 3D para superficies de suelo (FloorSurfaceMeshBuilder - Fase M4).
## Procesa los TileDescriptors de un FloorSurfaceCluster y genera un ArrayMesh PBR (FloorSlabs + FloorMortar).

const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")

## Construye la malla ArrayMesh a partir de los TileDescriptors y celdas de un cluster
func build_cluster_mesh(
	cluster,
	config = null
) -> ArrayMesh:
	if cluster == null or (cluster.descriptors.is_empty() and cluster.cells.is_empty()):
		return ArrayMesh.new()

	if config == null:
		config = _FloorTileConfigScript.new()

	var st_slabs := SurfaceTool.new()
	var st_mortar := SurfaceTool.new()

	st_slabs.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_mortar.begin(Mesh.PRIMITIVE_TRIANGLES)

	var tile_size: float = config.tile_size
	var is_catacomb_dirt: bool = (config.pattern == _FloorTileConfigScript.PatternType.CATACOMB_DIRT)

	# 1. Generar la base de suelo (Mortero plano o Tierra con relieve 3D ondulante)
	if is_catacomb_dirt:
		for c in cluster.cells:
			var cell: Vector2i = c if c is Vector2i else Vector2i(c.x, c.y)
			_build_dirt_relief_cell(st_mortar, cell, tile_size, config.seed)
	else:
		for c in cluster.cells:
			var cell: Vector2i = c if c is Vector2i else Vector2i(c.x, c.y)
			var cell_x: float = float(cell.x) * tile_size
			var cell_z: float = float(cell.y) * tile_size

			var m_p0 := Vector3(cell_x, 0.0, cell_z)
			var m_p1 := Vector3(cell_x + tile_size, 0.0, cell_z)
			var m_p2 := Vector3(cell_x + tile_size, 0.0, cell_z + tile_size)
			var m_p3 := Vector3(cell_x, 0.0, cell_z + tile_size)

			_add_quad_with_normal(st_mortar, m_p0, m_p1, m_p2, m_p3, Vector3.UP, Color(0.12, 0.12, 0.14))

	# 2. Generar las losas 3D y guijarros a partir de los TileDescriptors (Tono oscuro por defecto)
	var base_slab_color: Color = Color(0.25, 0.26, 0.29)

	for desc in cluster.descriptors:
		var h: float = desc.height
		var b: float = desc.bevel
		var world_off: Vector2 = desc.world_offset

		var slab_color := base_slab_color.lightened(desc.color_mod) if desc.color_mod > 0.0 else base_slab_color.darkened(-desc.color_mod)
		if desc.material_variant == 1:
			slab_color = slab_color.darkened(0.12) # Tono piedra agrietada / oscura

		if not desc.polygon_2d.is_empty() and desc.polygon_2d.size() >= 3:
			# A. Generar polígono fractal 3D con biseles
			_build_polygon_slab(st_slabs, desc.polygon_2d, world_off, h, b, slab_color)
		else:
			# B. Generar losa rectangular estándar biselada
			_build_rect_slab(st_slabs, desc.rect, world_off, h, b, slab_color)

	var mesh := ArrayMesh.new()

	# Superficie 0: Losas de Piedra / Guijarros (FloorSlabs)
	var slabs_arr := st_slabs.commit_to_arrays()
	if slabs_arr.size() > 0 and slabs_arr[Mesh.ARRAY_VERTEX] != null and (slabs_arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, slabs_arr)
		mesh.surface_set_name(mesh.get_surface_count() - 1, "FloorSlabs")
		mesh.surface_set_material(mesh.get_surface_count() - 1, _WallMaterialFactoryScript.create_floor_slab_material(config.material_preset))

	# Superficie 1: Mortero Base o Tierra de Catacumba (FloorMortar / FloorDirt)
	var mortar_arr := st_mortar.commit_to_arrays()
	if mortar_arr.size() > 0 and mortar_arr[Mesh.ARRAY_VERTEX] != null and (mortar_arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mortar_arr)
		var surf_name: String = "FloorDirt" if is_catacomb_dirt else "FloorMortar"
		var surf_mat = _WallMaterialFactoryScript.create_floor_dirt_material(config.material_preset) if is_catacomb_dirt else _WallMaterialFactoryScript.create_floor_mortar_material(config.material_preset)
		mesh.surface_set_name(mesh.get_surface_count() - 1, surf_name)
		mesh.surface_set_material(mesh.get_surface_count() - 1, surf_mat)

	return mesh

## Construye la malla de suelo de tierra con micro-relieve 3D subdividido y variaciones tonales
func _build_dirt_relief_cell(st: SurfaceTool, cell: Vector2i, tile_size: float, seed_val: int) -> void:
	var subdivisions: int = 5 # 5x5 quads por cada celda de 2x2m
	var step: float = tile_size / float(subdivisions)
	var base_x: float = float(cell.x) * tile_size
	var base_z: float = float(cell.y) * tile_size

	for ix in range(subdivisions):
		for iz in range(subdivisions):
			var x0: float = base_x + float(ix) * step
			var x1: float = base_x + float(ix + 1) * step
			var z0: float = base_z + float(iz) * step
			var z1: float = base_z + float(iz + 1) * step

			var y00: float = _sample_dirt_elevation(x0, z0, seed_val)
			var y10: float = _sample_dirt_elevation(x1, z0, seed_val)
			var y11: float = _sample_dirt_elevation(x1, z1, seed_val)
			var y01: float = _sample_dirt_elevation(x0, z1, seed_val)

			var p0 := Vector3(x0, y00, z0)
			var p1 := Vector3(x1, y10, z0)
			var p2 := Vector3(x1, y11, z1)
			var p3 := Vector3(x0, y01, z1)

			# Color de tierra modulado por elevación (huecos más oscuros y húmedos, lomos más claros)
			var col00 := _get_dirt_vertex_color(y00)
			var col10 := _get_dirt_vertex_color(y10)
			var col11 := _get_dirt_vertex_color(y11)
			var col01 := _get_dirt_vertex_color(y01)

			# Triángulo 1 (p0 -> p1 -> p2)
			var n1: Vector3 = (p1 - p0).cross(p2 - p0).normalized()
			st.set_normal(n1)
			st.set_color(col00); st.set_uv(Vector2(x0, z0)); st.add_vertex(p0)
			st.set_color(col10); st.set_uv(Vector2(x1, z0)); st.add_vertex(p1)
			st.set_color(col11); st.set_uv(Vector2(x1, z1)); st.add_vertex(p2)

			# Triángulo 2 (p0 -> p2 -> p3)
			var n2: Vector3 = (p2 - p0).cross(p3 - p0).normalized()
			st.set_normal(n2)
			st.set_color(col00); st.set_uv(Vector2(x0, z0)); st.add_vertex(p0)
			st.set_color(col11); st.set_uv(Vector2(x1, z1)); st.add_vertex(p2)
			st.set_color(col01); st.set_uv(Vector2(x0, z1)); st.add_vertex(p3)

func _sample_dirt_elevation(wx: float, wz: float, seed_val: int) -> float:
	var s: float = float(seed_val % 10000) * 0.05
	var elev: float = sin(wx * 2.2 + s) * cos(wz * 2.2 + s * 0.8) * 0.015
	elev += sin(wx * 5.1 + wz * 4.3 + s * 1.7) * 0.009
	elev += sin(wx * 9.7 - wz * 8.4 + s * 2.3) * 0.004
	return maxf(0.0, elev + 0.014) # Relieve orgánico entre 0.002 y 0.035m

func _get_dirt_vertex_color(elev: float) -> Color:
	# Gradiente natural de tierra: desde marrón muy oscuro / húmedo en valles hasta tierra seca en crestas
	var t: float = clampf((elev - 0.005) / 0.030, 0.0, 1.0)
	var base_dark := Color(0.70, 0.65, 0.60)
	var base_light := Color(1.15, 1.08, 0.98)
	return base_dark.lerp(base_light, t)

## Construye una losa rectangular biselada
func _build_rect_slab(
	st: SurfaceTool,
	r: Rect2,
	world_off: Vector2,
	h: float,
	b: float,
	color: Color
) -> void:
	var b_x0: float = world_off.x + r.position.x
	var b_x1: float = world_off.x + r.end.x
	var b_z0: float = world_off.y + r.position.y
	var b_z1: float = world_off.y + r.end.y

	var t_x0: float = b_x0 + b
	var t_x1: float = b_x1 - b
	var t_z0: float = b_z0 + b
	var t_z1: float = b_z1 - b

	var p_top_0 := Vector3(t_x0, h, t_z0)
	var p_top_1 := Vector3(t_x1, h, t_z0)
	var p_top_2 := Vector3(t_x1, h, t_z1)
	var p_top_3 := Vector3(t_x0, h, t_z1)

	var p_bot_0 := Vector3(b_x0, 0.01, b_z0)
	var p_bot_1 := Vector3(b_x1, 0.01, b_z0)
	var p_bot_2 := Vector3(b_x1, 0.01, b_z1)
	var p_bot_3 := Vector3(b_x0, 0.01, b_z1)

	# Cara superior
	_add_quad_with_normal(st, p_top_0, p_top_1, p_top_2, p_top_3, Vector3.UP, color)

	# 4 Biseles laterales
	_add_bevel_quad(st, p_bot_0, p_bot_1, p_top_1, p_top_0, color.darkened(0.08))
	_add_bevel_quad(st, p_bot_1, p_bot_2, p_top_2, p_top_1, color.darkened(0.12))
	_add_bevel_quad(st, p_bot_2, p_bot_3, p_top_3, p_top_2, color.darkened(0.15))
	_add_bevel_quad(st, p_bot_3, p_bot_0, p_top_0, p_top_3, color.darkened(0.05))

## Construye una esquirla o losa poligonal irregular con biseles
func _build_polygon_slab(
	st: SurfaceTool,
	poly: PackedVector2Array,
	world_off: Vector2,
	h: float,
	b: float,
	color: Color
) -> void:
	var n: int = poly.size()
	if n < 3:
		return

	# Calcular centroide 2D
	var centroid := Vector2.ZERO
	for pt in poly:
		centroid += pt
	centroid /= float(n)

	var p_bot: Array[Vector3] = []
	var p_top: Array[Vector3] = []

	for i in range(n):
		var v := poly[i]
		var bot_pt := Vector3(world_off.x + v.x, 0.01, world_off.y + v.y)
		p_bot.append(bot_pt)

		var to_center := centroid - v
		var dist := to_center.length()
		var inset := minf(b, dist * 0.45)
		var top_2d := v + (to_center.normalized() * inset) if dist > 0.001 else v
		var top_pt := Vector3(world_off.x + top_2d.x, h, world_off.y + top_2d.y)
		p_top.append(top_pt)

	# 1. Cara superior (triangulación en abanico)
	st.set_color(color)
	st.set_normal(Vector3.UP)
	for i in range(1, n - 1):
		st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(p_top[0])
		st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(p_top[i])
		st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(p_top[i + 1])

	# 2. Biseles laterales por cada arista
	for i in range(n):
		var next_i := (i + 1) % n
		var tone_mod: float = 0.06 + (float(i % 3) * 0.03)
		_add_bevel_quad(st, p_bot[i], p_bot[next_i], p_top[next_i], p_top[i], color.darkened(tone_mod))

func _add_quad_with_normal(
	st: SurfaceTool,
	p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
	normal: Vector3,
	color: Color
) -> void:
	st.set_color(color)
	st.set_normal(normal)
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(p0)
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(p1)
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(p2)

	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(p0)
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(p2)
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(p3)

func _add_bevel_quad(
	st: SurfaceTool,
	p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
	color: Color
) -> void:
	var normal: Vector3 = (p1 - p0).cross(p3 - p0).normalized()
	if normal.length_squared() < 0.001:
		normal = Vector3.UP

	st.set_color(color)
	st.set_normal(normal)
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(p0)
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(p1)
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(p2)

	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(p0)
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(p2)
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(p3)
