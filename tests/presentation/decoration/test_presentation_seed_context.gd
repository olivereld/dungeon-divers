extends SceneTree

const PresentationSeedContextScript = preload("res://src/presentation/architecture/presentation_seed_context.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_presentation_seed_context ---")
	print("==================================================================")

	var ctx_1a = PresentationSeedContextScript.for_room(12345, 1)
	var ctx_1b = PresentationSeedContextScript.for_room(12345, 1)
	var ctx_2  = PresentationSeedContextScript.for_room(12345, 2)

	# 1. Determinismo exacto para la misma sala y semilla maestra
	assert(ctx_1a.composition_seed == ctx_1b.composition_seed, "FAIL: Composition seed must match")
	assert(ctx_1a.fixture_seed == ctx_1b.fixture_seed, "FAIL: Fixture seed must match")
	assert(ctx_1a.prop_seed == ctx_1b.prop_seed, "FAIL: Prop seed must match")
	assert(ctx_1a.variant_seed == ctx_1b.variant_seed, "FAIL: Variant seed must match")
	assert(ctx_1a.lighting_seed == ctx_1b.lighting_seed, "FAIL: Lighting seed must match")
	print("  [OK] Exact determinism across identical calls verified.")

	# 2. Independencia y no colisión entre subsistemas de la misma sala
	assert(ctx_1a.fixture_seed != ctx_1a.prop_seed, "FAIL: Fixture and Prop seeds must not collide")
	assert(ctx_1a.prop_seed != ctx_1a.composition_seed, "FAIL: Prop and Composition seeds must not collide")
	print("  [OK] Orthogonal subsystem seeds verified.")

	# 3. Diferenciación entre distintas salas
	assert(ctx_1a.composition_seed != ctx_2.composition_seed, "FAIL: Different rooms must have different seeds")
	assert(ctx_1a.prop_seed != ctx_2.prop_seed, "FAIL: Different rooms must have different prop seeds")
	print("  [OK] Room seed differentiation verified.")

	print("[PASS] test_presentation_seed_context completed successfully!")
	quit(0)
