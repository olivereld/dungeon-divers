extends SceneTree

## Test suite para validar DecorationCompositionRule y DecorationCompositionProfile.

const DecorationCompositionRuleScript = preload("res://src/presentation/decoration/composition/decoration_composition_rule.gd")
const DecorationCompositionProfileScript = preload("res://src/presentation/decoration/composition/decoration_composition_profile.gd")
const CompositionRoleScript = preload("res://src/presentation/decoration/composition/composition_role.gd")
const DecorationTagScript = preload("res://src/presentation/decoration/composition/decoration_tag.gd")
const DecorationOrientationModeScript = preload("res://src/presentation/decoration/composition/decoration_orientation_mode.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_composition_profile_rules ---")
	print("==================================================================")

	# 1. Crear regla de Foco Central
	var rule_focal := DecorationCompositionRuleScript.new()
	rule_focal.rule_id = &"central_sarcophagus"
	rule_focal.composition_role = CompositionRoleScript.Role.PRIMARY
	rule_focal.target_tags = [DecorationTagScript.FOCAL, DecorationTagScript.BURIAL]
	rule_focal.orientation_mode = DecorationOrientationModeScript.Mode.FACE_ROOM
	rule_focal.min_count = 1
	rule_focal.max_count = 1
	rule_focal.clearance = 1

	assert(rule_focal.rule_id == &"central_sarcophagus")
	assert(rule_focal.target_tags.has(DecorationTagScript.FOCAL))
	print("  [OK] DecorationCompositionRule creation verified.")

	# 2. Crear perfil de composición de Cripta
	var profile := DecorationCompositionProfileScript.new()
	profile.id = &"tomb_central_focal_profile"
	profile.rules.append(rule_focal)
	profile.max_total_props = 6
	profile.lighting_budget = 6.0

	assert(profile.id == &"tomb_central_focal_profile")
	assert(profile.rules.size() == 1)
	assert(profile.max_total_props == 6)
	assert(profile.lighting_budget == 6.0)
	print("  [OK] DecorationCompositionProfile configuration verified.")

	print("==================================================================")
	print("[PASS] test_composition_profile_rules completado con 100% éxito!")
	print("==================================================================")
	quit(0)
