extends SceneTree

## Test de Integración: DungeonRoomStage en el Pipeline
## Valida el cumplimiento del contrato arquitectónico:
## 1. Generación de habitaciones (SpaceGrammar).
## 2. Construcción de SpatialIntent y SpatialComposition.
## 3. Asignación a DungeonGenerationContext.spatial_composition (sellado e inmutable).
## 4. Paso a CompositionStrategy y generación de RoomPlacementPlan sellado.
## 5. Aplicación mediante RoomPlacer (is_placed == true).
## 6. Validación de integridad de colocación y contención en límites.
## 7. Ejecución antes de CorridorPlanner.

const DungeonPipeline = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const DungeonConfig = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonGenerationContext = preload("res://src/dungeon_generator/core/data/dungeon_generation_context.gd")
const SpatialComposition = preload("res://src/dungeon_generator/core/data/spatial_composition.gd")
const SpatialIntentResult = preload("res://src/dungeon_generator/core/data/spatial_intent_result.gd")
const RoomPlacementPlan = preload("res://src/dungeon_generator/core/data/room_placement_plan.gd")
const RoomPlacer = preload("res://src/dungeon_generator/core/placement/room_placer.gd")
const RoomSpatialSeparator = preload("res://src/dungeon_generator/core/topology/room_spatial_separator.gd")

func _init() -> void:
	print("--- Running test_dungeon_room_stage_pipeline ---")

	test_room_stage_context_integration()
	test_room_stage_placement_validation()
	test_composition_completes_before_corridor_planning()
	test_multi_seed_pipeline_execution()

	print("[PASS] All DungeonRoomStage pipeline integration tests passed successfully!")
	quit(0)

func test_room_stage_context_integration() -> void:
	print("  Testing DungeonRoomStage context contract (SpatialIntent, SpatialComposition, RoomPlacementPlan)...")
	var pipeline := DungeonPipeline.new()
	var cfg := DungeonConfig.new()
	cfg.seed = 991234
	cfg.use_fixed_seed = true
	cfg.grid_width = 64
	cfg.grid_height = 64

	var res: DungeonResult = pipeline.generate(cfg)
	assert(res != null, "Pipeline generation must succeed")

	var ctx: DungeonGenerationContext = pipeline.get_context()
	assert(ctx != null, "Context must be retained in pipeline")

	# 1. SpatialIntent & SpatialComposition
	assert(ctx.spatial_intent != null, "ctx.spatial_intent must be populated")
	assert(ctx.spatial_intent is SpatialIntentResult, "ctx.spatial_intent must be SpatialIntentResult")
	assert(ctx.spatial_composition != null, "ctx.spatial_composition must be populated")
	assert(ctx.spatial_composition is SpatialComposition, "ctx.spatial_composition must be SpatialComposition")
	assert(ctx.spatial_composition.is_sealed(), "ctx.spatial_composition must be sealed")

	# 2. RoomPlacementPlan
	assert(ctx.placement_plan != null, "ctx.placement_plan must be populated")
	assert(ctx.placement_plan is RoomPlacementPlan, "ctx.placement_plan must be RoomPlacementPlan")
	assert(ctx.placement_plan.is_sealed(), "ctx.placement_plan must be sealed")
	assert(ctx.placement_plan.size() == ctx.rooms.size(), "Plan size must match room count")

	# 3. RoomPlacer applied to all rooms
	assert(not ctx.rooms.is_empty(), "Rooms must not be empty")
	for r in ctx.rooms:
		assert(r.is_placed, "Every room must be marked is_placed = true")
		assert(ctx.placement_plan.has_placement(r.id), "Room %d must exist in placement plan" % r.id)

	print("  -> Passed context contract test.")

func test_room_stage_placement_validation() -> void:
	print("  Testing placement validation and boundary integrity...")
	var pipeline := DungeonPipeline.new()
	var cfg := DungeonConfig.new()
	cfg.seed = 771122
	cfg.use_fixed_seed = true

	var res := pipeline.generate(cfg)
	assert(res != null, "Pipeline generation must succeed")

	var ctx := pipeline.get_context()
	var placer := RoomPlacer.new()
	assert(placer.validate_placement_integrity(ctx.rooms, 0), "No rooms may overlap geometrically")

	var grid_bounds := Rect2i(3, 3, cfg.grid_width - 6, cfg.grid_height - 6)
	var sep_val := RoomSpatialSeparator.validate_separation(ctx.rooms, grid_bounds, 0)
	assert(sep_val["is_valid"], "All rooms must be within bounds without overlaps")

	print("  -> Passed placement validation test.")

func test_composition_completes_before_corridor_planning() -> void:
	print("  Testing execution order: composition completes before corridor planning...")
	var pipeline := DungeonPipeline.new()
	var completed_phases: Array[String] = []

	pipeline.phase_completed.connect(func(phase_name: String, _elapsed: float):
		completed_phases.append(phase_name)
	)

	var cfg := DungeonConfig.new()
	cfg.seed = 554433
	cfg.use_fixed_seed = true

	var res := pipeline.generate(cfg)
	assert(res != null, "Pipeline generation must succeed")

	# Verificar que 'room_placement' y 'room_construction' ocurrieron antes de 'corridor_carving'
	var idx_placement: int = completed_phases.find("room_placement")
	var idx_construction: int = completed_phases.find("room_construction")
	var idx_corridor: int = completed_phases.find("corridor_carving")

	assert(idx_placement != -1, "room_placement must be reported in phase_completed")
	assert(idx_construction != -1, "room_construction must be reported in phase_completed")
	assert(idx_corridor != -1, "corridor_carving must be reported in phase_completed")

	assert(idx_placement < idx_corridor, "room_placement must complete before corridor_carving")
	assert(idx_construction < idx_corridor, "room_construction must complete before corridor_carving")

	print("  -> Passed execution order verification: %s" % str(completed_phases))

func test_multi_seed_pipeline_execution() -> void:
	print("  Testing multi-seed pipeline execution with DungeonRoomStage...")
	var pipeline := DungeonPipeline.new()

	for s in [10001, 20002, 30003, 40004, 50005]:
		var cfg := DungeonConfig.new()
		cfg.seed = s
		cfg.use_fixed_seed = true
		cfg.grid_width = 64
		cfg.grid_height = 64

		var res := pipeline.generate(cfg)
		assert(res != null, "Generation failed for seed %d" % s)
		assert(res.rooms.size() >= 4, "Must generate at least 4 rooms")
		assert(res.corridor_paths.size() >= 3, "Must generate corridors")
		assert(res.validation.is_winnable, "Must be winnable for seed %d" % s)

	print("  -> Passed multi-seed pipeline verification.")
