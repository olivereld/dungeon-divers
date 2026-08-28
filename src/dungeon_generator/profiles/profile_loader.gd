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
const _ProfileRoomArchitectureScript = preload("res://src/dungeon_generator/profiles/profile_room_architecture.gd")
const _ProfileWallVariantPolicyScript = preload("res://src/dungeon_generator/profiles/profile_wall_variant_policy.gd")
const _ProfileFloorVariantPolicyScript = preload("res://src/dungeon_generator/profiles/profile_floor_variant_policy.gd")
const _ProfileCompositionScript = preload("res://src/dungeon_generator/profiles/profile_composition.gd")
const _ProfileCompositionRuleScript = preload("res://src/dungeon_generator/profiles/profile_composition_rule.gd")
const _ProfileLightingScript = preload("res://src/dungeon_generator/profiles/profile_lighting.gd")
const _ProfileLightingSlotScript = preload("res://src/dungeon_generator/profiles/profile_lighting_slot.gd")
const _ProfileLightSettingsScript = preload("res://src/dungeon_generator/profiles/profile_light_settings.gd")
const _ProfileRelationshipScript = preload("res://src/dungeon_generator/profiles/profile_relationship.gd")
const _ProfileBundleScript = preload("res://src/dungeon_generator/profiles/profile_bundle.gd")
const _AssetRegistryScript = preload("res://src/dungeon_generator/profiles/asset_registry.gd")
const _AssetPropEntryScript = preload("res://src/dungeon_generator/profiles/assets/asset_prop_entry.gd")
const _AssetFixtureEntryScript = preload("res://src/dungeon_generator/profiles/assets/asset_fixture_entry.gd")
const _AssetMaterialEntryScript = preload("res://src/dungeon_generator/profiles/assets/asset_material_entry.gd")
const _AssetArchitectureEntryScript = preload("res://src/dungeon_generator/profiles/assets/asset_architecture_entry.gd")
const _PropAssetDefinitionScript = preload("res://src/presentation/decoration/assets/prop_asset_definition.gd")
const _PropAssetSourceScript = preload("res://src/presentation/decoration/assets/prop_asset_source.gd")
const _DestructibleDefinitionScript = preload("res://src/destruction/core/destructible_definition.gd")
const _ArchetypeCatalogScript = preload("res://src/dungeon_generator/profiles/archetype_catalog.gd")
const _ArchetypeRegistryScript = preload("res://src/dungeon_generator/profiles/archetype_registry.gd")
const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")

var base_path: String = "res://resources/dungeon_profiles/"
var _catalog: _ArchetypeCatalogScript = null
var _archetype_registry: _ArchetypeRegistryScript = null

func _init(p_base_path: String = "res://resources/dungeon_profiles/") -> void:
	base_path = p_base_path
	if not base_path.ends_with("/"):
		base_path += "/"
	_catalog = _ArchetypeCatalogScript.new(base_path + "archetypes/")
	_archetype_registry = _ArchetypeRegistryScript.new(base_path + "archetypes/")

func get_catalog() -> _ArchetypeCatalogScript:
	return _catalog

func get_archetype_registry() -> _ArchetypeRegistryScript:
	return _archetype_registry

