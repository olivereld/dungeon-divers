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

