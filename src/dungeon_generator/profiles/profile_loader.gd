class_name ProfileLoader
extends RefCounted

## Único punto de deserialización declarativa de JSON a objetos tipados.
## No ejecuta validación semántica (responsabilidad de ProfileValidator),
## únicamente parsing estructurado y seguro.

const _ProfileArchetypeScript = preload("res://src/dungeon_generator/profiles/profile_archetype.gd")
const _ProfileArchetypeGlobalSettingsScript = preload("res://src/dungeon_generator/profiles/profile_archetype_global_settings.gd")
const _ProfileArchetypeStyleScript = preload("res://src/dungeon_generator/profiles/profile_archetype_style.gd")
const _ProfileArchetypeRoomRulesScript = preload("res://src/dungeon_generator/profiles/profile_archetype_room_rules.gd")
const _ProfileRoomScript = preload("res://src/dungeon_generator/profiles/profile_room.gd")
const _ProfileRoomIntentScript = preload("res://src/dungeon_generator/profiles/profile_room_intent.gd")
const _ProfileCompositionScript = preload("res://src/dungeon_generator/profiles/profile_composition.gd")
const _ProfileCompositionRuleScript = preload("res://src/dungeon_generator/profiles/profile_composition_rule.gd")
const _ProfileLightingScript = preload("res://src/dungeon_generator/profiles/profile_lighting.gd")
const _ProfileLightingSlotScript = preload("res://src/dungeon_generator/profiles/profile_lighting_slot.gd")
const _ProfileRelationshipScript = preload("res://src/dungeon_generator/profiles/profile_relationship.gd")
const _ProfileBundleScript = preload("res://src/dungeon_generator/profiles/profile_bundle.gd")
const _AssetRegistryScript = preload("res://src/dungeon_generator/profiles/asset_registry.gd")
const _AssetPropEntryScript = preload("res://src/dungeon_generator/profiles/assets/asset_prop_entry.gd")
const _AssetFixtureEntryScript = preload("res://src/dungeon_generator/profiles/assets/asset_fixture_entry.gd")
const _AssetMaterialEntryScript = preload("res://src/dungeon_generator/profiles/assets/asset_material_entry.gd")

var base_path: String = "res://resources/dungeon_profiles/"

func _init(p_base_path: String = "res://resources/dungeon_profiles/") -> void:
	base_path = p_base_path
	if not base_path.ends_with("/"):
		base_path += "/"

## Carga el bundle completo: Arquetipo + AssetRegistry + Todas las salas referenciadas.
func load_full_archetype_bundle(archetype_id: String) -> _ProfileBundleScript:
	var assets := load_asset_registry()
	var arch := load_archetype(archetype_id)
	var rooms_map: Dictionary = {}

	if arch != null:
		for purpose_key in arch.rooms:
			var filename: String = str(arch.rooms[purpose_key])
			var room_prof := load_room(filename)
			if room_prof != null:
				rooms_map[StringName(purpose_key)] = room_prof

	return _ProfileBundleScript.new(arch, rooms_map, assets)

## Carga el catálogo completo de Assets (props, fixtures, materials).
func load_asset_registry() -> _AssetRegistryScript:
	var registry := _AssetRegistryScript.new()

	# 1. Props
	var props_json = _read_json_file(base_path + "assets/props.json")
	if props_json is Dictionary and props_json.has("props"):
		var p_dict = props_json["props"]
		for pid in p_dict:
			var pdata = p_dict[pid]
			var tags_arr: Array[StringName] = []
			for t in pdata.get("tags", []):
				tags_arr.append(StringName(t))
			var modes_arr: Array[StringName] = []
			for m in pdata.get("placement_modes", []):
				modes_arr.append(StringName(m))
			var anchors_arr: Array[StringName] = []
			for a in pdata.get("anchors", []):
				anchors_arr.append(StringName(a))

			var fp_dict = pdata.get("footprint", {})
			var fp := Vector2i(int(fp_dict.get("width", 1)), int(fp_dict.get("depth", 1)))

			var prop_entry := _AssetPropEntryScript.new(
				StringName(pid),
				str(pdata.get("scene", "")),
				tags_arr,
				modes_arr,
				fp,
				StringName(pdata.get("collision", "blocking")),
				anchors_arr
			)
			registry.register_prop(prop_entry)

	# 2. Fixtures
	var fix_json = _read_json_file(base_path + "assets/fixtures.json")
	if fix_json is Dictionary and fix_json.has("fixtures"):
		var f_dict = fix_json["fixtures"]
		for fid in f_dict:
			var fdata = f_dict[fid]
			var modes_arr: Array[StringName] = []
			for m in fdata.get("placement_modes", []):
				modes_arr.append(StringName(m))
			var anchors_arr: Array[StringName] = []
			for a in fdata.get("anchors", []):
				anchors_arr.append(StringName(a))
			var tags_arr: Array[StringName] = []
			for t in fdata.get("tags", []):
				tags_arr.append(StringName(t))

			var fix_entry := _AssetFixtureEntryScript.new(
				StringName(fid),
				str(fdata.get("scene", "")),
				StringName(fdata.get("style", "torch")),
				modes_arr,
				anchors_arr,
				tags_arr
			)
			registry.register_fixture(fix_entry)

	# 3. Materials
	var mat_json = _read_json_file(base_path + "assets/materials.json")
	if mat_json is Dictionary and mat_json.has("materials"):
		var m_dict = mat_json["materials"]
		for mid in m_dict:
			var mdata = m_dict[mid]
			var mat_entry := _AssetMaterialEntryScript.new(
				StringName(mid),
				str(mdata.get("floor", "")),
				str(mdata.get("wall", "")),
				str(mdata.get("trim", ""))
			)
			registry.register_material(mat_entry)

	return registry

