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

- [ ] **Step 1: Write the failing test for config and CorridorPath metrics**

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

- [ ] **Step 2: Run test to verify it fails**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_corridor_aesthetic_quality.gd"`
Expected: FAIL on missing config properties or path fields.

- [ ] **Step 3: Update `DungeonConfig` and `CorridorPath`**

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

- [ ] **Step 4: Run test to verify it passes**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_corridor_aesthetic_quality.gd"`
Expected: PASS with exit code 0.

- [ ] **Step 5: Commit**

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

- [ ] **Step 1: Write the failing test for Straight & L-Route planning**

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

- [ ] **Step 2: Run test to verify it fails**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_orthogonal_corridor_planner.gd"`
Expected: FAIL because `orthogonal_corridor_planner.gd` does not exist yet.

- [ ] **Step 3: Implement `OrthogonalCorridorPlanner` Level 0 & Level 1**

Create `src/dungeon_generator/core/algorithms/orthogonal_corridor_planner.gd`:
```gdscript
class_name OrthogonalCorridorPlanner
extends RefCounted

## Planificador de rutas ortogonales de alta calidad arquitectónica (Fase 5 Refined).
## Evalúa en orden de preferencia estricto:
## Level 0: Línea recta (0 giros)
## Level 1: L limpia (H->V o V->H, 1 giro)
## Level 2: Rutas multi-giro ortogonales (2-3 giros)

static func plan_route(
	grid: CellGrid,
	rooms: Array[RoomData],
	room_a_id: int,
	room_b_id: int,
	start: Vector2i,
	goal: Vector2i,
	config: DungeonConfig
) -> Dictionary:
	var room_map: Dictionary = {}
	for r in rooms:
		if r != null:
			room_map[r.id] = r

	# Level 0: Línea recta (colineal)
	if start.y == goal.y or start.x == goal.x:
		var straight_path = _try_straight(grid, room_map, room_a_id, room_b_id, start, goal)
		if not straight_path.is_empty():
			return {
				"success": true,
				"centerline": straight_path,
				"strategy": "Straight",
				"turns": 0
			}

	# Level 1: L limpio (H->V y V->H)
	var l_res = _try_l_routes(grid, room_map, room_a_id, room_b_id, start, goal)
	if l_res["success"]:
		return l_res

	return {"success": false, "centerline": [], "strategy": "None", "turns": -1}

static func _is_cell_valid_for_corridor(
	grid: CellGrid,
	room_map: Dictionary,
	room_a_id: int,
	room_b_id: int,
	cell: Vector2i
) -> bool:
	if not grid.is_in_bounds(cell.x, cell.y):
		return false
	var ctype: int = grid.get_cell(cell)
	if ctype == CellGrid.CellType.VOID or ctype == CellGrid.CellType.COLUMN or ctype == CellGrid.CellType.SOLID_ROCK:
		return false

	# Verificar si pertenece a otra sala prohibida
	for rid in room_map:
		if rid != room_a_id and rid != room_b_id:
			var r: RoomData = room_map[rid]
			if r.rect.has_point(cell):
				return false
	return true

static func _build_straight_line(p1: Vector2i, p2: Vector2i) -> Array[Vector2i]:
	var line: Array[Vector2i] = []
	var dx: int = clampi(p2.x - p1.x, -1, 1)
	var dy: int = clampi(p2.y - p1.y, -1, 1)
	var curr := p1
	while true:
		line.append(curr)
		if curr == p2:
			break
		curr += Vector2i(dx, dy)
	return line

static func _try_straight(
	grid: CellGrid,
	room_map: Dictionary,
	room_a_id: int,
	room_b_id: int,
	start: Vector2i,
	goal: Vector2i
) -> Array[Vector2i]:
	var line := _build_straight_line(start, goal)
	for cell in line:
		if not _is_cell_valid_for_corridor(grid, room_map, room_a_id, room_b_id, cell):
			return []
	return line

static func _try_l_routes(
	grid: CellGrid,
	room_map: Dictionary,
	room_a_id: int,
	room_b_id: int,
	start: Vector2i,
	goal: Vector2i
) -> Dictionary:
	# Opción A: H -> V (corner at goal.x, start.y)
	var corner_hv := Vector2i(goal.x, start.y)
	var path_hv := _build_straight_line(start, corner_hv)
	var leg2_hv := _build_straight_line(corner_hv, goal)
	for i in range(1, leg2_hv.size()):
		path_hv.append(leg2_hv[i])

	var valid_hv: bool = true
	for cell in path_hv:
		if not _is_cell_valid_for_corridor(grid, room_map, room_a_id, room_b_id, cell):
			valid_hv = false
			break

	# Opción B: V -> H (corner at start.x, goal.y)
	var corner_vh := Vector2i(start.x, goal.y)
	var path_vh := _build_straight_line(start, corner_vh)
	var leg2_vh := _build_straight_line(corner_vh, goal)
	for i in range(1, leg2_vh.size()):
		path_vh.append(leg2_vh[i])

	var valid_vh: bool = true
	for cell in path_vh:
		if not _is_cell_valid_for_corridor(grid, room_map, room_a_id, room_b_id, cell):
			valid_vh = false
			break

	if valid_hv and not valid_vh:
		return {"success": true, "centerline": path_hv, "strategy": "L_HV", "turns": 1}
	if valid_vh and not valid_hv:
		return {"success": true, "centerline": path_vh, "strategy": "L_VH", "turns": 1}
	if valid_hv and valid_vh:
		# Si ambas son válidas, preferir la que tenga mayor reuso de corredor existente
		var reused_hv: int = 0
		var reused_vh: int = 0
		for c in path_hv:
			if grid.get_cell(c) == CellGrid.CellType.CORRIDOR:
				reused_hv += 1
		for c in path_vh:
			if grid.get_cell(c) == CellGrid.CellType.CORRIDOR:
				reused_vh += 1
		if reused_vh > reused_hv:
			return {"success": true, "centerline": path_vh, "strategy": "L_VH", "turns": 1}
		return {"success": true, "centerline": path_hv, "strategy": "L_HV", "turns": 1}

	return {"success": false, "centerline": [], "strategy": "None", "turns": -1}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_orthogonal_corridor_planner.gd"`
