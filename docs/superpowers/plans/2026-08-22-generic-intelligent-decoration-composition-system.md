# Generic Intelligent Decoration & Composition System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the decoration system from independent random anchor picking into a declarative, constraint-based, deterministic spatial composition engine (Generic Intelligent Decoration & Composition System).

**Architecture:** Introduce `DecorationCompositionProfile`, `DecorationCompositionRule`, `DecorationRelationship`, and `DecorationPlacementConstraint` to express spatial intent. A candidate generator (`DecorationPlacementCandidate`) filters anchors through hard constraints and scores them deterministically via `DecorationPlacementScorer` and `DecorationOrientationResolver`, managing physical and clearance occupancy in `DecorationOccupancyMap` without touching `CellGrid`.

**Tech Stack:** Godot 4.x, GDScript, Procedural Decoration Architecture, Strict Determinism.

**Spec:** Generic Intelligent Decoration & Composition System Architecture (Phases 0 - 60, focus on Blocks A-D foundation).

## Global Constraints
- Core (`DungeonArchetype`, `RoomPurpose`, `DungeonSemanticResult`, `RoomData`, `CellGrid`) must remain 100% agnostic to props, fixtures, and furniture names.
- Spawners only materialize (`Directive` -> `Node3D`); they never make placement or clearance decisions.
- `CellGrid` is never modified during decoration; spatial reservation and footprint tracking live in presentation occupancy data structures.
- Strict determinism: all placement calculations use derived room seeds (`PresentationSeedContext`), never global `randi()`, `randf()`, or `randomize()`.
- Zero hardcoded `if archetype == MAUSOLEUM:` in the composition engine; all rules and behaviors are driven by generic Resources.

---

### Task 1: Core Composition Enums and Tags (`DecorationTag`, `CompositionRole`, `DecorationRelationship`)

**Files:**
- Create: `src/presentation/decoration/composition/decoration_tag.gd`
- Create: `src/presentation/decoration/composition/composition_role.gd`
- Create: `src/presentation/decoration/composition/decoration_relationship.gd`
- Test: `tests/presentation/decoration/composition/test_composition_contracts.gd`

**Interfaces:**
- `DecorationTag`: Constants/BitFlags (`FOCAL`, `SEATING`, `BURIAL`, `RITUAL`, `LIGHTING`, `STORAGE`, `WALL_DECOR`, `TABLETOP`, `FLOOR_LIGHT`, `NAVIGATION_SENSITIVE`).
- `CompositionRole`: Enum (`PRIMARY = 0`, `SECONDARY = 1`, `COMPANION = 2`, `LIGHTING = 3`, `DETAIL = 4`).
- `DecorationRelationship`: Enum (`NEAR = 0`, `ADJACENT = 1`, `SYMMETRIC = 2`, `OPPOSITE = 3`, `CENTERED_ON = 4`, `ALIGNED_WITH = 5`, `SUPPORTED_BY = 6`, `FACE_TOWARD = 7`, `KEEP_AWAY_FROM = 8`).

- [x] **Step 1: Write the failing test**
Create `tests/presentation/decoration/composition/test_composition_contracts.gd` testing all enum members, conversions, and relationships.

- [x] **Step 2: Run test to verify it fails**
Run test using SceneTree execution. Expected: FAIL (files missing).

- [x] **Step 3: Write minimal implementation**
Implement `decoration_tag.gd`, `composition_role.gd`, and `decoration_relationship.gd`.

- [x] **Step 4: Run test to verify it passes**
Run `test_composition_contracts.gd`. Expected: PASS.

---

### Task 2: Placement Constraints and Orientation Modes

**Files:**
- Create: `src/presentation/decoration/composition/decoration_placement_constraint.gd`
- Create: `src/presentation/decoration/composition/decoration_orientation_mode.gd`
- Test: `tests/presentation/decoration/composition/test_placement_constraints.gd`

