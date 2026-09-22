class_name HydrologySpatialIndex
extends RefCounted

## Índice espacial uniforme para aceleración de consultas geométricas de ríos y lagos.
## Estructura de aceleración puramente derivada de HydrologyResult (no es fuente de verdad).

const DEFAULT_BUCKET_SIZE: int = 16

var bucket_size: int = DEFAULT_BUCKET_SIZE
var cell_size: float = 1.0

## Grid de segmentos fluviales: Vector2i (bucket_coord) -> Array[Dictionary]
var _river_grid: Dictionary = {}

## Grid de lagos: Vector2i (bucket_coord) -> Array[Dictionary]
var _lake_grid: Dictionary = {}

## Lista de todos los segmentos indexados
var all_segments: Array[Dictionary] = []

## Lista de todos los lagos indexados
var all_lakes: Array[Dictionary] = []

var total_segments_count: int = 0
var total_lakes_count: int = 0


func _init(p_bucket_size: int = DEFAULT_BUCKET_SIZE, p_cell_size: float = 1.0) -> void:
	bucket_size = maxi(p_bucket_size, 4)
	cell_size = p_cell_size if p_cell_size > 0.0 else 1.0


## Construye los índices espaciales a partir de los ríos y lagos globales de HydrologyResult.
func build(rivers: Array, lakes: Array, p_cell_size: float = 1.0) -> void:
	cell_size = p_cell_size if p_cell_size > 0.0 else 1.0
	_river_grid.clear()
	_lake_grid.clear()
	all_segments.clear()
	all_lakes.clear()

	_index_rivers(rivers)
	_index_lakes(lakes)

	total_segments_count = all_segments.size()
	total_lakes_count = all_lakes.size()


