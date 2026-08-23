extends SceneTree

## Test suite para validar las plantillas de composición espacial (DecorationCompositionTemplate).

const DecorationCompositionTemplateScript = preload("res://src/presentation/decoration/composition/decoration_composition_template.gd")
const DecorationCompositionRuleScript = preload("res://src/presentation/decoration/composition/decoration_composition_rule.gd")
const CompositionRoleScript = preload("res://src/presentation/decoration/composition/composition_role.gd")
const DecorationTagScript = preload("res://src/presentation/decoration/composition/decoration_tag.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_composition_template ---")
	print("==================================================================")

	var template := DecorationCompositionTemplateScript.new()
	template.template_id = &"tomb_central_ceremonial"
	template.min_room_size = Vector2i(5, 5)

	# 1. Regla primaria (Sarcófago central)
	var r_primary := DecorationCompositionRuleScript.new()
	r_primary.rule_id = &"sarcophagus_centerpiece"
	r_primary.composition_role = CompositionRoleScript.Role.PRIMARY
	r_primary.target_tags = [DecorationTagScript.FOCAL, DecorationTagScript.BURIAL]
	template.primary_rule = r_primary

	# 2. Regla de apoyo (Urnas perimetrales)
	var r_urns := DecorationCompositionRuleScript.new()
	r_urns.rule_id = &"support_urns"
	r_urns.composition_role = CompositionRoleScript.Role.SECONDARY
	r_urns.target_tags = [DecorationTagScript.BURIAL]
	r_urns.max_count = 2
	template.support_rules.append(r_urns)

	assert(template.template_id == &"tomb_central_ceremonial")
	assert(template.primary_rule != null)
	assert(template.support_rules.size() == 1)
	assert(template.is_room_size_compatible(Vector2i(6, 6)) == true, "FAIL: 6x6 room is compatible with 5x5 minimum")
	assert(template.is_room_size_compatible(Vector2i(4, 4)) == false, "FAIL: 4x4 room is incompatible with 5x5 minimum")
	print("  [OK] DecorationCompositionTemplate multi-rule packaging and size checks verified.")

	print("==================================================================")
	print("[PASS] test_composition_template completado con 100% éxito!")
	print("==================================================================")
	quit(0)
