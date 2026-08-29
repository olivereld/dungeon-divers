class_name ProfileValidator
extends RefCounted

## Validador exhaustivo de integridad y consistencia semántica para ProfileBundle.
## Verifica esquemas, referencias cruzadas a assets, rangos numéricos y reglas de distribución.

const _ProfileBundleScript = preload("res://src/dungeon_generator/profiles/profile_bundle.gd")
const _ProfileValidationResultScript = preload("res://src/dungeon_generator/profiles/profile_validation_result.gd")
const _ProfileRoomScript = preload("res://src/dungeon_generator/profiles/profile_room.gd")

const VALID_GAMEPLAY_ROLES: Array[StringName] = [
	&"START", &"BOSS", &"TREASURE", &"COMBAT", &"EXPLORE"
]

func validate(bundle: _ProfileBundleScript) -> _ProfileValidationResultScript:
	var result := _ProfileValidationResultScript.new()

	if bundle == null:
		result.add_error("ProfileBundle is null.")
		return result

	if bundle.archetype == null:
		result.add_error("ProfileBundle archetype is null.")
		return result

	if bundle.assets == null:
		result.add_error("ProfileBundle AssetRegistry is null.")
		return result

	_validate_assets(bundle.assets, result)
	_validate_archetype(bundle, result)
	_validate_rooms(bundle, result)

	return result

func _validate_assets(assets, result: _ProfileValidationResultScript) -> void:
	if assets.props.is_empty():
		result.add_warning("AssetRegistry contains 0 props.")
	if assets.fixtures.is_empty():
		result.add_warning("AssetRegistry contains 0 fixtures.")
	if assets.materials.is_empty():
		result.add_warning("AssetRegistry contains 0 materials.")
	if assets.architecture.is_empty():
		result.add_warning("AssetRegistry contains 0 architecture entries.")

	for pid in assets.props:
		var p = assets.props[pid]
		if p.footprint.x <= 0 or p.footprint.y <= 0:
			result.add_error("Prop '%s' has invalid footprint %s." % [str(pid), str(p.footprint)])

func _validate_archetype(bundle: _ProfileBundleScript, result: _ProfileValidationResultScript) -> void:
	var arch = bundle.archetype

	# 1. Schema version & ID
	if arch.schema_version != 1:
		result.add_error("Archetype '%s' schema_version must be 1 (found %d)." % [str(arch.id), arch.schema_version])
	if arch.id == &"":
		result.add_error("Archetype ID cannot be empty.")

	# 2. Global settings
	if arch.global_settings == null:
		result.add_error("Archetype '%s' missing global_settings." % str(arch.id))
	else:
		var gs = arch.global_settings
		if gs.min_rooms <= 0:
			result.add_error("min_rooms must be > 0 (found %d)." % gs.min_rooms)
		if gs.min_rooms > gs.max_rooms:
			result.add_error("min_rooms (%d) cannot be greater than max_rooms (%d)." % [gs.min_rooms, gs.max_rooms])
		if gs.decoration_density < 0.0 or gs.decoration_density > 1.0:
			result.add_error("decoration_density must be in [0.0, 1.0] (found %f)." % gs.decoration_density)
		if gs.lighting_density < 0.0 or gs.lighting_density > 1.0:
			result.add_error("lighting_density must be in [0.0, 1.0] (found %f)." % gs.lighting_density)

	# 3. Distribution sum validation (must sum to ~1.0)
	if arch.room_purpose_distribution.is_empty():
		result.add_error("Archetype '%s' room_purpose_distribution is empty." % str(arch.id))
	else:
		var total_dist: float = 0.0
		for p_key in arch.room_purpose_distribution:
			var w = float(arch.room_purpose_distribution[p_key])
			if w < 0.0:
				result.add_error("room_purpose_distribution weight for '%s' cannot be negative (%f)." % [str(p_key), w])
			total_dist += w

		if absf(total_dist - 1.0) > 0.01:
			result.add_error("room_purpose_distribution must sum to 1.0 (found %f)." % total_dist)

	# 4. Contextual weights
	for p_key in arch.purpose_weights:
		var w = float(arch.purpose_weights[p_key])
		if w < 0.0:
			result.add_error("purpose_weights for '%s' cannot be negative (%f)." % [str(p_key), w])

	# 5. Gameplay Purpose Map
	for role in arch.gameplay_purpose_map:
		if not VALID_GAMEPLAY_ROLES.has(role):
			result.add_warning("Unrecognized gameplay role '%s' in gameplay_purpose_map." % str(role))

	# 6. Architectural Material Profile
	if arch.architectural_style != null:
		var mat_id = arch.architectural_style.material_profile
		if mat_id != &"" and not bundle.assets.has_material(mat_id):
			result.add_error("Archetype references unknown material_profile '%s'." % str(mat_id))

	# 7. Room files references exist
	for p_key in arch.rooms:
		if not bundle.rooms.has(p_key):
			result.add_error("Archetype references room '%s' (%s) but it failed to load." % [str(p_key), str(arch.rooms[p_key])])

