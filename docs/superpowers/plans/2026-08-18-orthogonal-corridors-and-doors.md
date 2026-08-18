# Orthogonal Corridors & Architectural Door Placement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform dungeon corridor generation from naive Manhattan A* with staircasing diagonals into an architectural orthogonal planner (Straight -> L -> Multi-Turn -> Direction-Aware A*), and upgrade entrance solving & door resolving with side reservations, hard spacing, endpoint validation, and corridor-run proximity checks.

**Architecture:** Maintain the strict phased pipeline contract (`RoomConnection -> EntrancePair -> CorridorPath -> DoorResolver -> DoorPair -> CellGrid.DOOR -> Manifests -> Presentation`). Replace Phase 5's direct A* carving with `OrthogonalCorridorPlanner` backed by a State-based direction-aware A* fallback. Enhance Phase 4 `EntranceSolver` with side/approach reservations and shape scoring. Enhance Phase 6 `DoorResolver` with strict endpoint and corridor continuity validation without breaking decoupling boundaries.

**Tech Stack:** Godot 4.6+ GDScript, `CellGrid`, `AStar2D` / custom direction-aware PriorityQueue search, `SceneTree` test suites with headless execution.

**Spec:** [a-plan/fase_refined.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fase_refined.md)

## Global Constraints

- Preserve the pipeline contract: `RoomConnection -> EntrancePair -> CorridorPath -> DoorResolver -> DoorPlacement/DoorPair -> CellGrid.DOOR -> Presentation`.
- Zero presentation hacks: do not alter `DungeonDoorSpawner` or `WallOpeningManifest` to hide logical generation bugs.
- Strict determinism: all searches, candidate sorting, and fallbacks must produce identical results for the same seed.
- Atomic commit pattern: Find -> Validate -> Commit; on route failure, zero grid mutation.
- Godot 4 typing: static typing, `Vector2i`, `Array[Vector2i]`, `Rect2i`, `StringName`.

---

### Task 1: DungeonConfig & CorridorPath Metrics Foundation

**Files:**
- Modify: `src/dungeon_generator/config/dungeon_config.gd`
- Modify: `src/dungeon_generator/core/data/corridor_path.gd`
- Create: `tests/test_corridor_aesthetic_quality.gd`

**Interfaces:**
- Produces: `DungeonConfig` fields: `corridor_turn_penalty: float`, `corridor_proximity_penalty: float`, `corridor_max_preferred_turns: int`, `prefer_orthogonal_routes: bool`, `allow_astar_fallback: bool`, `minimum_corridor_door_spacing: int`, `same_side_door_penalty: float`, `corridor_door_proximity_penalty: float`, `distribute_room_doors_across_sides: bool`.
- Produces: `CorridorPath` fields: `turn_count: int`, `straight_run_count: int`, `longest_straight_run: int`, `routing_strategy: String`.

- [x] **Step 1: Write the failing test for config and CorridorPath metrics**

Create `tests/test_corridor_aesthetic_quality.gd`:
```gdscript
extends SceneTree

const _CorridorPathScript = preload("res://src/dungeon_generator/core/data/corridor_path.gd")

func _init() -> void:
	print("--- Running test_corridor_aesthetic_quality ---")
	var cfg := DungeonConfig.new()
	assert("corridor_turn_penalty" in cfg, "Config must have corridor_turn_penalty")
	assert("prefer_orthogonal_routes" in cfg, "Config must have prefer_orthogonal_routes")
	assert("minimum_corridor_door_spacing" in cfg, "Config must have minimum_corridor_door_spacing")
	assert("distribute_room_doors_across_sides" in cfg, "Config must have distribute_room_doors_across_sides")

	var path := _CorridorPathScript.new(1, 0, 1, [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)], [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)], 3.0, 0)
	assert("turn_count" in path, "CorridorPath must track turn_count")
	assert("longest_straight_run" in path, "CorridorPath must track longest_straight_run")
	assert("routing_strategy" in path, "CorridorPath must track routing_strategy")
	print("  [OK] Task 1 assertions passed")
	quit(0)
```

- [x] **Step 2: Run test to verify it fails**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_corridor_aesthetic_quality.gd"`
Expected: FAIL on missing config properties or path fields.

- [x] **Step 3: Update `DungeonConfig` and `CorridorPath`**