Expected: PASS with exit code 0.

- [ ] **Step 5: Commit**

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

- [ ] **Step 1: Write test for multi-turn routing around obstacles**

Extend `tests/test_orthogonal_corridor_planner.gd`:
```gdscript
	# Test Level 2: Multi-turn (2-turn Z/U-route) when direct L is blocked by an obstacle
	var grid_obst := CellGrid.new(30, 30, CellGrid.CellType.WALL)
	var ro1 := RoomData.new(0, Rect2i(2, 10, 5, 5), &"ro1")
	var ro2 := RoomData.new(1, Rect2i(22, 10, 5, 5), &"ro2")
	grid_obst.fill_rect(ro1.rect, CellGrid.CellType.FLOOR)
	grid_obst.fill_rect(ro2.rect, CellGrid.CellType.FLOOR)

	# Place an obstacle directly in the horizontal corridor line between them
	grid_obst.fill_rect(Rect2i(10, 8, 8, 8), CellGrid.CellType.COLUMN)

	var s_obst := Vector2i(7, 12)
	var g_obst := Vector2i(21, 12)
	var res_multi = _PlannerScript.plan_route(grid_obst, [ro1, ro2], 0, 1, s_obst, g_obst, cfg)
	assert(res_multi["success"], "Multi-turn route must navigate around obstacle")
	assert(res_multi["turns"] >= 2 and res_multi["turns"] <= cfg.corridor_max_preferred_turns, "Must use 2 to 3 turns")
	for c in res_multi["centerline"]:
		assert(grid_obst.get_cell(c) != CellGrid.CellType.COLUMN, "Path must not intersect column obstacle")
	print("  [OK] Multi-turn routing around obstacles validated")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_orthogonal_corridor_planner.gd"`
Expected: FAIL because multi-turn route returns `success: false`.

- [ ] **Step 3: Implement multi-turn route search in `OrthogonalCorridorPlanner`**

