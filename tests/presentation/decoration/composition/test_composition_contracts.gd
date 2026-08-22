extends SceneTree

## Test suite para validar los contratos básicos de Composición: DecorationTag, CompositionRole y DecorationRelationship.

const DecorationTagScript = preload("res://src/presentation/decoration/composition/decoration_tag.gd")
const CompositionRoleScript = preload("res://src/presentation/decoration/composition/composition_role.gd")
const DecorationRelationshipScript = preload("res://src/presentation/decoration/composition/decoration_relationship.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_composition_contracts ---")
	print("==================================================================")

	# 1. Validar DecorationTag
	assert(DecorationTagScript.FOCAL == &"focal")
	assert(DecorationTagScript.SEATING == &"seating")
	assert(DecorationTagScript.BURIAL == &"burial")
	assert(DecorationTagScript.RITUAL == &"ritual")
	assert(DecorationTagScript.LIGHTING == &"lighting")
	assert(DecorationTagScript.STORAGE == &"storage")
	assert(DecorationTagScript.WALL_DECOR == &"wall_decor")
	assert(DecorationTagScript.TABLETOP == &"tabletop")
	assert(DecorationTagScript.FLOOR_LIGHT == &"floor_light")
	assert(DecorationTagScript.NAVIGATION_SENSITIVE == &"navigation_sensitive")
	print("  [OK] DecorationTag constants verified.")

	# 2. Validar CompositionRole
	assert(CompositionRoleScript.Role.PRIMARY == 0)
	assert(CompositionRoleScript.Role.SECONDARY == 1)
	assert(CompositionRoleScript.Role.COMPANION == 2)
	assert(CompositionRoleScript.Role.LIGHTING == 3)
	assert(CompositionRoleScript.Role.DETAIL == 4)
	assert(CompositionRoleScript.role_to_name(CompositionRoleScript.Role.PRIMARY) == "PRIMARY")
	assert(CompositionRoleScript.name_to_role("companion") == CompositionRoleScript.Role.COMPANION)
	print("  [OK] CompositionRole enum and conversions verified.")

	# 3. Validar DecorationRelationship
	assert(DecorationRelationshipScript.Relation.NEAR == 0)
	assert(DecorationRelationshipScript.Relation.ADJACENT == 1)
	assert(DecorationRelationshipScript.Relation.SYMMETRIC == 2)
	assert(DecorationRelationshipScript.Relation.OPPOSITE == 3)
	assert(DecorationRelationshipScript.Relation.CENTERED_ON == 4)
	assert(DecorationRelationshipScript.Relation.ALIGNED_WITH == 5)
	assert(DecorationRelationshipScript.Relation.SUPPORTED_BY == 6)
	assert(DecorationRelationshipScript.Relation.FACE_TOWARD == 7)
	assert(DecorationRelationshipScript.Relation.KEEP_AWAY_FROM == 8)
	assert(DecorationRelationshipScript.relation_to_name(DecorationRelationshipScript.Relation.SYMMETRIC) == "SYMMETRIC")
	assert(DecorationRelationshipScript.name_to_relation("face_toward") == DecorationRelationshipScript.Relation.FACE_TOWARD)
	print("  [OK] DecorationRelationship enum and conversions verified.")

	print("==================================================================")
	print("[PASS] test_composition_contracts completado con 100% éxito!")
	print("==================================================================")
	quit(0)