## Carga un archivo de arquetipo por ID (ej. "mausoleum").
func load_archetype(archetype_id: String) -> _ProfileArchetypeScript:
	var path := base_path + "archetypes/" + archetype_id + ".json"
	var json_data = _read_json_file(path)
	if not (json_data is Dictionary):
		return null

	var dict: Dictionary = json_data
	var id := StringName(dict.get("id", archetype_id))
	var display_name := str(dict.get("display_name", ""))
	var version := int(dict.get("schema_version", 1))

	var weights_raw = dict.get("purpose_weights", {})
	var weights: Dictionary = {}
	if weights_raw is Dictionary:
		for k in weights_raw:
			weights[StringName(k)] = float(weights_raw[k])

	var gameplay_raw = dict.get("gameplay_purpose_map", {})
	var gameplay_map: Dictionary = {}
	if gameplay_raw is Dictionary:
		for k in gameplay_raw:
			var arr: Array[StringName] = []
			for item in gameplay_raw[k]:
				arr.append(StringName(item))
			gameplay_map[StringName(k)] = arr

	var dist_raw = dict.get("room_purpose_distribution", {})
	var dist: Dictionary = {}
	if dist_raw is Dictionary:
		for k in dist_raw:
			dist[StringName(k)] = float(dist_raw[k])

	# Global settings
	var g_raw = dict.get("global_settings", {})
	var global_settings := _ProfileArchetypeGlobalSettingsScript.new(
		int(g_raw.get("min_rooms", 8)),
		int(g_raw.get("max_rooms", 20)),
		float(g_raw.get("decoration_density", 0.65)),
		float(g_raw.get("lighting_density", 0.55)),
		float(g_raw.get("prop_density", 0.60)),
		float(g_raw.get("fixture_density", 0.55))
	)

	# Architectural Style
	var s_raw = dict.get("architectural_style", {})
	var arch_style := _ProfileArchetypeStyleScript.new(
		StringName(s_raw.get("floor_style", "mausoleum")),
		StringName(s_raw.get("wall_style", "mausoleum")),
		StringName(s_raw.get("door_style", "mausoleum")),
		StringName(s_raw.get("stairs_style", "mausoleum")),
		StringName(s_raw.get("material_profile", "mausoleum_stone"))
	)

	# Room rules
	var r_raw = dict.get("room_rules", {})
	var guar_arr: Array[StringName] = []
	for g in r_raw.get("guaranteed", []):
		guar_arr.append(StringName(g))
	var rare_arr: Array[StringName] = []
	for r in r_raw.get("rare", []):
		rare_arr.append(StringName(r))

	var room_rules := _ProfileArchetypeRoomRulesScript.new(
		bool(r_raw.get("allow_duplicate_purposes", true)),
		int(r_raw.get("max_same_purpose_consecutive", 2)),
		guar_arr,
		rare_arr
	)

	# Rooms mapping
	var rooms_raw = dict.get("rooms", {})
	var rooms_dict: Dictionary = {}
	if rooms_raw is Dictionary:
		for k in rooms_raw:
			rooms_dict[StringName(k)] = StringName(rooms_raw[k])

	return _ProfileArchetypeScript.new(
		id, display_name, version, weights, gameplay_map, dist,
		global_settings, arch_style, room_rules, rooms_dict
	)