func validate_room(room: _ProfileRoomScript, assets = null) -> _ProfileValidationResultScript:
	var res := _ProfileValidationResultScript.new()
	_validate_single_room(room, assets, res)
	return res

func _validate_rooms(bundle: _ProfileBundleScript, result: _ProfileValidationResultScript) -> void:
	for r_id in bundle.rooms:
		var room = bundle.rooms[r_id]
		_validate_single_room(room, bundle.assets, result)

func _validate_single_room(room: _ProfileRoomScript, assets, result: _ProfileValidationResultScript) -> void:
	if room == null:
		result.add_error("Null room found in bundle.")
		return

	if room.schema_version < 1:
		result.add_error("Room '%s' schema_version must be >= 1 (found %d)." % [str(room.id), room.schema_version])
	if room.id == &"":
		result.add_error("Room ID cannot be empty.")

	# Intent
	if room.intent == null:
		result.add_error("Room '%s' missing intent." % str(room.id))

	# Architecture
	if room.architecture != null:
		if assets != null:
			if room.architecture.floor != &"" and not assets.has_architecture(room.architecture.floor):
				result.add_error("Room '%s' references unknown architecture floor '%s'." % [str(room.id), str(room.architecture.floor)])
			if room.architecture.walls != &"" and not assets.has_architecture(room.architecture.walls):
				result.add_error("Room '%s' references unknown architecture walls '%s'." % [str(room.id), str(room.architecture.walls)])
			if room.architecture.door != &"" and not assets.has_architecture(room.architecture.door):
				result.add_error("Room '%s' references unknown architecture door '%s'." % [str(room.id), str(room.architecture.door)])
			if room.architecture.stairs != &"" and not assets.has_architecture(room.architecture.stairs):
				result.add_error("Room '%s' references unknown architecture stairs '%s'." % [str(room.id), str(room.architecture.stairs)])

		if room.architecture.wall_variants != null and room.architecture.wall_variants.enabled:
			var wv = room.architecture.wall_variants
			if wv.allowed.is_empty():
				result.add_error("Room '%s' wall_variants has empty allowed variants list." % str(room.id))
			var total_w: float = 0.0
			for v_name in wv.weights.keys():
				var w = float(wv.weights[v_name])
				if w < 0.0:
					result.add_error("Room '%s' wall_variant '%s' has negative weight %f." % [str(room.id), str(v_name), w])
				total_w += w
			if total_w <= 0.0:
				result.add_error("Room '%s' wall_variants total weight must be > 0." % str(room.id))

		if room.architecture.floor_variants != null and room.architecture.floor_variants.enabled:
			var fv = room.architecture.floor_variants
			if fv.base_weight < 0.0:
				result.add_error("Room '%s' floor base_weight cannot be negative." % str(room.id))
			var total_fw: float = fv.base_weight
			for v_dict in fv.variants:
				var v_st = v_dict.get("style", &"")
				var v_w = float(v_dict.get("weight", 0.0))
				if v_w < 0.0:
					result.add_error("Room '%s' floor variant '%s' has negative weight %f." % [str(room.id), str(v_st), v_w])
				if assets != null and v_st != &"" and not assets.has_architecture(v_st):
					result.add_error("Room '%s' floor variant references unknown architecture '%s'." % [str(room.id), str(v_st)])
				total_fw += v_w
			if total_fw <= 0.0:
				result.add_error("Room '%s' floor_variants total weight must be > 0." % str(room.id))

	# Composition
	if room.composition != null:
		if room.composition.primary != null:
			var pr = room.composition.primary
			if pr.min_count < 0 or pr.max_count < pr.min_count:
				result.add_error("Room '%s' primary rule '%s' invalid count range [%d, %d]." % [
					str(room.id), str(pr.rule_id), pr.min_count, pr.max_count
				])
			if pr.clearance < 0:
				result.add_error("Room '%s' primary rule '%s' clearance cannot be negative." % [str(room.id), str(pr.rule_id)])

		for sr in room.composition.secondary:
			if sr.min_count < 0 or sr.max_count < sr.min_count:
				result.add_error("Room '%s' secondary rule '%s' invalid count range [%d, %d]." % [
					str(room.id), str(sr.rule_id), sr.min_count, sr.max_count
				])

	# Lighting
	if room.lighting != null:
		if room.lighting.budget < 0.0:
			result.add_error("Room '%s' lighting budget cannot be negative (%f)." % [str(room.id), room.lighting.budget])

		if room.lighting.defaults != null:
			_validate_light_settings("Room '%s' lighting defaults" % str(room.id), room.lighting.defaults, result)

		var slots = [room.lighting.wall, room.lighting.floor, room.lighting.hanging]
		var slot_names = ["wall", "floor", "hanging"]
		for idx in range(slots.size()):
			var s = slots[idx]
			if s != null:
				if s.lighting_override != null:
					_validate_light_settings("Room '%s' %s slot override" % [str(room.id), slot_names[idx]], s.lighting_override, result)
				for aid in s.asset_overrides:
					_validate_light_settings("Room '%s' %s asset '%s' override" % [str(room.id), slot_names[idx], str(aid)], s.asset_overrides[aid], result)

		var all_fixtures = room.lighting.get_all_allowed_fixture_ids()
		for fid in all_fixtures:
			if not assets.has_fixture(fid):
				result.add_error("Room '%s' references unknown lighting fixture '%s'." % [str(room.id), str(fid)])

	# Relationships
	for rel in room.relationships:
		if rel.id == &"":
			result.add_warning("Room '%s' has relationship without ID." % str(room.id))

		for src in rel.source:
			if not assets.has_prop(src):
				result.add_error("Room '%s' relationship '%s' references unknown source prop '%s'." % [
					str(room.id), str(rel.id), str(src)
				])

		for tgt in rel.targets:
			if not assets.has_fixture(tgt):
				result.add_error("Room '%s' relationship '%s' references unknown target fixture '%s'." % [
					str(room.id), str(rel.id), str(tgt)
				])

		for forb in rel.forbidden_targets:
			if not assets.has_fixture(forb):
				result.add_error("Room '%s' relationship '%s' references unknown forbidden fixture '%s'." % [
					str(room.id), str(rel.id), str(forb)
				])

		if rel.min_count < 0 or rel.max_count < rel.min_count:
			result.add_error("Room '%s' relationship '%s' invalid count range [%d, %d]." % [
				str(room.id), str(rel.id), rel.min_count, rel.max_count
			])
		if rel.min_distance < 0.0 or rel.max_distance < rel.min_distance:
			result.add_error("Room '%s' relationship '%s' invalid distance range [%f, %f]." % [
				str(room.id), str(rel.id), rel.min_distance, rel.max_distance
			])

	# Templates & Spatial Constraints
	if room.template_constraints != null:
		var tc = room.template_constraints
		if "template_registry" in bundle and bundle.template_registry != null:
			var reg = bundle.template_registry
			for t_id in tc.allowed_templates:
				if not reg.has_template(t_id):
					result.add_error("Room '%s' references unknown allowed template '%s'." % [str(room.id), str(t_id)])
			for t_id in tc.preferred_templates:
				if not reg.has_template(t_id):
					result.add_error("Room '%s' references unknown preferred template '%s'." % [str(room.id), str(t_id)])
				elif not tc.is_template_allowed(t_id):
					result.add_error("Room '%s' preferred template '%s' is not in allowed_templates." % [str(room.id), str(t_id)])

func _validate_light_settings(context_name: String, settings, result: _ProfileValidationResultScript) -> void:
	if settings == null:
		return
	if settings.has_energy() and settings.energy < 0.0:
		result.add_error("%s energy cannot be negative (%f)." % [context_name, settings.energy])
	if settings.has_range() and settings.light_range <= 0.0:
		result.add_error("%s range must be strictly positive (%f)." % [context_name, settings.light_range])
