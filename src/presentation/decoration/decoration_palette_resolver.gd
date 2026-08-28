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

	var torch = _FixtureStyleScript.new(
		&"wall_torch",
		_FixtureStyleScript.Type.TORCH,
		_FixturePlacementModeScript.Mode.WALL,
		1.0, Vector3(0.0, 2.0, 0.0), false, _FixtureCollisionModeScript.Mode.NONE,
		true, Color(1.0, 0.62, 0.25, 1.0), 1.4, 6.5
	)
	var wall_lantern = _FixtureStyleScript.new(
		&"wall_lantern",
		_FixtureStyleScript.Type.LANTERN,
		_FixturePlacementModeScript.Mode.WALL,
		1.0, Vector3(0.0, 2.0, 0.0), true, _FixtureCollisionModeScript.Mode.NONE,
		true, Color(0.376, 0.161, 0.671, 1.0), 1.5, 7.0
	)
	var hanging_lantern = _FixtureStyleScript.new(
		&"hanging_lantern",
		_FixtureStyleScript.Type.LANTERN,
		_FixturePlacementModeScript.Mode.HANGING,
		1.0, Vector3.ZERO, false, _FixtureCollisionModeScript.Mode.NONE,
		true, Color(0.376, 0.161, 0.671, 1.0), 1.6, 7.5
	)
	var brazier = _FixtureStyleScript.new(
		&"floor_brazier",
		_FixtureStyleScript.Type.BRAZIER,
		_FixturePlacementModeScript.Mode.FLOOR,
		1.0, Vector3.ZERO, true, _FixtureCollisionModeScript.Mode.STATIC_BODY,
		true, Color(1.0, 0.5, 0.2, 1.0), 2.2, 9.0
	)
	var candle_cluster = _FixtureStyleScript.new(
		&"floor_candles",
		_FixtureStyleScript.Type.CANDLE_CLUSTER,
		_FixturePlacementModeScript.Mode.FLOOR,
		1.0, Vector3.ZERO, false, _FixtureCollisionModeScript.Mode.NONE,
		true, Color(1.0, 0.8, 0.5, 1.0), 0.8, 4.0
	)

	entries.append(_FixturePaletteEntryScript.new(torch, 1.0, 1.0))
	entries.append(_FixturePaletteEntryScript.new(wall_lantern, 0.5, 1.0))
	entries.append(_FixturePaletteEntryScript.new(hanging_lantern, 0.5, 1.0))
	entries.append(_FixturePaletteEntryScript.new(brazier, 0.8, 1.0))
	entries.append(_FixturePaletteEntryScript.new(candle_cluster, 0.6, 1.0))

	return _FixturePaletteScript.new(
		&"fixtures_%s" % str(purp_id),
		entries
	)

func _resolve_dynamic_props(bundle: _ProfileBundleScript, purp_id: StringName) -> _PropPaletteScript:
	var entries: Array[_PropPaletteEntryScript] = []

	# Si el bundle tiene la sala definida con composición de props
	if bundle != null and bundle.has_room(purp_id):
		var r_prof := bundle.get_room(purp_id)
		if r_prof != null and r_prof.composition != null and not r_prof.composition.props.is_empty():
			for p_def in r_prof.composition.props:
				var prop_name: String = str(p_def.get("prop", p_def.get("name", "")))
				if prop_name.is_empty():
					continue

				var weight: float = float(p_def.get("weight", 1.0))
				var role_str: String = str(p_def.get("role", "SUPPORT")).to_upper()
				var role: _DecorationRoleScript.Role = _DecorationRoleScript.Role.SUPPORT
				if role_str == "FOCAL" or role_str == "FEATURE":
					role = _DecorationRoleScript.Role.FOCAL
				elif role_str == "AMBIENT" or role_str == "SCATTER":
					role = _DecorationRoleScript.Role.AMBIENT
				elif role_str == "FUNCTIONAL" or role_str == "STORAGE":
					role = _DecorationRoleScript.Role.FUNCTIONAL

				var style = _create_prop_style(prop_name, bundle.assets)
				entries.append(_PropPaletteEntryScript.new(style, weight, 0, -1))

	if entries.is_empty():
		# Paleta genérica data-driven básica
		var crate = _create_prop_style("wooden_crate", bundle.assets if bundle != null else null)
		var barrel = _create_prop_style("barrel", bundle.assets if bundle != null else null)
		var urn = _create_prop_style("urn", bundle.assets if bundle != null else null)
		var chest = _create_prop_style("chest", bundle.assets if bundle != null else null)
		var sarcophagus = _create_prop_style("sarcophagus", bundle.assets if bundle != null else null)

		entries.append(_PropPaletteEntryScript.new(crate, 1.0, 0, -1))
		entries.append(_PropPaletteEntryScript.new(barrel, 0.8, 0, -1))
		entries.append(_PropPaletteEntryScript.new(urn, 0.6, 0, -1))
		entries.append(_PropPaletteEntryScript.new(chest, 0.3, 0, -1))
		entries.append(_PropPaletteEntryScript.new(sarcophagus, 0.5, 0, -1))

	return _PropPaletteScript.new(&"props_%s" % str(purp_id), entries)

func _create_prop_style(prop_name: String, assets = null) -> _PropStyleScript:
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

	if assets != null and assets.has_method("get_prop"):
		var p_entry = assets.get_prop(id)
		if p_entry != null and "footprint" in p_entry and p_entry.footprint != null:
			fp = p_entry.footprint

	return _PropStyleScript.new(
		id,
		type_val,
		_PropPlacementModeScript.Mode.FLOOR,
		_PropCollisionModeScript.Mode.BLOCKING,
		fp,
		id
	)