func _index_rivers(rivers: Array) -> void:
	var seg_id: int = 0

	for river_idx in range(rivers.size()):
		var river_data: Dictionary = rivers[river_idx]
		var pts_arr: Array = river_data.get("points", [])
		var depths_arr: Array = river_data.get("depths", [])
		var widths_arr: Array = river_data.get("widths", [])
		var num_pts: int = pts_arr.size()

		if num_pts < 2:
			continue

		for j in range(num_pts - 1):
			var p0_3d: Vector3 = pts_arr[j]
			var p1_3d: Vector3 = pts_arr[j + 1]

			# Posiciones 2D en metros en el espacio del mundo
			var p0 := Vector2(p0_3d.x, p0_3d.z) * cell_size
			var p1 := Vector2(p1_3d.x, p1_3d.z) * cell_size
			var v := p1 - p0
			var len_sq: float = v.length_squared()
			var inv_len_sq: float = 1.0 / len_sq if len_sq > 0.00001 else 0.0

			var w0: float = float(widths_arr[j]) if j < widths_arr.size() else 1.0
			var w1: float = float(widths_arr[j + 1]) if (j + 1) < widths_arr.size() else w0
			var d0: float = float(depths_arr[j]) if j < depths_arr.size() else 0.5
			var d1: float = float(depths_arr[j + 1]) if (j + 1) < depths_arr.size() else d0

			var max_w: float = maxf(w0, w1)
			var max_w_river: float = max_w * 0.5
			var max_w_bank_slope: float = maxf(max_w_river * 1.5, cell_size * 6.0)
			var max_w_bank: float = max_w_river + max_w_bank_slope

			# AABB en coordenadas de celda entera
			var min_cx: int = int(floor((minf(p0.x, p1.x) - max_w_bank) / cell_size))
			var max_cx: int = int(ceil((maxf(p0.x, p1.x) + max_w_bank) / cell_size))
			var min_cy: int = int(floor((minf(p0.y, p1.y) - max_w_bank) / cell_size))
			var max_cy: int = int(ceil((maxf(p0.y, p1.y) + max_w_bank) / cell_size))

			var aabb := Rect2i(min_cx, min_cy, max_cx - min_cx + 1, max_cy - min_cy + 1)

			var p0_grid := Vector2(p0_3d.x, p0_3d.z)
			var p1_grid := Vector2(p1_3d.x, p1_3d.z)
			var v_grid := p1_grid - p0_grid
			var l_sq_grid: float = v_grid.length_squared()
			var max_seg_half_w: float = max_w * 0.5

			# Invariantes geométricos precalculados (BLOQUE 13C / BLOQUE 14C)
			var delta_w: float = w1 - w0
			var delta_d: float = d1 - d0
			var delta_y: float = p1_3d.y - p0_3d.y
			var p0_y: float = p0_3d.y
			var inv_l_sq_grid: float = 1.0 / l_sq_grid if l_sq_grid > 0.00001 else 0.0
			var min_gx: float = minf(p0_grid.x, p1_grid.x)
			var max_gx: float = maxf(p0_grid.x, p1_grid.x)
			var min_gy: float = minf(p0_grid.y, p1_grid.y)
			var max_gy: float = maxf(p0_grid.y, p1_grid.y)
			var half_w0: float = w0 * 0.5
			var half_delta_w: float = (w1 - w0) * 0.5

			var seg := {
				"id": seg_id,
				"river_index": river_idx,
				"segment_index": j,
				"p0_3d": p0_3d,
				"p1_3d": p1_3d,
				"p0": p0,
				"p1": p1,
				"v": v,
				"inv_len_sq": inv_len_sq,
				"p0_grid": p0_grid,
				"p1_grid": p1_grid,
				"v_grid": v_grid,
				"l_sq_grid": l_sq_grid,
				"inv_l_sq_grid": inv_l_sq_grid,
				"p0_gx": p0_grid.x,
				"p0_gy": p0_grid.y,
				"v_gx": v_grid.x,
				"v_gy": v_grid.y,
				"min_gx": min_gx,
				"max_gx": max_gx,
				"min_gy": min_gy,
				"max_gy": max_gy,
				"half_w0": half_w0,
				"half_delta_w": half_delta_w,
				"max_seg_half_w": max_seg_half_w,
				"w0": w0,
				"w1": w1,
				"d0": d0,
				"d1": d1,
				"delta_w": delta_w,
				"delta_d": delta_d,
				"delta_y": delta_y,
				"p0_y": p0_y,
				"max_w": max_w,
				"max_w_river": max_w_river,
				"max_w_bank_slope": max_w_bank_slope,
				"max_w_bank": max_w_bank,
				"min_cx": min_cx,
				"max_cx": max_cx,
				"min_cy": min_cy,
				"max_cy": max_cy,
				"aabb": aabb
			}
			all_segments.append(seg)
			seg_id += 1


			# Registrar en los buckets del grid espacial uniforme
			var bx0: int = int(floor(float(min_cx) / float(bucket_size)))
			var bx1: int = int(floor(float(max_cx) / float(bucket_size)))
			var by0: int = int(floor(float(min_cy) / float(bucket_size)))
			var by1: int = int(floor(float(max_cy) / float(bucket_size)))

			for by in range(by0, by1 + 1):
				for bx in range(bx0, bx1 + 1):
					var bk := Vector2i(bx, by)
					if not _river_grid.has(bk):
						_river_grid[bk] = []
					_river_grid[bk].append(seg)


func _index_lakes(lakes: Array) -> void:
	for lake_idx in range(lakes.size()):
		var lake: Dictionary = lakes[lake_idx]
		var cluster: Array = lake.get("cells", [])
		if cluster.is_empty():
			continue

		var min_pos: Vector2i = lake.get("min_pos", Vector2i.ZERO)
		var max_pos: Vector2i = lake.get("max_pos", Vector2i.ZERO)
		if min_pos == Vector2i.ZERO and max_pos == Vector2i.ZERO and not cluster.is_empty():
			min_pos = cluster[0]
			max_pos = cluster[0]
			for p in cluster:
				min_pos.x = mini(min_pos.x, p.x)
				min_pos.y = mini(min_pos.y, p.y)
				max_pos.x = maxi(max_pos.x, p.x)
				max_pos.y = maxi(max_pos.y, p.y)

		# Margen de influencia de la orilla/talud del lago (en celdas)
		var lake_bank_margin: int = clampi(int(ceil((cell_size * 3.5) / cell_size)) + 1, 1, 6)
		var aabb := Rect2i(
			min_pos.x - lake_bank_margin,
			min_pos.y - lake_bank_margin,
			(max_pos.x - min_pos.x) + 2 * lake_bank_margin + 1,
			(max_pos.y - min_pos.y) + 2 * lake_bank_margin + 1
		)

		var lake_entry := {
			"id": lake.get("id", lake_idx),
			"lake_index": lake_idx,
			"raw_lake": lake,
			"min_pos": min_pos,
			"max_pos": max_pos,
			"cells": cluster,
			"aabb": aabb
		}
		all_lakes.append(lake_entry)

		var bx0: int = int(floor(float(aabb.position.x) / float(bucket_size)))
		var bx1: int = int(floor(float(aabb.end.x - 1) / float(bucket_size)))
		var by0: int = int(floor(float(aabb.position.y) / float(bucket_size)))
		var by1: int = int(floor(float(aabb.end.y - 1) / float(bucket_size)))

		for by in range(by0, by1 + 1):
			for bx in range(bx0, bx1 + 1):
				var bk := Vector2i(bx, by)
				if not _lake_grid.has(bk):
					_lake_grid[bk] = []
				_lake_grid[bk].append(lake_entry)


