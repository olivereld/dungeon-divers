extends SceneTree

const _PresentationGeometryPartitionScript = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")
const _FixtureAnchorResolverScript = preload("res://src/presentation/fixtures/fixture_anchor_resolver.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_corridor_torch_profile_authority ---")
	print("==================================================================")

	var loader = _ProfileLoaderScript.new()
	var arch_bundle = loader.load_full_archetype_bundle("mausoleum")
	assert(arch_bundle != null, "FAIL: Mausoleum bundle is null")
	assert(arch_bundle.archetype != null, "FAIL: Mausoleum archetype is null")
	assert(arch_bundle.archetype.corridor_lighting != null, "FAIL: Corridor lighting in mausoleum is null")

	var corr_light = arch_bundle.archetype.corridor_lighting
	assert(corr_light.wall != null, "FAIL: Corridor wall slot is null")
	assert(corr_light.wall.allowed.has(&"wall_torch"), "FAIL: Corridor allowed fixtures must contain wall_torch")
	print("  [OK] Corridor lighting correctly loaded from mausoleum archetype.")

	var l_set = corr_light.resolve_settings_for_fixture(&"wall", &"wall_torch", Color.WHITE, 1.0, 4.0)
	print("  Corridor light color: ", l_set.color, " energy: ", l_set.energy, " range: ", l_set.light_range)
	assert(l_set.color == Color("#D6B36A"), "FAIL: Light color must match #D6B36A")
	assert(is_equal_approx(l_set.energy, 0.90), "FAIL: Light energy must match 0.90")
	assert(is_equal_approx(l_set.light_range, 4.5), "FAIL: Light range must match 4.5")

	print("  [OK] Corridor light authority settings verified.")
	print("==================================================================")
	print("[PASS] test_corridor_torch_profile_authority passed successfully!")
	print("==================================================================")
	quit(0)