In `orthogonal_corridor_planner.gd`:
Add candidates for 2-turn Z/U routes (varying the intermediate jog coordinate across room bounds, midpoint `(start.x + goal.x)/2`, `(start.y + goal.y)/2`, and clearance offsets `start.y +/- offset`, `goal.x +/- offset`):
```gdscript
static func _try_multi_turn_routes(
	grid: CellGrid,
	room_map: Dictionary,
	room_a_id: int,
	room_b_id: int,
	start: Vector2i,
	goal: Vector2i,
	config: DungeonConfig
) -> Dictionary:
	var max_turns: int = config.corridor_max_preferred_turns
	if max_turns < 2:
		return {"success": false, "centerline": [], "strategy": "None", "turns": -1}

	var best_path: Array[Vector2i] = []
	var best_cost: float = INF
	var best_turns: int = -1
	var best_strat: String = ""

	# Generar puntos de quiebre candidatos (Z-routes horizontales y verticales)
	var mid_x: int = int((start.x + goal.x) / 2.0)
	var mid_y: int = int((start.y + goal.y) / 2.0)

	var xs_to_try: Array[int] = [mid_x]
	var ys_to_try: Array[int] = [mid_y]
	for delta in [2, -2, 4, -4, 6, -6]:
		xs_to_try.append(mid_x + delta)
		ys_to_try.append(mid_y + delta)

	# Probar Z-route H-V-H (2 giros)
	for x in xs_to_try:
		if x <= mini(start.x, goal.x) or x >= maxi(start.x, goal.x):
			continue
		var p1 := Vector2i(x, start.y)
		var p2 := Vector2i(x, goal.y)
		var full := _combine_segments([start, p1, p2, goal])
		if _is_path_valid(grid, room_map, room_a_id, room_b_id, full):
			var cost: float = float(full.size()) + 2.0 * config.corridor_turn_penalty
			if cost < best_cost:
				best_cost = cost
				best_path = full
				best_turns = 2
				best_strat = "Z_HVH"

	# Probar Z-route V-H-V (2 giros)
	for y in ys_to_try:
		if y <= mini(start.y, goal.y) or y >= maxi(start.y, goal.y):
			continue
		var p1 := Vector2i(start.x, y)
		var p2 := Vector2i(goal.x, y)
		var full := _combine_segments([start, p1, p2, goal])
		if _is_path_valid(grid, room_map, room_a_id, room_b_id, full):
			var cost: float = float(full.size()) + 2.0 * config.corridor_turn_penalty
			if cost < best_cost:
				best_cost = cost
				best_path = full
				best_turns = 2
				best_strat = "Z_VHV"

	# Probar U-routes si Z está bloqueado (giros de rodeo)
	if best_path.is_empty() and max_turns >= 2:
		for y in ys_to_try:
			var p1 := Vector2i(start.x, y)
			var p2 := Vector2i(goal.x, y)
			var full := _combine_segments([start, p1, p2, goal])
			if _is_path_valid(grid, room_map, room_a_id, room_b_id, full):
				var cost: float = float(full.size()) + 2.0 * config.corridor_turn_penalty
				if cost < best_cost:
					best_cost = cost
					best_path = full
					best_turns = 2
					best_strat = "U_VHV"

	if not best_path.is_empty():
		return {"success": true, "centerline": best_path, "strategy": best_strat, "turns": best_turns}

	return {"success": false, "centerline": [], "strategy": "None", "turns": -1}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_orthogonal_corridor_planner.gd"`
Expected: PASS with exit code 0.

- [ ] **Step 5: Commit**

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

- [ ] **Step 1: Write test for staircasing elimination in `test_corridor_aesthetic_quality.gd`**

Extend `tests/test_corridor_aesthetic_quality.gd`:
```gdscript
	# Test anti-staircase guarantee on diagonal targets
	var grid_diag := CellGrid.new(40, 40, CellGrid.CellType.WALL)
	var rd1 := RoomData.new(0, Rect2i(5, 5, 6, 6), &"r1")
	var rd2 := RoomData.new(1, Rect2i(25, 25, 6, 6), &"r2")
	grid_diag.fill_rect(rd1.rect, CellGrid.CellType.FLOOR)
	grid_diag.fill_rect(rd2.rect, CellGrid.CellType.FLOOR)

	var p_pair := EntrancePair.new(
		RoomEntrance.new(0, Vector2i(10, 8), Vector2i(11, 8), Vector2i(1, 0)),
		RoomEntrance.new(1, Vector2i(25, 27), Vector2i(24, 27), Vector2i(-1, 0)),
		0
	)
	var c_diag := RoomConnection.new(0, 0, 1, true)
	var carve_res = _AStarCarverScript.carve_corridors(grid_diag, [rd1, rd2], [p_pair], [c_diag], cfg)
	assert(carve_res.is_valid and carve_res.paths.size() == 1, "Must carve corridor")
	var path_diag: _CorridorPathScript = carve_res.paths[0]
	assert(path_diag.turn_count <= 2, "Diagonal connection must use <= 2 turns (clean L or Z), got %d turns" % path_diag.turn_count)
	print("  [OK] Staircase pattern elimination verified (turn_count=%d)" % path_diag.turn_count)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_corridor_aesthetic_quality.gd"`
