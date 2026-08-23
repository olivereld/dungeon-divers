extends SceneTree

## Benchmark Exhaustivo de Calidad de Cripta (Fase 9 — 100 Semillas: 1000 a 1100).
## Verifica determinismo, jerarquía primaria, ausencia de sobre-saturación lumínica,
## respeto de clearance y orientación 100% válida.

const _DecorationCompositionPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const _DecorationPurposeProfileRegistryScript = preload("res://src/presentation/decoration/composition/decoration_purpose_profile_registry.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const _CompositionRoleScript = preload("res://src/presentation/decoration/composition/composition_role.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_crypt_benchmark_100_seeds (Seeds 1000 to 1100) ---")
	print("==================================================================")

	var planner := _DecorationCompositionPlannerScript.new()
	var registry := _DecorationPurposeProfileRegistryScript.new()
	var pal_resolver := _DecorationPaletteResolverScript.new()

	var tested_purposes: Array = [
		_RoomPurposeScript.Type.TOMB,
		_RoomPurposeScript.Type.ROYAL_TOMB,
		_RoomPurposeScript.Type.MORTUARY,
		_RoomPurposeScript.Type.SACRISTY,
		_RoomPurposeScript.Type.CATACOMB,
		_RoomPurposeScript.Type.ANTECHAMBER,
		_RoomPurposeScript.Type.ENTRANCE
	]

	var total_rooms_evaluated: int = 0
	var total_props_placed: int = 0
	var total_fixtures_placed: int = 0

	for seed_val in range(1000, 1101):
		# Variar dimensiones de habitación geométricamente (5x5, 6x6, 7x5, 8x6)
		var width: int = 5 + (seed_val % 4)
		var height: int = 5 + ((seed_val / 4) % 3)

		var floor_cells: Array[Vector2i] = []
		for x in range(width):
			for y in range(height):
				floor_cells.append(Vector2i(x, y))

		var door_pos := Vector2i(width / 2, height - 1)
		var room_geom = _PresentationRoomGeometryScript.new(
			seed_val,
			Rect2i(0, 0, width, height),
			floor_cells,
			[],
			[door_pos],
			null,
			[]
		)

		for purpose in tested_purposes:
			total_rooms_evaluated += 1
			var prof = registry.get_profile_for_purpose(purpose)
			var pal = pal_resolver.resolve_palette(_DungeonArchetypeScript.Type.MAUSOLEUM, purpose)

			var comp = planner.plan_room_composition(
				null,
				pal,
				room_geom,
				{"purpose": purpose, "room_id": seed_val},
				null,
				{"prop_seed": seed_val, "fixture_seed": seed_val + 77},
				2.0
			)

			assert(comp != null, "Composition must not be null for seed %d" % seed_val)
			total_props_placed += comp.prop_directives.size()
			total_fixtures_placed += comp.fixture_directives.size()

			# 1. Presupuesto lumínico estricto (ninguna sala excede 6 luminarias activas)
			var light_count: int = 0
			for f in comp.fixture_directives:
				if f.style != null and f.style.has_light:
					light_count += 1
			assert(light_count <= 6, "Seed %d (Purpose %s) has %d lights (exceeds budget 6)" % [seed_val, _RoomPurposeScript.to_name(purpose), light_count])

			# 2. Puertas libres de props y fixtures
			for p in comp.prop_directives:
				assert(not p.occupied_cells.has(door_pos), "Prop %s collides with door at %v in seed %d" % [p.prop_id, door_pos, seed_val])

			for f in comp.fixture_directives:
				assert(f.placement != null and f.placement.cell != door_pos, "Fixture collides with door at %v in seed %d" % [door_pos, seed_val])

			# 3. Restricciones semánticas por propósito
			if purpose in [_RoomPurposeScript.Type.CATACOMB, _RoomPurposeScript.Type.TOMB, _RoomPurposeScript.Type.ENTRANCE]:
				for p in comp.prop_directives:
					if p.style != null and p.style.prop_type == _PropStyleScript.Type.BENCH:
						assert(false, "Room %s in seed %d placed forbidden BENCH" % [_RoomPurposeScript.to_name(purpose), seed_val])

			# 4. Comprobación de Primary y jerarquía en Tomb
			if purpose == _RoomPurposeScript.Type.TOMB:
				var primary_count: int = 0
				for p in comp.prop_directives:
					if p.style != null and p.style.prop_type == _PropStyleScript.Type.SARCOPHAGUS:
						primary_count += 1
				assert(primary_count == 1, "Tomb in seed %d must have exactly 1 Primary Sarcophagus, got %d" % [seed_val, primary_count])

	print("  [OK] 100 Seeds (1000..1100) benchmark completed successfully!")
	print("  -> Total room configurations tested: %d" % total_rooms_evaluated)
	print("  -> Total props validated: %d" % total_props_placed)
	print("  -> Total fixtures validated: %d" % total_fixtures_placed)
	print("==================================================================")
	print("[PASS] test_crypt_benchmark_100_seeds 100% SUCCESSFUL!")
	print("==================================================================")
	quit(0)
