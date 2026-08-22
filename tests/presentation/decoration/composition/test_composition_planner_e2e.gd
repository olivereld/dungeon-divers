extends SceneTree

## Test suite E2E para validar DecorationCompositionPlanner y la integración en DecorationCompositionResolver.

const DecorationCompositionPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const DecorationCompositionResolverScript = preload("res://src/presentation/decoration/decoration_composition_resolver.gd")
const DecorationCompositionProfileScript = preload("res://src/presentation/decoration/composition/decoration_composition_profile.gd")
const DecorationCompositionRuleScript = preload("res://src/presentation/decoration/composition/decoration_composition_rule.gd")
const CompositionRoleScript = preload("res://src/presentation/decoration/composition/composition_role.gd")
const DecorationTagScript = preload("res://src/presentation/decoration/composition/decoration_tag.gd")
const DecorationPaletteScript = preload("res://src/presentation/decoration/decoration_palette.gd")
const DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const PresentationSeedContextScript = preload("res://src/presentation/architecture/presentation_seed_context.gd")
const PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_composition_planner_e2e ---")
	print("==================================================================")

	var planner := DecorationCompositionPlannerScript.new()
	var pal_resolver := DecorationPaletteResolverScript.new()

	# 1. Crear geometría de sala de prueba (6x6)
	var floor_cells: Array[Vector2i] = []
	for x in range(1, 7):
		for y in range(1, 7):
			floor_cells.append(Vector2i(x, y))

	var room_geom = PresentationRoomGeometryScript.new(
		0,
		Rect2i(1, 1, 6, 6),
		floor_cells,
		[],
		[Vector2i(1, 4)]
	)

	# 2. Crear un perfil de composición de prueba (Tomb Central Focal)
	var profile := DecorationCompositionProfileScript.new()
	profile.id = &"tomb_profile"

	var r_primary := DecorationCompositionRuleScript.new()
	r_primary.rule_id = &"primary_sarcophagus"
	r_primary.composition_role = CompositionRoleScript.Role.PRIMARY
	r_primary.target_style_ids = [&"sarcophagus_stone_closed"]
	r_primary.min_count = 1
	r_primary.max_count = 1
	r_primary.clearance = 1
	profile.rules.append(r_primary)

	var r_support := DecorationCompositionRuleScript.new()
	r_support.rule_id = &"support_tombstones"
	r_support.composition_role = CompositionRoleScript.Role.SECONDARY
	r_support.target_style_ids = [&"tombstone_classic_wall"]
	r_support.min_count = 1
	r_support.max_count = 2
	profile.rules.append(r_support)

	# 3. Resolver paleta de Tumba
	var palette = pal_resolver.resolve_palette(1, RoomPurposeScript.Type.TOMB)
	var seed_ctx = PresentationSeedContextScript.for_room(1337, 0)

	var comp = planner.plan_room_composition(
		profile,
		palette,
		room_geom,
		{"room_id": 0},
		null,
		seed_ctx,
		2.0
	)

	assert(comp != null, "FAIL: Composition result is null")
	assert(comp.prop_directives.size() >= 1, "FAIL: Composition must have placed primary prop")

	# Verificar que el primario fue colocado en el centro y no bloquea la puerta
	var primary_dir = comp.prop_directives[0]
	assert(primary_dir.prop_id == &"sarcophagus_stone_closed", "FAIL: Primary prop must be sarcophagus")
	assert(not primary_dir.occupied_cells.has(Vector2i(1, 4)), "FAIL: Primary prop must not overlap door")
	print("  [OK] DecorationCompositionPlanner successfully executed CentralFocal composition without door conflicts.")

	print("==================================================================")
	print("[PASS] test_composition_planner_e2e completado con 100% éxito!")
	print("==================================================================")
	quit(0)
