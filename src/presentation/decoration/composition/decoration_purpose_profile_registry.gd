class_name DecorationPurposeProfileRegistry
extends RefCounted

## Registro y fábrica declarativa de perfiles de composición según el propósito semántico de la sala.

const _DecorationPurposeProfileScript = preload("res://src/presentation/decoration/composition/decoration_purpose_profile.gd")
const _DecorationRoomIntentScript = preload("res://src/presentation/decoration/composition/decoration_room_intent.gd")
const _DecorationCompositionTemplateScript = preload("res://src/presentation/decoration/composition/decoration_composition_template.gd")
const _DecorationCompositionRuleScript = preload("res://src/presentation/decoration/composition/decoration_composition_rule.gd")
const _FixtureBudgetRuleScript = preload("res://src/presentation/decoration/composition/fixture_budget_rule.gd")
const _CompositionRoleScript = preload("res://src/presentation/decoration/composition/composition_role.gd")
const _DecorationTagScript = preload("res://src/presentation/decoration/composition/decoration_tag.gd")
const _DecorationOrientationModeScript = preload("res://src/presentation/decoration/composition/decoration_orientation_mode.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _DecorationRoomZoneScript = preload("res://src/presentation/decoration/composition/decoration_room_zone.gd")
const _PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _PropFixtureRelationshipProfileScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relationship_profile.gd")
const _PropFixtureRelationScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relation.gd")
const _PropFixtureRelationPlacementScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relation_placement.gd")

var _profiles: Dictionary = {} # purpose_type (int) -> DecorationPurposeProfile

func _init() -> void:
	_register_crypt_purpose_profiles()

func get_profile_for_purpose(purpose_type: int) -> _DecorationPurposeProfileScript:
	if _profiles.has(purpose_type):
		return _profiles[purpose_type]
	# Fallback a perfil genérico
	return _build_generic_profile(purpose_type)

func _register_crypt_purpose_profiles() -> void:
	# 1. TOMB & ROYAL_TOMB
	var tomb_profile := _DecorationPurposeProfileScript.new()
	tomb_profile.purpose_type = _RoomPurposeScript.Type.TOMB
	tomb_profile.default_lighting_budget = 4.0

	var tomb_intent := _DecorationRoomIntentScript.new()
	tomb_intent.focal_zone = _DecorationRoomZoneScript.ZoneType.FOCAL
	tomb_intent.symmetry_required = true
	tomb_intent.player_clearance_level = 2
	tomb_intent.lighting_budget = 4.0
	tomb_intent.allowed_tags = [
		_DecorationTagScript.BURIAL, _DecorationTagScript.FOCAL, _DecorationTagScript.LIGHTING,
		_DecorationTagScript.FURNITURE, _DecorationTagScript.WALL_DECOR, _DecorationTagScript.CORNER_DECOR,
		_DecorationTagScript.DETAIL, _DecorationTagScript.DEBRIS
	]
	tomb_intent.forbidden_tags = [_DecorationTagScript.STORAGE, _DecorationTagScript.SEATING]
	tomb_profile.intent = tomb_intent

	var tomb_template := _DecorationCompositionTemplateScript.new()
	tomb_template.template_id = &"tomb_central_sarcophagus"
	tomb_template.min_room_size = Vector2i(4, 4)

	var r_tomb_primary := _DecorationCompositionRuleScript.new()
	r_tomb_primary.rule_id = &"primary_sarcophagus"
	r_tomb_primary.composition_role = _CompositionRoleScript.Role.PRIMARY
	r_tomb_primary.placement_mode = _PropPlacementModeScript.Mode.CENTER
	r_tomb_primary.required_tags = [_DecorationTagScript.FOCAL, _DecorationTagScript.BURIAL]
	r_tomb_primary.orientation_mode = _DecorationOrientationModeScript.Mode.FACE_ROOM
	r_tomb_primary.min_count = 1
	r_tomb_primary.max_count = 1
	r_tomb_primary.clearance = 1
	tomb_template.primary_rule = r_tomb_primary

	var r_tomb_support := _DecorationCompositionRuleScript.new()
	r_tomb_support.rule_id = &"support_urns_tombstones"
	r_tomb_support.composition_role = _CompositionRoleScript.Role.SECONDARY
	r_tomb_support.placement_mode = _PropPlacementModeScript.Mode.FLOOR
	r_tomb_support.required_tags = [_DecorationTagScript.BURIAL]
	r_tomb_support.orientation_mode = _DecorationOrientationModeScript.Mode.FACE_ROOM
	r_tomb_support.min_count = 1
	r_tomb_support.max_count = 2
	tomb_template.support_rules.append(r_tomb_support)

	tomb_profile.templates.append(tomb_template)
	tomb_profile.fixture_rules = [
		_FixtureBudgetRuleScript.new(_FixturePlacementModeScript.Mode.HANGING, 1, 1, _FixtureBudgetRuleScript.Affinity.FOCAL_COMPANION, [], &"tomb_focal_lantern"),
		_FixtureBudgetRuleScript.new(_FixturePlacementModeScript.Mode.FLOOR, 1, 2, _FixtureBudgetRuleScript.Affinity.FOCAL_COMPANION, [], &"tomb_focal_braziers"),
		_FixtureBudgetRuleScript.new(_FixturePlacementModeScript.Mode.WALL, 1, 3, _FixtureBudgetRuleScript.Affinity.PERIMETER, [], &"tomb_perimeter_torches")
	]
	tomb_profile.relationship_profile = _PropFixtureRelationshipProfileScript.new(&"tomb_relations", [
		_PropFixtureRelationScript.new(
			&"sarcophagus_ornate",
			[_FixtureStyleScript.Type.CANDLE_CLUSTER, _FixtureStyleScript.Type.CANDLE_HOLDER],
			_PropFixtureRelationPlacementScript.Placement.NEAR,
			1, 2, &"sarcophagus_candles", 1.0, 2.0
		),
		_PropFixtureRelationScript.new(
			&"sarcophagus_ornate",
			[_FixtureStyleScript.Type.LANTERN],
			_PropFixtureRelationPlacementScript.Placement.ABOVE,
			1, 1, &"sarcophagus_hanging_lantern"
		),
		_PropFixtureRelationScript.new(
			&"wood_bench",
			[],
			_PropFixtureRelationPlacementScript.Placement.NEAR,
			0, 0, &"bench_no_lights", 1.0, 2.0, 1.0,
			[_FixtureStyleScript.Type.BRAZIER, _FixtureStyleScript.Type.CANDLE_CLUSTER, _FixtureStyleScript.Type.CANDLE_HOLDER]
		)
	])
	_profiles[_RoomPurposeScript.Type.TOMB] = tomb_profile
	_profiles[_RoomPurposeScript.Type.ROYAL_TOMB] = tomb_profile

	# 2. ENTRANCE
	var entry_profile := _DecorationPurposeProfileScript.new()
	entry_profile.purpose_type = _RoomPurposeScript.Type.ENTRANCE
	entry_profile.default_lighting_budget = 3.0

	var entry_intent := _DecorationRoomIntentScript.new()
	entry_intent.player_clearance_level = 2
	entry_intent.allowed_tags = [
		_DecorationTagScript.LIGHTING, _DecorationTagScript.WALL_DECOR,
		_DecorationTagScript.SEATING, _DecorationTagScript.DETAIL, _DecorationTagScript.DEBRIS
	]
	entry_intent.forbidden_tags = [_DecorationTagScript.BURIAL]
	entry_profile.intent = entry_intent
	entry_profile.fixture_rules = [
		_FixtureBudgetRuleScript.new(_FixturePlacementModeScript.Mode.WALL, 1, 2, _FixtureBudgetRuleScript.Affinity.PERIMETER, [], &"entry_perimeter_torches")
	]
	_profiles[_RoomPurposeScript.Type.ENTRANCE] = entry_profile

	# 3. ANTECHAMBER
	var ante_profile := _DecorationPurposeProfileScript.new()
	ante_profile.purpose_type = _RoomPurposeScript.Type.ANTECHAMBER
	ante_profile.default_lighting_budget = 4.5

	var ante_intent := _DecorationRoomIntentScript.new()
	ante_intent.player_clearance_level = 1
	ante_intent.allowed_tags = [
		_DecorationTagScript.SEATING, _DecorationTagScript.LIGHTING, _DecorationTagScript.WALL_DECOR,
		_DecorationTagScript.FURNITURE, _DecorationTagScript.DETAIL, _DecorationTagScript.DEBRIS
	]
	ante_intent.forbidden_tags = [_DecorationTagScript.STORAGE]
	ante_profile.intent = ante_intent

	var ante_template := _DecorationCompositionTemplateScript.new()
	ante_template.template_id = &"antechamber_seating"

	var r_benches := _DecorationCompositionRuleScript.new()
	r_benches.rule_id = &"wall_benches"
	r_benches.composition_role = _CompositionRoleScript.Role.SECONDARY
	r_benches.placement_mode = _PropPlacementModeScript.Mode.WALL
	r_benches.required_tags = [_DecorationTagScript.SEATING]
	r_benches.orientation_mode = _DecorationOrientationModeScript.Mode.FACE_ROOM
	r_benches.min_count = 1
	r_benches.max_count = 2
	ante_template.support_rules.append(r_benches)
	ante_profile.templates.append(ante_template)
	ante_profile.fixture_rules = [
		_FixtureBudgetRuleScript.new(_FixturePlacementModeScript.Mode.WALL, 1, 2, _FixtureBudgetRuleScript.Affinity.PERIMETER, [], &"ante_perimeter_torches"),
		_FixtureBudgetRuleScript.new(_FixturePlacementModeScript.Mode.HANGING, 0, 1, _FixtureBudgetRuleScript.Affinity.FREE, [], &"ante_ambient_hanging")
	]
	_profiles[_RoomPurposeScript.Type.ANTECHAMBER] = ante_profile

	# 4. SACRISTY / ALTAR_ROOM
	var sacristy_profile := _DecorationPurposeProfileScript.new()
	sacristy_profile.purpose_type = _RoomPurposeScript.Type.SACRISTY
	sacristy_profile.default_lighting_budget = 5.0

	var sacristy_intent := _DecorationRoomIntentScript.new()
	sacristy_intent.allowed_tags = [
		_DecorationTagScript.CEREMONIAL, _DecorationTagScript.FOCAL, _DecorationTagScript.SEATING,
		_DecorationTagScript.LIGHTING, _DecorationTagScript.FURNITURE, _DecorationTagScript.WALL_DECOR,
		_DecorationTagScript.DETAIL, _DecorationTagScript.DEBRIS
	]
	sacristy_profile.intent = sacristy_intent

	var sacristy_template := _DecorationCompositionTemplateScript.new()
	sacristy_template.template_id = &"sacristy_altar_pews"

	var r_altar_primary := _DecorationCompositionRuleScript.new()
	r_altar_primary.rule_id = &"primary_altar"
	r_altar_primary.composition_role = _CompositionRoleScript.Role.PRIMARY
	r_altar_primary.placement_mode = _PropPlacementModeScript.Mode.CENTER
	r_altar_primary.required_tags = [_DecorationTagScript.CEREMONIAL, _DecorationTagScript.FOCAL]
	r_altar_primary.orientation_mode = _DecorationOrientationModeScript.Mode.FACE_ROOM
	r_altar_primary.min_count = 1
	r_altar_primary.max_count = 1
	r_altar_primary.clearance = 1
	sacristy_template.primary_rule = r_altar_primary

	var r_sacristy_pews := _DecorationCompositionRuleScript.new()
	r_sacristy_pews.rule_id = &"sacristy_pews"
	r_sacristy_pews.composition_role = _CompositionRoleScript.Role.SECONDARY
	r_sacristy_pews.placement_mode = _PropPlacementModeScript.Mode.WALL
	r_sacristy_pews.required_tags = [_DecorationTagScript.SEATING]
	r_sacristy_pews.orientation_mode = _DecorationOrientationModeScript.Mode.FACE_ROOM
	r_sacristy_pews.min_count = 1
	r_sacristy_pews.max_count = 2
	sacristy_template.support_rules.append(r_sacristy_pews)

	sacristy_profile.templates.append(sacristy_template)
	sacristy_profile.fixture_rules = [
		_FixtureBudgetRuleScript.new(_FixturePlacementModeScript.Mode.HANGING, 1, 1, _FixtureBudgetRuleScript.Affinity.FOCAL_COMPANION, [], &"altar_hanging_lantern"),
		_FixtureBudgetRuleScript.new(_FixturePlacementModeScript.Mode.FLOOR, 1, 2, _FixtureBudgetRuleScript.Affinity.FOCAL_COMPANION, [], &"altar_flanking_braziers"),
		_FixtureBudgetRuleScript.new(_FixturePlacementModeScript.Mode.WALL, 1, 3, _FixtureBudgetRuleScript.Affinity.PERIMETER, [], &"sacristy_perimeter_torches")
	]
	sacristy_profile.relationship_profile = _PropFixtureRelationshipProfileScript.new(&"sacristy_relations", [
		_PropFixtureRelationScript.new(
			&"altar_stone",
			[_FixtureStyleScript.Type.CANDLE_CLUSTER, _FixtureStyleScript.Type.CANDLE_HOLDER],
			_PropFixtureRelationPlacementScript.Placement.NEAR,
			1, 2, &"altar_candles", 1.0, 2.0
		),
		_PropFixtureRelationScript.new(
			&"altar_stone",
			[_FixtureStyleScript.Type.BRAZIER],
			_PropFixtureRelationPlacementScript.Placement.NEAR,
			0, 2, &"altar_braziers", 1.5, 2.5
		),
		_PropFixtureRelationScript.new(
			&"wood_bench",
			[],
			_PropFixtureRelationPlacementScript.Placement.NEAR,
			0, 0, &"bench_no_lights", 1.0, 2.0, 1.0,
			[_FixtureStyleScript.Type.BRAZIER, _FixtureStyleScript.Type.CANDLE_CLUSTER, _FixtureStyleScript.Type.CANDLE_HOLDER]
		)
	])
	_profiles[_RoomPurposeScript.Type.SACRISTY] = sacristy_profile
	_profiles[_RoomPurposeScript.Type.ALTAR_ROOM] = sacristy_profile

	# 5. CATACOMB & BURIAL_HALL & MORTUARY
	var catacomb_profile := _DecorationPurposeProfileScript.new()
	catacomb_profile.purpose_type = _RoomPurposeScript.Type.CATACOMB
	catacomb_profile.default_lighting_budget = 4.0

	var cata_intent := _DecorationRoomIntentScript.new()
	cata_intent.allowed_tags = [
		_DecorationTagScript.BURIAL, _DecorationTagScript.FOCAL, _DecorationTagScript.LIGHTING,
		_DecorationTagScript.FURNITURE, _DecorationTagScript.WALL_DECOR, _DecorationTagScript.CORNER_DECOR,
		_DecorationTagScript.DETAIL, _DecorationTagScript.DEBRIS, _DecorationTagScript.CEREMONIAL
	]
	cata_intent.forbidden_tags = [_DecorationTagScript.SEATING]
	catacomb_profile.intent = cata_intent

	var cata_template := _DecorationCompositionTemplateScript.new()
	cata_template.template_id = &"catacomb_niches_urns"

	var r_niches := _DecorationCompositionRuleScript.new()
	r_niches.rule_id = &"perimeter_burials"
	r_niches.composition_role = _CompositionRoleScript.Role.SECONDARY
	r_niches.placement_mode = _PropPlacementModeScript.Mode.FLOOR
	r_niches.required_tags = [_DecorationTagScript.BURIAL]
	r_niches.orientation_mode = _DecorationOrientationModeScript.Mode.FACE_ROOM
	r_niches.min_count = 1
	r_niches.max_count = 3
	cata_template.support_rules.append(r_niches)
	catacomb_profile.templates.append(cata_template)
	catacomb_profile.fixture_rules = [
		_FixtureBudgetRuleScript.new(_FixturePlacementModeScript.Mode.WALL, 1, 3, _FixtureBudgetRuleScript.Affinity.PERIMETER, [], &"catacomb_wall_torches"),
		_FixtureBudgetRuleScript.new(_FixturePlacementModeScript.Mode.FLOOR, 0, 1, _FixtureBudgetRuleScript.Affinity.FREE, [], &"catacomb_ambient_brazier")
	]
	catacomb_profile.relationship_profile = _PropFixtureRelationshipProfileScript.new(&"catacomb_relations", [
		_PropFixtureRelationScript.new(
			&"tombstone_cross",
			[_FixtureStyleScript.Type.CANDLE_CLUSTER, _FixtureStyleScript.Type.CANDLE_HOLDER],
			_PropFixtureRelationPlacementScript.Placement.NEAR,
			0, 1, &"tombstone_candle", 1.0, 1.5
		),
		_PropFixtureRelationScript.new(
			&"wood_bench",
			[],
			_PropFixtureRelationPlacementScript.Placement.NEAR,
			0, 0, &"bench_no_lights", 1.0, 2.0, 1.0,
			[_FixtureStyleScript.Type.BRAZIER, _FixtureStyleScript.Type.CANDLE_CLUSTER, _FixtureStyleScript.Type.CANDLE_HOLDER]
		)
	])

	_profiles[_RoomPurposeScript.Type.CATACOMB] = catacomb_profile
	_profiles[_RoomPurposeScript.Type.CRYPT] = catacomb_profile
	_profiles[_RoomPurposeScript.Type.MORTUARY] = catacomb_profile
	_profiles[_RoomPurposeScript.Type.CHAMBER] = catacomb_profile
	_profiles[_RoomPurposeScript.Type.HALL] = ante_profile
	_profiles[_RoomPurposeScript.Type.SANCTUM] = tomb_profile
	_profiles[_RoomPurposeScript.Type.SHRINE] = sacristy_profile
	_profiles[_RoomPurposeScript.Type.STORAGE] = catacomb_profile

func _build_generic_profile(purpose_type: int) -> _DecorationPurposeProfileScript:
	var prof := _DecorationPurposeProfileScript.new()
	prof.purpose_type = purpose_type
	var intent := _DecorationRoomIntentScript.new()
	intent.allowed_tags = [
		_DecorationTagScript.FOCAL, _DecorationTagScript.BURIAL, _DecorationTagScript.SEATING,
		_DecorationTagScript.LIGHTING, _DecorationTagScript.FURNITURE, _DecorationTagScript.WALL_DECOR,
		_DecorationTagScript.CORNER_DECOR, _DecorationTagScript.DETAIL, _DecorationTagScript.DEBRIS
	]
	prof.intent = intent

	var template := _DecorationCompositionTemplateScript.new()
	template.template_id = &"generic_fallback_template"

	var r_primary := _DecorationCompositionRuleScript.new()
	r_primary.rule_id = &"generic_primary"
	r_primary.composition_role = _CompositionRoleScript.Role.PRIMARY
	r_primary.placement_mode = _PropPlacementModeScript.Mode.CENTER
	r_primary.min_count = 1
	r_primary.max_count = 1
	template.primary_rule = r_primary

	var r_support := _DecorationCompositionRuleScript.new()
	r_support.rule_id = &"generic_support"
	r_support.composition_role = _CompositionRoleScript.Role.SECONDARY
	r_support.placement_mode = -1
	r_support.min_count = 1
	r_support.max_count = 3
	template.support_rules.append(r_support)

	prof.templates.append(template)
	prof.fixture_rules = [
		_FixtureBudgetRuleScript.new(_FixturePlacementModeScript.Mode.WALL, 1, 2),
		_FixtureBudgetRuleScript.new(_FixturePlacementModeScript.Mode.FLOOR, 0, 1)
	]
	return prof