Expected: FAIL because current AStarCarver produces high turn counts (staircase).

- [ ] **Step 3: Implement Direction-Aware A* and Orthogonal Planner integration in `astar_carver.gd`**

In `src/dungeon_generator/core/algorithms/astar_carver.gd`:
1. In `_carve_single_request()`, first invoke `OrthogonalCorridorPlanner.plan_route()`. If successful, use its centerline.
2. If orthogonal planner returns false and `config.allow_astar_fallback` is true, invoke `_find_turn_aware_path()` using `(cell, in_dir)` states where turning adds `config.corridor_turn_penalty`.
3. Compute metrics (`turn_count`, `straight_run_count`, `longest_straight_run`, `routing_strategy`) and assign them to `CorridorPath`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_corridor_aesthetic_quality.gd"`
Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_phase5_astar_carver.gd"`
Expected: Both test suites PASS with 100% assertions.

- [ ] **Step 5: Commit**

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

- [ ] **Step 1: Write test for clean corner footprint without ragged offsets**

In `tests/test_phase5_astar_carver.gd`, verify Test 6 (corridor widening with width=2) and ensure corners and junctions are properly filled with no missing internal corner voxels.

- [ ] **Step 2: Run test to verify existing baseline**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_phase5_astar_carver.gd"`

- [ ] **Step 3: Implement clean segment-based widening in `astar_carver.gd`**

Update `_widen_corridor()` in `astar_carver.gd` to classify straight segments, 90° corners, and door throats, ensuring door throats stay narrow (1-tile width for bottleneck distance) and corners form solid blocks.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_phase5_astar_carver.gd"`
Expected: PASS with 100% assertions.

- [ ] **Step 5: Commit**

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

- [ ] **Step 1: Write the failing test for hard spacing and side distribution**

Create `tests/test_door_spacing.gd`:
```gdscript
extends SceneTree

const _EntranceSolverScript = preload("res://src/dungeon_generator/core/solvers/entrance_solver.gd")
const _RoomConnectionScript = preload("res://src/dungeon_generator/core/data/room_connection.gd")

func _init() -> void:
	print("--- Running test_door_spacing ---")
	var grid := CellGrid.new(50, 50, CellGrid.CellType.WALL)
	var r_hub := RoomData.new(0, Rect2i(20, 20, 10, 10), &"hub")
	var r_north := RoomData.new(1, Rect2i(20, 5, 10, 8), &"north")
	var r_east := RoomData.new(2, Rect2i(35, 20, 8, 10), &"east")
	grid.fill_rect(r_hub.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(r_north.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(r_east.rect, CellGrid.CellType.FLOOR)

	var cfg := DungeonConfig.new()
	cfg.minimum_entrance_spacing = 3
	cfg.distribute_room_doors_across_sides = true

	var c_n := _RoomConnectionScript.new(0, 0, 1, true)
	var c_e := _RoomConnectionScript.new(1, 0, 2, true)

	var ent_res = _EntranceSolverScript.resolve([r_hub, r_north, r_east], [c_n, c_e], grid, cfg)
	assert(ent_res.is_valid, "Entrance resolution must succeed")
	assert(ent_res.entrance_pairs.size() == 2, "Must resolve 2 pairs")

	# Check hub entrances: one must be on NORTH side, one on EAST side (distributed across sides)
	var hub_ent_1 = ent_res.entrance_pairs[0].entrance_a if ent_res.entrance_pairs[0].entrance_a.room_id == 0 else ent_res.entrance_pairs[0].entrance_b
	var hub_ent_2 = ent_res.entrance_pairs[1].entrance_a if ent_res.entrance_pairs[1].entrance_a.room_id == 0 else ent_res.entrance_pairs[1].entrance_b

	assert(hub_ent_1.facing_dir != hub_ent_2.facing_dir, "Hub room doors must be distributed across different room sides")
	var dist: int = absi(hub_ent_1.position.x - hub_ent_2.position.x) + absi(hub_ent_1.position.y - hub_ent_2.position.y)
	assert(dist >= cfg.minimum_entrance_spacing, "Doors must be at least minimum_entrance_spacing apart")
	print("  [OK] Hard door spacing and side distribution verified")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_door_spacing.gd"`
