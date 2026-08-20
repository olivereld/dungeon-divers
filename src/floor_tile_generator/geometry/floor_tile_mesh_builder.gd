class_name FloorTileMeshBuilder
extends RefCounted

## Constructor de mallas 3D para regiones de suelo de mazmorra (Floor Tiles).
## Genera losas de piedra estilizadas entrelazadas con biseles a 45°, alturas variables, vertex colors y lecho de mortero.

const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")

## Definición interna de una losa dentro de la baldosa
class StoneSlab:
	var rect: Rect2
	var height: float
	var bevel: float
	var color_mod: float

	func _init(p_rect: Rect2, p_height: float, p_bevel: float, p_color_mod: float = 0.0) -> void:
		rect = p_rect
		height = p_height
		bevel = p_bevel
		color_mod = p_color_mod

## Construye la malla ArrayMesh para una región completa de celdas de suelo.
func build_region_mesh(
	cells: Array,
	config = null,
	seed_val: int = 1337
) -> ArrayMesh:
	if cells.is_empty():
		return ArrayMesh.new()

	if config == null:
		config = _FloorTileConfigScript.new()

	var st_slabs := SurfaceTool.new()
	var st_mortar := SurfaceTool.new()

	st_slabs.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_mortar.begin(Mesh.PRIMITIVE_TRIANGLES)

	var tile_size: float = config.tile_size

	for c in cells:
		var cell: Vector2i = c if c is Vector2i else Vector2i(c.x, c.y)
		var offset := Vector2(float(cell.x) * tile_size, float(cell.y) * tile_size)
		# Semilla determinista derivada por coordenadas espaciales
		var cell_seed: int = (seed_val ^ (cell.x * 73856093) ^ (cell.y * 19349663)) & 0x7FFFFFFF
		_generate_tile_geometry(st_slabs, st_mortar, offset, config, cell_seed)

	var mesh := ArrayMesh.new()

	# Superficie 0: Losas de Piedra (FloorSlabs)
	var slabs_arr := st_slabs.commit_to_arrays()
	if slabs_arr.size() > 0 and slabs_arr[Mesh.ARRAY_VERTEX] != null and (slabs_arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, slabs_arr)
		mesh.surface_set_name(mesh.get_surface_count() - 1, "FloorSlabs")
		mesh.surface_set_material(mesh.get_surface_count() - 1, _WallMaterialFactoryScript.create_floor_slab_material(config.material_preset))

	# Superficie 1: Mortero / Sustrato Base (FloorMortar)
	var mortar_arr := st_mortar.commit_to_arrays()
	if mortar_arr.size() > 0 and mortar_arr[Mesh.ARRAY_VERTEX] != null and (mortar_arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mortar_arr)
		mesh.surface_set_name(mesh.get_surface_count() - 1, "FloorMortar")
		mesh.surface_set_material(mesh.get_surface_count() - 1, _WallMaterialFactoryScript.create_floor_mortar_material(config.material_preset))

	return mesh

