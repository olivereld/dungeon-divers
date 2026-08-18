# Smart Door Placement & Corridor Wall Boundaries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement an intelligent, deterministic door placement policy and corridor wall boundary enclosure:
1. Eliminate redundant double doors in short corridors ($\le 3$ tiles) by placing at most 1 door (or open passage) based on seeded RNG and room priority.
2. Support open archways / open thresholds (`OPEN_PASSAGE`) without wooden door entities.
3. Guarantee continuous perimeter walls separating parallel corridors from adjacent non-connected rooms.

**Architecture:** Extend data layer with `DoorType`, add `CorridorAnalyzer` for corridor geometric metrics, integrate `DoorPlacementPolicy` in `DoorResolver` using connection-derived seeds, and adapt `DungeonDoorSpawner` to spawn stone archways for `OPEN_PASSAGE` vs interactive wooden doors for `CLOSED_DOOR`.

**Tech Stack:** Godot 4.6 Stable (Static GDScript, headless testing CLI).

**Spec:** [a-plan/fase-reforced](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fase-reforced).

## Global Constraints
- Every decision must be bit-by-bit deterministic using derived seeds (`DungeonSeedFactoryScript.derive_seed`).
- Strict static typing across all variables, parameters, and return types.
- Atomic commit cycle: `Resolve -> Validate -> Commit` without premature mutation of `CellGrid`.
- Strict TDD: write failing test, verify failure in Godot 4.6 headless, write minimal implementation, verify pass, commit.

---

### Task 1: Data Model & Config Foundation (`DoorType`, `DoorPlacement`, `DungeonConfig`)

**Files:**
- Create: `src/dungeon_generator/core/data/door_type.gd`
- Modify: `src/dungeon_generator/core/data/door_placement.gd`
- Modify: `src/dungeon_generator/config/dungeon_config.gd`
- Test: `tests/test_door_data_and_config.gd`

**Interfaces:**
- Produces: `DoorType.CLOSED_DOOR`, `DoorType.LOCKED_DOOR`, `DoorType.OPEN_PASSAGE`.
- Produces: `DoorPlacement.door_type`, `DoorPlacement.is_open_passage()`.
- Produces: `DungeonConfig` exports (`door_open_passage_chance`, `door_single_door_chance`, `door_double_door_chance`, `min_corridor_length_for_double_doors`, `short_corridor_single_door_threshold`).

- [ ] **Step 1: Write the failing test**

Create `tests/test_door_data_and_config.gd`:
```gdscript
extends SceneTree

func _init() -> void:
	print("--- Running test_door_data_and_config ---")
	var DoorTypeScript = preload("res://src/dungeon_generator/core/data/door_type.gd")
	assert(DoorTypeScript != null, "DoorType script must exist")
	assert(DoorTypeScript.DoorType.CLOSED_DOOR == 0, "CLOSED_DOOR enum")
	assert(DoorTypeScript.DoorType.LOCKED_DOOR == 1, "LOCKED_DOOR enum")
	assert(DoorTypeScript.DoorType.OPEN_PASSAGE == 2, "OPEN_PASSAGE enum")

	var cfg := DungeonConfig.new()
	assert("door_open_passage_chance" in cfg, "Config must have door_open_passage_chance")
	assert("door_single_door_chance" in cfg, "Config must have door_single_door_chance")
	assert("door_double_door_chance" in cfg, "Config must have door_double_door_chance")
	assert("min_corridor_length_for_double_doors" in cfg, "Config must have min_corridor_length_for_double_doors")
	assert("short_corridor_single_door_threshold" in cfg, "Config must have short_corridor_single_door_threshold")

	var DoorPlacementScript = preload("res://src/dungeon_generator/core/data/door_placement.gd")
	var dp = DoorPlacementScript.new(1, 0, Vector2i(5, 5), 0, Vector2i(5, 4), Vector2i(5, 6))
	assert("door_type" in dp, "DoorPlacement must have door_type")
	assert(dp.door_type == DoorTypeScript.DoorType.CLOSED_DOOR, "Default door_type must be CLOSED_DOOR")
	assert(dp.is_open_passage() == false, "Default is_open_passage must be false")

	dp.door_type = DoorTypeScript.DoorType.OPEN_PASSAGE
	assert(dp.is_open_passage() == true, "is_open_passage must return true for OPEN_PASSAGE")

	print("[PASS] test_door_data_and_config completed successfully!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_door_data_and_config.gd"`
