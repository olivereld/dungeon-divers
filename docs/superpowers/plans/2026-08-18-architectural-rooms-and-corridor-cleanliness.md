# Architectural Rooms & Corridor Cleanliness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate degenerate "worm-like" 1-tile rooms, cross stubs, orphaned room islands, and 1-tile parallel corridor grazing by introducing parametric architectural room templates, room integrity cleaning, and corridor clearance buffering.

**Architecture:**
1. `RoomShapeGenerator`: Generates spacious, recognizable room interiors (Open Hall, Pillared Sanctuary, Octagonal Vault, Corner Alcove) with guaranteed $\ge 70\%$ walkable core, replacing destructive small-box cellular automata.
2. `RoomIntegrityCleaner`: Prunes isolated room pockets ($< 4$ cells) that become detached when corridors slice through room peripheries.
3. `AStarCarver` Buffer Penalty: Adds proximity cost to tiles sharing an immediate wall with unrelated rooms, encouraging corridors to route with natural separation.
4. CI test suite validating seed `812297351` and the 10 Golden Seeds.

**Tech Stack:** Godot 4.6 Stable (Static GDScript, headless testing CLI).

**Spec:** [a-plan/fix-1-dungeon.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fix-1-dungeon.md) & Seed `812297351` diagnostic analysis.

## Global Constraints
- Every pipeline decision must remain bit-by-bit deterministic using derived seeds (`_DungeonSeedFactoryScript.derive_seed`).
- Zero 1-tile-wide worm rooms: every room must have a minimum open convex core $\ge 3\times 3$.
- Zero orphaned floor islands ($< 4$ cells) detached from main room bodies.

---

### Task 1: Parametric Architectural Room Generator (`RoomShapeGenerator`)

**Files:**
- Create: `src/dungeon_generator/core/algorithms/room_shape_generator.gd`
- Test: `tests/test_room_shape_generator.gd`

**Interfaces:**
- Produces: `RoomShapeGenerator.apply_room_shape(grid: CellGrid, room: RoomData, shape_type: String, rng: RandomNumberGenerator) -> void`
- Shapes:
  - `OPEN_HALL`: Full rectangular floor with clean perimeter.
  - `PILLARED_HALL`: Rectangular floor with symmetrical 1x1 stone columns spaced $\ge 2$ tiles from walls.
  - `OCTAGONAL_CHAMBER`: Rectangular floor with beveled/chamfered 45° solid corners.
  - `CRUCIFORM_SANCTUARY`: Cross-shaped grand chamber with recessed corner walls.
- Invariant: Walkable floor ratio $\ge 70\%$ of room bounding box, zero disconnected fragments.

- [ ] **Step 1: Write the failing test** in `tests/test_room_shape_generator.gd`.
- [ ] **Step 2: Run test to verify it fails**.
- [ ] **Step 3: Write minimal implementation** of `RoomShapeGenerator`.
- [ ] **Step 4: Run test to verify it passes**.
- [ ] **Step 5: Commit**.

---

### Task 2: Pipeline Integration for Room Shapes

**Files:**
- Modify: `src/dungeon_generator/core/dungeon_pipeline.gd:358-378`
- Test: `tests/test_pipeline_room_shapes.gd`

**Interfaces:**
- Updates `_build_rooms()` in `DungeonPipeline`:
  - `start`, `boss`, `goal`: Use `OPEN_HALL` or `PILLARED_HALL`.
  - `treasure`, `puzzle`, `explore`: Sample deterministic architectural shape based on room aspect ratio and derived variation seed.
  - Safe-guards `CellularAutomata` to only execute on large cave areas ($\ge 12\times 12$).

- [ ] **Step 1: Write the failing test** in `tests/test_pipeline_room_shapes.gd`.
- [ ] **Step 2: Run test to verify it fails**.
- [ ] **Step 3: Write minimal implementation** in `DungeonPipeline`.
- [ ] **Step 4: Run test to verify it passes**.
- [ ] **Step 5: Commit**.

---

### Task 3: Orphaned Room Pocket & Island Cleaner (`RoomIntegrityCleaner`)

**Files:**
- Create: `src/dungeon_generator/core/repair/room_integrity_cleaner.gd`
- Modify: `src/dungeon_generator/core/dungeon_pipeline.gd:180-210`
- Test: `tests/test_room_integrity_cleaner.gd`

**Interfaces:**
- Produces: `RoomIntegrityCleaner.clean_orphaned_room_pockets(grid: CellGrid, rooms: Array[RoomData], min_pocket_size: int = 4) -> int`
- Behavior: For each room, flood-fills from `room.get_center()`. Any disconnected `FLOOR` tiles inside the room bounding box that cannot reach the room center are reverted to `WALL`.

- [ ] **Step 1: Write the failing test** in `tests/test_room_integrity_cleaner.gd`.
- [ ] **Step 2: Run test to verify it fails**.
- [ ] **Step 3: Write minimal implementation** of `RoomIntegrityCleaner`.
- [ ] **Step 4: Run test to verify it passes**.
- [ ] **Step 5: Commit**.

---

### Task 4: Corridor Clearance Buffer in AStar Carver (`AStarCarver`)

**Files:**
- Modify: `src/dungeon_generator/core/algorithms/astar_carver.gd:110-180`
- Test: `tests/test_corridor_clearance_buffer.gd`

**Interfaces:**
- Consumes: `grid: CellGrid`, `room_bounds: Array[Rect2i]`.
- Behavior: In `_get_movement_cost()`, add a mild penalty (+1.5 cost) for carving immediately adjacent (distance = 1) to an unrelated room's perimeter unless approaching the designated entrance point.

- [ ] **Step 1: Write the failing test** in `tests/test_corridor_clearance_buffer.gd`.
- [ ] **Step 2: Run test to verify it fails**.
- [ ] **Step 3: Write minimal implementation** in `AStarCarver`.
- [ ] **Step 4: Run test to verify it passes**.
- [ ] **Step 5: Commit**.

---

### Task 5: Seed 812297351 & Golden Seeds Full Suite Verification

**Files:**
- Modify: `tests/test_golden_seeds_reforced.gd`
- Test: `tests/test_golden_seeds_reforced.gd`, `tests/debug_seed_812297351.gd`, `tests/run_all_tests.gd`

**Validation:**
- Seed `812297351`: All 7 rooms are open and spacious ($\ge 70\%$ floor), 0 worm rooms, 0 floating 1-tile islands.
- All 10 Golden Seeds pass with 0 regressions.
- CI 28+ test suites pass 100%.

- [ ] **Step 1: Run seed 812297351 test and verify visual floorplan**.
- [ ] **Step 2: Run full CI test suite**.
- [ ] **Step 3: Commit and update walkthrough**.
