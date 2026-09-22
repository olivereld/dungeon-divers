class_name HydrologyResult
extends RefCounted

enum HydrologyZone {
	DRY = 0,
	RIVER_WATER = 1,
	RIVER_BANK = 2,
	LAKE_WATER = 3,
	LAKE_BANK = 4,
}

## Holds the computed hydrological features: planar depression lakes and downhill rivers.
## Completely decoupled from WorldCell and TerrainStage.

## Map from Vector2i grid position to cell hydrological data:
## {
##   "type": "lake" | "river",
##   "water_height": float,      # H_water: Cota absoluta de la lámina de agua pura (verdad hidráulica)
##   "bed_height": float,        # H_bed: Cota absoluta del fondo del lecho hidráulico
##   "depth": float,             # Valor derivado: water_height - bed_height
##   "shoreline_height": float,  # Cota de referencia independiente de orilla / coronación
##   "flow_dir": Vector2,
##   "river_index": int,
##   "lake_id": int
## }
var water_cells: Dictionary = {}

## Array of river path dictionaries:
## {
##   "index": int,
##   "points": Array[Vector3],
##   "widths": Array[float],
##   "cells": Array[Vector2i]
## }
var rivers: Array = []

## Array of lake body dictionaries:
## {
##   "id": int,
##   "water_height": float,
##   "cells": Array[Vector2i],
##   "spillway_pos": Vector2i,
##   "spillway_height": float,
##   "min_pos": Vector2i,
##   "max_pos": Vector2i
var lakes: Array = []

## Basin dictionaries (basin_id -> { "id": int, "outlet": Vector2i, "area": int, "cells": Array[Vector2i], "min_elevation": float, "max_elevation": float })
var basins: Dictionary = {}

## Array of confluence dictionaries:
## {
##   "position": Vector2i,
##   "upstream_rivers": Array[int],
##   "downstream_river": int
## }
var confluences: Array = []

## RiverNetwork instance modeling the explicit topological river network DAG:
var river_network: Variant = null

func get_river_network() -> RefCounted:
	return river_network if river_network != null else null

const _HydrologySpatialIndexScript = preload("res://src/world_generator/hydrology/hydrology_spatial_index.gd")

## Debug maps (Vector2i -> float or Vector2) for visual analysis:
## "noise", "lake_potential", "river_potential", "drainage", "flow_dir", "flow_vector", "flow_to", "upstream", "basins"
var debug_layers: Dictionary = {}

## Estructura de aceleración espacial puramente derivada (no es fuente de verdad)
var spatial_index: RefCounted = null

func build_spatial_index(p_cell_size: float = 1.0) -> void:
	spatial_index = _HydrologySpatialIndexScript.new(16, p_cell_size)
	spatial_index.build(rivers, lakes, p_cell_size)

func merge(other: HydrologyResult, cell_size: float = 1.0) -> void:
	if other == null:
		return
	for pos in other.water_cells:
		water_cells[pos] = other.water_cells[pos]
	for r in other.rivers:
		rivers.append(r)
	for l in other.lakes:
		lakes.append(l)
	for b_id in other.basins:
		basins[b_id] = other.basins[b_id]
	for c in other.confluences:
		confluences.append(c)
	for pos in other.accumulation:
		accumulation[pos] = other.accumulation[pos]
	for pos in other.zones:
		zones[pos] = other.zones[pos]
	for pos in other.hydraulic_influence:
		hydraulic_influence[pos] = other.hydraulic_influence[pos]
	for pos in other.exclusion_mask:
		exclusion_mask[pos] = other.exclusion_mask[pos]

	if other.height_min != 0.0 or other.height_max != 0.0:
		if height_min == 0.0 and height_max == 0.0:
			height_min = other.height_min
			height_max = other.height_max
		else:
			height_min = minf(height_min, other.height_min)
			height_max = maxf(height_max, other.height_max)

	build_spatial_index(cell_size)

## Datos globales de terreno para normalización idéntica y determinista
var height_min: float = 0.0
var height_max: float = 0.0

## Acumulación de flujo topológica global (Vector2i -> float)
var accumulation: Dictionary = {}

func is_water(pos: Vector2i) -> bool:
	return water_cells.has(pos)

