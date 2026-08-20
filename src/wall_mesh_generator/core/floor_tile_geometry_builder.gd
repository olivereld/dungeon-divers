class_name FloorTileGeometryBuilder
extends RefCounted

## Constructor procedural de losas y baldosas de suelo estilizadas para mazmorras (estilo Zelda / Diablo / KayKit).
## Genera baldosas de piedra irregulares con biseles 3D a 45°, juntas de mortero, micro-variaciones de cota y colores de vértice.

const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")

## Definición de una losa dentro del patrón de la baldosa
class StoneSlab:
	var rect: Rect2
	var height: float
	var bevel: float
	var color_mod: float # Factor de tonalidad (0.0 = neutro, -0.15 = más oscuro, +0.15 = más claro)

	func _init(p_rect: Rect2, p_height: float, p_bevel: float, p_color_mod: float = 0.0) -> void:
		rect = p_rect
		height = p_height
		bevel = p_bevel
		color_mod = p_color_mod

## Genera una malla de baldosa de suelo individual (2.0m x 2.0m o tamaño personalizado).
func build_floor_tile_mesh(tile_size: float = 2.0, seed_val: int = 1337) -> ArrayMesh:
	var st_slabs := SurfaceTool.new()
	var st_mortar := SurfaceTool.new()

	st_slabs.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_mortar.begin(Mesh.PRIMITIVE_TRIANGLES)

	_generate_tile_geometry(st_slabs, st_mortar, Vector2.ZERO, tile_size, seed_val)

	var mesh := ArrayMesh.new()

	# Superficie 0: Losas de Piedra
	var slabs_arr := st_slabs.commit_to_arrays()
	if slabs_arr.size() > 0 and slabs_arr[Mesh.ARRAY_VERTEX] != null and (slabs_arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, slabs_arr)
		mesh.surface_set_name(mesh.get_surface_count() - 1, "FloorSlabs")
		mesh.surface_set_material(mesh.get_surface_count() - 1, _WallMaterialFactoryScript.create_floor_slab_material())

	# Superficie 1: Mortero / Lecho base
	var mortar_arr := st_mortar.commit_to_arrays()
	if mortar_arr.size() > 0 and mortar_arr[Mesh.ARRAY_VERTEX] != null and (mortar_arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mortar_arr)
		mesh.surface_set_name(mesh.get_surface_count() - 1, "FloorMortar")
		mesh.surface_set_material(mesh.get_surface_count() - 1, _WallMaterialFactoryScript.create_floor_mortar_material())

	return mesh

## Genera una cuadrícula de suelo (ej. 3x3 baldosas continuas) para visualizar el tileado de la sala.
func build_floor_grid_mesh(cols: int = 3, rows: int = 3, tile_size: float = 2.0, seed_val: int = 1337) -> ArrayMesh:
	var st_slabs := SurfaceTool.new()
	var st_mortar := SurfaceTool.new()

	st_slabs.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_mortar.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	for r in range(rows):
		for c in range(cols):
			var tile_offset := Vector2(float(c) * tile_size, float(r) * tile_size)
			var sub_seed := rng.randi()
			_generate_tile_geometry(st_slabs, st_mortar, tile_offset, tile_size, sub_seed)

	var mesh := ArrayMesh.new()

	var slabs_arr := st_slabs.commit_to_arrays()
	if slabs_arr.size() > 0 and slabs_arr[Mesh.ARRAY_VERTEX] != null and (slabs_arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, slabs_arr)
		mesh.surface_set_name(mesh.get_surface_count() - 1, "FloorSlabs")
		mesh.surface_set_material(mesh.get_surface_count() - 1, _WallMaterialFactoryScript.create_floor_slab_material())

	var mortar_arr := st_mortar.commit_to_arrays()
	if mortar_arr.size() > 0 and mortar_arr[Mesh.ARRAY_VERTEX] != null and (mortar_arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mortar_arr)
		mesh.surface_set_name(mesh.get_surface_count() - 1, "FloorMortar")
		mesh.surface_set_material(mesh.get_surface_count() - 1, _WallMaterialFactoryScript.create_floor_mortar_material())

	return mesh

## Genera la geometría 3D de una baldosa completa con sus losas biseladas y mortero
func _generate_tile_geometry(
	st_slabs: SurfaceTool,
	st_mortar: SurfaceTool,
	offset: Vector2,
	tile_size: float,
	seed_val: int
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# 1. Base de Mortero inferior (Sustrato oscuro en Y=0.0)
	var m_p0 := Vector3(offset.x, 0.0, offset.y)
	var m_p1 := Vector3(offset.x + tile_size, 0.0, offset.y)
	var m_p2 := Vector3(offset.x + tile_size, 0.0, offset.y + tile_size)
	var m_p3 := Vector3(offset.x, 0.0, offset.y + tile_size)

	_add_quad_with_normal(st_mortar, m_p0, m_p1, m_p2, m_p3, Vector3.UP, Color(0.20, 0.18, 0.16))

	# 2. Generar el patrón de losas (interlocking stone pattern proporcional)
	var slabs := _generate_slab_pattern(tile_size, rng)

	for slab in slabs:
		var r := slab.rect
		var h := slab.height
		var b := slab.bevel

		var base_color: Color = Color(0.52, 0.54, 0.56) # Tono piedra base
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

		# A. Cara Superior Plana (Top Face)
		_add_quad_with_normal(st_slabs, p_top_0, p_top_1, p_top_2, p_top_3, Vector3.UP, slab_color)

		# B. Bisel Norte (North Bevel Slope)
		_add_bevel_quad(st_slabs, p_bot_0, p_bot_1, p_top_1, p_top_0, slab_color.darkened(0.08))

		# C. Bisel Este (East Bevel Slope)
		_add_bevel_quad(st_slabs, p_bot_1, p_bot_2, p_top_2, p_top_1, slab_color.darkened(0.12))

		# D. Bisel Sur (South Bevel Slope)
		_add_bevel_quad(st_slabs, p_bot_2, p_bot_3, p_top_3, p_top_2, slab_color.darkened(0.15))

		# E. Bisel Oeste (West Bevel Slope)
		_add_bevel_quad(st_slabs, p_bot_3, p_bot_0, p_top_0, p_top_3, slab_color.darkened(0.05))

## Genera la distribución modular y armónica de losas rectangulares/cuadradas como en la referencia.
func _generate_slab_pattern(tile_size: float, rng: RandomNumberGenerator) -> Array[StoneSlab]:
	var slabs: Array[StoneSlab] = []
	var margin: float = 0.035 # Separación de mortero entre piedras

	# Matriz proporcional de 12 losas entrelazadas estilizadas
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

		var h: float = rng.randf_range(0.045, 0.075) # Altura de 4.5cm a 7.5cm
		var bevel: float = rng.randf_range(0.022, 0.032) # Bisel de 2.2cm a 3.2cm
		var tone: float = float(item["tone"]) + rng.randf_range(-0.04, 0.04)

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