func list_available_archetypes() -> Array[StringName]:
	if _catalog != null:
		return _catalog.get_ids()
	if _archetype_registry != null:
		return _archetype_registry.get_available_ids()
	return []

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

			var coll_str: String = "blocking"
			var c_val = pdata.get("collision", "blocking")
			if c_val is Dictionary:
				coll_str = str(c_val.get("mode", "blocking"))
			elif c_val is String:
				coll_str = str(c_val)

			var prop_entry := _AssetPropEntryScript.new(
				StringName(pid),
				str(pdata.get("scene", "")),
				tags_arr,
				modes_arr,
				fp,
				StringName(coll_str),
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

	# 4. Architecture
	var arch_json = _read_json_file(base_path + "assets/architecture.json")
	if arch_json is Dictionary:
		var categories: Array[String] = ["floors", "walls", "doors", "stairs"]
		for cat: String in categories:
			if arch_json.has(cat) and arch_json[cat] is Dictionary:
				var cat_dict: Dictionary = arch_json[cat]
				for aid in cat_dict:
					var adata = cat_dict[aid]
					var single_cat: String = cat.trim_suffix("s")
					var arch_entry := _AssetArchitectureEntryScript.new(
						StringName(aid),
						StringName(adata.get("category", single_cat)),
						StringName(adata.get("style", aid)),
						StringName(adata.get("generator", "procedural")),
						str(adata.get("scene", ""))
					)
					registry.register_architecture(arch_entry)

	return registry

## Popula un PropAssetRegistry con definiciones deserializadas de assets/props.json
func populate_prop_asset_registry(registry) -> void:
	if registry == null:
		return
	var props_json = _read_json_file(base_path + "assets/props.json")
	if not (props_json is Dictionary and props_json.has("props")):
		return

	var p_dict = props_json["props"]
	for pid in p_dict:
		var pdata = p_dict[pid]
		if not (pdata is Dictionary):
			continue
		var prop_id := StringName(pid)
		var source_type: int = _PropAssetSourceScript.SourceType.PROCEDURAL
		var scene_path: String = ""
		var builder_id: StringName = &""
		var params: Dictionary = {}
		var scale_vec := Vector3.ONE

		if pdata.has("scale"):
			var sc = pdata["scale"]
			if sc is float or sc is int:
				scale_vec = Vector3.ONE * float(sc)
			elif sc is Dictionary:
				var def_s = float(sc.get("default", 1.0))
				scale_vec = Vector3.ONE * def_s

		if pdata.has("source") and pdata["source"] is Dictionary:
			var s_dict = pdata["source"]
			var st_str = str(s_dict.get("type", "procedural")).to_lower()
			if st_str == "packed_scene" or st_str == "scene":
				source_type = _PropAssetSourceScript.SourceType.PACKED_SCENE
				scene_path = str(s_dict.get("scene", ""))
			else:
				source_type = _PropAssetSourceScript.SourceType.PROCEDURAL
				builder_id = StringName(s_dict.get("builder_id", ""))
				params = s_dict.get("params", {})
		elif pdata.has("scene") and str(pdata["scene"]) != "":
			source_type = _PropAssetSourceScript.SourceType.PACKED_SCENE
			scene_path = str(pdata["scene"])

		var variants_arr: Array[Dictionary] = []
		if pdata.has("variants") and pdata["variants"] is Array:
			for v in pdata["variants"]:
				if v is Dictionary:
					variants_arr.append(v)
		elif pdata.has("source") and pdata["source"] is Dictionary and pdata["source"].has("variants"):
			for v in pdata["source"]["variants"]:
				if v is Dictionary:
					variants_arr.append(v)

		if source_type == _PropAssetSourceScript.SourceType.PACKED_SCENE and (scene_path != "" or not variants_arr.is_empty()):
			if scene_path == "" or ResourceLoader.exists(scene_path):
				var def = _PropAssetDefinitionScript.new(
					prop_id,
					_PropAssetSourceScript.SourceType.PACKED_SCENE,
					&"",
					{},
					null,
					scale_vec,
					0.0,
					scene_path,
					variants_arr
				)
				registry.register_definition(def)
		elif source_type == _PropAssetSourceScript.SourceType.PROCEDURAL and builder_id != &"":
			var def = _PropAssetDefinitionScript.new(
				prop_id,
				_PropAssetSourceScript.SourceType.PROCEDURAL,
				builder_id,
				params,
				null,
				scale_vec
			)
			registry.register_definition(def)

## Carga un archivo de arquetipo por ID (String, StringName o int legacy).
func load_archetype(archetype_id: Variant) -> _ProfileArchetypeScript:
	var target_id := _DungeonArchetypeScript.resolve_id(archetype_id)
	var path := ""
	if _catalog != null and _catalog.has_archetype(target_id):
		path = _catalog.get_profile_path(target_id)
	elif _archetype_registry != null and _archetype_registry.has_archetype(target_id):
		path = _archetype_registry.get_filepath(target_id)
	else:
		path = base_path + "archetypes/" + str(target_id) + ".json"

	var json_data = _read_json_file(path)
	if not (json_data is Dictionary):
		if target_id == &"mausoleum":
			json_data = _read_json_file(base_path + "archetypes/necropolis.json")
		elif target_id == &"necropolis":
			json_data = _read_json_file(base_path + "archetypes/mausoleum.json")
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
		StringName(s_raw.get("floor_style", "generic")),
		StringName(s_raw.get("wall_style", "generic")),
		StringName(s_raw.get("door_style", "generic")),
		StringName(s_raw.get("stairs_style", "generic")),
		StringName(s_raw.get("material_profile", "generic_stone"))
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

	# Corridor lighting
	var corr_raw = dict.get("corridor", {})
	var corr_light_raw = corr_raw.get("lighting", {})
	var corr_lighting: _ProfileLightingScript = null
	if corr_light_raw is Dictionary and not corr_light_raw.is_empty():
		corr_lighting = _parse_lighting(corr_light_raw)

	return _ProfileArchetypeScript.new(
		id, display_name, version, weights, gameplay_map, dist,
		global_settings, arch_style, room_rules, rooms_dict, corr_lighting
	)

## Parsea un perfil de sala desde un string JSON
func parse_room_from_json_string(json_str: String) -> _ProfileRoomScript:
	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK or not (json.data is Dictionary):
		return null
	return parse_room_dict(json.data as Dictionary)

## Carga un perfil de sala desde su filename (ej. "tomb.json" o "tomb").
func load_room(filename: String) -> _ProfileRoomScript:
	var clean_file := filename if filename.ends_with(".json") else filename + ".json"
	var path := base_path + "rooms/" + clean_file
	var json_data = _read_json_file(path)
	if not (json_data is Dictionary):
		return null
	return parse_room_dict(json_data as Dictionary)

## Parsea un perfil de sala desde un diccionario deserializado
func parse_room_dict(dict: Dictionary) -> _ProfileRoomScript:
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

	# Architecture
	var arch_raw = dict.get("architecture", {})
	var wall_vars_raw = arch_raw.get("wall_variants", {})
	var wall_variant_policy: _ProfileWallVariantPolicyScript = null
	if wall_vars_raw is Dictionary and not wall_vars_raw.is_empty():
		var wv_enabled: bool = bool(wall_vars_raw.get("enabled", true))
		var wv_allowed: Array[StringName] = []
		for a in wall_vars_raw.get("allowed", []):
			wv_allowed.append(StringName(a))
		if wv_allowed.is_empty():
			wv_allowed = [&"normal"]
		var wv_weights: Dictionary = {}
		var raw_w = wall_vars_raw.get("weights", {})
		if raw_w is Dictionary:
			for k in raw_w:
				wv_weights[StringName(k)] = float(raw_w[k])
		wall_variant_policy = _ProfileWallVariantPolicyScript.new(wv_enabled, wv_allowed, wv_weights)

	# Floor & Floor Variants parsing (polimórfico: string o diccionario)
	var floor_raw = arch_raw.get("floor", "")
	var floor_name: StringName = &""
	var floor_variant_policy: _ProfileFloorVariantPolicyScript = null

	if floor_raw is Dictionary:
		var base_data = floor_raw.get("base", "")
		var base_name: StringName = &""
		var base_w: float = 100.0
		if base_data is Dictionary:
			base_name = StringName(str(base_data.get("style", "")))
			base_w = float(base_data.get("weight", 100.0))
		else:
			base_name = StringName(str(base_data))
			base_w = float(floor_raw.get("base_weight", 100.0))

		floor_name = base_name
		var vars_arr: Array[Dictionary] = []
		for v in floor_raw.get("variants", []):
			if v is Dictionary:
				vars_arr.append({
					"style": StringName(str(v.get("style", ""))),
					"weight": float(v.get("weight", 0.0))
				})
		floor_variant_policy = _ProfileFloorVariantPolicyScript.new(
			true,
			base_name,
			base_w,
			vars_arr,
			StringName(str(floor_raw.get("distribution_mode", "weighted")))
		)
	else:
		floor_name = StringName(str(floor_raw))
		floor_variant_policy = _ProfileFloorVariantPolicyScript.new(
			false,
			floor_name,
			100.0,
			[]
		)

	var architecture := _ProfileRoomArchitectureScript.new(
		floor_name,
		StringName(arch_raw.get("walls", arch_raw.get("wall", ""))),
		StringName(arch_raw.get("door", arch_raw.get("doors", ""))),
		StringName(arch_raw.get("stairs", "")),
		wall_variant_policy,
		floor_variant_policy
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
	var lighting := _parse_lighting(light_raw)

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

	return _ProfileRoomScript.new(id, display_name, version, intent, architecture, composition, lighting, relationships)

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

func _parse_light_settings(raw: Dictionary) -> _ProfileLightSettingsScript:
	if raw.is_empty():
		return _ProfileLightSettingsScript.new()

	var col: Color = Color(-1.0, -1.0, -1.0, -1.0)
	var nrg: float = -1.0
	var rng: float = -1.0

	var has_col: bool = false
	var has_nrg: bool = false
	var has_rng: bool = false

	if raw.has("color"):
		var c_val = raw.get("color")
		if c_val is String and not c_val.is_empty():
			col = Color.from_string(c_val, Color(-1.0, -1.0, -1.0, -1.0))
			has_col = true
		elif c_val is Color:
			col = c_val
			has_col = true

	if raw.has("energy"):
		nrg = float(raw.get("energy", -1.0))
		has_nrg = true

	if raw.has("range"):
		rng = float(raw.get("range", -1.0))
		has_rng = true

	var res := _ProfileLightSettingsScript.new(col, nrg, rng)
	res.has_color_override = has_col
	res.has_energy_override = has_nrg
	res.has_range_override = has_rng
	return res

func _parse_lighting(light_raw: Dictionary) -> _ProfileLightingScript:
	var budget := float(light_raw.get("budget", 4.0))

	# Room defaults can be in "defaults" sub-dictionary or shorthand at lighting root level
	var defs_raw = light_raw.get("defaults", {})
	var room_defaults: _ProfileLightSettingsScript = null
	if defs_raw is Dictionary and not defs_raw.is_empty():
		room_defaults = _parse_light_settings(defs_raw)
	elif light_raw.has("color") or light_raw.has("energy") or light_raw.has("range"):
		room_defaults = _parse_light_settings(light_raw)

	var fix_slots = light_raw.get("fixtures", {})
	var wall_slot := _parse_lighting_slot(fix_slots.get("wall", {}))
	var floor_slot := _parse_lighting_slot(fix_slots.get("floor", {}))
	var hanging_slot := _parse_lighting_slot(fix_slots.get("hanging", {}))

	return _ProfileLightingScript.new(budget, room_defaults, wall_slot, floor_slot, hanging_slot)

func _parse_lighting_slot(raw: Dictionary) -> _ProfileLightingSlotScript:
	var min_c := int(raw.get("min", 0))
	var max_c := int(raw.get("max", 0))
	var allowed: Array[StringName] = []
	for a in raw.get("allowed", []):
		allowed.append(StringName(a))

	# Slot override
	var override: _ProfileLightSettingsScript = null
	var ov_raw = raw.get("lighting_override", {})
	if ov_raw is Dictionary and not ov_raw.is_empty():
		override = _parse_light_settings(ov_raw)
	elif raw.has("color") or raw.has("energy") or raw.has("range"):
		override = _parse_light_settings(raw)

	# Asset-specific overrides
	var asset_overrides: Dictionary = {}
	var a_ov_raw = raw.get("lighting_overrides", {})
	if a_ov_raw is Dictionary:
		for aid in a_ov_raw:
			if a_ov_raw[aid] is Dictionary:
				asset_overrides[StringName(aid)] = _parse_light_settings(a_ov_raw[aid])

	return _ProfileLightingSlotScript.new(min_c, max_c, allowed, override, asset_overrides)

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

## Pobla el DestructionRegistry desde destruction.json y bloques inline opcionales en props.json/fixtures.json
func populate_destruction_registry(target_registry) -> void:
	if target_registry == null:
		return

	# 1. Catálogo canónico destruction.json
	var d_json = _read_json_file(base_path + "assets/destruction.json")
	if d_json is Dictionary and d_json.has("destructibles"):
		var d_dict = d_json["destructibles"]
		for did in d_dict:
			var ddata = d_dict[did]
			if ddata is Dictionary:
				var def = _DestructibleDefinitionScript.from_dict(StringName(did), ddata)
				target_registry.register_definition(def)

	# 2. Definiciones inline opcionales en props.json
	var p_json = _read_json_file(base_path + "assets/props.json")
	if p_json is Dictionary and p_json.has("props"):
		var p_dict = p_json["props"]
		for pid in p_dict:
			var pdata = p_dict[pid]
			if pdata is Dictionary and pdata.has("destruction") and pdata["destruction"] is Dictionary:
				var def = _DestructibleDefinitionScript.from_dict(StringName(pid), pdata["destruction"])
				target_registry.register_definition(def)

	# 3. Definiciones inline opcionales en fixtures.json
	var f_json = _read_json_file(base_path + "assets/fixtures.json")
	if f_json is Dictionary and f_json.has("fixtures"):
		var f_dict = f_json["fixtures"]
		for fid in f_dict:
			var fdata = f_dict[fid]
			if fdata is Dictionary and fdata.has("destruction") and fdata["destruction"] is Dictionary:
				var def = _DestructibleDefinitionScript.from_dict(StringName(fid), fdata["destruction"])
				target_registry.register_definition(def)
