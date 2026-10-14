extends SceneTree

const _ProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")
const _EvaluatorScript = preload("res://src/world_generator/poi/necropolis_influence_evaluator.gd")

func _init() -> void:
	print("Running test_necropolis_influence_evaluator...")
	var prof = _ProfileScript.new()
	var poi_center := Vector2(100.0, 100.0)
	var seed_val := 424242

	# 1. At center -> Clear zone, maximum influence (1.0)
	var eval_center = _EvaluatorScript.evaluate_point(poi_center, poi_center, seed_val, prof)
	assert(eval_center.influence == 1.0, "Center influence must be 1.0")
	assert(eval_center.is_cleared == true, "Center must be in cleared zone")
	assert(eval_center.zone == _EvaluatorScript.ZONE_CLEAR, "Zone must be ZONE_CLEAR")

	# 2. At 8m (funeral ground)
	var eval_funeral = _EvaluatorScript.evaluate_point(poi_center + Vector2(8.0, 0.0), poi_center, seed_val, prof)
	assert(eval_funeral.is_cleared == false, "8m must not be cleared")
	assert(eval_funeral.zone == _EvaluatorScript.ZONE_FUNERAL, "Zone at 8m must be ZONE_FUNERAL")
	assert(eval_funeral.influence >= 0.7, "Funeral influence must be high")

	# 3. Outside 50m -> Wild zone, influence 0.0
	var eval_far = _EvaluatorScript.evaluate_point(poi_center + Vector2(60.0, 0.0), poi_center, seed_val, prof)
	assert(eval_far.influence == 0.0, "Influence at 60m must be 0.0")
	assert(eval_far.zone == _EvaluatorScript.ZONE_WILD, "Zone at 60m must be ZONE_WILD")

	# 4. Organic border noise test (different angles at same distance have subtle perturbation)
	var eval_a = _EvaluatorScript.evaluate_point(poi_center + Vector2(20.0, 0.0), poi_center, seed_val, prof)
	var eval_b = _EvaluatorScript.evaluate_point(poi_center + Vector2(0.0, 20.0), poi_center, seed_val, prof)
	assert(eval_a.influence != eval_b.influence, "Noise perturbation must create organic non-circular borders")

	print("[PASS] test_necropolis_influence_evaluator")
	quit(0)
