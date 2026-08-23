extends SceneTree

## Test suite para validar el registro y resolución de perfiles por propósito (DecorationPurposeProfileRegistry).

const DecorationPurposeProfileRegistryScript = preload("res://src/presentation/decoration/composition/decoration_purpose_profile_registry.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const DecorationTagScript = preload("res://src/presentation/decoration/composition/decoration_tag.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_purpose_profile_registry ---")
	print("==================================================================")

	var registry := DecorationPurposeProfileRegistryScript.new()

	# 1. Validar Perfil de Tumba (TOMB)
	var tomb_profile = registry.get_profile_for_purpose(RoomPurposeScript.Type.TOMB)
	assert(tomb_profile != null, "FAIL: Tomb profile must be registered")
	assert(tomb_profile.intent != null, "FAIL: Tomb profile must have intent")
	assert(tomb_profile.intent.allowed_tags.has(DecorationTagScript.BURIAL), "FAIL: Tomb intent must allow BURIAL")
	assert(tomb_profile.intent.forbidden_tags.has(DecorationTagScript.SEATING), "FAIL: Tomb intent must forbid SEATING")
	assert(tomb_profile.templates.size() >= 1, "FAIL: Tomb profile must have at least 1 composition template")

	# 2. Validar Perfil de Entrada (ENTRANCE)
	var entry_profile = registry.get_profile_for_purpose(RoomPurposeScript.Type.ENTRANCE)
	assert(entry_profile != null, "FAIL: Entrance profile must be registered")
	assert(entry_profile.intent.player_clearance_level >= 2, "FAIL: Entrance must have high player clearance")

	# 3. Validar Perfil de Antecámara (ANTECHAMBER)
	var ante_profile = registry.get_profile_for_purpose(RoomPurposeScript.Type.ANTECHAMBER)
	assert(ante_profile != null, "FAIL: Antechamber profile must be registered")
	assert(ante_profile.intent.is_tag_allowed(DecorationTagScript.SEATING) == true, "FAIL: Antechamber allows seating benches")
	print("  [OK] DecorationPurposeProfileRegistry successfully mapped Crypt room purposes to declarative intents and templates.")

	print("==================================================================")
	print("[PASS] test_purpose_profile_registry completado con 100% éxito!")
	print("==================================================================")
	quit(0)