Expected: FAIL if side distribution or hard spacing is not strictly enforced.

- [ ] **Step 3: Update `EntranceSolver` with side reservations & hard spacing**

In `src/dungeon_generator/core/solvers/entrance_solver.gd`:
1. Maintain `side_usage: Dictionary` (mapping `room_id -> {Vector2i: int}`) to track faces used.
2. In `score_candidate_pair()`, apply `config.same_side_door_penalty` when a face has already been assigned a door.
3. Reject candidates within Manhattan distance `< config.minimum_entrance_spacing` of any already reserved door for that room (return `INF` score / invalid).

- [ ] **Step 4: Run test to verify it passes**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_door_spacing.gd"`
Expected: PASS with exit code 0.

- [ ] **Step 5: Commit**

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

- [ ] **Step 1: Write test for entrance approach alignment**

In `tests/test_phase4_entrance_solver.gd`, add test cases validating that collinear facing entrances are strongly prioritized over misaligned ones.

- [ ] **Step 2: Run test to verify baseline**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_phase4_entrance_solver.gd"`

- [ ] **Step 3: Add corridor shape heuristic to `score_candidate_pair()`**

In `entrance_solver.gd`, compute shape alignment score:
- Collinear facing: `0.0`
- Orthogonal facing with single L potential: `+5.0`
- Opposing or misaligned facing requiring multiple turns: `+20.0`

- [ ] **Step 4: Run test to verify it passes**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_phase4_entrance_solver.gd"`
Expected: PASS with 100% assertions.

- [ ] **Step 5: Commit**

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

- [ ] **Step 1: Write the failing test for door endpoint & run-length validation**

Create `tests/test_door_endpoint_quality.gd`:
```gdscript
extends SceneTree

const _DoorResolverScript = preload("res://src/dungeon_generator/core/solvers/door_resolver.gd")
const _EntrancePairScript = preload("res://src/dungeon_generator/core/data/entrance_pair.gd")
const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")
const _CorridorPathScript = preload("res://src/dungeon_generator/core/data/corridor_path.gd")

func _init() -> void:
	print("--- Running test_door_endpoint_quality ---")
	var grid := CellGrid.new(30, 30, CellGrid.CellType.WALL)
	var r1 := RoomData.new(0, Rect2i(2, 5, 6, 6), &"r1")
	var r2 := RoomData.new(1, Rect2i(20, 5, 6, 6), &"r2")
	grid.fill_rect(r1.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(r2.rect, CellGrid.CellType.FLOOR)

	var ent_a := _RoomEntranceScript.new(0, Vector2i(7, 7), Vector2i(8, 7), Vector2i(1, 0))
	var ent_b := _RoomEntranceScript.new(1, Vector2i(20, 7), Vector2i(19, 7), Vector2i(-1, 0))
	var pair := _EntrancePairScript.new(ent_a, ent_b, 0)

	# Legitimate corridor with endpoints matching outer cells
	var centerline: Array[Vector2i] = []
	for x in range(8, 20):
		centerline.append(Vector2i(x, 7))
		grid.set_cell(Vector2i(x, 7), CellGrid.CellType.CORRIDOR)

	var c_path := _CorridorPathScript.new(0, 0, 1, centerline, centerline, 12.0, 0)
	var cfg := DungeonConfig.new()

	var res = _DoorResolverScript.resolve(grid, [r1, r2], [pair], [c_path], cfg)
	assert(res.is_valid, "Door resolver must succeed for valid endpoints")
	assert(res.doors.size() == 2, "Must produce 2 door placements")

	# Test endpoint rejection: if corridor_cell is in the middle of the centerline, resolver must reject
	var fake_ent_mid := _RoomEntranceScript.new(0, Vector2i(7, 7), Vector2i(14, 7), Vector2i(1, 0))
	var fake_pair := _EntrancePairScript.new(fake_ent_mid, ent_b, 1)
	var res_bad = _DoorResolverScript.resolve(grid, [r1, r2], [fake_pair], [c_path], cfg)
	assert(not res_bad.is_valid, "Door resolver must reject door not at corridor endpoint")

	print("  [OK] Door endpoint and corridor continuity validation verified")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_door_endpoint_quality.gd"`
