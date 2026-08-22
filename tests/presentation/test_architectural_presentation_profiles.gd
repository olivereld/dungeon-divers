extends SceneTree

const ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")
const ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_architectural_presentation_profiles ---")
	print("==================================================================")

	# 1. Verificar Enums de Estilo
	assert(ArchitecturalStyleScript.FloorStyle.RUINED_STONE != null)
	assert(ArchitecturalStyleScript.WallStyle.DARK_STONE != null)
	assert(ArchitecturalStyleScript.DoorStyle.STONE_ARCH != null)
	assert(ArchitecturalStyleScript.StairsStyle.STONE != null)
	assert(ArchitecturalStyleScript.FixtureStyle.BRAZIER != null)
	assert(ArchitecturalStyleScript.DecorationPalette.CRYPT != null)

	assert(ArchitecturalStyleScript.floor_to_name(ArchitecturalStyleScript.FloorStyle.RUINED_STONE) == "RUINED_STONE")
	assert(ArchitecturalStyleScript.wall_to_name(ArchitecturalStyleScript.WallStyle.DARK_STONE) == "DARK_STONE")

	# 2. Verificar Contrato ArchitecturalPresentationProfile
	var profile := ArchitecturalPresentationProfileScript.new(
		ArchitecturalStyleScript.FloorStyle.RUINED_STONE,
		ArchitecturalStyleScript.WallStyle.DARK_STONE,
		ArchitecturalStyleScript.DoorStyle.STONE_ARCH,
		ArchitecturalStyleScript.StairsStyle.STONE,
		ArchitecturalStyleScript.FixtureStyle.TORCH,
		ArchitecturalStyleScript.DecorationPalette.CRYPT
	)

	assert(profile.floor_style == ArchitecturalStyleScript.FloorStyle.RUINED_STONE)
	assert(profile.wall_style == ArchitecturalStyleScript.WallStyle.DARK_STONE)
	assert(profile.door_style == ArchitecturalStyleScript.DoorStyle.STONE_ARCH)
	assert(profile.stairs_style == ArchitecturalStyleScript.StairsStyle.STONE)
	assert(profile.fixture_style == ArchitecturalStyleScript.FixtureStyle.TORCH)
	assert(profile.decoration_palette == ArchitecturalStyleScript.DecorationPalette.CRYPT)

	var debug_str = profile.to_debug_string()
	assert(debug_str.contains("Floor: RUINED_STONE"))
	assert(debug_str.contains("Wall: DARK_STONE"))

	print("  [OK] ArchitecturalStyle enums and name helpers verified.")
	print("  [OK] ArchitecturalPresentationProfile contract verified.")
	print("[PASS] test_architectural_presentation_profiles completed successfully.")
	quit(0)