func is_lake(pos: Vector2i) -> bool:
	if not zones.is_empty():
		return zones.get(pos, HydrologyZone.DRY) == HydrologyZone.LAKE_WATER
	if not water_cells.has(pos):
		return false
	return water_cells[pos].get("type", "") == "lake"

func is_river(pos: Vector2i) -> bool:
	if not water_cells.has(pos):
		return false
	return water_cells[pos].get("type", "") == "river"

func get_water_height(pos: Vector2i, default_val: float = 0.0) -> float:
	if water_cells.has(pos):
		return water_cells[pos].get("water_height", default_val)
	return default_val

func get_bed_height(pos: Vector2i, default_val: float = 0.0) -> float:
	if water_cells.has(pos):
		return float(water_cells[pos].get("bed_height", default_val))
	return default_val

func get_shoreline_height(pos: Vector2i, default_val: float = 0.0) -> float:
	if water_cells.has(pos):
		return float(water_cells[pos].get("shoreline_height", default_val))
	return default_val

func get_water_depth(pos: Vector2i) -> float:
	if water_cells.has(pos):
		return water_cells[pos].get("depth", 0.0)
	return 0.0

func get_cell_data(pos: Vector2i) -> Dictionary:
	return water_cells.get(pos, {})

func set_debug_grid(layer_name: String, grid: Dictionary) -> void:
	debug_layers[layer_name] = grid

func get_debug_value(layer_name: String, pos: Vector2i, default_val: Variant = 0.0) -> Variant:
	if debug_layers.has(layer_name):
		return debug_layers[layer_name].get(pos, default_val)
	return default_val

func has_debug_layer(layer_name: String) -> bool:
	return debug_layers.has(layer_name)

# =============================================================================
# ZONIFICACIÓN HIDROLÓGICA Y MÁSCARA DE EXCLUSIÓN PARA VEGETACIÓN
# =============================================================================

## Mapeo por celda Vector2i -> HydrologyZone (int)
var zones: Dictionary = {}

## Mapeo continuo de influencia hidráulica Vector2i -> float en [0.0, 1.0]
## 0.0 = terreno intacto, 0.0 -> 1.0 = transición / talud, 1.0 = cuenca / cauce sumergido
var hydraulic_influence: Dictionary = {}

## Cache del SDF de orilla (Shoreline Distance Field) normalizado en [0.0, 1.0]
var shoreline_sdf: PackedFloat32Array = PackedFloat32Array()

## Cache de altura de agua extendida y suavizada hacia tierra firme
var extended_water_heights: PackedFloat32Array = PackedFloat32Array()

func get_shoreline_sdf_at(pos: Vector2i, macro_w: int = 0, macro_h: int = 0) -> float:
	if macro_w > 0 and macro_h > 0 and not shoreline_sdf.is_empty() and shoreline_sdf.size() == macro_w * macro_h:
		if pos.x >= 0 and pos.x < macro_w and pos.y >= 0 and pos.y < macro_h:
			return shoreline_sdf[pos.y * macro_w + pos.x]
	# Si no hay SDF macro o pos cae fuera de la grilla macro:
	if is_water(pos):
		return 1.0
	return 0.0

func get_extended_water_height_at(pos: Vector2i, macro_w: int = 0, macro_h: int = 0, default_val: float = 0.0) -> float:
	if macro_w > 0 and macro_h > 0 and not extended_water_heights.is_empty() and extended_water_heights.size() == macro_w * macro_h:
		if pos.x >= 0 and pos.x < macro_w and pos.y >= 0 and pos.y < macro_h:
			return extended_water_heights[pos.y * macro_w + pos.x]
	if water_cells.has(pos):
		return float(water_cells[pos].get("water_height", default_val))
	return default_val

func get_hydraulic_influence(pos: Vector2i, default_val: float = 0.0) -> float:
	return float(hydraulic_influence.get(pos, default_val))

## Máscara booleana rápida de exclusión para vegetación Vector2i -> bool (true = excluido)
var exclusion_mask: Dictionary = {}

func get_zone(pos: Vector2i) -> int:
	return zones.get(pos, HydrologyZone.DRY)

func is_water_zone(pos: Vector2i) -> bool:
	var z: int = get_zone(pos)
	return z == HydrologyZone.RIVER_WATER or z == HydrologyZone.LAKE_WATER

