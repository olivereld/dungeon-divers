extends SceneTree

const _PolicyScript = preload("res://src/dungeon_generator/profiles/profile_floor_variant_policy.gd")

func _init() -> void:
	print("--- Running test_floor_variant_data ---")
	var p = _PolicyScript.new(
		true,
		&"catacomb_dirt",
		80.0,
		[
			{ "style": &"ruined_stone", "weight": 15.0 },
			{ "style": &"cracked_dirt", "weight": 5.0 }
		]
	)
	assert(p.enabled, "Policy must be enabled")
	assert(p.base_style == &"catacomb_dirt", "Base style mismatch")
	assert(p.get_total_weight() == 100.0, "Total weight should be 100.0")
	print("  [OK] ProfileFloorVariantPolicy data contract verified")
	print("[PASS] test_floor_variant_data passed!")
	quit(0)