Expected: FAIL because endpoint check is not yet implemented in `DoorResolver`.

- [ ] **Step 3: Implement endpoint and proximity validation in `DoorResolver`**

In `src/dungeon_generator/core/solvers/door_resolver.gd`:
1. In `_validate_all_placements()`, check that `door.corridor_cell` matches `path.centerline_cells[0]` or `path.centerline_cells[-1]` for the matching room.
2. In multi-door checks on the same corridor path, verify that two doors on the same run are either the legitimate opposite endpoints or separated by `>= config.minimum_corridor_door_spacing`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_door_endpoint_quality.gd"`
Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_phase6_door_resolver.gd"`
Expected: PASS with 100% assertions.

- [ ] **Step 5: Commit**

```bash
git add src/dungeon_generator/core/solvers/door_resolver.gd tests/test_door_endpoint_quality.gd tests/test_phase6_door_resolver.gd
git commit -m "feat(doors): add endpoint validation and corridor-run proximity checks in DoorResolver"
```

---

### Task 9: Dungeon Pipeline Metrics & Full CI Suite Integration

**Files:**
- Modify: `src/dungeon_generator/core/dungeon_pipeline.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Produces: Aggregated dungeon generation metrics in `DungeonResult.metadata["aesthetic_metrics"]`: `average_turns_per_corridor`, `percent_zero_turn`, `percent_one_turn`, `percent_two_turn`, `door_count`, `min_door_distance`.
- Produces: `run_all_tests.gd` executing all new quality and spacing suites.

- [ ] **Step 1: Write test checking pipeline aesthetic metrics**

In `tests/test_corridor_aesthetic_quality.gd`, run full `DungeonPipeline.generate()` and assert that:
- `dungeon_res.metadata.has("aesthetic_metrics")`
- `dungeon_res.metadata["aesthetic_metrics"]["average_turns_per_corridor"] <= 2.0`
- `dungeon_res.metadata["aesthetic_metrics"]["staircase_corridors"] == 0`

- [ ] **Step 2: Run test to verify it fails**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_corridor_aesthetic_quality.gd"`

- [ ] **Step 3: Update `DungeonPipeline` and `run_all_tests.gd`**

1. In `src/dungeon_generator/core/dungeon_pipeline.gd`, collect corridor aesthetic metrics after Phase 5 and Phase 6, storing them in `result.metadata["aesthetic_metrics"]`.
2. In `tests/run_all_tests.gd`, add the 4 new test suites:
   - `"res://tests/test_orthogonal_corridor_planner.gd"`
   - `"res://tests/test_corridor_aesthetic_quality.gd"`
   - `"res://tests/test_door_spacing.gd"`
   - `"res://tests/test_door_endpoint_quality.gd"`

- [ ] **Step 4: Run full CI test runner to verify 100% pass**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/run_all_tests.gd"`
Expected: All suites execute with 0 failures.

- [ ] **Step 5: Commit**

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

- [ ] **Step 1: Run golden fixtures test**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_golden_fixtures.gd"`

- [ ] **Step 2: Update golden fixtures expectations with clean orthogonal corridors**

Update `test_golden_fixtures.gd` to assert that average turns <= 2.0 and door spacing is strictly respected across all golden seeds.

- [ ] **Step 3: Run stress test on 1,000+ seeds**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_stress_10k_seeds.gd"`
Expected: PASS with 100% success rate.

- [ ] **Step 4: Commit**

```bash
git add tests/test_golden_fixtures.gd tests/test_stress_10k_seeds.gd
git commit -m "test(qa): verify golden fixtures and multi-seed stress test with orthogonal carver"
```
