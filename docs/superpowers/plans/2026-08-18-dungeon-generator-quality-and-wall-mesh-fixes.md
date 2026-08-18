# Dungeon Generator Quality & Wall Mesh Geometric Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve geometric distortions (miter spikes), corridor dead-end stubs (1-tile jagged alcoves), invalid floating door placements, and mesh gap defects identified in generated dungeon layouts.

**Architecture:** 
1. `CorridorPruner`: Cleans up 1-tile dead-end pockets and redundant jagged stubs from corridor networks before door resolution.
2. `DoorPhysicalValidator`: Enforces physical wall-jamb invariants (solid flanking walls on both sides of a door) and prevents doors blocking isolated 1x1 cells by converting invalid doors to `OPEN_PASSAGE`.
3. `ContinuousWallMeshBuilder`: Adds vertex welding, miter angle clamping, and degenerate triangle removal to eliminate visual spikes and triangle wedges at wall corners.
4. Seamless integration across pipeline stages and regression verification against golden seeds and user test seeds.

**Tech Stack:** Godot 4.6 Stable (Static GDScript, headless testing CLI).

**Spec:** [a-plan/fix-1-dungeon.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fix-1-dungeon.md).

## Global Constraints
- Every pipeline decision must remain bit-by-bit deterministic using derived seeds (`DungeonSeedFactoryScript.derive_seed`).
- Zero floating or non-enclosed physical doors: every `CLOSED_DOOR` / `LOCKED_DOOR` must have flanking solid walls.
- Zero degenerate triangles or stretched miter wedges in 3D continuous wall meshes.

---

### Task 1: Corridor Dead-End Stub Pruner (`CorridorPruner`)

**Files:**
- Create: `src/dungeon_generator/core/algorithms/corridor_pruner.gd`
- Modify: `src/dungeon_generator/core/dungeon_pipeline.gd:220-250`
- Test: `tests/test_corridor_pruner.gd`

**Interfaces:**
- Produces: `CorridorPruner.prune_dead_end_stubs(grid: CellGrid, protected_cells: Array[Vector2i]) -> int`
- Invariant: A corridor cell with $\ge 3$ non-walkable orthogonal neighbors and not in `protected_cells` (entrances, doors, spawns) is pruned back to `WALL`.

- [ ] **Step 1: Write the failing test** in `tests/test_corridor_pruner.gd`.
- [ ] **Step 2: Run test to verify it fails**.
- [ ] **Step 3: Write minimal implementation** of `CorridorPruner`.
- [ ] **Step 4: Run test to verify it passes**.
- [ ] **Step 5: Commit**.

---

### Task 2: Physical Door Jamb Validation & Free Area Check (`DoorPhysicalValidator`)

**Files:**
- Create: `src/dungeon_generator/core/validation/door_physical_validator.gd`
- Modify: `src/dungeon_generator/core/solvers/door_resolver.gd:160-210`
- Test: `tests/test_door_physical_validator.gd`

**Interfaces:**
- Produces: `DoorPhysicalValidator.validate_door_jambs(grid: CellGrid, door_pos: Vector2i, side: int) -> bool`
- Produces: `DoorPhysicalValidator.get_local_free_area(grid: CellGrid, origin: Vector2i, radius: int) -> int`
- Behavior: If a candidate `CLOSED_DOOR` does not have solid wall jambs on both lateral sides or blocks an isolated $\le 1$ free area pocket, it is automatically demoted to `OPEN_PASSAGE`.

- [ ] **Step 1: Write the failing test** in `tests/test_door_physical_validator.gd`.
- [ ] **Step 2: Run test to verify it fails**.
- [ ] **Step 3: Write minimal implementation** in `DoorPhysicalValidator` and hook into `DoorResolver`.
- [ ] **Step 4: Run test to verify it passes**.
- [ ] **Step 5: Commit**.

---

### Task 3: Continuous Wall Mesh Miter Clamping & Degenerate Triangle Removal

**Files:**
- Modify: `src/wall_mesh_generator/core/continuous_wall_extractor.gd:80-160`
- Modify: `src/wall_mesh_generator/core/continuous_wall_mesh_builder.gd:60-140`
- Test: `tests/test_wall_mesh_spike_suppression.gd`

**Interfaces:**
- Consumes: Extracted `WallLoop` polylines.
- Produces: Sanitized `ArrayMesh` with vertex welding ($< 0.001\text{m}$), clamped miter offsets at sharp corners, and zero zero-area degenerate triangles.

- [ ] **Step 1: Write the failing test** in `tests/test_wall_mesh_spike_suppression.gd`.
- [ ] **Step 2: Run test to verify it fails**.
- [ ] **Step 3: Write minimal implementation** with vertex welding and miter limit clamping.
- [ ] **Step 4: Run test to verify it passes**.
- [ ] **Step 5: Commit**.

---

### Task 4: Unified Doorway Opening Alignment & Gap Suppression

**Files:**
- Modify: `src/dungeon_generator/core/data/door_manifest_factory.gd:50-90`
- Modify: `src/dungeon_generator/presentation/dungeon_door_spawner.gd:90-140`
- Test: `tests/test_door_wall_alignment.gd`

**Interfaces:**
- Ensures `WallOpeningManifest` cuts precise rectangular openings in `ContinuousWallExtractor` that align with `StoneArch` portal frames without visible pixel gaps or overlaps.

- [ ] **Step 1: Write the failing test** in `tests/test_door_wall_alignment.gd`.
- [ ] **Step 2: Run test to verify it fails**.
- [ ] **Step 3: Write minimal implementation**.
- [ ] **Step 4: Run test to verify it passes**.
- [ ] **Step 5: Commit**.

---

### Task 5: Golden Seeds, Visual Inspection & Full Integration Verification

**Files:**
- Modify: `tests/test_golden_seeds_reforced.gd`
- Test: All suites (`test_golden_seeds_reforced.gd`, `test_golden_seeds_visual_quality.gd`, `test_corridor_pruner.gd`, `test_door_physical_validator.gd`, `test_wall_mesh_spike_suppression.gd`)

**Validation:**
- 0 door jamb invalidity violations across 10 golden seeds + seed `221533744`.
- 0 corridor 1-tile dead-end stubs.
- 0 miter spike deformations in wall meshes.

- [ ] **Step 1: Run full test suite across all golden seeds**.
- [ ] **Step 2: Verify zero regressions and 100% assertions passing**.
- [ ] **Step 3: Commit and update walkthrough**.