Expected: FAIL with "Preload file does not exist".

- [ ] **Step 3: Write minimal implementation**

1. Create `src/dungeon_generator/core/data/door_type.gd`:
```gdscript
class_name DoorType
extends RefCounted

enum DoorType {
	CLOSED_DOOR = 0,
	LOCKED_DOOR = 1,
	OPEN_PASSAGE = 2
}
```

2. Modify `src/dungeon_generator/core/data/door_placement.gd`:
```gdscript
const _DoorTypeScript = preload("res://src/dungeon_generator/core/data/door_type.gd")

var door_type: int = _DoorTypeScript.DoorType.CLOSED_DOOR
var reason: String = "DEFAULT"

func is_open_passage() -> bool:
	return door_type == _DoorTypeScript.DoorType.OPEN_PASSAGE
```

3. Modify `src/dungeon_generator/config/dungeon_config.gd`:
```gdscript
@export_group("Door Placement Policy")
@export var min_corridor_length_for_double_doors: int = 6
@export var short_corridor_single_door_threshold: int = 3
@export_range(0.0, 1.0) var door_open_passage_chance: float = 0.25
@export_range(0.0, 1.0) var door_single_door_chance: float = 0.65
@export_range(0.0, 1.0) var door_double_door_chance: float = 0.10
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_door_data_and_config.gd"`
Expected: PASS with 100% assertions.

- [ ] **Step 5: Commit**

```bash
git add src/dungeon_generator/core/data/door_type.gd src/dungeon_generator/core/data/door_placement.gd src/dungeon_generator/config/dungeon_config.gd tests/test_door_data_and_config.gd
git commit -m "feat(data): add DoorType enum, DoorPlacement type property, and DoorPlacementPolicy config (Task 1)"
```

---

### Task 2: Corridor Wall Enclosure & Separation from Non-Connected Rooms

**Files:**
- Modify: `src/dungeon_generator/core/algorithms/orthogonal_corridor_planner.gd`
- Modify: `src/dungeon_generator/core/algorithms/astar_carver.gd`
- Modify: `src/wall_mesh_generator/core/continuous_wall_extractor.gd`
- Test: `tests/test_corridor_wall_enclosure.gd`

**Interfaces:**
- Guarantees that when a corridor runs parallel or adjacent to a non-connected room, it preserves a 1-tile wall or `ContinuousWallExtractor` extracts the continuous boundary wall between `FLOOR` and `CORRIDOR` unless explicitly registered in `opening_manifest`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_corridor_wall_enclosure.gd`:
```gdscript
extends SceneTree