func is_bank_zone(pos: Vector2i) -> bool:
	var z: int = get_zone(pos)
	return z == HydrologyZone.RIVER_BANK or z == HydrologyZone.LAKE_BANK

## Consulta booleana rápida O(1) a nivel de celda para el bucle de vegetación
func is_vegetation_excluded(pos: Vector2i) -> bool:
	if exclusion_mask.has(pos):
		return exclusion_mask[pos]
	var z: int = get_zone(pos)
	return z != HydrologyZone.DRY

## Consulta geométrica continua precisa para una posición 2D continua con jitter
func is_position_excluded(
	pos_2d: Vector2,
	bank_clearance: float = 1.0,
	scoped_lakes: Variant = null,
	scoped_rivers: Variant = null
) -> bool:
	# 1. Filtro rápido de celda central
	var cell_pos := Vector2i(int(floor(pos_2d.x + 0.5)), int(floor(pos_2d.y + 0.5)))
	if is_vegetation_excluded(cell_pos):
		return true

	# 2. Vía rápida si se proveen candidatos acotados pre-consultados (BLOQUE 14)
	if scoped_lakes != null or scoped_rivers != null:
		if scoped_lakes != null and not scoped_lakes.is_empty():
			var lake_radius: float = 0.707 + bank_clearance
			var lake_radius_sq: float = lake_radius * lake_radius
			var min_lx: int = int(floor(pos_2d.x - lake_radius))
			var max_lx: int = int(ceil(pos_2d.x + lake_radius))
			var min_ly: int = int(floor(pos_2d.y - lake_radius))
			var max_ly: int = int(ceil(pos_2d.y + lake_radius))

			for ly in range(min_ly, max_ly + 1):
				for lx in range(min_lx, max_lx + 1):
					if is_lake(Vector2i(lx, ly)):
						var dx := pos_2d.x - (float(lx) + 0.5)
						var dy := pos_2d.y - (float(ly) + 0.5)
						if dx * dx + dy * dy < lake_radius_sq:
							return true

		if scoped_rivers != null and not scoped_rivers.is_empty():
			if scoped_rivers is PackedFloat32Array or (scoped_rivers is Array and (scoped_rivers[0] is float or scoped_rivers[0] is int)):
				var n: int = scoped_rivers.size()
				var idx: int = 0
				while idx < n:
					var min_x: float = scoped_rivers[idx]
					var max_x: float = scoped_rivers[idx + 1]
					var min_y: float = scoped_rivers[idx + 2]
					var max_y: float = scoped_rivers[idx + 3]
					if pos_2d.x < min_x or pos_2d.x > max_x or pos_2d.y < min_y or pos_2d.y > max_y:
						idx += 11
						continue
					var p0_x: float = scoped_rivers[idx + 4]
					var p0_y: float = scoped_rivers[idx + 5]
					var v_x: float = scoped_rivers[idx + 6]
					var v_y: float = scoped_rivers[idx + 7]
					var inv_l_sq: float = scoped_rivers[idx + 8]
					var dx: float = pos_2d.x - p0_x
					var dy: float = pos_2d.y - p0_y
					var t: float = clampf((dx * v_x + dy * v_y) * inv_l_sq, 0.0, 1.0)
					var proj_x: float = p0_x + v_x * t
					var proj_y: float = p0_y + v_y * t
					var cur_half_w: float = scoped_rivers[idx + 9] + scoped_rivers[idx + 10] * t
					var max_dist: float = cur_half_w + bank_clearance
					var pdx: float = pos_2d.x - proj_x
					var pdy: float = pos_2d.y - proj_y
					if pdx * pdx + pdy * pdy < max_dist * max_dist:
						return true
					idx += 11
			elif scoped_rivers[0] is Array:
				for s in scoped_rivers:
					if pos_2d.x < s[0] or pos_2d.x > s[1] or pos_2d.y < s[2] or pos_2d.y > s[3]:
						continue
					var dx: float = pos_2d.x - s[4]
					var dy: float = pos_2d.y - s[5]
					var t: float = clampf((dx * s[6] + dy * s[7]) * s[8], 0.0, 1.0)
					var proj_x: float = s[4] + s[6] * t
					var proj_y: float = s[5] + s[7] * t
					var cur_half_w: float = s[9] + s[10] * t
					var max_dist: float = cur_half_w + bank_clearance
					var pdx: float = pos_2d.x - proj_x
					var pdy: float = pos_2d.y - proj_y
					if pdx * pdx + pdy * pdy < max_dist * max_dist:
						return true
			elif scoped_rivers[0] is Dictionary:
				for seg in scoped_rivers:
					var seg_margin: float = float(seg.get("max_seg_half_w", 1.0)) + bank_clearance
					var min_x: float = float(seg.get("min_gx", minf(seg["p0_grid"].x, seg["p1_grid"].x))) - seg_margin
					var max_x: float = float(seg.get("max_gx", maxf(seg["p0_grid"].x, seg["p1_grid"].x))) + seg_margin
					var min_y: float = float(seg.get("min_gy", minf(seg["p0_grid"].y, seg["p1_grid"].y))) - seg_margin
					var max_y: float = float(seg.get("max_gy", maxf(seg["p0_grid"].y, seg["p1_grid"].y))) + seg_margin

					if pos_2d.x < min_x or pos_2d.x > max_x or pos_2d.y < min_y or pos_2d.y > max_y:
						continue

					var p0_x: float = float(seg.get("p0_gx", seg["p0_grid"].x))
					var p0_y: float = float(seg.get("p0_gy", seg["p0_grid"].y))
					var v_x: float = float(seg.get("v_gx", seg["v_grid"].x))
					var v_y: float = float(seg.get("v_gy", seg["v_grid"].y))
					var inv_l_sq: float = float(seg.get("inv_l_sq_grid", 1.0 / seg["l_sq_grid"] if seg["l_sq_grid"] > 0.00001 else 0.0))

					var dx: float = pos_2d.x - p0_x
					var dy: float = pos_2d.y - p0_y
					var t: float = clampf((dx * v_x + dy * v_y) * inv_l_sq, 0.0, 1.0)
					var proj_x: float = p0_x + v_x * t
					var proj_y: float = p0_y + v_y * t

					var half_w0: float = float(seg.get("half_w0", seg["w0"] * 0.5))
					var half_dw: float = float(seg.get("half_delta_w", (seg["w1"] - seg["w0"]) * 0.5))
					var cur_half_w: float = half_w0 + half_dw * t
					var max_dist: float = cur_half_w + bank_clearance

					var pdx: float = pos_2d.x - proj_x
					var pdy: float = pos_2d.y - proj_y
					if pdx * pdx + pdy * pdy < max_dist * max_dist:
						return true

	return false


	# 3. Vía rápida acelerada si el índice espacial está disponible
	if spatial_index != null:
		var candidate_lakes: Array[Dictionary] = spatial_index.query_lakes_near_point(pos_2d, 1.5 + bank_clearance)
		if not candidate_lakes.is_empty():
			var lake_radius: float = 0.707 + bank_clearance
			var lake_radius_sq: float = lake_radius * lake_radius
			var min_lx := int(floor(pos_2d.x - lake_radius))
			var max_lx := int(ceil(pos_2d.x + lake_radius))
			var min_ly := int(floor(pos_2d.y - lake_radius))
			var max_ly := int(ceil(pos_2d.y + lake_radius))

			for ly in range(min_ly, max_ly + 1):
				for lx in range(min_lx, max_lx + 1):
					if is_lake(Vector2i(lx, ly)):
						var dx := pos_2d.x - (float(lx) + 0.5)
						var dy := pos_2d.y - (float(ly) + 0.5)
						if dx * dx + dy * dy < lake_radius_sq:
							return true

		var candidate_segs: Array[Dictionary] = spatial_index.query_river_segments_near_point(pos_2d, 12.0 + bank_clearance)
		for seg in candidate_segs:
			var seg_margin: float = float(seg.get("max_seg_half_w", 1.0)) + bank_clearance
			var min_x: float = float(seg.get("min_gx", minf(seg["p0_grid"].x, seg["p1_grid"].x))) - seg_margin
			var max_x: float = float(seg.get("max_gx", maxf(seg["p0_grid"].x, seg["p1_grid"].x))) + seg_margin
			var min_y: float = float(seg.get("min_gy", minf(seg["p0_grid"].y, seg["p1_grid"].y))) - seg_margin
			var max_y: float = float(seg.get("max_gy", maxf(seg["p0_grid"].y, seg["p1_grid"].y))) + seg_margin

			if pos_2d.x < min_x or pos_2d.x > max_x or pos_2d.y < min_y or pos_2d.y > max_y:
				continue

			var p0_x: float = float(seg.get("p0_gx", seg["p0_grid"].x))
			var p0_y: float = float(seg.get("p0_gy", seg["p0_grid"].y))
			var v_x: float = float(seg.get("v_gx", seg["v_grid"].x))
			var v_y: float = float(seg.get("v_gy", seg["v_grid"].y))
			var inv_l_sq: float = float(seg.get("inv_l_sq_grid", 1.0 / seg["l_sq_grid"] if seg["l_sq_grid"] > 0.00001 else 0.0))

			var dx: float = pos_2d.x - p0_x
			var dy: float = pos_2d.y - p0_y
			var t: float = clampf((dx * v_x + dy * v_y) * inv_l_sq, 0.0, 1.0)
			var proj_x: float = p0_x + v_x * t
			var proj_y: float = p0_y + v_y * t

			var half_w0: float = float(seg.get("half_w0", seg["w0"] * 0.5))
			var half_dw: float = float(seg.get("half_delta_w", (seg["w1"] - seg["w0"]) * 0.5))
			var cur_half_w: float = half_w0 + half_dw * t
			var max_dist: float = cur_half_w + bank_clearance

			var pdx: float = pos_2d.x - proj_x
			var pdy: float = pos_2d.y - proj_y
			if pdx * pdx + pdy * pdy < max_dist * max_dist:
				return true


		return false

	# 3. Fallback geométrico tradicional sin índice espacial
	for lake in lakes:
		var min_pos: Vector2i = lake.get("min_pos", Vector2i.ZERO)
		var max_pos: Vector2i = lake.get("max_pos", Vector2i.ZERO)
		var bound_margin: float = 1.5 + bank_clearance
		if pos_2d.x < float(min_pos.x) - bound_margin or pos_2d.x > float(max_pos.x) + bound_margin or \
		   pos_2d.y < float(min_pos.y) - bound_margin or pos_2d.y > float(max_pos.y) + bound_margin:
			continue

		var lake_cells: Array = lake.get("cells", [])
		var lake_radius_sq: float = (0.707 + bank_clearance) * (0.707 + bank_clearance)
		for lp in lake_cells:
			var cell_center := Vector2(float(lp.x) + 0.5, float(lp.y) + 0.5)
			if pos_2d.distance_squared_to(cell_center) < lake_radius_sq:
				return true

	for river in rivers:
		var pts: Array = river.get("points", [])
		var widths: Array = river.get("widths", [])
		var n: int = pts.size()
		if n < 2:
			continue

		for i in range(n - 1):
			var p0_3d: Vector3 = pts[i]
			var p1_3d: Vector3 = pts[i + 1]
			var p0 := Vector2(p0_3d.x, p0_3d.z)
			var p1 := Vector2(p1_3d.x, p1_3d.z)

			var w0: float = float(widths[i]) if i < widths.size() else 1.0
			var w1: float = float(widths[i + 1]) if (i + 1) < widths.size() else w0
			var max_seg_half_w: float = maxf(w0, w1) * 0.5
			var seg_total_margin: float = max_seg_half_w + bank_clearance

			if pos_2d.x < minf(p0.x, p1.x) - seg_total_margin or pos_2d.x > maxf(p0.x, p1.x) + seg_total_margin or \
			   pos_2d.y < minf(p0.y, p1.y) - seg_total_margin or pos_2d.y > maxf(p0.y, p1.y) + seg_total_margin:
				continue

			var v := p1 - p0
			var l_sq: float = v.length_squared()
			var t: float = clampf((pos_2d - p0).dot(v) / l_sq, 0.0, 1.0) if l_sq > 0.00001 else 0.0
			var proj := p0 + v * t
			var cur_half_w: float = lerpf(w0, w1, t) * 0.5

			if pos_2d.distance_to(proj) < (cur_half_w + bank_clearance):
				return true

	return false
