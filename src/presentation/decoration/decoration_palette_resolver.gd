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

	# 1. Chequear si la sala tiene iluminación definida en el bundle
	if bundle != null and bundle.has_room(purp_id):
		var r_prof := bundle.get_room(purp_id)
		if r_prof != null and r_prof.lighting != null:
			var lit = r_prof.lighting
			var torch_style = _FixtureStyleScript.new(
				&"wall_torch",
				_FixtureStyleScript.Type.TORCH,
				_FixturePlacementModeScript.Mode.WALL,
				1.0,
				Vector3(0.0, 2.0, 0.0),
				false,
				_FixtureCollisionModeScript.Mode.NONE,
				true,
				lit.color if "color" in lit else Color(1.0, 0.7, 0.3, 1.0),
				lit.energy if "energy" in lit else 1.2,
				lit.range if "range" in lit else 7.0
			)
			entries.append(_FixturePaletteEntryScript.new(torch_style, 1.0, 2, 4))

	if entries.is_empty():
		# Fixture genérico universal
		var def_torch = _FixtureStyleScript.new(
			&"generic_torch",
			_FixtureStyleScript.Type.TORCH,
			_FixturePlacementModeScript.Mode.WALL,
			1.0,
			Vector3(0.0, 2.0, 0.0),
			false,
			_FixtureCollisionModeScript.Mode.NONE,
			true,
			Color(1.0, 0.7, 0.3, 1.0),
			1.2,
			6.5
		)
		entries.append(_FixturePaletteEntryScript.new(def_torch, 1.0, 2, 4))

	return _FixturePaletteScript.new(
		&"fixtures_%s" % str(purp_id),
		entries
	)

func _resolve_dynamic_props(bundle: _ProfileBundleScript, purp_id: StringName) -> _PropPaletteScript:
	var entries: Array[_PropPaletteEntryScript] = []

	# Si el bundle tiene la sala definida con composición de props
	if bundle != null and bundle.has_room(purp_id):
		var r_prof := bundle.get_room(purp_id)
		if r_prof != null and r_prof.composition != null:
			var comp = r_prof.composition
			if comp.has_method("get_all_rules"):
				for rule in comp.get_all_rules():
					if rule == null:
						continue
					var matched: bool = false
					if bundle.assets != null:
						for tag in rule.asset_tags:
							var tag_props = bundle.assets.get_props_by_tag(tag)
							for p_entry in tag_props:
								matched = true
								var style = _create_prop_style(str(p_entry.id), bundle.assets, rule.placement_mode)
								entries.append(_PropPaletteEntryScript.new(style, 1.0, rule.min_count, rule.max_count))
						if not matched and bundle.assets.has_prop(rule.rule_id):
							matched = true
							var style = _create_prop_style(str(rule.rule_id), bundle.assets, rule.placement_mode)
							entries.append(_PropPaletteEntryScript.new(style, 1.0, rule.min_count, rule.max_count))
					if not matched and not rule.rule_id.is_empty():
						var style = _create_prop_style(str(rule.rule_id), bundle.assets if bundle != null else null, rule.placement_mode)
						entries.append(_PropPaletteEntryScript.new(style, 1.0, rule.min_count, rule.max_count))
			elif comp is Dictionary:
				var raw_props = comp.get("props", [])
				for p_def in raw_props:
					var prop_name: String = str(p_def.get("prop", p_def.get("name", "")))
					if prop_name.is_empty():
						continue
					var weight: float = float(p_def.get("weight", 1.0))
					var style = _create_prop_style(prop_name, bundle.assets if bundle != null else null)
					entries.append(_PropPaletteEntryScript.new(style, weight, 0, -1))

	if entries.is_empty():
		# Paleta genérica data-driven básica
		var crate = _create_prop_style("crate_wooden_standard", bundle.assets if bundle != null else null)
		var barrel = _create_prop_style("barrel_wood_small", bundle.assets if bundle != null else null)
		var urn = _create_prop_style("crypt_urn_banded_floor", bundle.assets if bundle != null else null)
		var chest = _create_prop_style("chest_wood_small", bundle.assets if bundle != null else null)
		var sarcophagus = _create_prop_style("sarcophagus_stone_closed", bundle.assets if bundle != null else null)

		entries.append(_PropPaletteEntryScript.new(crate, 1.0, 0, -1))
		entries.append(_PropPaletteEntryScript.new(barrel, 0.8, 0, -1))
		entries.append(_PropPaletteEntryScript.new(urn, 0.6, 0, -1))
		entries.append(_PropPaletteEntryScript.new(chest, 0.3, 0, -1))
		entries.append(_PropPaletteEntryScript.new(sarcophagus, 0.5, 0, -1))

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
	var place_str: String = str(placement_hint).to_lower()
	if place_str == "corner":
		place_mode = _PropPlacementModeScript.Mode.CORNER
	elif place_str == "wall":
		place_mode = _PropPlacementModeScript.Mode.WALL
	elif place_str == "center":
		place_mode = _PropPlacementModeScript.Mode.CENTER

	if assets != null and assets.has_method("get_prop"):
		var p_entry = assets.get_prop(id)
		if p_entry != null:
			if "footprint" in p_entry and p_entry.footprint != null:
				if p_entry.footprint is Vector2i:
					fp = _PropFootprintScript.new(p_entry.footprint)
				elif p_entry.footprint is _PropFootprintScript:
					fp = p_entry.footprint
			if place_str.is_empty() and "placement_modes" in p_entry and not p_entry.placement_modes.is_empty():
				var first_p: String = str(p_entry.placement_modes[0]).to_lower()
				if first_p == "corner":
					place_mode = _PropPlacementModeScript.Mode.CORNER
				elif first_p == "wall":
					place_mode = _PropPlacementModeScript.Mode.WALL
				elif first_p == "center":
					place_mode = _PropPlacementModeScript.Mode.CENTER

	if place_str.is_empty():
		if "corner" in prop_name:
			place_mode = _PropPlacementModeScript.Mode.CORNER
		elif "wall" in prop_name:
			place_mode = _PropPlacementModeScript.Mode.WALL
		elif "center" in prop_name:
			place_mode = _PropPlacementModeScript.Mode.CENTER

	return _PropStyleScript.new(
		id,
		type_val,
		place_mode,
		_PropCollisionModeScript.Mode.BLOCKING,
		fp,
		id
	)