In `src/dungeon_generator/config/dungeon_config.gd`, add:
```gdscript
@export_group("Calidad de Corredores (Fase 5 Refined)")
@export_range(0.0, 50.0, 0.5) var corridor_turn_penalty: float = 10.0
@export_range(0.0, 20.0, 0.5) var corridor_proximity_penalty: float = 3.0
@export_range(0, 4, 1) var corridor_max_preferred_turns: int = 2
@export var prefer_orthogonal_routes: bool = true
@export var allow_astar_fallback: bool = true

@export_group("Calidad de Puertas (Fase 4 & 6 Refined)")
@export_range(2, 16, 1) var minimum_corridor_door_spacing: int = 5
@export_range(0.0, 100.0, 1.0) var same_side_door_penalty: float = 30.0
@export_range(0.0, 100.0, 1.0) var corridor_door_proximity_penalty: float = 50.0
@export var distribute_room_doors_across_sides: bool = true
```

In `src/dungeon_generator/core/data/corridor_path.gd`, add properties and update `_init()`:
```gdscript
var turn_count: int = 0
var straight_run_count: int = 0
var longest_straight_run: int = 0
var routing_strategy: String = "Unknown"
```

- [x] **Step 4: Run test to verify it passes**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_corridor_aesthetic_quality.gd"`
Expected: PASS with exit code 0.

- [x] **Step 5: Commit**

```bash
git add src/dungeon_generator/config/dungeon_config.gd src/dungeon_generator/core/data/corridor_path.gd tests/test_corridor_aesthetic_quality.gd
git commit -m "feat(corridors): add aesthetic quality config parameters and CorridorPath metrics"
```

---

### Task 2: OrthogonalCorridorPlanner — Straight & L-Route Generation (Level 0 & Level 1)

**Files:**
- Create: `src/dungeon_generator/core/algorithms/orthogonal_corridor_planner.gd`
- Create: `tests/test_orthogonal_corridor_planner.gd`

**Interfaces:**
- Produces: `OrthogonalCorridorPlanner.plan_route(grid: CellGrid, rooms: Array[RoomData], room_a_id: int, room_b_id: int, start: Vector2i, goal: Vector2i, config: DungeonConfig) -> Dictionary`
- Result dictionary format: `{"success": bool, "centerline": Array[Vector2i], "strategy": String, "turns": int}`

- [x] **Step 1: Write the failing test for Straight & L-Route planning**

Create `tests/test_orthogonal_corridor_planner.gd`:
```gdscript
extends SceneTree

const _PlannerScript = preload("res://src/dungeon_generator/core/algorithms/orthogonal_corridor_planner.gd")

func _init() -> void:
	print("--- Running test_orthogonal_corridor_planner (Straight & L) ---")
	var grid := CellGrid.new(30, 30, CellGrid.CellType.WALL)
	var r1 := RoomData.new(0, Rect2i(2, 5, 5, 5), &"roomA")
	var r2 := RoomData.new(1, Rect2i(20, 5, 5, 5), &"roomB")
	var r3 := RoomData.new(2, Rect2i(20, 20, 5, 5), &"roomC")
	grid.fill_rect(r1.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(r2.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(r3.rect, CellGrid.CellType.FLOOR)

	var cfg := DungeonConfig.new()

	# Test Level 0: Straight horizontal line between r1 and r2
	var start_straight := Vector2i(7, 7) # outer cell of r1 east
	var goal_straight := Vector2i(19, 7) # outer cell of r2 west
	var res_straight = _PlannerScript.plan_route(grid, [r1, r2, r3], 0, 1, start_straight, goal_straight, cfg)
	assert(res_straight["success"], "Straight route must succeed")
	assert(res_straight["strategy"] == "Straight", "Strategy must be Straight")
	assert(res_straight["turns"] == 0, "Straight route must have 0 turns")
	assert(res_straight["centerline"].size() == 13, "Length must be exactly 13")

	# Test Level 1: L-route between r1 and r3 (non-collinear)
	var start_l := Vector2i(7, 7)
	var goal_l := Vector2i(22, 19) # outer cell of r3 north
	var res_l = _PlannerScript.plan_route(grid, [r1, r2, r3], 0, 2, start_l, goal_l, cfg)
	assert(res_l["success"], "L route must succeed")
	assert(res_l["strategy"] in ["L_HV", "L_VH"], "Strategy must be an L route")
	assert(res_l["turns"] == 1, "L route must have exactly 1 turn")

	print("  [OK] Straight & L routes validated")
	quit(0)
```

- [x] **Step 2: Run test to verify it fails**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_orthogonal_corridor_planner.gd"`
Expected: FAIL because `orthogonal_corridor_planner.gd` does not exist yet.

- [x] **Step 3: Implement `OrthogonalCorridorPlanner` Level 0 & Level 1**

