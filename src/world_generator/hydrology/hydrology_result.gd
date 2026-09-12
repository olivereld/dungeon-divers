class_name HydrologyResult
extends RefCounted

## Holds the computed hydrological features: planar depression lakes and downhill rivers.
## Completely decoupled from WorldCell and TerrainStage.

## Map from Vector2i grid position to cell hydrological data:
## {
##   "type": "lake" | "river",
##   "water_height": float,
##   "terrain_height": float,
##   "depth": float,
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

## Debug maps (Vector2i -> float or Vector2) for visual analysis:
## "noise", "lake_potential", "river_potential", "drainage", "flow_dir", "flow_vector", "flow_to", "upstream", "basins"
var debug_layers: Dictionary = {}

func is_water(pos: Vector2i) -> bool:
	return water_cells.has(pos)

func is_lake(pos: Vector2i) -> bool:
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

enum HydrologyZone {
	DRY = 0,
	RIVER_WATER = 1,
	RIVER_BANK = 2,
	LAKE_WATER = 3,
	LAKE_BANK = 4,
}

## Mapeo por celda Vector2i -> HydrologyZone (int)
var zones: Dictionary = {}

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
func is_position_excluded(pos_2d: Vector2, bank_clearance: float = 1.0) -> bool:
	# 1. Filtro rápido de celda central
	var cell_pos := Vector2i(int(floor(pos_2d.x + 0.5)), int(floor(pos_2d.y + 0.5)))
	if is_vegetation_excluded(cell_pos):
		return true

	# 2. Comprobación geométrica contra lagos (radio celda + margen)
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

	# 3. Comprobación geométrica continua contra ríos (segmentos de polilínea + ancho + margen)
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

