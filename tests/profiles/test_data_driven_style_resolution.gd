extends SceneTree

## Test para Task 3: Resolución de paletas y estilos arquitectónicos por ID dinámico.

func _init() -> void:
	print("--- Running test_data_driven_style_resolution (Task 3) ---")
	var palette_resolver_script = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
	var profile_resolver_script = preload("res://src/presentation/architecture/presentation_profile_resolver.gd")

	var palette_resolver = palette_resolver_script.new()
	var profile_resolver = profile_resolver_script.new()

	# 1. Test resolve_palette con StringName
	var pal_necro = palette_resolver.resolve_palette_by_id(&"necropolis", 0, null)
	assert(pal_necro != null, "Must resolve palette for &\"necropolis\"")
	assert(pal_necro.fixtures != null and pal_necro.props != null, "Palette must have fixtures and props")

	var pal_mine = palette_resolver.resolve_palette_by_id(&"mine", 0, null)
	assert(pal_mine != null, "Must resolve palette for &\"mine\"")
	print("  [OK] DecorationPaletteResolver.resolve_palette_by_id() works dynamically.")

	# 2. Test resolve_profile_for_archetype con StringName
	var prof_necro = profile_resolver.resolve_profile_for_archetype(&"necropolis", 0)
	assert(prof_necro != null, "Must resolve presentation profile for &\"necropolis\"")

	var prof_temple = profile_resolver.resolve_profile_for_archetype(&"temple", 0)
	assert(prof_temple != null, "Must resolve presentation profile for &\"temple\"")
	print("  [OK] PresentationProfileResolver.resolve_profile_for_archetype() works dynamically.")

	print("\n==================================================================")
	print("[PASS] test_data_driven_style_resolution passed 100%!")
	print("==================================================================\n")
	quit(0)
