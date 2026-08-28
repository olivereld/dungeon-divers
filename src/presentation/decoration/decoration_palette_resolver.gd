class_name DecorationPaletteResolver
extends RefCounted

## Resolvedor puro y data-driven de paletas de decoración a partir de arquetipos, propósitos y ProfileBundles.
## Construye paletas de fixtures y props dinámicamente a partir de los datos declarativos JSON (o fallbacks genéricos).
## 100% puro: no crea nodos ni mallas 3D.

const _DecorationPaletteScript = preload("res://src/presentation/decoration/decoration_palette.gd")
const _FixturePaletteScript = preload("res://src/presentation/fixtures/fixture_palette.gd")
const _FixturePaletteEntryScript = preload("res://src/presentation/fixtures/fixture_palette_entry.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const _FixtureCollisionModeScript = preload("res://src/presentation/fixtures/fixture_collision_mode.gd")
const _PropPaletteScript = preload("res://src/presentation/props/prop_palette.gd")
const _PropPaletteEntryScript = preload("res://src/presentation/props/prop_palette_entry.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const _PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")
const _PropCollisionModeScript = preload("res://src/presentation/props/prop_collision_mode.gd")
const _PropFootprintScript = preload("res://src/presentation/props/prop_footprint.gd")
const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const _DecorationRoleScript = preload("res://src/presentation/decoration/decoration_role.gd")
const _DecorationTagScript = preload("res://src/presentation/decoration/composition/decoration_tag.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _ProfileRoomScript = preload("res://src/dungeon_generator/profiles/profile_room.gd")
const _ProfileBundleScript = preload("res://src/dungeon_generator/profiles/profile_bundle.gd")
const _ProfileCompositionScript = preload("res://src/dungeon_generator/profiles/profile_composition.gd")
const _ProfileCompositionRuleScript = preload("res://src/dungeon_generator/profiles/profile_composition_rule.gd")

var _loader: _ProfileLoaderScript = null

func _init(loader: _ProfileLoaderScript = null) -> void:
	_loader = loader if loader != null else _ProfileLoaderScript.new()

## Resuelve la paleta de decoración completa (fixtures + props) para una sala a partir de un ID de arquetipo dinámico.
func resolve_palette_by_id(
	archetype_id: Variant,
	room_purpose: Variant,
	profile: _ArchitecturalPresentationProfileScript = null,
	bundle: _ProfileBundleScript = null
) -> _DecorationPaletteScript:
	var arch_id := _DungeonArchetypeScript.resolve_id(archetype_id)
	var purp_id := _RoomPurposeScript.resolve_id(room_purpose)

	var active_bundle := bundle
	if active_bundle == null and _loader != null:
		active_bundle = _loader.load_full_archetype_bundle(str(arch_id))

	var fix_palette: _FixturePaletteScript = _resolve_dynamic_fixtures(active_bundle, purp_id)
	var prop_palette: _PropPaletteScript = _resolve_dynamic_props(active_bundle, purp_id)

	return _DecorationPaletteScript.new(
		&"dec_palette_%s_%s" % [str(arch_id), str(purp_id)],
		fix_palette,
		prop_palette
	)

func resolve_palette_for_archetype(
	archetype_id: Variant,
	room_purpose: Variant,
	profile: _ArchitecturalPresentationProfileScript = null,
	bundle: _ProfileBundleScript = null
) -> _DecorationPaletteScript:
	return resolve_palette_by_id(archetype_id, room_purpose, profile, bundle)

func resolve_palette(
	archetype: Variant,
	room_purpose: Variant,
	profile: _ArchitecturalPresentationProfileScript = null
) -> _DecorationPaletteScript:
	return resolve_palette_by_id(archetype, room_purpose, profile)

# ==============================================================================
# Dynamic Fixtures & Props Builders
# ==============================================================================

func _resolve_dynamic_fixtures(bundle: _ProfileBundleScript, purp_id: StringName) -> _FixturePaletteScript:
	var entries: Array[_FixturePaletteEntryScript] = []
	var added_ids: Dictionary = {}

	# 1. Chequear si la sala tiene iluminación definida en el bundle
	if bundle != null and bundle.has_room(purp_id):
		var r_prof := bundle.get_room(purp_id)
		if r_prof != null and r_prof.lighting != null:
			var lit = r_prof.lighting

			# Wall fixtures
			if lit.wall != null:
				for fix_name in lit.wall.allowed:
					var f_id := StringName(str(fix_name))
					if not added_ids.has(f_id):
						added_ids[f_id] = true
						var style = _create_fixture_style(f_id, _FixturePlacementModeScript.Mode.WALL, lit)
						entries.append(_FixturePaletteEntryScript.new(style, 1.0, lit.wall.min_count, lit.wall.max_count))

			# Floor fixtures (Braziers, floor candles, candelabras)
			if lit.floor != null:
				for fix_name in lit.floor.allowed:
					var f_id := StringName(str(fix_name))
					if not added_ids.has(f_id):
						added_ids[f_id] = true
						var style = _create_fixture_style(f_id, _FixturePlacementModeScript.Mode.FLOOR, lit)
						entries.append(_FixturePaletteEntryScript.new(style, 1.0, lit.floor.min_count, lit.floor.max_count))

			# Hanging fixtures
			if lit.hanging != null:
				for fix_name in lit.hanging.allowed:
					var f_id := StringName(str(fix_name))
					if not added_ids.has(f_id):
						added_ids[f_id] = true
						var style = _create_fixture_style(f_id, _FixturePlacementModeScript.Mode.HANGING, lit)
						entries.append(_FixturePaletteEntryScript.new(style, 1.0, lit.hanging.min_count, lit.hanging.max_count))

			# Relational fixtures (near sarcophagus, altar, etc.)
			if r_prof.relationships != null:
				for rel in r_prof.relationships:
					for t_name in rel.targets:
						var f_id := StringName(str(t_name))
						if not added_ids.has(f_id):
							added_ids[f_id] = true
							var place_mode = _FixturePlacementModeScript.Mode.FLOOR
							if "hanging" in str(f_id) or str(rel.placement).to_lower() == "above":
								place_mode = _FixturePlacementModeScript.Mode.HANGING
							elif "wall" in str(f_id):
								place_mode = _FixturePlacementModeScript.Mode.WALL
							var style = _create_fixture_style(f_id, place_mode, lit)
							entries.append(_FixturePaletteEntryScript.new(style, 1.0, rel.min_count, rel.max_count))

	if entries.is_empty():
		# Paleta genérica completa de fixtures
		var torch = _create_fixture_style(&"wall_torch", _FixturePlacementModeScript.Mode.WALL)
		var brazier = _create_fixture_style(&"brazier", _FixturePlacementModeScript.Mode.FLOOR)
		var candles = _create_fixture_style(&"candle_cluster", _FixturePlacementModeScript.Mode.FLOOR)
		var lantern = _create_fixture_style(&"wall_lantern", _FixturePlacementModeScript.Mode.WALL)
		entries.append(_FixturePaletteEntryScript.new(torch, 1.0, 1, 4))
		entries.append(_FixturePaletteEntryScript.new(brazier, 0.8, 1, 2))
		entries.append(_FixturePaletteEntryScript.new(candles, 0.6, 0, 2))
		entries.append(_FixturePaletteEntryScript.new(lantern, 0.5, 0, 2))

	return _FixturePaletteScript.new(
		&"fixtures_%s" % str(purp_id),
		entries
	)

func _create_fixture_style(fixture_id: StringName, mode: int, lighting_data = null) -> _FixtureStyleScript:
	var f_type: _FixtureStyleScript.Type = _FixtureStyleScript.Type.TORCH
	var f_name := str(fixture_id).to_lower()
	if "lantern" in f_name:
		f_type = _FixtureStyleScript.Type.LANTERN
	elif "brazier" in f_name:
		f_type = _FixtureStyleScript.Type.BRAZIER
	elif "candle_holder" in f_name or "candelabra" in f_name:
		f_type = _FixtureStyleScript.Type.CANDLE_HOLDER
	elif "candle" in f_name or "cluster" in f_name:
		f_type = _FixtureStyleScript.Type.CANDLE_CLUSTER

	var col: Color = Color(1.0, 0.7, 0.3, 1.0)
	var energy: float = 1.2
	var light_range: float = 6.5
	var offset := Vector3(0.0, 2.0, 0.0)

	if mode == _FixturePlacementModeScript.Mode.FLOOR:
		offset = Vector3(0.0, 0.0, 0.0)
	elif mode == _FixturePlacementModeScript.Mode.HANGING:
		offset = Vector3(0.0, 3.5, 0.0)

	if lighting_data != null:
		if "color" in lighting_data and lighting_data.color != null:
			col = lighting_data.color
		if "energy" in lighting_data and lighting_data.energy > 0.0:
			energy = lighting_data.energy
		if "range" in lighting_data and lighting_data.range > 0.0:
			light_range = lighting_data.range

	return _FixtureStyleScript.new(
		fixture_id,
		f_type,
		mode,
		1.0,
		offset,
		false,
		_FixtureCollisionModeScript.Mode.NONE,
		true,
		col,
		energy,
		light_range
	)

func _resolve_dynamic_props(bundle: _ProfileBundleScript, purp_id: StringName) -> _PropPaletteScript:
	var entries: Array[_PropPaletteEntryScript] = []
	var added_prop_ids: Dictionary = {}

	# Si el bundle tiene la sala definida con composición de props
	if bundle != null and bundle.has_room(purp_id):
		var r_prof := bundle.get_room(purp_id)
		if r_prof != null:
			# 1. Cargar props de las reglas específicas de composición
			if r_prof.composition != null and r_prof.composition.has_method("get_all_rules"):
				for rule in r_prof.composition.get_all_rules():
					if rule == null:
						continue
					if bundle.assets != null:
						if not rule.asset_tags.is_empty():
							var candidate_props = bundle.assets.get_props_by_tag(rule.asset_tags[0])
							for p_entry in candidate_props:
								var all_tags_match: bool = true
								for tag in rule.asset_tags:
									if not p_entry.has_tag(tag):
										all_tags_match = false
										break
								if all_tags_match and rule.forbidden_tags != null:
									for f_tag in rule.forbidden_tags:
										if p_entry.has_tag(f_tag):
											all_tags_match = false
											break
								if all_tags_match and not added_prop_ids.has(p_entry.id):
									added_prop_ids[p_entry.id] = true
									var style = _create_prop_style(str(p_entry.id), bundle.assets)
									entries.append(_PropPaletteEntryScript.new(style, 1.0, rule.min_count, rule.max_count))
						if bundle.assets.has_prop(rule.rule_id):
							if not added_prop_ids.has(rule.rule_id):
								added_prop_ids[rule.rule_id] = true
								var style = _create_prop_style(str(rule.rule_id), bundle.assets)
								entries.append(_PropPaletteEntryScript.new(style, 1.0, rule.min_count, rule.max_count))
					elif not rule.rule_id.is_empty():
						if not added_prop_ids.has(rule.rule_id):
							added_prop_ids[rule.rule_id] = true
							var style = _create_prop_style(str(rule.rule_id), null)
							entries.append(_PropPaletteEntryScript.new(style, 1.0, rule.min_count, rule.max_count))

			# 2. Cargar props adicionales permitidos por el intent de la sala
			if r_prof.intent != null and bundle.assets != null:
				for tag in r_prof.intent.allowed_tags:
					var tag_props = bundle.assets.get_props_by_tag(tag)
					for p_entry in tag_props:
						var is_forbidden: bool = false
						if r_prof.intent.forbidden_tags != null:
							for f_tag in r_prof.intent.forbidden_tags:
								if p_entry.has_tag(f_tag):
									is_forbidden = true
									break
						if not is_forbidden and not added_prop_ids.has(p_entry.id):
							added_prop_ids[p_entry.id] = true
							var style = _create_prop_style(str(p_entry.id), bundle.assets)
							entries.append(_PropPaletteEntryScript.new(style, 1.0, 0, 2))

	if entries.is_empty() and bundle != null and bundle.assets != null:
		# Fallback data-driven: Poblar desde todos los props registrados en el AssetRegistry
		for p_entry in bundle.assets.props.values():
			var style = _create_prop_style(str(p_entry.id), bundle.assets)
			entries.append(_PropPaletteEntryScript.new(style, 1.0, 0, -1))

	return _PropPaletteScript.new(&"props_%s" % str(purp_id), entries)

func _create_prop_style(prop_name: String, assets = null, placement_hint: StringName = &"") -> _PropStyleScript:
	var id := StringName(prop_name.to_lower())
	var fp := _PropFootprintScript.new(Vector2i(1, 1))
	var type_val: _PropStyleScript.Type = _PropStyleScript.Type.CRATE
	if "sarcophagus" in prop_name:
		type_val = _PropStyleScript.Type.SARCOPHAGUS
	elif "urn" in prop_name:
		type_val = _PropStyleScript.Type.URN
	elif "barrel" in prop_name:
		type_val = _PropStyleScript.Type.BARREL
	elif "chest" in prop_name:
		type_val = _PropStyleScript.Type.CHEST
	elif "altar" in prop_name:
		type_val = _PropStyleScript.Type.ALTAR
	elif "bench" in prop_name or "pew" in prop_name:
		type_val = _PropStyleScript.Type.BENCH
	elif "bookshelf" in prop_name:
		type_val = _PropStyleScript.Type.BOOKSHELF
	elif "table" in prop_name:
		type_val = _PropStyleScript.Type.TABLE
	elif "chair" in prop_name:
		type_val = _PropStyleScript.Type.CHAIR
	elif "tombstone" in prop_name:
		type_val = _PropStyleScript.Type.TOMBSTONE
	elif "pillar" in prop_name:
		type_val = _PropStyleScript.Type.PILLAR

	var place_mode: _PropPlacementModeScript.Mode = _PropPlacementModeScript.Mode.FLOOR
	var prop_tags: Array[StringName] = []
	var prop_role: int = _DecorationRoleScript.Role.SUPPORT

	if assets != null and assets.has_method("get_prop"):
		var p_entry = assets.get_prop(id)
		if p_entry != null:
			if "tags" in p_entry and p_entry.tags != null:
				for t in p_entry.tags:
					prop_tags.append(StringName(str(t)))
			if "footprint" in p_entry and p_entry.footprint != null:
				if p_entry.footprint is Vector2i:
					fp = _PropFootprintScript.new(p_entry.footprint)
				elif p_entry.footprint is _PropFootprintScript:
					fp = p_entry.footprint
			if "placement_modes" in p_entry and not p_entry.placement_modes.is_empty():
				var first_p: String = str(p_entry.placement_modes[0]).to_lower()
				if first_p == "corner":
					place_mode = _PropPlacementModeScript.Mode.CORNER
				elif first_p == "wall":
					place_mode = _PropPlacementModeScript.Mode.WALL
				elif first_p == "center":
					place_mode = _PropPlacementModeScript.Mode.CENTER
				elif first_p == "floor":
					place_mode = _PropPlacementModeScript.Mode.FLOOR

	if place_mode == _PropPlacementModeScript.Mode.FLOOR and not placement_hint.is_empty():
		var place_str: String = str(placement_hint).to_lower()
		if place_str == "corner":
			place_mode = _PropPlacementModeScript.Mode.CORNER
		elif place_str == "wall":
			place_mode = _PropPlacementModeScript.Mode.WALL
		elif place_str == "center":
			place_mode = _PropPlacementModeScript.Mode.CENTER

	if prop_tags.is_empty():
		prop_tags.append(id)
		match type_val:
			_PropStyleScript.Type.CHEST:
				prop_tags.append_array([&"chest", &"treasure", &"storage"])
			_PropStyleScript.Type.PILLAR:
				prop_tags.append_array([&"pillar", &"architectural", &"structural"])
			_PropStyleScript.Type.TABLE:
				prop_tags.append_array([&"table", &"furniture", &"storage"])
			_PropStyleScript.Type.BENCH:
				prop_tags.append_array([&"bench", &"seating", &"furniture"])
			_PropStyleScript.Type.BOOKSHELF:
				prop_tags.append_array([&"bookshelf", &"furniture", &"storage"])
			_PropStyleScript.Type.BARREL, _PropStyleScript.Type.CRATE:
				prop_tags.append_array([&"storage", &"debris"])
			_PropStyleScript.Type.ALTAR:
				prop_tags.append_array([&"altar", &"ceremonial", &"focal"])
			_PropStyleScript.Type.SARCOPHAGUS, _PropStyleScript.Type.TOMBSTONE, _PropStyleScript.Type.URN:
				prop_tags.append_array([&"burial", &"detail"])

	return _PropStyleScript.new(
		id,
		type_val,
		place_mode,
		_PropCollisionModeScript.Mode.BLOCKING,
		fp,
		id,
		{},
		prop_role,
		prop_tags
	)
