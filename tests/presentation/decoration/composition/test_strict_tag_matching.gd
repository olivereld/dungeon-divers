extends SceneTree

const _PlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const _RuleScript = preload("res://src/presentation/decoration/composition/decoration_composition_rule.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const _PropPaletteEntryScript = preload("res://src/presentation/props/prop_palette_entry.gd")
const _DecorationTagScript = preload("res://src/presentation/decoration/composition/decoration_tag.gd")
const _DecorationRoomIntentScript = preload("res://src/presentation/decoration/composition/decoration_room_intent.gd")
const _PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")

const _DecorationRoleScript = preload("res://src/presentation/decoration/decoration_role.gd")

func _init() -> void:
	print("--- Running test_strict_tag_matching ---")

	# Setup: three props with different tags
	var sarc := _PropStyleScript.new(&"sarcophagus_closed", _PropStyleScript.Type.SARCOPHAGUS,
		_PropPlacementModeScript.Mode.CENTER, 0, null, &"sarcophagus", {},
		_DecorationRoleScript.Role.FOCAL,
		[_DecorationTagScript.BURIAL, _DecorationTagScript.FOCAL])
	var urn := _PropStyleScript.new(&"urn_pedestal", _PropStyleScript.Type.URN,
		_PropPlacementModeScript.Mode.FLOOR, 0, null, &"urn", {},
		_DecorationRoleScript.Role.SUPPORT,
		[_DecorationTagScript.BURIAL])
	var bench := _PropStyleScript.new(&"bench_stone", _PropStyleScript.Type.BENCH,
		_PropPlacementModeScript.Mode.WALL, 0, null, &"bench", {},
		_DecorationRoleScript.Role.SUPPORT,
		[_DecorationTagScript.SEATING])

	var entries: Array = [
		_PropPaletteEntryScript.new(sarc, 1.0),
		_PropPaletteEntryScript.new(urn, 1.0),
		_PropPaletteEntryScript.new(bench, 1.0),
	]

	# Test 1: required_tags = [BURIAL, FOCAL] should match sarcophagus ONLY (AND logic)
	var rule1 := _RuleScript.new()
	rule1.required_tags = [_DecorationTagScript.BURIAL, _DecorationTagScript.FOCAL]
	var matched1 = _PlannerScript._find_matching_palette_entries(entries, rule1, null)
	assert(matched1.size() == 1, "Required [BURIAL, FOCAL] should match only sarcophagus, got %d" % matched1.size())
	assert(matched1[0].style.id == &"sarcophagus_closed", "Should be sarcophagus")
	print("  [OK] required_tags AND logic works")

	# Test 2: required_tags = [BURIAL] should match sarcophagus AND urn (both have BURIAL)
	var rule2 := _RuleScript.new()
	rule2.required_tags = [_DecorationTagScript.BURIAL]
	var matched2 = _PlannerScript._find_matching_palette_entries(entries, rule2, null)
	assert(matched2.size() == 2, "Required [BURIAL] should match 2, got %d" % matched2.size())
	print("  [OK] required_tags single tag works")

	# Test 3: preferred_tags boost is additive; entries lacking preferred still match if required is met
	var rule3 := _RuleScript.new()
	rule3.required_tags = [_DecorationTagScript.BURIAL]
	rule3.preferred_tags = [_DecorationTagScript.FOCAL]
	var matched3 = _PlannerScript._find_matching_palette_entries(entries, rule3, null)
	assert(matched3.size() == 2, "Preferred should NOT exclude; got %d" % matched3.size())
	print("  [OK] preferred_tags are non-exclusive")

	# Test 4: forbidden_tags on RULE excludes entries
	var rule4 := _RuleScript.new()
	rule4.required_tags = [_DecorationTagScript.BURIAL]
	rule4.forbidden_tags = [_DecorationTagScript.FOCAL]
	var matched4 = _PlannerScript._find_matching_palette_entries(entries, rule4, null)
	assert(matched4.size() == 1, "forbidden [FOCAL] should exclude sarcophagus, got %d" % matched4.size())
	assert(matched4[0].style.id == &"urn_pedestal")
	print("  [OK] rule-level forbidden_tags works")

	# Test 5: NO fallback — if no tags match, result is EMPTY
	var rule5 := _RuleScript.new()
	rule5.required_tags = [&"nonexistent_tag"]
	var matched5 = _PlannerScript._find_matching_palette_entries(entries, rule5, null)
	assert(matched5.size() == 0, "No match should return empty, got %d" % matched5.size())
	print("  [OK] No fallback — empty when no match")

	# Test 6: empty required_tags + empty target_tags = accept all (unconstrained rule)
	var rule6 := _RuleScript.new()
	var matched6 = _PlannerScript._find_matching_palette_entries(entries, rule6, null)
	assert(matched6.size() == 3, "Unconstrained rule should accept all, got %d" % matched6.size())
	print("  [OK] Unconstrained rule accepts all entries")

	# Test 7: legacy target_tags still works (backward compat via OR, but only when required_tags is empty)
	var rule7 := _RuleScript.new()
	rule7.target_tags = [_DecorationTagScript.SEATING]
	var matched7 = _PlannerScript._find_matching_palette_entries(entries, rule7, null)
	assert(matched7.size() == 1, "Legacy target_tags should match bench only, got %d" % matched7.size())
	assert(matched7[0].style.id == &"bench_stone")
	print("  [OK] Legacy target_tags backward compat works")

	print("[PASS] test_strict_tag_matching completed!")
	quit(0)
