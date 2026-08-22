extends SceneTree

const PresentationRoomRoleScript = preload("res://src/presentation/architecture/presentation_room_role.gd")
const PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")
const ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_presentation_room_role ---")
	print("==================================================================")

	assert(PresentationRoomRoleScript.Role.START == 0, "FAIL: START must be 0")
	assert(PresentationRoomRoleScript.Role.BOSS == 4, "FAIL: BOSS must be 4")
	assert(PresentationRoomRoleScript.to_name(PresentationRoomRoleScript.Role.START) == "START")

	var prof := ArchitecturalPresentationProfileScript.new()
	var ctx := PresentationRoomContextScript.new(
		1, Rect2i(0, 0, 6, 6), RoomPurposeScript.Type.CRYPT, prof, PresentationRoomRoleScript.Role.COMBAT
	)
	assert(ctx.role == PresentationRoomRoleScript.Role.COMBAT)
	assert(ctx.role_name == "COMBAT")

	print("  [OK] PresentationRoomRole enum and name helpers verified.")
	print("  [OK] PresentationRoomContext role typing verified.")
	print("[PASS] test_presentation_room_role completed successfully.")
	quit(0)
