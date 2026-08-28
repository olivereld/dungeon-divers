extends SceneTree

const PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")
const PresentationRoomRoleScript = preload("res://src/presentation/architecture/presentation_room_role.gd")
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
		&"ruined_stone",
		&"dark_stone",
		&"stone_arch",
		&"stone",
		&"torch",
		&"crypt"
	)

	var ctx := PresentationRoomContextScript.new(
		0, Rect2i(0, 0, 10, 10), &"crypt", prof, PresentationRoomRoleScript.Role.COMBAT
	)
	assert(ctx.room_id == 0, "FAIL: room_id mismatch")
	assert(ctx.purpose == &"crypt", "FAIL: purpose mismatch")
	assert(ctx.profile.floor_style == &"ruined_stone", "FAIL: profile floor_style mismatch")
	assert(ctx.role == PresentationRoomRoleScript.Role.COMBAT, "FAIL: role mismatch")
	assert(ctx.role_name == "COMBAT", "FAIL: role_name mismatch")

	print("  [OK] PresentationRoomContext contract verified.")
	print("[PASS] test_presentation_room_context completed successfully.")
	quit(0)
