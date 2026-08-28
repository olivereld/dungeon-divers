extends SceneTree

const DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_room_purpose_to_decoration_palette ---")
	print("==================================================================")

	var dec_resolver := DecorationPaletteResolverScript.new()
	var prof := ArchitecturalPresentationProfileScript.new()

	var archetypes: Array[StringName] = [
		&"necropolis",
		&"temple",
		&"fortress",
		&"mine"
	]

	var purposes: Array[StringName] = [
		&"tomb",
		&"entrance",
		&"sanctum",
		&"crypt"
	]

	for arch in archetypes:
		for purp in purposes:
			var dec_palette = dec_resolver.resolve_palette_by_id(arch, purp, prof)
			assert(dec_palette != null, "FAIL: DecorationPalette cannot be null for %s:%s" % [str(arch), str(purp)])
			assert(dec_palette.fixtures != null, "FAIL: FixturePalette cannot be null for %s:%s" % [str(arch), str(purp)])
			assert(not dec_palette.fixtures.entries.is_empty(), "FAIL: Entries cannot be empty for %s:%s" % [str(arch), str(purp)])

	print("  [OK] DecorationPalette resolution verified for all archetype and room purpose combinations.")
	print("[PASS] test_room_purpose_to_decoration_palette completed successfully!")
	quit(0)
