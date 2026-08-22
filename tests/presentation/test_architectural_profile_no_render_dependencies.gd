extends SceneTree

const PresentationProfileResolverScript = preload("res://src/presentation/architecture/presentation_profile_resolver.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_architectural_profile_no_render_dependencies ---")
	print("==================================================================")

	var resolver := PresentationProfileResolverScript.new()
	for arch in range(5):
		for purpose in [0, 1, 2, 3, 10, 11, 20, 21, 22, 30, 31, 40, 42]:
			var prof = resolver.resolve(arch, purpose)
			assert(prof != null)
			assert(typeof(prof.floor_style) == TYPE_INT)
			assert(typeof(prof.wall_style) == TYPE_INT)
			assert(typeof(prof.door_style) == TYPE_INT)
			assert(typeof(prof.stairs_style) == TYPE_INT)
			assert(typeof(prof.fixture_style) == TYPE_INT)
			assert(typeof(prof.decoration_palette) == TYPE_INT)

	print("  [OK] Zero rendering dependencies verified in headless execution.")
	print("[PASS] test_architectural_profile_no_render_dependencies completed successfully.")
	quit(0)
