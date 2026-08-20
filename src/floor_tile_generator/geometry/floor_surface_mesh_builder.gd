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

	# 1. Generar la base continua de mortero por cada celda de la región
	for c in cluster.cells:
		var cell: Vector2i = c if c is Vector2i else Vector2i(c.x, c.y)
		var cell_x: float = float(cell.x) * tile_size
		var cell_z: float = float(cell.y) * tile_size

		var m_p0 := Vector3(cell_x, 0.0, cell_z)
		var m_p1 := Vector3(cell_x + tile_size, 0.0, cell_z)
		var m_p2 := Vector3(cell_x + tile_size, 0.0, cell_z + tile_size)
		var m_p3 := Vector3(cell_x, 0.0, cell_z + tile_size)

		_add_quad_with_normal(st_mortar, m_p0, m_p1, m_p2, m_p3, Vector3.UP, Color(0.20, 0.18, 0.16))

	# 2. Generar las losas 3D a partir de los TileDescriptors
	var base_slab_color: Color = Color(0.52, 0.54, 0.56)

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

	# Superficie 0: Losas de Piedra (FloorSlabs)
	var slabs_arr := st_slabs.commit_to_arrays()
	if slabs_arr.size() > 0 and slabs_arr[Mesh.ARRAY_VERTEX] != null and (slabs_arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, slabs_arr)
		mesh.surface_set_name(mesh.get_surface_count() - 1, "FloorSlabs")
		mesh.surface_set_material(mesh.get_surface_count() - 1, _WallMaterialFactoryScript.create_floor_slab_material(config.material_preset))

	# Superficie 1: Mortero Base (FloorMortar)
	var mortar_arr := st_mortar.commit_to_arrays()
	if mortar_arr.size() > 0 and mortar_arr[Mesh.ARRAY_VERTEX] != null and (mortar_arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mortar_arr)
		mesh.surface_set_name(mesh.get_surface_count() - 1, "FloorMortar")
		mesh.surface_set_material(mesh.get_surface_count() - 1, _WallMaterialFactoryScript.create_floor_mortar_material(config.material_preset))

	return mesh

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
