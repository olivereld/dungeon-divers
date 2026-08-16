extends SceneTree

func _init() -> void:
	print("--- Running test_winnability (stress test) ---")
	var grammar := MissionGrammar.new()
	var solver := WinnabilitySolver.new()
	var config := DungeonConfig.new()
	config.mission_depth = 6
	config.max_grammar_iterations = 25
	config.lock_key_frequency = 0.4
	config.optional_branch_chance = 0.3

	var total_runs: int = 200
	var success_count: int = 0

	for i in range(total_runs):
		var graph := grammar.generate(config, 1000 + i)
		var val: WinnabilitySolver.ValidationResult = solver.validate(graph)
		if val.is_winnable:
			success_count += 1
		else:
			print("FAILED seed: ", 1000 + i, " info: ", val.to_string())

	var success_rate: float = (float(success_count) / float(total_runs)) * 100.0
	print("Winnability results: %d / %d (%.2f%%)" % [success_count, total_runs, success_rate])
	assert(success_count == total_runs, "Winnability should be 100% for generated mission graphs")

	print("[PASS] test_winnability succeeded.")
	quit(0)