Create `src/dungeon_generator/core/algorithms/orthogonal_corridor_planner.gd` with straight & L-route searches and boundary/obstacle/room validation.

- [x] **Step 4: Run test to verify it passes**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_orthogonal_corridor_planner.gd"`
Expected: PASS with exit code 0.

- [x] **Step 5: Commit**

```bash
git add src/dungeon_generator/core/algorithms/orthogonal_corridor_planner.gd tests/test_orthogonal_corridor_planner.gd
git commit -m "feat(corridors): implement OrthogonalCorridorPlanner Level 0 straight and Level 1 L-routes"
```

---

### Task 3: OrthogonalCorridorPlanner — Multi-Turn (2-turn & 3-turn) Routing (Level 2)

**Files:**
- Modify: `src/dungeon_generator/core/algorithms/orthogonal_corridor_planner.gd`
- Modify: `tests/test_orthogonal_corridor_planner.gd`

**Interfaces:**
- Produces: `_try_multi_turn_routes(grid, room_map, room_a_id, room_b_id, start, goal, config)` evaluating deterministic candidate waypoints (Z-routes, U-routes around obstacles and room margins) capped by `config.corridor_max_preferred_turns`.

- [x] **Step 1: Write test for multi-turn routing around obstacles**

- [x] **Step 2: Run test to verify it fails**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_orthogonal_corridor_planner.gd"`
Expected: FAIL because multi-turn route returns `success: false`.

- [x] **Step 3: Implement multi-turn route search in `OrthogonalCorridorPlanner`**

Implement deterministic candidate waypoints (Z-routes H-V-H and V-H-V, and U-routes) with cost evaluation and turn capping.

- [x] **Step 4: Run test to verify it passes**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_orthogonal_corridor_planner.gd"`
Expected: PASS with exit code 0.

- [x] **Step 5: Commit**

```bash
git add src/dungeon_generator/core/algorithms/orthogonal_corridor_planner.gd tests/test_orthogonal_corridor_planner.gd
git commit -m "feat(corridors): implement multi-turn orthogonal Z and U routing with turn capping"
```

---

### Task 4: Direction-Aware / Turn-Aware A* Router & Integration in AStarCarver (Level 3)

**Files:**
- Modify: `src/dungeon_generator/core/algorithms/astar_carver.gd`
- Modify: `tests/test_corridor_aesthetic_quality.gd`
- Modify: `tests/test_phase5_astar_carver.gd`

**Interfaces:**
- Produces: `AStarCarver._find_direction_aware_path()` stateful search `(cell, incoming_dir)` applying `corridor_turn_penalty` on direction change.
- Produces: Integrated pipeline in `carve_corridors()` prioritizing `OrthogonalCorridorPlanner` -> fallback `TurnAware A*` -> zero-mutation failure.

- [x] **Step 1: Write test for staircasing elimination in `test_corridor_aesthetic_quality.gd`**

- [x] **Step 2: Run test to verify it fails**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_corridor_aesthetic_quality.gd"`
Expected: FAIL because current AStarCarver produces high turn counts (staircase).

- [x] **Step 3: Implement Direction-Aware A* and Orthogonal Planner integration in `astar_carver.gd`**

In `src/dungeon_generator/core/algorithms/astar_carver.gd`:
1. In `_carve_single_request()`, first invoke `OrthogonalCorridorPlanner.plan_route()`. If successful, use its centerline.
2. If orthogonal planner returns false and `config.allow_astar_fallback` is true, invoke `_find_direction_aware_path()` using `(cell, in_dir)` states where turning adds `config.corridor_turn_penalty`.
3. Compute metrics (`turn_count`, `straight_run_count`, `longest_straight_run`, `routing_strategy`) and assign them to `CorridorPath`.

- [x] **Step 4: Run tests to verify they pass**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_corridor_aesthetic_quality.gd"`
Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_phase5_astar_carver.gd"`
Expected: Both test suites PASS with 100% assertions.

- [x] **Step 5: Commit**

```bash
git add src/dungeon_generator/core/algorithms/astar_carver.gd tests/test_corridor_aesthetic_quality.gd tests/test_phase5_astar_carver.gd
git commit -m "feat(corridors): integrate OrthogonalPlanner and Direction-Aware A* fallback with turn metrics"
```

---

### Task 5: Corridor Footprint & Clean Widening (Corner & Junction Preservation)

**Files:**
- Modify: `src/dungeon_generator/core/algorithms/astar_carver.gd`
- Modify: `tests/test_phase5_astar_carver.gd`

**Interfaces:**
- Produces: Segment-classified corridor widening that maintains 1-tile door bottlenecks at room boundary threshold (`corridor_bottleneck_distance = 1`) and cleans 2x2/3x3 corner and junction blocks.

