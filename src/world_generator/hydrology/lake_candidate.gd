class_name LakeCandidate
extends RefCounted

var id: int = -1
var seed_endpoint: RefCounted = null
var source_river_ids: Array[int] = []
var outflow_river_id: int = -1
var cells: Array[Vector2i] = []
var spillway_pos: Vector2i = Vector2i(-1, -1)
var spillway_height: float = INF
var water_height: float = 0.0
var min_pos: Vector2i = Vector2i(999999, 999999)
var max_pos: Vector2i = Vector2i(-999999, -999999)

func _init(p_id: int = -1, p_seed_endpoint: RefCounted = null) -> void:
	id = p_id
	seed_endpoint = p_seed_endpoint
	if p_seed_endpoint != null and "river_id" in p_seed_endpoint and p_seed_endpoint.river_id != -1:
		source_river_ids.append(p_seed_endpoint.river_id)

func add_cell(pos: Vector2i) -> void:
	cells.append(pos)
	min_pos.x = mini(min_pos.x, pos.x)
	min_pos.y = mini(min_pos.y, pos.y)
	max_pos.x = maxi(max_pos.x, pos.x)
	max_pos.y = maxi(max_pos.y, pos.y)

func to_dict() -> Dictionary:
	return {
		"id": id,
		"cells": cells,
		"spillway_pos": spillway_pos,
		"spillway_height": spillway_height,
		"water_height": water_height,
		"min_pos": min_pos,
		"max_pos": max_pos,
		"source_river_ids": source_river_ids,
		"outflow_river_id": outflow_river_id
	}
