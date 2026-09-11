class_name LakeMeshBuilder
extends RefCounted

## Constructor de geometría de superficie plana horizontal para lagos y depresiones.
## Genera una malla continua a la cota exacta lake.water_height sin deformaciones ni inclinaciones.

const _WaterSurfaceDataScript = preload("res://src/world_generator/presentation/water/water_surface_data.gd")

static func build_lake_surface(lake: Dictionary, result: WorldResult, profile: WorldProfile) -> RefCounted:
	var lake_cells: Array = lake.get("cells", [])
	if lake_cells.is_empty():
		return null

	var water_y: float = float(lake.get("water_height", 0.0))
	var lake_set: Dictionary = {}
	for c in lake_cells:
		lake_set[c] = true

	var surf = _WaterSurfaceDataScript.new()
	var w: int = result.dimensions.x
	var h: int = result.dimensions.y

	# Identificar quads que tocan las celdas del lago
	var quads_to_check: Dictionary = {}
	for cp in lake_cells:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var qx: int = cp.x + dx
				var qy: int = cp.y + dy
				if qx >= 0 and qx < w - 1 and qy >= 0 and qy < h - 1:
					quads_to_check[Vector2i(qx, qy)] = true

	for qpos in quads_to_check.keys():
		var c0: Vector2i = qpos
		var c1: Vector2i = qpos + Vector2i(1, 0)
		var c2: Vector2i = qpos + Vector2i(1, 1)
		var c3: Vector2i = qpos + Vector2i(0, 1)

		var in_basin: bool = lake_set.has(c0) or lake_set.has(c1) or lake_set.has(c2) or lake_set.has(c3)
		if not in_basin:
			continue

		var h0: float = result.get_cell(c0).height
		var h1: float = result.get_cell(c1).height
		var h2: float = result.get_cell(c2).height
		var h3: float = result.get_cell(c3).height

		# Verificar si alguna esquina queda por debajo de la lámina de agua
		var s0: bool = in_basin and h0 < water_y
		var s1: bool = in_basin and h1 < water_y
		var s2: bool = in_basin and h2 < water_y
		var s3: bool = in_basin and h3 < water_y

		if not (s0 or s1 or s2 or s3):
			continue

		var p0 := Vector3(float(c0.x), water_y, float(c0.y))
		var p1 := Vector3(float(c1.x), water_y, float(c1.y))
		var p2 := Vector3(float(c2.x), water_y, float(c2.y))
		var p3 := Vector3(float(c3.x), water_y, float(c3.y))

		var uv0 := Vector2(p0.x, p0.z)
		var uv1 := Vector2(p1.x, p1.z)
		var uv2 := Vector2(p2.x, p2.z)
		var uv3 := Vector2(p3.x, p3.z)

		var col: Color = profile.water_color_lake
		var flow: Vector2 = Vector2.ZERO  # Lago en calma

		var i0: int = surf.add_vertex(p0, Vector3.UP, uv0, flow, col)
		var i1: int = surf.add_vertex(p1, Vector3.UP, uv1, flow, col)
		var i2: int = surf.add_vertex(p2, Vector3.UP, uv2, flow, col)
		var i3: int = surf.add_vertex(p3, Vector3.UP, uv3, flow, col)

		surf.add_triangle(i0, i1, i2)
		surf.add_triangle(i0, i2, i3)

	return surf
