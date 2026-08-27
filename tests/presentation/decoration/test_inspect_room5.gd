extends SceneTree

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const _SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const _DungeonPresentationBuilderScript = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const _DecorationCompPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _PresentationGeometryPartitionScript = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")
const _PresentationSeedContextScript = preload("res://src/presentation/architecture/presentation_seed_context.gd")

func _init() -> void:
	var seed_val: int = 5000
	var config := _DungeonConfigScript.new()
	config.grid_width = 48
	config.grid_height = 48
	config.seed = seed_val
	config.dungeon_archetype = 1 # MAUSOLEUM

	var pipeline := _DungeonPipelineScript.new()
	var d_res = pipeline.generate(config)
	var sem_orchestrator := _SemanticOrchestratorScript.new()
	var sem_res = sem_orchestrator.generate_semantics(d_res, config)

	var ctx_builder := preload("res://src/presentation/architecture/presentation_context_builder.gd").new()
	var room_contexts = ctx_builder.build_contexts(sem_res)

	var geom_partition := _PresentationGeometryPartitionScript.new()
	geom_partition.build_partition(sem_res.grid, room_contexts, sem_res)

	var loader := _ProfileLoaderScript.new()
	var royal_prof = loader.load_room("royal_tomb.json")
	var pal_resolver := _DecorationPaletteResolverScript.new()
	var palette = pal_resolver.resolve_palette(1, 14, null)

	var target_room_id: int = -1
	for r in sem_res.rooms:
		var purp = sem_res.room_purposes.get(r.id, 0)
		if purp == 14:
			target_room_id = r.id
			break
	if target_room_id == -1:
		target_room_id = sem_res.rooms[0].id

	var r_geom = geom_partition.get_room_geometry(target_room_id)
	print("Target Room %d Geometry Floor Cells: %d Rect: %s" % [target_room_id, r_geom.floor_cells.size(), str(r_geom.bounds)])
	print("Target Room %d Door Positions: %s" % [target_room_id, str(r_geom.door_positions)])

	var planner := _DecorationCompPlannerScript.new()
	var seed_ctx = _PresentationSeedContextScript.for_room(seed_val, target_room_id)

	var comp = planner.plan_room_composition(
		royal_prof,
		palette,
		r_geom,
		{"room_id": target_room_id, "purpose": 14},
		null,
		seed_ctx,
		2.0
	)

	print("Directives placed in comp: ", comp.prop_directives.size())
	for d in comp.prop_directives:
		print("  - Directive: %s at %s cells: %s" % [d.prop_id, str(d.world_position), str(d.occupied_cells)])

	quit(0)
