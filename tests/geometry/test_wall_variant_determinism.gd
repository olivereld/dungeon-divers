extends SceneTree

const _WallSectionScript = preload("res://src/geometry_generator/data/wall_section.gd")
const _WallVariantPolicyScript = preload("res://src/geometry_generator/data/wall_variant_policy.gd")
const _WallVariantResolverScript = preload("res://src/geometry_generator/variants/wall_variant_resolver.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_wall_variant_determinism ---")
	print("==================================================================")

	var resolver := _WallVariantResolverScript.new()
	var policy := _WallVariantPolicyScript.new(
		true,
		[&"normal", &"cracked", &"damaged"],
		{ &"normal": 70.0, &"cracked": 20.0, &"damaged": 10.0 }
	)

	var sec1 := _WallSectionScript.new(1, 10, [Vector2i(0, 0), Vector2i(4, 0)], 5, &"normal", false)

	# 1. Determinismo estricto: misma semilla y sección da exactamente el mismo resultado
	var v_run1 = resolver.resolve_section_variant(sec1, policy, 12345)
	for i in range(100):
		var v_test = resolver.resolve_section_variant(sec1, policy, 12345)
		assert(v_test == v_run1, "FAIL: Variant resolution must be 100% deterministic (got " + str(v_test) + " vs " + str(v_run1) + ")")

	# 2. Distribución estadística sobre 1000 secciones
	var counts: Dictionary = { &"normal": 0, &"cracked": 0, &"damaged": 0 }
	for s_idx in range(1000):
		var s := _WallSectionScript.new(s_idx, 10, [Vector2i(s_idx * 4, 0), Vector2i((s_idx + 1) * 4, 0)], 5, &"normal", false)
		var v = resolver.resolve_section_variant(s, policy, 1337)
		counts[v] = counts.get(v, 0) + 1

	assert(counts[&"normal"] > counts[&"cracked"], "FAIL: normal should have higher count than cracked")
	assert(counts[&"cracked"] > 0, "FAIL: cracked should appear in 1000 samples")
	assert(counts[&"damaged"] > 0, "FAIL: damaged should appear in 1000 samples")

	print("  [OK] Strict determinism verified.")
	print("  [OK] Statistical distribution verified: normal=%d, cracked=%d, damaged=%d." % [counts[&"normal"], counts[&"cracked"], counts[&"damaged"]])
	print("==================================================================")
	print("[PASS] test_wall_variant_determinism passed successfully!")
	print("==================================================================")
	quit(0)
