extends SceneTree

## Test suite para validar la intención semántica y prohibiciones de sala (DecorationRoomIntent).

const DecorationRoomIntentScript = preload("res://src/presentation/decoration/composition/decoration_room_intent.gd")
const DecorationTagScript = preload("res://src/presentation/decoration/composition/decoration_tag.gd")
const DecorationRoomZoneScript = preload("res://src/presentation/decoration/composition/decoration_room_zone.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_decoration_room_intent ---")
	print("==================================================================")

	# 1. Crear intención de Tumba Sagrada (TOMB)
	var intent := DecorationRoomIntentScript.new()
	intent.focal_zone = DecorationRoomZoneScript.ZoneType.FOCAL
	intent.symmetry_required = true
	intent.player_clearance_level = 2
	intent.lighting_budget = 4.0
	intent.allowed_tags = [DecorationTagScript.BURIAL, DecorationTagScript.FOCAL, DecorationTagScript.LIGHTING]
	intent.forbidden_tags = [DecorationTagScript.STORAGE, DecorationTagScript.SEATING]

	# 2. Validar filtrado de tags
	assert(intent.is_tag_allowed(DecorationTagScript.BURIAL) == true, "FAIL: BURIAL tag must be allowed")
	assert(intent.is_tag_allowed(DecorationTagScript.FOCAL) == true, "FAIL: FOCAL tag must be allowed")
	assert(intent.is_tag_allowed(DecorationTagScript.STORAGE) == false, "FAIL: STORAGE tag must be rejected by forbidden list")
	assert(intent.is_tag_allowed(DecorationTagScript.SEATING) == false, "FAIL: SEATING tag must be rejected by forbidden list")
	assert(intent.is_tag_allowed(&"random_unlisted_tag") == false, "FAIL: Unlisted tag must be rejected when allowed_tags is specified")

	# 3. Validar zonas permitidas
	assert(intent.can_place_in_zone(DecorationRoomZoneScript.ZoneType.FOCAL) == true, "FAIL: FOCAL zone is allowed")
	assert(intent.can_place_in_zone(DecorationRoomZoneScript.ZoneType.ENTRY) == false, "FAIL: ENTRY zone should be blocked for decorative props")
	print("  [OK] DecorationRoomIntent tags, forbidden lists, and zone clearance verified.")

	print("==================================================================")
	print("[PASS] test_decoration_room_intent completado con 100% éxito!")
	print("==================================================================")
	quit(0)