func _init() -> void:
	print("--- Running test_corridor_wall_enclosure ---")
	var grid := CellGrid.new(20, 20)
	var room := RoomData.new(0, Rect2i(2, 2, 6, 6), &"room0")
	grid.fill_rect(room.rect, CellGrid.CellType.FLOOR)

	# Parallel corridor at x=8 adjacent to room0 boundary at x=7
	for y in range(2, 8):
		grid.set_cell(Vector2i(8, y), CellGrid.CellType.CORRIDOR)

	var extractor = preload("res://src/wall_mesh_generator/core/continuous_wall_extractor.gd")
	var loops = extractor.extract_wall_loops(grid, 2.0, null)
	assert(loops.size() >= 1, "Must extract closed wall loops separating room from adjacent parallel corridor")

	print("[PASS] test_corridor_wall_enclosure completed successfully!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_corridor_wall_enclosure.gd"`

- [ ] **Step 3: Write minimal implementation**

1. In `continuous_wall_extractor.gd`, ensure internal boundaries between different non-connected regions (such as room floor vs parallel corridor floor) generate boundary edges unless marked in `opening_manifest`.
2. In `orthogonal_corridor_planner.gd`, enforce penalty/buffer in `is_cell_valid_for_corridor` for cells sharing borders with un-connected rooms.

- [ ] **Step 4: Run test to verify it passes**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_corridor_wall_enclosure.gd"`
Expected: PASS with 100% assertions.

- [ ] **Step 5: Commit**

```bash
git add src/dungeon_generator/core/algorithms/orthogonal_corridor_planner.gd src/dungeon_generator/core/algorithms/astar_carver.gd src/wall_mesh_generator/core/continuous_wall_extractor.gd tests/test_corridor_wall_enclosure.gd
git commit -m "fix(walls): enforce wall boundaries between parallel corridors and adjacent rooms (Task 2)"
```

---

### Task 3: Corridor Analysis & Metrics (`CorridorInfo` / `CorridorAnalyzer`)

**Files:**
- Create: `src/dungeon_generator/core/data/corridor_info.gd`
- Create: `src/dungeon_generator/core/algorithms/corridor_analyzer.gd`
- Test: `tests/test_corridor_analyzer.gd`

**Interfaces:**
- Produces: `CorridorInfo` (`connection_id`, `length`, `min_width`, `max_width`, `endpoints`, `is_short`).
- Produces: `CorridorAnalyzer.analyze_corridor(grid, path, rooms) -> CorridorInfo`.

- [ ] **Step 1: Write the failing test**

Create `tests/test_corridor_analyzer.gd`:
```gdscript
extends SceneTree

func _init() -> void:
	print("--- Running test_corridor_analyzer ---")
	var AnalyzerScript = preload("res://src/dungeon_generator/core/algorithms/corridor_analyzer.gd")
	var PathScript = preload("res://src/dungeon_generator/core/data/corridor_path.gd")

	var path_short := PathScript.new(1, [Vector2i(5, 5), Vector2i(5, 6)])
	var grid := CellGrid.new(20, 20)
	grid.set_cell(Vector2i(5, 5), CellGrid.CellType.CORRIDOR)
	grid.set_cell(Vector2i(5, 6), CellGrid.CellType.CORRIDOR)

	var info = AnalyzerScript.analyze_corridor(grid, path_short, [])
	assert(info != null, "CorridorInfo must not be null")
	assert(info.length == 2, "Length must be 2")
	assert(info.is_short == true, "is_short must be true for length <= 3")

	print("[PASS] test_corridor_analyzer completed successfully!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_corridor_analyzer.gd"`

- [ ] **Step 3: Write minimal implementation**

1. Create `src/dungeon_generator/core/data/corridor_info.gd`:
```gdscript
class_name CorridorInfo
extends RefCounted

var connection_id: int = 0
var length: int = 0
var min_width: int = 1
var max_width: int = 1
var is_short: bool = false
var endpoints: Array = []
```

2. Create `src/dungeon_generator/core/algorithms/corridor_analyzer.gd`:
```gdscript
class_name CorridorAnalyzer
extends RefCounted

static func analyze_corridor(grid: CellGrid, path: RefCounted, rooms: Array) -> CorridorInfo:
	var info := CorridorInfo.new()
	if path == null:
		return info
	info.connection_id = path.connection_id
	info.length = path.centerline_cells.size()
	info.is_short = (info.length <= 3)
	return info
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_corridor_analyzer.gd"`
Expected: PASS with 100% assertions.

- [ ] **Step 5: Commit**

```bash
git add src/dungeon_generator/core/data/corridor_info.gd src/dungeon_generator/core/algorithms/corridor_analyzer.gd tests/test_corridor_analyzer.gd
git commit -m "feat(analysis): create CorridorInfo and CorridorAnalyzer (Task 3)"
```

---

### Task 4: Intelligent Door Selection & Short Corridor Single Door Policy (`DoorResolver`)

**Files:**
- Modify: `src/dungeon_generator/core/solvers/door_resolver.gd`
- Modify: `src/dungeon_generator/core/data/door_pair.gd`
- Modify: `src/dungeon_generator/core/validation/door_transition_validator.gd`
- Test: `tests/test_door_resolver_policy.gd`

**Interfaces:**
- Invariant: If `centerline_cells.size() <= 3`, the connection produces **at most 1 physical door** (`CLOSED_DOOR`), setting the other end as `OPEN_PASSAGE`.
- Invariant: Special rooms (Boss, Treasure, Puzzle) always prioritize physical doors at their entrance over Start / Normal rooms.

- [ ] **Step 1: Write the failing test**

Create `tests/test_door_resolver_policy.gd`:
```gdscript
extends SceneTree

func _init() -> void:
	print("--- Running test_door_resolver_policy ---")
	var ResolverScript = preload("res://src/dungeon_generator/core/solvers/door_resolver.gd")
	var DoorTypeScript = preload("res://src/dungeon_generator/core/data/door_type.gd")

	var grid := CellGrid.new(30, 30)
	var r1 := RoomData.new(0, Rect2i(2, 2, 6, 6), &"start")
	var r2 := RoomData.new(1, Rect2i(10, 2, 6, 6), &"boss")
	grid.fill_rect(r1.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(r2.rect, CellGrid.CellType.FLOOR)

	grid.set_cell(Vector2i(8, 4), CellGrid.CellType.CORRIDOR)
	grid.set_cell(Vector2i(9, 4), CellGrid.CellType.CORRIDOR)

	var ent_a = preload("res://src/dungeon_generator/core/data/room_entrance.gd").new(0, 1, Vector2i(7, 4), 1, Vector2i(6, 4), Vector2i(8, 4))
	var ent_b = preload("res://src/dungeon_generator/core/data/room_entrance.gd").new(1, 1, Vector2i(10, 4), 3, Vector2i(11, 4), Vector2i(9, 4))
	var ep = preload("res://src/dungeon_generator/core/data/entrance_pair.gd").new(1, ent_a, ent_b, 0.0)
	var conn = preload("res://src/dungeon_generator/core/data/room_connection.gd").new(1, 0, 1, true)
	var path = preload("res://src/dungeon_generator/core/data/corridor_path.gd").new(1, [Vector2i(8, 4), Vector2i(9, 4)])

	var cfg := DungeonConfig.new()
	cfg.seed = 12345
	cfg.use_fixed_seed = true

	var res = ResolverScript.resolve_doors(grid, [r1, r2], [ep], [path], [conn], cfg)
	assert(res.is_valid, "DoorResolver must resolve successfully")
	assert(res.door_pairs.size() == 1, "Must have 1 door pair")
	var dp = res.door_pairs[0]

	var closed_count: int = 0
	if dp.door_a.door_type != DoorTypeScript.DoorType.OPEN_PASSAGE: closed_count += 1
	if dp.door_b.door_type != DoorTypeScript.DoorType.OPEN_PASSAGE: closed_count += 1

	assert(closed_count <= 1, "Short corridor must have AT MOST 1 physical door, got %d" % closed_count)
	assert(dp.door_b.door_type != DoorTypeScript.DoorType.OPEN_PASSAGE, "Boss room door must be prioritized for physical door")

	print("[PASS] test_door_resolver_policy completed successfully!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_door_resolver_policy.gd"`

- [ ] **Step 3: Write minimal implementation in `door_resolver.gd`**

1. Calculate length of `path.centerline_cells`.
2. For short corridors ($\le 3$ tiles): evaluate room priority (`boss > treasure > puzzle > normal > start`). Assign `DoorType.CLOSED_DOOR` to the higher priority room and `DoorType.OPEN_PASSAGE` to the other.
3. For standard/long corridors: sample seeded RNG (`door_open_passage_chance`, `door_single_door_chance`, `door_double_door_chance`).

- [ ] **Step 4: Run test to verify it passes**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_door_resolver_policy.gd"`
Expected: PASS with 100% assertions.

- [ ] **Step 5: Commit**

```bash
git add src/dungeon_generator/core/solvers/door_resolver.gd src/dungeon_generator/core/data/door_pair.gd src/dungeon_generator/core/validation/door_transition_validator.gd tests/test_door_resolver_policy.gd
git commit -m "feat(resolver): implement smart door placement policy for short and standard corridors (Task 4)"
```

---

### Task 5: 3D Materialization of Open Archways (`DungeonDoorManifest` & `DungeonDoorSpawner`)

**Files:**
- Modify: `src/dungeon_generator/core/data/dungeon_door_manifest.gd`
- Modify: `src/dungeon_generator/core/data/door_manifest_factory.gd`
- Modify: `src/dungeon_generator/presentation/dungeon_door_spawner.gd`
- Test: `tests/test_door_spawner_passage.gd`

**Interfaces:**
- Produces: If `manifest.door_type == OPEN_PASSAGE`, `DungeonDoorSpawner` creates only `StoneArch` without `DoorEntity` (no wooden leaf, no blocking collider).

- [ ] **Step 1: Write the failing test**

Create `tests/test_door_spawner_passage.gd`:
```gdscript
extends SceneTree

func _init() -> void:
	print("--- Running test_door_spawner_passage ---")
	var SpawnerScript = preload("res://src/dungeon_generator/presentation/dungeon_door_spawner.gd")
	var ManifestScript = preload("res://src/dungeon_generator/core/data/dungeon_door_manifest.gd")
	var DoorTypeScript = preload("res://src/dungeon_generator/core/data/door_type.gd")

	var spawner = SpawnerScript.new()
	var staging := Node3D.new()

	var m_open = ManifestScript.new("open_0", 1, 0, Vector2i(5, 5), 0, Vector3(10, 0, 10), Vector3.ZERO)
	m_open.door_type = DoorTypeScript.DoorType.OPEN_PASSAGE

	var res = spawner.spawn_doors([m_open], staging, null, 2.0, 2, 1337)
	assert(res.spawned_doors.size() == 1, "Must process manifest")
	var portal = staging.get_node_or_null("Doors/DoorPortal_open_0")
	assert(portal != null, "Portal node must be created")
	assert(portal.has_node("DoorEntity") == false, "OPEN_PASSAGE must NOT instantiate DoorEntity (wooden door)")

	staging.free()
	print("[PASS] test_door_spawner_passage completed successfully!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_door_spawner_passage.gd"`

- [ ] **Step 3: Write minimal implementation**

1. In `dungeon_door_manifest.gd`, add `var door_type: int = 0`.
2. In `door_manifest_factory.gd`, pass `door.door_type` to manifest.
3. In `dungeon_door_spawner.gd`, instantiate `DoorEntity` only when `manifest.door_type != DoorType.OPEN_PASSAGE`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_door_spawner_passage.gd"`
Expected: PASS with 100% assertions.

- [ ] **Step 5: Commit**

```bash
git add src/dungeon_generator/core/data/dungeon_door_manifest.gd src/dungeon_generator/core/data/door_manifest_factory.gd src/dungeon_generator/presentation/dungeon_door_spawner.gd tests/test_door_spawner_passage.gd
git commit -m "feat(presentation): spawn open archways without wooden doors for OPEN_PASSAGE portals (Task 5)"
```

---

### Task 6: Golden Seeds & Seed 221533744 Integration

**Files:**
- Modify: `tests/test_golden_seeds_visual_quality.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Validates seed `221533744` and all 10 golden seeds to assert 0 short-corridor double doors, intact continuous perimeter wall meshes, 100% reachability and 0 regressions across the entire suite.

- [ ] **Step 1: Add seed 221533744 assertion to `test_golden_seeds_visual_quality.gd`**
- [ ] **Step 2: Run `test_golden_seeds_visual_quality.gd`**
`cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/test_golden_seeds_visual_quality.gd"`
- [ ] **Step 3: Run full CI test runner `run_all_tests.gd`**
`cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/run_all_tests.gd"`
- [ ] **Step 4: Commit**
`git commit -m "test(qa): verify smart door policy and corridor wall boundaries across CI test runner (Task 6)"`
