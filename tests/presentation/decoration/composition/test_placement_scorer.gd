extends SceneTree

## Test suite para validar DecorationPlacementScorer.

const DecorationPlacementScorerScript = preload("res://src/presentation/decoration/composition/decoration_placement_scorer.gd")
const DecorationPlacementCandidateScript = preload("res://src/presentation/decoration/composition/decoration_placement_candidate.gd")
const DecorationOccupancyMapScript = preload("res://src/presentation/decoration/composition/decoration_occupancy_map.gd")
const CompositionRoleScript = preload("res://src/presentation/decoration/composition/composition_role.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_placement_scorer ---")
	print("==================================================================")

	var scorer := DecorationPlacementScorerScript.new()
	var occupancy := DecorationOccupancyMapScript.new()

	# 1. Candidato en el centro de la sala para rol PRIMARY
	var cand_center := DecorationPlacementCandidateScript.new()
	cand_center.cell = Vector2i(5, 5)
	cand_center.occupied_cells = [Vector2i(5, 5)]

	var room_center := Vector2i(5, 5)
	var door_cells: Array[Vector2i] = [Vector2i(1, 5)]

	var score_center = scorer.score_candidate(
		cand_center,
		CompositionRoleScript.Role.PRIMARY,
		occupancy,
		room_center,
		door_cells,
		1337
	)

	# 2. Candidato en la esquina lejos del centro para rol PRIMARY
	var cand_corner := DecorationPlacementCandidateScript.new()
	cand_corner.cell = Vector2i(1, 1)
	cand_corner.occupied_cells = [Vector2i(1, 1)]

	var score_corner = scorer.score_candidate(
		cand_corner,
		CompositionRoleScript.Role.PRIMARY,
		occupancy,
		room_center,
		door_cells,
		1337
	)

	assert(score_center > score_corner, "FAIL: PRIMARY role must prefer center candidate over corner candidate")

	# 3. Penalización por proximidad a puerta
	var cand_near_door := DecorationPlacementCandidateScript.new()
	cand_near_door.cell = Vector2i(2, 5)
	cand_near_door.occupied_cells = [Vector2i(2, 5)]

	var score_near_door = scorer.score_candidate(
		cand_near_door,
		CompositionRoleScript.Role.PRIMARY,
		occupancy,
		room_center,
		door_cells,
		1337
	)

	assert(score_center > score_near_door, "FAIL: Candidate near door must have lower score due to door proximity penalty")
	print("  [OK] DecorationPlacementScorer heuristics and score ordering verified.")

	print("==================================================================")
	print("[PASS] test_placement_scorer completado con 100% éxito!")
	print("==================================================================")
	quit(0)
