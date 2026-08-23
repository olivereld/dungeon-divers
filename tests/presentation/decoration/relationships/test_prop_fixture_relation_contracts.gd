extends SceneTree

const _PropFixtureRelationScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relation.gd")
const _PropFixtureRelationPlacementScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relation_placement.gd")
const _PropFixtureRelationTypeScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relation_type.gd")
const _PropFixtureRelationshipProfileScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relationship_profile.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")

func _init() -> void:
	print("--- Running test_prop_fixture_relation_contracts ---")

	# 1. Test creation of relations
	var rel_candle := _PropFixtureRelationScript.new(
		&"sarcophagus_ornate",
		[_FixtureStyleScript.Type.CANDLE_CLUSTER, _FixtureStyleScript.Type.CANDLE_HOLDER],
		_PropFixtureRelationPlacementScript.Placement.NEAR,
		1, 2, &"sarcophagus_candles", 1.0, 2.0
	)

	var rel_hanging := _PropFixtureRelationScript.new(
		&"sarcophagus_ornate",
		[_FixtureStyleScript.Type.LANTERN],
		_PropFixtureRelationPlacementScript.Placement.ABOVE,
		1, 1, &"sarcophagus_hanging"
	)

	var rel_bench := _PropFixtureRelationScript.new(
		&"wood_bench",
		[],
		_PropFixtureRelationPlacementScript.Placement.NEAR,
		0, 0, &"bench_no_lights", 1.0, 2.0, 1.0,
		[_FixtureStyleScript.Type.BRAZIER, _FixtureStyleScript.Type.CANDLE_CLUSTER] # Forbidden
	)

	var profile := _PropFixtureRelationshipProfileScript.new(&"crypt_relations", [
		rel_candle, rel_hanging, rel_bench
	])

	# 2. Test query by prop
	var sarc_relations = profile.get_relations_for_prop(&"sarcophagus_ornate")
	assert(sarc_relations.size() == 2, "Must return 2 relations for sarcophagus")
	print("  [OK] Profile returns matching relations for prop ID")

	# 3. Test forbidden query
	assert(profile.is_fixture_forbidden(&"wood_bench", _FixtureStyleScript.Type.BRAZIER, &"iron_brazier") == true, "Brazier must be forbidden for wood_bench")
	assert(profile.is_fixture_forbidden(&"sarcophagus_ornate", _FixtureStyleScript.Type.BRAZIER, &"iron_brazier") == false, "Brazier is not forbidden for sarcophagus")
	print("  [OK] Forbidden fixtures validated correctly")

	print("[PASS] test_prop_fixture_relation_contracts completed!")
	quit(0)
