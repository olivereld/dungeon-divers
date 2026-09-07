class_name SolidGeometryBuilder
extends RefCounted

## Construye la geometría 3D volumétrica completa de una SolidRegion (Fase M6 / Hardening).
## Genera un volumen sólido de (cell_size x cell_size x wall_height) por cada celda WALL,
## con tapa superior continua y culling del 100% de caras internas entre celdas WALL adyacentes.

const _SolidRegionScript = preload("res://src/geometry_generator/data/solid_region.gd")
const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")

## Genera la malla volumétrica completa de una región sólida.
func build_region_mesh(
	region: _SolidRegionScript,
	config: _WallGeometryConfigScript = null,
	door_opening_height: float = 2.4
) -> _GeneratedMeshScript:
	var g_mesh := _GeneratedMeshScript.new()
	if region == null or region.cells.is_empty():
		return g_mesh

	if config == null:
		config = _WallGeometryConfigScript.new()

	var tile_size: float = config.cube_size
	var total_h: float = config.get_total_height()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var aabb := AABB()
	var aabb_init := false

	# 1. Tapa superior plana continua (Top Cap) para cada celda WALL
	for cell in region.cells:
		var cx: float = float(cell.x) * tile_size
		var cz: float = float(cell.y) * tile_size
		var p_min := Vector3(cx, 0.0, cz)
		var p_max := Vector3(cx + tile_size, total_h, cz + tile_size)

		if not aabb_init:
			aabb = AABB(p_min, p_max - p_min)
			aabb_init = true
		else:
			aabb = aabb.expand(p_min)
			aabb = aabb.expand(p_max)

		# Tapa superior en Y = total_h mirando hacia arriba (Vector3.UP)
		var t0 := Vector3(cx, total_h, cz + tile_size)
		var t1 := Vector3(cx + tile_size, total_h, cz + tile_size)
		var t2 := Vector3(cx + tile_size, total_h, cz)
		var t3 := Vector3(cx, total_h, cz)
		_add_quad(st, t0, t1, t2, t3)

	# 2. Caras verticales exteriores (solo hacia celdas no-WALL o bordes)
	for face in region.exterior_faces:
		var cell: Vector2i = face["cell"]
		var side: int = face["side"]
		var is_opening: bool = face.get("is_opening", false)

		var cx: float = float(cell.x) * tile_size
		var cz: float = float(cell.y) * tile_size

		var y_start: float = 0.0
		var y_end: float = total_h

		if is_opening:
			# Si hay un opening/vano registrado, solo se genera el dintel superior si hay altura sobrante
			if total_h > door_opening_height:
				y_start = door_opening_height
			else:
				continue

		match side:
			_RoomEntranceScript.NORTH:
				# Cara Z = cz, mirando a -Z
				var v0 := Vector3(cx + tile_size, y_start, cz)
				var v1 := Vector3(cx, y_start, cz)
				var v2 := Vector3(cx, y_end, cz)
				var v3 := Vector3(cx + tile_size, y_end, cz)
				_add_quad(st, v0, v1, v2, v3)

			_RoomEntranceScript.SOUTH:
				# Cara Z = cz + tile_size, mirando a +Z
				var v0 := Vector3(cx, y_start, cz + tile_size)
				var v1 := Vector3(cx + tile_size, y_start, cz + tile_size)
				var v2 := Vector3(cx + tile_size, y_end, cz + tile_size)
				var v3 := Vector3(cx, y_end, cz + tile_size)
				_add_quad(st, v0, v1, v2, v3)

			_RoomEntranceScript.WEST:
				# Cara X = cx, mirando a -X
				var v0 := Vector3(cx, y_start, cz)
				var v1 := Vector3(cx, y_start, cz + tile_size)
				var v2 := Vector3(cx, y_end, cz + tile_size)
				var v3 := Vector3(cx, y_end, cz)
				_add_quad(st, v0, v1, v2, v3)

			_RoomEntranceScript.EAST:
				# Cara X = cx + tile_size, mirando a +X
				var v0 := Vector3(cx + tile_size, y_start, cz + tile_size)
				var v1 := Vector3(cx + tile_size, y_start, cz)
				var v2 := Vector3(cx + tile_size, y_end, cz)
				var v3 := Vector3(cx + tile_size, y_end, cz + tile_size)
				_add_quad(st, v0, v1, v2, v3)

	var mesh := ArrayMesh.new()
	st.generate_normals()
	st.index()
	st.generate_tangents()
	mesh = st.commit(mesh)
	if mesh.get_surface_count() > 0:
		mesh.surface_set_name(0, "SolidMass")

	g_mesh.mesh = mesh
	g_mesh.bounds = aabb
	return g_mesh

static func _add_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	var cross1: Vector3 = (p1 - p0).cross(p2 - p0)
	if cross1.length_squared() >= 0.000001:
		var normal1: Vector3 = cross1.normalized()
		st.set_normal(normal1)
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(p0)

		st.set_normal(normal1)
		st.set_uv(Vector2(1.0, 0.0))
		st.add_vertex(p1)

		st.set_normal(normal1)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(p2)

	var cross2: Vector3 = (p2 - p0).cross(p3 - p0)
	if cross2.length_squared() >= 0.000001:
		var normal2: Vector3 = cross2.normalized()
		st.set_normal(normal2)
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(p0)

		st.set_normal(normal2)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(p2)

		st.set_normal(normal2)
		st.set_uv(Vector2(0.0, 1.0))
		st.add_vertex(p3)