## Carga un perfil de sala desde su filename (ej. "tomb.json" o "tomb").
func load_room(filename: String) -> _ProfileRoomScript:
	var clean_file := filename if filename.ends_with(".json") else filename + ".json"
	var path := base_path + "rooms/" + clean_file
	var json_data = _read_json_file(path)
	if not (json_data is Dictionary):
		return null

	var dict: Dictionary = json_data
	var id := StringName(dict.get("id", ""))
	var display_name := str(dict.get("display_name", ""))
	var version := int(dict.get("schema_version", 1))

	# Intent
	var intent_raw = dict.get("intent", {})
	var allowed_tags: Array[StringName] = []
	for t in intent_raw.get("allowed_tags", []):
		allowed_tags.append(StringName(t))
	var forbidden_tags: Array[StringName] = []
	for t in intent_raw.get("forbidden_tags", []):
		forbidden_tags.append(StringName(t))

	var intent := _ProfileRoomIntentScript.new(
		StringName(intent_raw.get("type", "transition")),
		bool(intent_raw.get("focal", false)),
		bool(intent_raw.get("symmetry", false)),
		int(intent_raw.get("player_clearance_level", 1)),
		allowed_tags,
		forbidden_tags
	)

	# Composition
	var comp_raw = dict.get("composition", {})
	var primary_rule: _ProfileCompositionRuleScript = null
	var prim_raw = comp_raw.get("primary", null)
	if prim_raw is Dictionary:
		primary_rule = _parse_composition_rule(prim_raw)

	var secondary_rules: Array[_ProfileCompositionRuleScript] = []
	var sec_raw = comp_raw.get("secondary", [])
	if sec_raw is Array:
		for s in sec_raw:
			if s is Dictionary:
				secondary_rules.append(_parse_composition_rule(s))

	var support_rules: Array[_ProfileCompositionRuleScript] = []
	var sup_raw = comp_raw.get("support", [])
	if sup_raw is Array:
		for s in sup_raw:
			if s is Dictionary:
				support_rules.append(_parse_composition_rule(s))

	var composition := _ProfileCompositionScript.new(primary_rule, secondary_rules, support_rules)


	# Lighting
	var light_raw = dict.get("lighting", {})
	var budget := float(light_raw.get("budget", 4.0))
	var fix_slots = light_raw.get("fixtures", {})

	var wall_slot := _parse_lighting_slot(fix_slots.get("wall", {}))
	var floor_slot := _parse_lighting_slot(fix_slots.get("floor", {}))
	var hanging_slot := _parse_lighting_slot(fix_slots.get("hanging", {}))

	var lighting := _ProfileLightingScript.new(budget, wall_slot, floor_slot, hanging_slot)

	# Relationships
	var rels_raw = dict.get("relationships", [])
	var relationships: Array[_ProfileRelationshipScript] = []
	if rels_raw is Array:
		for r in rels_raw:
			if r is Dictionary:
				var r_id := StringName(r.get("id", ""))
				var src_arr: Array[StringName] = []
				for s in r.get("source", []):
					src_arr.append(StringName(s))
				var tgt_arr: Array[StringName] = []
				for t in r.get("targets", []):
					tgt_arr.append(StringName(t))
				var forb_arr: Array[StringName] = []
				for f in r.get("forbidden_targets", []):
					forb_arr.append(StringName(f))

				relationships.append(_ProfileRelationshipScript.new(
					r_id,
					src_arr,
					tgt_arr,
					forb_arr,
					StringName(r.get("placement", "near")),
					int(r.get("min_count", 1)),
					int(r.get("max_count", 2)),
					float(r.get("min_distance", 1.0)),
					float(r.get("max_distance", 2.0))
				))

	return _ProfileRoomScript.new(id, display_name, version, intent, composition, lighting, relationships)

func _parse_composition_rule(raw: Dictionary) -> _ProfileCompositionRuleScript:
	var rule_id := StringName(raw.get("rule_id", ""))
	var tags_arr: Array[StringName] = []
	for t in raw.get("asset_tags", []):
		tags_arr.append(StringName(t))
	var forb_arr: Array[StringName] = []
	for f in raw.get("forbidden_tags", []):
		forb_arr.append(StringName(f))

	var p_raw = raw.get("placement", {})
	var mode := StringName(p_raw.get("mode", "floor"))
	var orientation := StringName(p_raw.get("orientation", "face_room"))
	var min_c := int(p_raw.get("min_count", 1))
	var max_c := int(p_raw.get("max_count", 1))
	var clearance := int(p_raw.get("clearance", 0))

	return _ProfileCompositionRuleScript.new(
		rule_id, tags_arr, forb_arr, mode, orientation, min_c, max_c, clearance
	)

func _parse_lighting_slot(raw: Dictionary) -> _ProfileLightingSlotScript:
	var min_c := int(raw.get("min", 0))
	var max_c := int(raw.get("max", 0))
	var allowed: Array[StringName] = []
	for a in raw.get("allowed", []):
		allowed.append(StringName(a))
	return _ProfileLightingSlotScript.new(min_c, max_c, allowed)

func _read_json_file(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(content)
	if error != OK:
		return null
	return json.data
