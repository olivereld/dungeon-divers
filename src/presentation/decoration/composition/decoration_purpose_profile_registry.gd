class_name DecorationPurposeProfileRegistry
extends RefCounted

## Registro y fábrica declarativa de perfiles de composición según el propósito semántico de la sala.

const _DecorationPurposeProfileScript = preload("res://src/presentation/decoration/composition/decoration_purpose_profile.gd")
const _DecorationRoomIntentScript = preload("res://src/presentation/decoration/composition/decoration_room_intent.gd")
const _DecorationCompositionTemplateScript = preload("res://src/presentation/decoration/composition/decoration_composition_template.gd")
const _DecorationCompositionRuleScript = preload("res://src/presentation/decoration/composition/decoration_composition_rule.gd")
const _CompositionRoleScript = preload("res://src/presentation/decoration/composition/composition_role.gd")
const _DecorationTagScript = preload("res://src/presentation/decoration/composition/decoration_tag.gd")
const _DecorationOrientationModeScript = preload("res://src/presentation/decoration/composition/decoration_orientation_mode.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _DecorationRoomZoneScript = preload("res://src/presentation/decoration/composition/decoration_room_zone.gd")

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
	tomb_intent.allowed_tags = [_DecorationTagScript.BURIAL, _DecorationTagScript.FOCAL, _DecorationTagScript.LIGHTING]
	tomb_intent.forbidden_tags = [_DecorationTagScript.STORAGE, _DecorationTagScript.SEATING]
	tomb_profile.intent = tomb_intent

	var tomb_template := _DecorationCompositionTemplateScript.new()
	tomb_template.template_id = &"tomb_central_sarcophagus"
	tomb_template.min_room_size = Vector2i(4, 4)

	var r_tomb_primary := _DecorationCompositionRuleScript.new()
	r_tomb_primary.rule_id = &"primary_sarcophagus"
	r_tomb_primary.composition_role = _CompositionRoleScript.Role.PRIMARY
	r_tomb_primary.target_tags = [_DecorationTagScript.FOCAL, _DecorationTagScript.BURIAL]
	r_tomb_primary.orientation_mode = _DecorationOrientationModeScript.Mode.FACE_ROOM
	r_tomb_primary.min_count = 1
	r_tomb_primary.max_count = 1
	r_tomb_primary.clearance = 1
	tomb_template.primary_rule = r_tomb_primary

	var r_tomb_support := _DecorationCompositionRuleScript.new()
	r_tomb_support.rule_id = &"support_urns_tombstones"
	r_tomb_support.composition_role = _CompositionRoleScript.Role.SECONDARY
	r_tomb_support.target_tags = [_DecorationTagScript.BURIAL]
	r_tomb_support.orientation_mode = _DecorationOrientationModeScript.Mode.FACE_ROOM
	r_tomb_support.min_count = 1
	r_tomb_support.max_count = 2
	tomb_template.support_rules.append(r_tomb_support)

	tomb_profile.templates.append(tomb_template)
	_profiles[_RoomPurposeScript.Type.TOMB] = tomb_profile
	_profiles[_RoomPurposeScript.Type.ROYAL_TOMB] = tomb_profile

	# 2. ENTRANCE
	var entry_profile := _DecorationPurposeProfileScript.new()
	entry_profile.purpose_type = _RoomPurposeScript.Type.ENTRANCE
	entry_profile.default_lighting_budget = 3.0

	var entry_intent := _DecorationRoomIntentScript.new()
	entry_intent.player_clearance_level = 2
	entry_intent.allowed_tags = [_DecorationTagScript.LIGHTING, _DecorationTagScript.WALL_DECOR]
	entry_intent.forbidden_tags = [_DecorationTagScript.BURIAL]
	entry_profile.intent = entry_intent
	_profiles[_RoomPurposeScript.Type.ENTRANCE] = entry_profile

	# 3. ANTECHAMBER
	var ante_profile := _DecorationPurposeProfileScript.new()
	ante_profile.purpose_type = _RoomPurposeScript.Type.ANTECHAMBER
	ante_profile.default_lighting_budget = 4.5

	var ante_intent := _DecorationRoomIntentScript.new()
	ante_intent.player_clearance_level = 1
	ante_intent.allowed_tags = [_DecorationTagScript.SEATING, _DecorationTagScript.LIGHTING, _DecorationTagScript.WALL_DECOR]
	ante_intent.forbidden_tags = [_DecorationTagScript.STORAGE]
	ante_profile.intent = ante_intent

	var ante_template := _DecorationCompositionTemplateScript.new()
	ante_template.template_id = &"antechamber_seating"

	var r_benches := _DecorationCompositionRuleScript.new()
	r_benches.rule_id = &"wall_benches"
	r_benches.composition_role = _CompositionRoleScript.Role.SECONDARY
	r_benches.target_tags = [_DecorationTagScript.SEATING]
	r_benches.orientation_mode = _DecorationOrientationModeScript.Mode.FACE_ROOM
	r_benches.min_count = 1
	r_benches.max_count = 2
	ante_template.support_rules.append(r_benches)
	ante_profile.templates.append(ante_template)
	_profiles[_RoomPurposeScript.Type.ANTECHAMBER] = ante_profile

	# 4. CATACOMB & BURIAL_HALL & MORTUARY
	var catacomb_profile := _DecorationPurposeProfileScript.new()
	catacomb_profile.purpose_type = _RoomPurposeScript.Type.CATACOMB
	catacomb_profile.default_lighting_budget = 4.0

	var cata_intent := _DecorationRoomIntentScript.new()
	cata_intent.allowed_tags = [_DecorationTagScript.BURIAL, _DecorationTagScript.LIGHTING, _DecorationTagScript.WALL_DECOR]
	cata_intent.forbidden_tags = [_DecorationTagScript.SEATING]
	catacomb_profile.intent = cata_intent

	var cata_template := _DecorationCompositionTemplateScript.new()
	cata_template.template_id = &"catacomb_niches_urns"

	var r_niches := _DecorationCompositionRuleScript.new()
	r_niches.rule_id = &"perimeter_burials"
	r_niches.composition_role = _CompositionRoleScript.Role.SECONDARY
	r_niches.target_tags = [_DecorationTagScript.BURIAL]
	r_niches.orientation_mode = _DecorationOrientationModeScript.Mode.FACE_ROOM
	r_niches.min_count = 1
	r_niches.max_count = 3
	cata_template.support_rules.append(r_niches)
	catacomb_profile.templates.append(cata_template)

	_profiles[_RoomPurposeScript.Type.CATACOMB] = catacomb_profile
	_profiles[_RoomPurposeScript.Type.CRYPT] = catacomb_profile
	_profiles[_RoomPurposeScript.Type.MORTUARY] = catacomb_profile

func _build_generic_profile(purpose_type: int) -> _DecorationPurposeProfileScript:
	var prof := _DecorationPurposeProfileScript.new()
	prof.purpose_type = purpose_type
	var intent := _DecorationRoomIntentScript.new()
	prof.intent = intent
	return prof