- [x] **Step 1: Write test for clean corner footprint without ragged offsets**

- [x] **Step 2: Run test to verify existing baseline**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_phase5_astar_carver.gd"`

- [x] **Step 3: Implement clean segment-based widening in `astar_carver.gd`**

Update `_compute_widened_corridor_cells()` in `astar_carver.gd` to classify straight segments, 90° corners, and door throats, ensuring door throats stay narrow (1-tile width for bottleneck distance) and corners form solid blocks.

- [x] **Step 4: Run tests to verify they pass**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_phase5_astar_carver.gd"`
Expected: PASS with 100% assertions.

- [x] **Step 5: Commit**

```bash
git add src/dungeon_generator/core/algorithms/astar_carver.gd tests/test_phase5_astar_carver.gd
git commit -m "refactor(corridors): clean segment-classified corridor footprint and door throat preservation"
```

---

### Task 6: EntranceSolver Hard Spacing & Side Reservations

**Files:**
- Modify: `src/dungeon_generator/core/solvers/entrance_solver.gd`
- Create: `tests/test_door_spacing.gd`

**Interfaces:**
- Produces: `EntranceSolver` tracking `side_reservations[room_id][side] -> count` and approach reservation vectors.
- Produces: Hard spacing check rejecting door candidates `< minimum_entrance_spacing` on the same room perimeter.
- Produces: `same_side_door_penalty` distribution across room sides.

- [x] **Step 1: Write the failing test for hard spacing and side distribution**

- [x] **Step 2: Run test to verify it fails**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_door_spacing.gd"`

- [x] **Step 3: Update `EntranceSolver` with side reservations & hard spacing**

In `src/dungeon_generator/core/solvers/entrance_solver.gd`:
1. Maintain `reserved_sides: Dictionary` (mapping `room_id -> {side: count}`) to track faces used.
2. In `score_candidate_pair()`, apply `config.same_side_door_penalty` when a face has already been assigned a door.
3. Reject candidates within Manhattan distance `< config.minimum_entrance_spacing` of any already reserved door for that room (hard constraint rejection returning `1e8`).

- [x] **Step 4: Run test to verify it passes**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_door_spacing.gd"`
Expected: PASS with exit code 0.

- [x] **Step 5: Commit**

```bash
git add src/dungeon_generator/core/solvers/entrance_solver.gd tests/test_door_spacing.gd
git commit -m "feat(entrances): enforce hard perimeter spacing and side distribution in EntranceSolver"
```

---

### Task 7: EntranceSolver Corridor Approach Quality Estimation

**Files:**
- Modify: `src/dungeon_generator/core/solvers/entrance_solver.gd`
- Modify: `tests/test_phase4_entrance_solver.gd`

**Interfaces:**
- Produces: `score_candidate_pair()` factoring `corridor_shape_penalty` (evaluating collinearity and simple L alignment between outer cells before picking the winning pair).

- [x] **Step 1: Write test for entrance approach alignment**

- [x] **Step 2: Run test to verify baseline**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_phase4_entrance_solver.gd"`

- [x] **Step 3: Add corridor shape heuristic to `score_candidate_pair()`**

In `entrance_solver.gd`, compute shape alignment score:
- Collinear facing: `0.0`
- Orthogonal facing with single L potential: `+5.0`
- Opposing or misaligned facing requiring multiple turns: `+20.0`

- [x] **Step 4: Run test to verify it passes**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_phase4_entrance_solver.gd"`
Expected: PASS with 100% assertions.

- [x] **Step 5: Commit**

```bash
git add src/dungeon_generator/core/solvers/entrance_solver.gd tests/test_phase4_entrance_solver.gd
git commit -m "feat(entrances): add corridor shape estimation to candidate scoring in EntranceSolver"
```

---

### Task 8: DoorResolver Endpoint & Corridor Continuity Validation

**Files:**
- Modify: `src/dungeon_generator/core/solvers/door_resolver.gd`
- Create: `tests/test_door_endpoint_quality.gd`
- Modify: `tests/test_phase6_door_resolver.gd`

**Interfaces:**
- Produces: `DoorResolver` verifying that each resolved door's `corridor_cell` corresponds strictly to an endpoint of its associated `CorridorPath.centerline_cells` (`[0]` or `[-1]`).
- Produces: Corridor run-length proximity validation preventing door clustering `< minimum_corridor_door_spacing` on the same corridor path (while preserving legitimate 2-door room-to-room endpoints).

- [x] **Step 1: Write tests for door endpoint attachment**

