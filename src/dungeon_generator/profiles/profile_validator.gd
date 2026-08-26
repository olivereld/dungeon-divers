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

func _validate_rooms(bundle: _ProfileBundleScript, result: _ProfileValidationResultScript) -> void:
	for r_id in bundle.rooms:
		var room = bundle.rooms[r_id]
		_validate_single_room(room, bundle.assets, result)

func _validate_single_room(room: _ProfileRoomScript, assets, result: _ProfileValidationResultScript) -> void:
	if room == null:
		result.add_error("Null room found in bundle.")
		return

	if room.schema_version != 1:
		result.add_error("Room '%s' schema_version must be 1 (found %d)." % [str(room.id), room.schema_version])
	if room.id == &"":
		result.add_error("Room ID cannot be empty.")

	# Intent
	if room.intent == null:
		result.add_error("Room '%s' missing intent." % str(room.id))

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