## Consulta segmentos fluviales cuyo AABB de influencia intersecta el área de consulta en celdas.
## Deduplica estrictamente los resultados.
func query_river_segments(bounds: Rect2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var visited: Dictionary = {}

	var bx0: int = int(floor(float(bounds.position.x) / float(bucket_size)))
	var bx1: int = int(floor(float(bounds.end.x - 1) / float(bucket_size)))
	var by0: int = int(floor(float(bounds.position.y) / float(bucket_size)))
	var by1: int = int(floor(float(bounds.end.y - 1) / float(bucket_size)))

	for by in range(by0, by1 + 1):
		for bx in range(bx0, bx1 + 1):
			var bk := Vector2i(bx, by)
			var list: Array = _river_grid.get(bk, [])
			for seg in list:
				var s_id: int = seg["id"]
				if not visited.has(s_id):
					visited[s_id] = true
					var s_aabb: Rect2i = seg["aabb"]
					if bounds.intersects(s_aabb):
						result.append(seg)

	return result


## Consulta segmentos fluviales en la vecindad de un punto 2D continuo con un radio dado.
func query_river_segments_near_point(pos_2d: Vector2, radius: float) -> Array[Dictionary]:
	var min_cx: int = int(floor((pos_2d.x - radius) / cell_size))
	var max_cx: int = int(ceil((pos_2d.x + radius) / cell_size))
	var min_cy: int = int(floor((pos_2d.y - radius) / cell_size))
	var max_cy: int = int(ceil((pos_2d.y + radius) / cell_size))
	var bounds := Rect2i(min_cx, min_cy, max_cx - min_cx + 1, max_cy - min_cy + 1)
	return query_river_segments(bounds)


## Consulta lagos cuyo AABB de influencia intersecta el área de consulta en celdas.
func query_lakes(bounds: Rect2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var visited: Dictionary = {}

	var bx0: int = int(floor(float(bounds.position.x) / float(bucket_size)))
	var bx1: int = int(floor(float(bounds.end.x - 1) / float(bucket_size)))
	var by0: int = int(floor(float(bounds.position.y) / float(bucket_size)))
	var by1: int = int(floor(float(bounds.end.y - 1) / float(bucket_size)))

	for by in range(by0, by1 + 1):
		for bx in range(bx0, bx1 + 1):
			var bk := Vector2i(bx, by)
			var list: Array = _lake_grid.get(bk, [])
			for lk in list:
				var l_id: int = lk["id"]
				if not visited.has(l_id):
					visited[l_id] = true
					var l_aabb: Rect2i = lk["aabb"]
					if bounds.intersects(l_aabb):
						result.append(lk)

	return result


## Consulta lagos en la vecindad de un punto 2D continuo con un radio dado.
func query_lakes_near_point(pos_2d: Vector2, radius: float) -> Array[Dictionary]:
	var min_cx: int = int(floor((pos_2d.x - radius) / cell_size))
	var max_cx: int = int(ceil((pos_2d.x + radius) / cell_size))
	var min_cy: int = int(floor((pos_2d.y - radius) / cell_size))
	var max_cy: int = int(ceil((pos_2d.y + radius) / cell_size))
	var bounds := Rect2i(min_cx, min_cy, max_cx - min_cx + 1, max_cy - min_cy + 1)
	return query_lakes(bounds)