**Interfaces:**
- `DecorationOrientationMode`: Enum (`FACE_ROOM = 0`, `FACE_WALL = 1`, `FACE_CENTER = 2`, `ALIGN_WALL = 3`, `ALIGN_AXIS = 4`, `FREE = 5`).
- `DecorationPlacementConstraint`: Class defining hard constraints (`CANNOT_OVERLAP`, `CANNOT_TOUCH_DOOR`, `CANNOT_TOUCH_STAIRS`, `MUST_BE_FLOOR`, `MUST_BE_WALL`, `MUST_BE_CORNER`, `MUST_HAVE_CLEAR_APPROACH`).

- [x] **Step 1: Write the failing test**
Create `test_placement_constraints.gd` validating constraint evaluation and orientation enum contracts.

- [x] **Step 2: Run test to verify it fails**
Run `test_placement_constraints.gd`. Expected: FAIL.

- [x] **Step 3: Write minimal implementation**
Implement `decoration_orientation_mode.gd` and `decoration_placement_constraint.gd`.

- [x] **Step 4: Run test to verify it passes**
Run `test_placement_constraints.gd`. Expected: PASS.

---

### Task 3: Unified Decoration Occupancy Map (`DecorationOccupancyMap`)

**Files:**
- Create: `src/presentation/decoration/composition/decoration_occupancy_map.gd`
- Test: `tests/presentation/decoration/composition/test_decoration_occupancy_map.gd`

**Interfaces:**
- `DecorationOccupancyMap`:
  - `add_footprint(cells: Array[Vector2i], owner_id: StringName, layer: int) -> bool`
  - `add_clearance(cells: Array[Vector2i], owner_id: StringName) -> void`
  - `is_cell_available(cell: Vector2i, check_clearance: bool = false) -> bool`
  - `is_area_available(cells: Array[Vector2i], check_clearance: bool = false) -> bool`
  - `register_surface(cell: Vector2i, surface_type: StringName, height: float, owner_id: StringName) -> void`
  - `get_surface(cell: Vector2i) -> Dictionary`

- [x] **Step 1: Write the failing test**
Create `test_decoration_occupancy_map.gd` testing footprint collisions, clearances, and surface registrations.

- [x] **Step 2: Run test to verify it fails**
Run `test_decoration_occupancy_map.gd`. Expected: FAIL.

- [x] **Step 3: Write minimal implementation**
Implement `decoration_occupancy_map.gd`.

- [x] **Step 4: Run test to verify it passes**
Run `test_decoration_occupancy_map.gd`. Expected: PASS.

---

### Task 4: Placement Candidate and Orientation Resolver

**Files:**
- Create: `src/presentation/decoration/composition/decoration_placement_candidate.gd`
- Create: `src/presentation/decoration/composition/decoration_orientation_resolver.gd`
- Test: `tests/presentation/decoration/composition/test_candidate_and_orientation.gd`

**Interfaces:**
- `DecorationPlacementCandidate`: RefCounted storing `style`, `cell: Vector2i`, `rotation_y: float`, `occupied_cells: Array[Vector2i]`, `clearance_cells: Array[Vector2i]`, `score: float`, `violations: Array[StringName]`.
- `DecorationOrientationResolver`:
  - `resolve_rotation(anchor, orientation_mode: int, room_geometry, tile_size: float) -> float`

- [x] **Step 1: Write the failing test**
Create `test_candidate_and_orientation.gd` testing orientation towards room interior for wall furniture, axis alignment, and candidate data structure.

- [x] **Step 2: Run test to verify it fails**
Run `test_candidate_and_orientation.gd`. Expected: FAIL.

- [x] **Step 3: Write minimal implementation**
Implement `decoration_placement_candidate.gd` and `decoration_orientation_resolver.gd`.

- [x] **Step 4: Run test to verify it passes**
Run `test_candidate_and_orientation.gd`. Expected: PASS.

