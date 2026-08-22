extends SceneTree

## Test suite para validar DecorationPlacementCandidate y DecorationOrientationResolver.

const DecorationPlacementCandidateScript = preload("res://src/presentation/decoration/composition/decoration_placement_candidate.gd")
const DecorationOrientationResolverScript = preload("res://src/presentation/decoration/composition/decoration_orientation_resolver.gd")
const DecorationOrientationModeScript = preload("res://src/presentation/decoration/composition/decoration_orientation_mode.gd")
const PropAnchorScript = preload("res://src/presentation/props/prop_anchor.gd")
const PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_candidate_and_orientation ---")
	print("==================================================================")

	# 1. Validar DecorationPlacementCandidate
	var candidate := DecorationPlacementCandidateScript.new()
	candidate.style_id = &"gothic_bench"
	candidate.cell = Vector2i(2, 3)
	candidate.rotation_y = 180.0
	candidate.occupied_cells = [Vector2i(2, 3)]
	candidate.score = 85.0
	assert(candidate.is_valid() == true, "FAIL: Candidate with no violations is valid")
	candidate.violations.append(&"CANNOT_OVERLAP")
	assert(candidate.is_valid() == false, "FAIL: Candidate with violations is invalid")
	print("  [OK] DecorationPlacementCandidate data container verified.")

	# 2. Validar DecorationOrientationResolver
	var resolver := DecorationOrientationResolverScript.new()

	# Muro Norte (vector hacia abajo / sur = 0° en Godot mirando hacia +Z)
	var anchor_north := PropAnchorScript.new(
		PropPlacementModeScript.Mode.WALL,
		Vector2i(3, 1),
		Vector3(6.0, 0.0, 2.0),
		0.0 # rotación del anchor
	)
	anchor_north.wall_side = Vector2i(0, 1) # normal hacia el interior de la sala (+Y en cuadrícula)

	var rot_face_room = resolver.resolve_rotation(anchor_north, DecorationOrientationModeScript.Mode.FACE_ROOM)
	assert(rot_face_room == 0.0, "FAIL: Muro Norte orientado al interior debe ser 0°")

	# Muro Sur (normal hacia el interior de la sala = -Y en cuadrícula / 180°)
	var anchor_south := PropAnchorScript.new(
		PropPlacementModeScript.Mode.WALL,
		Vector2i(3, 8),
		Vector3(6.0, 0.0, 16.0),
		180.0
	)
	anchor_south.wall_side = Vector2i(0, -1)
	var rot_south = resolver.resolve_rotation(anchor_south, DecorationOrientationModeScript.Mode.FACE_ROOM)
	assert(rot_south == 180.0, "FAIL: Muro Sur orientado al interior debe ser 180°")

	# Muro Este (normal hacia interior = -X / -90° o 270°)
	var anchor_east := PropAnchorScript.new(
		PropPlacementModeScript.Mode.WALL,
		Vector2i(8, 4),
		Vector3(16.0, 0.0, 8.0),
		270.0
	)
	anchor_east.wall_side = Vector2i(-1, 0)
	var rot_east = resolver.resolve_rotation(anchor_east, DecorationOrientationModeScript.Mode.FACE_ROOM)
	assert(rot_east == 270.0 or rot_east == -90.0, "FAIL: Muro Este orientado al interior debe ser 270° o -90°")

	print("  [OK] DecorationOrientationResolver FACE_ROOM angles verified.")

	print("==================================================================")
	print("[PASS] test_candidate_and_orientation completado con 100% éxito!")
	print("==================================================================")
	quit(0)
