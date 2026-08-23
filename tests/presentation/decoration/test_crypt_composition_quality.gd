extends SceneTree

const _DecorationCompositionPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const _DecorationPurposeProfileRegistryScript = preload("res://src/presentation/decoration/composition/decoration_purpose_profile_registry.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const _DecorationRoleScript = preload("res://src/presentation/decoration/decoration_role.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_crypt_composition_quality (Multi-Room & Multi-Seed) ---")
	print("==================================================================")

	var planner := _DecorationCompositionPlannerScript.new()
	var registry := _DecorationPurposeProfileRegistryScript.new()
	var pal_resolver := _DecorationPaletteResolverScript.new()

	var floor_cells: Array[Vector2i] = []
	for x in range(6):
		for y in range(6):
			floor_cells.append(Vector2i(x, y))

	var room_geom = _PresentationRoomGeometryScript.new(
		0,
		Rect2i(0, 0, 6, 6),
		floor_cells,
		[],
		[Vector2i(3, 5)],
		null,
		[]
	)

	var tested_purposes: Array = [
		_RoomPurposeScript.Type.TOMB,
		_RoomPurposeScript.Type.ROYAL_TOMB,
		_RoomPurposeScript.Type.MORTUARY,
		_RoomPurposeScript.Type.SACRISTY,
		_RoomPurposeScript.Type.CATACOMB,
		_RoomPurposeScript.Type.ANTECHAMBER,
		_RoomPurposeScript.Type.ENTRANCE
	]

	for purpose in tested_purposes:
		var prof = registry.get_profile_for_purpose(purpose)
		var pal = pal_resolver.resolve_palette(_DungeonArchetypeScript.Type.MAUSOLEUM, purpose)

		for seed_val in [101, 202, 303, 404, 505]:
			var comp = planner.plan_room_composition(
				null,
				pal,
				room_geom,
				{"purpose": purpose},
				null,
				{"prop_seed": seed_val, "fixture_seed": seed_val + 50},
				2.0
			)

			assert(comp != null, "Composition cannot be null")

			# 1. Check light source sanity (no fire hazard)
			var light_count: int = 0
			for f_dir in comp.fixture_directives:
				if f_dir.style != null and f_dir.style.has_light:
					light_count += 1
			assert(light_count <= 6, "Room %s with seed %d has %d lights (exceeds budget max 6)" % [_RoomPurposeScript.to_name(purpose), seed_val, light_count])

			# 2. Check forbidden seating in Catacomb, Tomb, Entrance
			if purpose in [_RoomPurposeScript.Type.CATACOMB, _RoomPurposeScript.Type.TOMB, _RoomPurposeScript.Type.ENTRANCE]:
				for p_dir in comp.prop_directives:
					if p_dir.style != null and p_dir.style.prop_type == _PropStyleScript.Type.BENCH:
						assert(false, "Room %s must not contain bench props" % _RoomPurposeScript.to_name(purpose))

			# 3. Check entrance minimalism
			if purpose == _RoomPurposeScript.Type.ENTRANCE:
				assert(comp.prop_directives.size() <= 2, "Entrance must have <= 2 props, got %d" % comp.prop_directives.size())

	print("[PASS] test_crypt_composition_quality passed across all Crypt room purposes and seeds!")
	quit(0)