---

### Task 5: Deterministic Placement Scorer (`DecorationPlacementScorer`)

**Files:**
- Create: `src/presentation/decoration/composition/decoration_placement_scorer.gd`
- Test: `tests/presentation/decoration/composition/test_placement_scorer.gd`

**Interfaces:**
- `DecorationPlacementScorer`:
  - `score_candidate(candidate: DecorationPlacementCandidate, rule, occupancy: DecorationOccupancyMap, room_geometry, context_seed: int) -> float`

- [x] **Step 1: Write the failing test**
Create `test_placement_scorer.gd` testing score bonuses (symmetry, center suitability, wall alignment) and penalties (door proximity, overcrowding).

- [x] **Step 2: Run test to verify it fails**
Run `test_placement_scorer.gd`. Expected: FAIL.

- [x] **Step 3: Write minimal implementation**
Implement `decoration_placement_scorer.gd` with deterministic heuristic math.

- [x] **Step 4: Run test to verify it passes**
Run `test_placement_scorer.gd`. Expected: PASS.

---

### Task 6: Composition Rule and Profile Resources (`DecorationCompositionRule`, `DecorationCompositionProfile`)

**Files:**
- Create: `src/presentation/decoration/composition/decoration_composition_rule.gd`
- Create: `src/presentation/decoration/composition/decoration_composition_profile.gd`
- Test: `tests/presentation/decoration/composition/test_composition_profile_rules.gd`

**Interfaces:**
- `DecorationCompositionRule`: Resource containing `rule_id: StringName`, `composition_role: int`, `target_tags: Array[StringName]`, `placement_mode: int`, `orientation_mode: int`, `min_count: int`, `max_count: int`, `clearance: int`, `relationships: Array[Dictionary]`.
- `DecorationCompositionProfile`: Resource containing `id: StringName`, `rules: Array[DecorationCompositionRule]`, `max_total_props: int`, `lighting_budget: float`.

- [x] **Step 1: Write the failing test**
Create `test_composition_profile_rules.gd` creating and verifying composition profiles (e.g. `CentralFocal`, `WallFurniture`, `SymmetricalPair`).

- [x] **Step 2: Run test to verify it fails**
Run `test_composition_profile_rules.gd`. Expected: FAIL.

- [x] **Step 3: Write minimal implementation**
Implement `decoration_composition_rule.gd` and `decoration_composition_profile.gd`.

- [x] **Step 4: Run test to verify it passes**
Run `test_composition_profile_rules.gd`. Expected: PASS.

---

### Task 7: Composition Planner and Resolver Integration (`DecorationCompositionPlanner`)

**Files:**
- Create: `src/presentation/decoration/composition/decoration_composition_planner.gd`
- Modify: `src/presentation/decoration/decoration_composition_resolver.gd`
- Test: `tests/presentation/decoration/composition/test_composition_planner_e2e.gd`

**Interfaces:**
- `DecorationCompositionPlanner`:
  - `plan_room_composition(profile: DecorationCompositionProfile, palette: DecorationPalette, room_geometry, room_context, seed_ctx: PresentationSeedContext) -> DecorationComposition`

- [x] **Step 1: Write the failing test**
Create `test_composition_planner_e2e.gd` testing end-to-end composition planning for Tomb, Sacristy, and Catacomb rooms without overlapping lights, bench facing wall, or duplicated focals.

- [x] **Step 2: Run test to verify it fails**
Run `test_composition_planner_e2e.gd`. Expected: FAIL.

- [x] **Step 3: Implement DecorationCompositionPlanner and wire into DecorationCompositionResolver**
Connect the new planner as the primary composition engine, keeping legacy anchor fallback safely encapsulated.

- [x] **Step 4: Run test to verify it passes**
Run `test_composition_planner_e2e.gd` and `tests/run_all_tests.gd`. Expected: 100% PASS across all suites.