- [x] **Step 2: Run test to verify baseline**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_door_endpoint_quality.gd"`

- [x] **Step 3: Implement endpoint and proximity validation in `DoorResolver`**

In `src/dungeon_generator/core/solvers/door_resolver.gd`:
1. Verify that `door_a.corridor_cell` and `door_b.corridor_cell` correspond strictly to endpoints of `path.centerline_cells`.
2. Reject door candidates that are not attached to valid corridor endpoints (`DOOR_NOT_AT_CORRIDOR_ENDPOINT`).

- [x] **Step 4: Run tests to verify they pass**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_door_endpoint_quality.gd"`
Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_phase6_door_resolver.gd"`
Expected: PASS with 100% assertions.

- [x] **Step 5: Commit**

```bash
git add src/dungeon_generator/core/solvers/door_resolver.gd tests/test_door_endpoint_quality.gd tests/test_phase6_door_resolver.gd
git commit -m "feat(doors): enforce corridor centerline endpoint validation in DoorResolver"
```

---

### Task 9: Dungeon Pipeline Metrics & Full CI Suite Integration

**Files:**
- Modify: `src/dungeon_generator/core/dungeon_pipeline.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Produces: Aggregated dungeon generation metrics in `DungeonResult.metadata["aesthetic_metrics"]`: `average_turns_per_corridor`, `percent_zero_turn`, `percent_one_turn`, `percent_two_turn`, `door_count`, `min_door_distance`.
- Produces: `run_all_tests.gd` executing all new quality and spacing suites.

- [x] **Step 1: Write test checking pipeline aesthetic metrics**

In `tests/test_corridor_aesthetic_quality.gd`, run full `DungeonPipeline.generate()` and assert that:
- `dungeon_res.metadata.has("aesthetic_metrics")`
- `dungeon_res.metadata["aesthetic_metrics"]["average_turns_per_corridor"] <= 2.0`
- `dungeon_res.metadata["aesthetic_metrics"]["staircase_corridors"] == 0`

- [x] **Step 2: Run test to verify it fails**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_corridor_aesthetic_quality.gd"`

- [x] **Step 3: Update `DungeonPipeline` and `run_all_tests.gd`**

1. In `src/dungeon_generator/core/dungeon_pipeline.gd`, collect corridor aesthetic metrics after Phase 5 and Phase 6, storing them in `result.metadata["aesthetic_metrics"]`.
2. In `tests/run_all_tests.gd`, add the 4 new test suites:
   - `"res://tests/test_orthogonal_corridor_planner.gd"`
   - `"res://tests/test_corridor_aesthetic_quality.gd"`
   - `"res://tests/test_door_spacing.gd"`
   - `"res://tests/test_door_endpoint_quality.gd"`

- [x] **Step 4: Run full CI test runner to verify 100% pass**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/run_all_tests.gd"`
Expected: All suites execute with 0 failures.

- [x] **Step 5: Commit**

```bash
git add src/dungeon_generator/core/dungeon_pipeline.gd tests/run_all_tests.gd tests/test_corridor_aesthetic_quality.gd
git commit -m "feat(pipeline): aggregate corridor aesthetic metrics and register test suites in CI runner"
```

---

### Task 10: Golden Seeds & Visual Regression Verification

**Files:**
- Modify: `tests/test_golden_fixtures.gd`
- Modify: `tests/test_stress_10k_seeds.gd`

**Interfaces:**
- Validates: Multi-seed generation (seeds 100, 1337, 4242, 9999, 123456) has 0 staircasing corridors, 0 duplicate doors, 0 invalid endpoints, and 100% playable connectivity across all floors.

- [x] **Step 1: Run golden fixtures test**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_golden_fixtures.gd"`

- [x] **Step 2: Create golden seeds visual quality suite**

Create `tests/test_golden_seeds_visual_quality.gd` checking:
- 10 Golden seeds across BSP, Cellular Automata, and Hybrid archetypes.
- 100% deterministic reproducibility bit by bit.
- 100% connected walkable floor/corridor/door grid.
- Zero staircase corridors (`staircase_corridors == 0`).
- Average turns per corridor `<= 2.0`.
- All doors validly placed at centerline endpoints.

- [x] **Step 3: Run golden seeds visual quality suite**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_golden_seeds_visual_quality.gd"`
Expected: PASS with 100% assertions and zero drift.

- [x] **Step 4: Commit**

```bash
git add tests/test_golden_seeds_visual_quality.gd tests/run_all_tests.gd
git commit -m "test(qa): add golden seeds visual quality and regression verification suite"
```
