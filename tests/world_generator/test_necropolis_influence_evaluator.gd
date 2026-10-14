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

	# 5. Frontal corridor clearance test
	# Orientation 0: Vector3.FORWARD is (0, 0, -1), so forward in 2D is (0, -1)
	var pos_corridor := poi_center + Vector2(0.0, -6.0)
	assert(_EvaluatorScript.is_in_frontal_corridor(pos_corridor, poi_center, 0.0) == true, "Point in front must be inside corridor")
	var pos_behind := poi_center + Vector2(0.0, 6.0)
	assert(_EvaluatorScript.is_in_frontal_corridor(pos_behind, poi_center, 0.0) == false, "Point behind must not be inside corridor")
	var eval_corridor = _EvaluatorScript.evaluate_point(pos_corridor, poi_center, seed_val, prof, 0.0)
	assert(eval_corridor.is_cleared == true, "Corridor point must be cleared")

	# 6. Stepped survival curve tests
	assert(_EvaluatorScript.compute_survival_chance(4.0) == 0.0, "Crypt core must have 0% survival")
	assert(_EvaluatorScript.compute_survival_chance(8.0) >= 0.10 and _EvaluatorScript.compute_survival_chance(8.0) <= 0.20, "Ring 2 must have 10-20% survival")
	assert(_EvaluatorScript.compute_survival_chance(15.0) >= 0.30 and _EvaluatorScript.compute_survival_chance(15.0) <= 0.50, "Ring 3 (10-18m) must have 30-50% survival")
	assert(_EvaluatorScript.compute_survival_chance(22.0) >= 0.60 and _EvaluatorScript.compute_survival_chance(22.0) <= 0.80, "Ring 3 (18-28m) must have 60-80% survival")
	assert(_EvaluatorScript.compute_survival_chance(35.0) == 1.0, "Outside 28m must have 100% survival")

	print("[PASS] test_necropolis_influence_evaluator")
	quit(0)
