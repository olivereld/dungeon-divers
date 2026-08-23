class_name DecorationRelationshipSolver
extends RefCounted

## Motor matemático para el cálculo y satisfacción de relaciones espaciales y simetría.

const _DecorationRelationshipScript = preload("res://src/presentation/decoration/composition/decoration_relationship.gd")

func find_symmetric_positions(
	primary_cell: Vector2i,
	room_center: Vector2i,
	room_geom
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if room_geom == null:
		return result

	var floor_map: Dictionary = {}
	for fc in room_geom.floor_cells:
		floor_map[fc] = true

	# 1. Simetría sobre el eje horizontal (espejo en X)
	var delta_x = primary_cell.x - room_center.x
	var symm_x = Vector2i(room_center.x - delta_x, primary_cell.y)
	if floor_map.has(symm_x) and symm_x != primary_cell:
		result.append(symm_x)

	# 2. Simetría sobre el eje vertical (espejo en Y)
	var delta_y = primary_cell.y - room_center.y
	var symm_y = Vector2i(primary_cell.x, room_center.y - delta_y)
	if floor_map.has(symm_y) and symm_y != primary_cell and not result.has(symm_y):
		result.append(symm_y)

	return result

func find_nearby_positions(
	target_cell: Vector2i,
	min_dist: int,
	max_dist: int,
	room_geom
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if room_geom == null:
		return result

	var floor_map: Dictionary = {}
	for fc in room_geom.floor_cells:
		floor_map[fc] = true

	for dx in range(-max_dist, max_dist + 1):
		for dy in range(-max_dist, max_dist + 1):
			var dist = absi(dx) + absi(dy)
			if dist >= min_dist and dist <= max_dist:
				var neighbor = target_cell + Vector2i(dx, dy)
				if floor_map.has(neighbor):
					result.append(neighbor)
	return result

func find_adjacent_positions(target_cell: Vector2i, room_geom) -> Array[Vector2i]:
	return find_nearby_positions(target_cell, 1, 1, room_geom)

func is_relationship_satisfied(
	relation_type: int,
	candidate_cell: Vector2i,
	reference_cell: Vector2i,
	room_geom
) -> bool:
	var dist = absi(candidate_cell.x - reference_cell.x) + absi(candidate_cell.y - reference_cell.y)

	match relation_type:
		_DecorationRelationshipScript.Relation.NEAR:
			return dist >= 1 and dist <= 3
		_DecorationRelationshipScript.Relation.ADJACENT:
			return dist == 1
		_DecorationRelationshipScript.Relation.KEEP_AWAY_FROM:
			return dist >= 3
		_DecorationRelationshipScript.Relation.CENTERED_ON:
			return dist == 0
		_:
			return true
