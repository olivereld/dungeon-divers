extends SceneTree

const PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")
const ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_presentation_room_context ---")
	print("==================================================================")

	var prof := ArchitecturalPresentationProfileScript.new(
		ArchitecturalStyleScript.FloorStyle.RUINED_STONE,
		ArchitecturalStyleScript.WallStyle.DARK_STONE,
		ArchitecturalStyleScript.DoorStyle.STONE_ARCH,
		ArchitecturalStyleScript.StairsStyle.STONE,
		ArchitecturalStyleScript.FixtureStyle.TORCH,
		ArchitecturalStyleScript.DecorationPalette.CRYPT
	)

	var ctx := PresentationRoomContextScript.new(0, Rect2i(0, 0, 10, 10), RoomPurposeScript.Type.CRYPT, prof, "COMBAT")
	assert(ctx.room_id == 0, "FAIL: room_id mismatch")
	assert(ctx.purpose == RoomPurposeScript.Type.CRYPT, "FAIL: purpose mismatch")
	assert(ctx.profile.floor_style == ArchitecturalStyleScript.FloorStyle.RUINED_STONE, "FAIL: profile floor_style mismatch")
	assert(ctx.gameplay_role == "COMBAT", "FAIL: gameplay_role mismatch")

	print("  [OK] PresentationRoomContext contract verified.")
	print("[PASS] test_presentation_room_context completed successfully.")
	quit(0)
