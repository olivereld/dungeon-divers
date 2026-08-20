class_name FloorCollisionBuilder
extends RefCounted

## Genera formas de colisión física simplificadas (BoxShape3D) para regiones de suelo.
## Evita la penalización de rendimiento y los problemas de atasco de CONCAVE_TRIMESH por baldosa.

const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const _GeneratedFloorClusterScript = preload("res://src/floor_tile_generator/data/generated_floor_cluster.gd")

func build_collision_for_cluster(
	cluster,
	cells: Array,
	config = null
) -> void:
	if cluster == null or cells.is_empty():
		return

	if config == null:
		config = _FloorTileConfigScript.new()

	if config.collision_mode == _FloorTileConfigScript.CollisionMode.NONE:
		return

	var tile_size: float = config.tile_size
	var depth: float = config.collision_depth
	var top_y: float = (config.height_min + config.height_max) * 0.5
	var center_y: float = top_y - (depth * 0.5)

	if config.collision_mode == _FloorTileConfigScript.CollisionMode.SIMPLE_BOX:
		# Caja única abarcando el AABB 2D de todas las celdas
		var min_x: int = 999999
		var max_x: int = -999999
		var min_y: int = 999999
		var max_y: int = -999999

		for c in cells:
			var cell: Vector2i = c if c is Vector2i else Vector2i(c.x, c.y)
			min_x = mini(min_x, cell.x)
			max_x = maxi(max_x, cell.x)
			min_y = mini(min_y, cell.y)
			max_y = maxi(max_y, cell.y)

		var span_x: float = float(max_x - min_x + 1) * tile_size
		var span_z: float = float(max_y - min_y + 1) * tile_size
		var origin_x: float = (float(min_x) * tile_size) + (span_x * 0.5)
		var origin_z: float = (float(min_y) * tile_size) + (span_z * 0.5)

		var box := BoxShape3D.new()
		box.size = Vector3(span_x, depth, span_z)

		var xform := Transform3D.IDENTITY
		xform.origin = Vector3(origin_x, center_y, origin_z)
		cluster.add_collision_shape(box, xform)

	elif config.collision_mode == _FloorTileConfigScript.CollisionMode.COMPOUND_BOX:
		# Generar tiras horizontales contiguas (RLE en X) para reducir drásticamente el número de colliders
		var strips := _extract_horizontal_strips(cells)
		for strip in strips:
			var strip_start: Vector2i = strip["start"]
			var length: int = strip["length"]

			var span_x: float = float(length) * tile_size
			var span_z: float = tile_size
			var origin_x: float = (float(strip_start.x) * tile_size) + (span_x * 0.5)
			var origin_z: float = (float(strip_start.y) * tile_size) + (span_z * 0.5)

			var box := BoxShape3D.new()
			box.size = Vector3(span_x, depth, span_z)

			var xform := Transform3D.IDENTITY
			xform.origin = Vector3(origin_x, center_y, origin_z)
			cluster.add_collision_shape(box, xform)

## Agrupa celdas en tiras horizontales contiguas por fila
func _extract_horizontal_strips(cells: Array) -> Array[Dictionary]:
	var strips: Array[Dictionary] = []
	var by_row: Dictionary = {}

	for c in cells:
		var cell: Vector2i = c if c is Vector2i else Vector2i(c.x, c.y)
		if not by_row.has(cell.y):
			by_row[cell.y] = []
		by_row[cell.y].append(cell.x)

	for y in by_row.keys():
		var xs: Array = by_row[y]
		xs.sort()

		var i: int = 0
		while i < xs.size():
			var start_x: int = xs[i]
			var len_count: int = 1
			while (i + 1) < xs.size() and xs[i + 1] == xs[i] + 1:
				len_count += 1
				i += 1
			strips.append({
				"start": Vector2i(start_x, y),
				"length": len_count
			})
			i += 1

	return strips