## Genera la geometría 3D de una baldosa individual
func _generate_tile_geometry(
	st_slabs: SurfaceTool,
	st_mortar: SurfaceTool,
	offset: Vector2,
	config,
	cell_seed: int
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = cell_seed

	var tile_size: float = config.tile_size

	# 1. Base de Mortero inferior (en Y=0.0)
	var m_p0 := Vector3(offset.x, 0.0, offset.y)
	var m_p1 := Vector3(offset.x + tile_size, 0.0, offset.y)
	var m_p2 := Vector3(offset.x + tile_size, 0.0, offset.y + tile_size)
	var m_p3 := Vector3(offset.x, 0.0, offset.y + tile_size)

	_add_quad_with_normal(st_mortar, m_p0, m_p1, m_p2, m_p3, Vector3.UP, Color(0.20, 0.18, 0.16))

	# 2. Generar el patrón de losas (interlocking stone pattern proporcional)
	var slabs := _generate_slab_pattern(config, rng)

	for slab in slabs:
		var r := slab.rect
		var h := slab.height
		var b := slab.bevel

		var base_color: Color = Color(0.52, 0.54, 0.56)
		var slab_color := base_color.lightened(slab.color_mod) if slab.color_mod > 0.0 else base_color.darkened(-slab.color_mod)

		# Vértices de la base inferior (en contacto con el mortero)
		var b_x0 := offset.x + r.position.x
		var b_x1 := offset.x + r.end.x
		var b_z0 := offset.y + r.position.y
		var b_z1 := offset.y + r.end.y

		# Vértices de la meseta superior (retraídos por el bisel)
		var t_x0 := b_x0 + b
		var t_x1 := b_x1 - b
		var t_z0 := b_z0 + b
		var t_z1 := b_z1 - b

		# Puntos 3D de la parte superior
		var p_top_0 := Vector3(t_x0, h, t_z0)
		var p_top_1 := Vector3(t_x1, h, t_z0)
		var p_top_2 := Vector3(t_x1, h, t_z1)
		var p_top_3 := Vector3(t_x0, h, t_z1)

		# Puntos 3D de la base inferior
		var p_bot_0 := Vector3(b_x0, 0.01, b_z0)
		var p_bot_1 := Vector3(b_x1, 0.01, b_z0)
		var p_bot_2 := Vector3(b_x1, 0.01, b_z1)
		var p_bot_3 := Vector3(b_x0, 0.01, b_z1)

		# Cara Superior Plana (Top Face)
		_add_quad_with_normal(st_slabs, p_top_0, p_top_1, p_top_2, p_top_3, Vector3.UP, slab_color)

		# Bisel Norte
		_add_bevel_quad(st_slabs, p_bot_0, p_bot_1, p_top_1, p_top_0, slab_color.darkened(0.08))

		# Bisel Este
		_add_bevel_quad(st_slabs, p_bot_1, p_bot_2, p_top_2, p_top_1, slab_color.darkened(0.12))

		# Bisel Sur
		_add_bevel_quad(st_slabs, p_bot_2, p_bot_3, p_top_3, p_top_2, slab_color.darkened(0.15))

		# Bisel Oeste
		_add_bevel_quad(st_slabs, p_bot_3, p_bot_0, p_top_0, p_top_3, slab_color.darkened(0.05))

func _generate_slab_pattern(config, rng: RandomNumberGenerator) -> Array[StoneSlab]:
	var slabs: Array[StoneSlab] = []
	var margin: float = config.margin
	var tile_size: float = config.tile_size

	# Matriz proporcional de 12 losas entrelazadas
	var raw_layout = [
		# Fila 1 (Norte)
		{"rect": Rect2(0.02, 0.02, 0.44, 0.44), "tone": 0.08},
		{"rect": Rect2(0.48, 0.02, 0.52, 0.26), "tone": -0.05},
		{"rect": Rect2(1.02, 0.02, 0.46, 0.48), "tone": 0.12},
		{"rect": Rect2(1.50, 0.02, 0.48, 0.32), "tone": -0.08},

		# Fila 2
		{"rect": Rect2(0.48, 0.30, 0.24, 0.38), "tone": 0.04},
		{"rect": Rect2(0.74, 0.30, 0.26, 0.38), "tone": -0.10},
		{"rect": Rect2(1.50, 0.36, 0.48, 0.32), "tone": 0.06},

		# Fila 3 (Centro)
		{"rect": Rect2(0.02, 0.48, 0.44, 0.54), "tone": -0.04},
		{"rect": Rect2(0.48, 0.70, 0.52, 0.32), "tone": 0.10},
		{"rect": Rect2(1.02, 0.52, 0.46, 0.50), "tone": -0.06},

		# Fila 4 (Sur)
		{"rect": Rect2(0.02, 1.04, 0.44, 0.44), "tone": 0.05},
		{"rect": Rect2(0.48, 1.04, 0.24, 0.44), "tone": -0.08},
		{"rect": Rect2(0.74, 1.04, 0.26, 0.44), "tone": 0.02},
		{"rect": Rect2(1.02, 1.04, 0.46, 0.44), "tone": 0.09},
		{"rect": Rect2(1.50, 0.70, 0.48, 0.78), "tone": -0.03},

		# Fila 5 (Extremo Sur)
		{"rect": Rect2(0.02, 1.50, 0.44, 0.48), "tone": -0.06},
		{"rect": Rect2(0.48, 1.50, 0.52, 0.48), "tone": 0.07},
		{"rect": Rect2(1.02, 1.50, 0.46, 0.48), "tone": -0.02},
	]

	var scale_factor: float = tile_size / 2.0

	for item in raw_layout:
		var r: Rect2 = item["rect"]
		var scaled_rect := Rect2(
			r.position.x * scale_factor + (margin * 0.5),
			r.position.y * scale_factor + (margin * 0.5),
			(r.size.x * scale_factor) - margin,
			(r.size.y * scale_factor) - margin
		)

		var h: float = rng.randf_range(config.height_min, config.height_max)
		var bevel: float = rng.randf_range(config.bevel_min, config.bevel_max)
		var tone: float = float(item["tone"]) + rng.randf_range(-config.tone_variation, config.tone_variation)

		slabs.append(StoneSlab.new(scaled_rect, h, bevel, tone))

	return slabs

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
