# Semantic Spatial Composition Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Semantic Spatial Composition Engine (Phases 10.1 - 10.18) to elevate dungeon decoration from basic placement rules to full spatial intention, zones, templates, relationship solving, and intelligent lighting with Crypt as the complete vertical slice.

**Architecture:** Introduce `DecorationRoomZone` partitioner, `DecorationRoomIntent`, `DecorationRelationshipSolver`, `DecorationCompositionTemplate`, `DecorationLightingPlanner`, and `DecorationPurposeProfileRegistry`. The `DecorationCompositionPlanner` orchestrates these modules deterministically without mutating `CellGrid` or hardcoding archetype/asset names in the algorithmic core.

**Tech Stack:** Godot 4.x, GDScript, Declarative Composition Architecture, Heuristic Determinism.

**Spec:** Generic Intelligent Decoration & Composition System Architecture (Phases 10.1 - 10.18).

## Global Constraints
- Core (`DungeonArchetype`, `RoomPurpose`, `DungeonSemanticResult`, `RoomData`, `CellGrid`) remains 100% agnostic to props, fixtures, and furniture names.
- Zero hardcoded `if archetype == CRYPT:` or `if asset == SARCOPHAGUS:` in planner code. All behaviors, prohibitions, and affinities are data-driven via Resources.
- Spawners only materialize (`Directive` -> `Node3D`); they never make placement or clearance decisions.
- `CellGrid` is never modified during decoration.
- Strict determinism: all placement calculations use derived room seeds (`PresentationSeedContext`), never global `randi()`, `randf()`, or `randomize()`.

---

### Task 1: Room Spatial Zones (`DecorationRoomZone`)

**Files:**
- Create: `src/presentation/decoration/composition/decoration_room_zone.gd`
- Test: `tests/presentation/decoration/composition/test_decoration_room_zone.gd`

**Interfaces:**
- `DecorationRoomZone`:
  - `enum ZoneType { ENTRY = 0, TRAVERSAL = 1, FOCAL = 2, SIDE = 3, CORNER = 4, CENTER = 5, PERIMETER = 6 }`
  - `partition_room(room_geom: PresentationRoomGeometry, tile_size: float = 2.0) -> Dictionary` (Vector2i -> ZoneType)

- [x] **Step 1: Write the failing test**
Create `test_decoration_room_zone.gd` testing classification of door access cells as `ENTRY`/`TRAVERSAL`, perimeter cells as `PERIMETER`/`CORNER`, and inner centroid as `CENTER`/`FOCAL`.

- [x] **Step 2: Run test to verify it fails**
Run: `Godot_v4.6.1-stable_win64.exe --headless -s res://tests/presentation/decoration/composition/test_decoration_room_zone.gd`
Expected: FAIL (file not found).

- [x] **Step 3: Write minimal implementation**
Implement `decoration_room_zone.gd` using distance-to-door and distance-to-wall metrics.

- [x] **Step 4: Run test to verify it passes**
Run test again. Expected: PASS.

---

### Task 2: Room Intent and Prohibitions (`DecorationRoomIntent`)

**Files:**
- Create: `src/presentation/decoration/composition/decoration_room_intent.gd`
- Test: `tests/presentation/decoration/composition/test_decoration_room_intent.gd`

**Interfaces:**
- `DecorationRoomIntent`: Resource containing `focal_zone: int`, `symmetry_required: bool`, `player_clearance_level: int`, `lighting_budget: float`, `combat_space_ratio: float`, `preferred_density: float`, `allowed_tags: Array[StringName]`, `forbidden_tags: Array[StringName]`.
- Methods: `is_tag_allowed(tag: StringName) -> bool`, `can_place_in_zone(zone_type: int) -> bool`.

- [x] **Step 1: Write the failing test**
Create `test_decoration_room_intent.gd` testing tag filtering and forbidden tag rejection.

- [x] **Step 2: Run test to verify it fails**
Run test. Expected: FAIL.

- [x] **Step 3: Write minimal implementation**
Implement `decoration_room_intent.gd`.

- [x] **Step 4: Run test to verify it passes**
Run test. Expected: PASS.

---

### Task 3: Relationship Solver and Symmetry (`DecorationRelationshipSolver`)

**Files:**
- Create: `src/presentation/decoration/composition/decoration_relationship_solver.gd`
- Test: `tests/presentation/decoration/composition/test_decoration_relationship_solver.gd`

**Interfaces:**
- `DecorationRelationshipSolver`:
  - `find_symmetric_positions(primary_cell: Vector2i, room_center: Vector2i, room_geom: PresentationRoomGeometry) -> Array[Vector2i]`
  - `find_nearby_positions(target_cell: Vector2i, min_dist: int, max_dist: int, room_geom: PresentationRoomGeometry) -> Array[Vector2i]`
  - `find_adjacent_positions(target_cell: Vector2i, room_geom: PresentationRoomGeometry) -> Array[Vector2i]`
  - `is_relationship_satisfied(relation_type: int, candidate_cell: Vector2i, reference_cell: Vector2i, room_geom: PresentationRoomGeometry) -> bool`

- [x] **Step 1: Write the failing test**
Create `test_decoration_relationship_solver.gd` verifying `SYMMETRIC` reflection across axes, `NEAR`, `ADJACENT`, and `KEEP_AWAY_FROM`.

- [x] **Step 2: Run test to verify it fails**
Run test. Expected: FAIL.

- [x] **Step 3: Write minimal implementation**
Implement `decoration_relationship_solver.gd`.

- [x] **Step 4: Run test to verify it passes**
Run test. Expected: PASS.

---

### Task 4: Composition Templates (`DecorationCompositionTemplate`)

**Files:**
- Create: `src/presentation/decoration/composition/decoration_composition_template.gd`
- Test: `tests/presentation/decoration/composition/test_composition_template.gd`

**Interfaces:**
- `DecorationCompositionTemplate`: Resource defining multi-object arrangements (e.g. `TOMB_CENTRAL_FOCAL`, `RITUAL_ALTAR_PAIR`, `PERIMETER_BURIAL_ROW`, `SEATING_WALL`).
- Properties: `template_id: StringName`, `primary_rule: DecorationCompositionRule`, `support_rules: Array[DecorationCompositionRule]`, `lighting_rules: Array[DecorationCompositionRule]`, `min_room_size: Vector2i`.

- [x] **Step 1: Write the failing test**
Create `test_composition_template.gd` validating template definition and slot compatibility.

- [x] **Step 2: Run test to verify it fails**
Run test. Expected: FAIL.

- [x] **Step 3: Write minimal implementation**
Implement `decoration_composition_template.gd`.

- [x] **Step 4: Run test to verify it passes**
Run test. Expected: PASS.

---

### Task 5: Intelligent Lighting Planner (`DecorationLightingPlanner`)

**Files:**
- Create: `src/presentation/decoration/composition/decoration_lighting_planner.gd`
- Test: `tests/presentation/decoration/composition/test_decoration_lighting_planner.gd`

**Interfaces:**
- `DecorationLightingPlanner`:
  - `enum LightRole { PRIMARY_LIGHT = 0, SECONDARY_LIGHT = 1, ACCENT_LIGHT = 2, CEREMONIAL_LIGHT = 3 }`
  - `plan_room_lighting(budget: float, intent: DecorationRoomIntent, fixture_palette: FixturePalette, primary_props: Array, room_geom: PresentationRoomGeometry, occupancy: DecorationOccupancyMap, seed_val: int, tile_size: float = 2.0) -> Array[FixtureDirective]`

- [x] **Step 1: Write the failing test**
Create `test_decoration_lighting_planner.gd` verifying budget consumption, avoidance of door overlap, and placement of ceremonial candles near primary focal props.

- [x] **Step 2: Run test to verify it fails**
Run test. Expected: FAIL.

- [x] **Step 3: Write minimal implementation**
Implement `decoration_lighting_planner.gd` with role costs (Torch=1.0, Lantern=1.5, Brazier=2.0, Candle=0.5).

- [x] **Step 4: Run test to verify it passes**
Run test. Expected: PASS.

---

### Task 6: Room Purpose Profile Registry (`DecorationPurposeProfileRegistry`)

**Files:**
- Create: `src/presentation/decoration/composition/decoration_purpose_profile.gd`
- Create: `src/presentation/decoration/composition/decoration_purpose_profile_registry.gd`
- Test: `tests/presentation/decoration/composition/test_purpose_profile_registry.gd`

**Interfaces:**
- `DecorationPurposeProfile`: Resource binding `room_purpose: int`, `intent: DecorationRoomIntent`, `templates: Array[DecorationCompositionTemplate]`, `default_lighting_budget: float`.
- `DecorationPurposeProfileRegistry`: Singleton/Factory providing profiles for `ENTRANCE`, `ANTECHAMBER`, `BURIAL_HALL`, `TOMB`, `SHRINE`, `BOSS_ROOM`, etc.

- [x] **Step 1: Write the failing test**
Create `test_purpose_profile_registry.gd` verifying resolution of default purpose profiles for Crypt rooms.

- [x] **Step 2: Run test to verify it fails**
Run test. Expected: FAIL.

- [x] **Step 3: Write minimal implementation**
Implement `decoration_purpose_profile.gd` and `decoration_purpose_profile_registry.gd`.

- [x] **Step 4: Run test to verify it passes**
Run test. Expected: PASS.

---

### Task 7: Full Pipeline Integration and Crypt Vertical Slice E2E

**Files:**
- Modify: `src/presentation/decoration/composition/decoration_composition_planner.gd`
- Modify: `src/presentation/decoration/decoration_composition_resolver.gd`
- Test: `tests/presentation/decoration/composition/test_crypt_vertical_slice_e2e.gd`

**Interfaces:**
- `DecorationCompositionPlanner.plan_room_composition(...)`: Integrates Zone partitioning, Intent evaluation, Template selection, Relationship solving, Occupancy enforcement, and Lighting planning.

- [x] **Step 1: Write the failing test**
Create `test_crypt_vertical_slice_e2e.gd` testing generation of a complete set of Crypt rooms (`ENTRANCE`, `ANTECHAMBER`, `BURIAL_HALL`, `TOMB`, `SHRINE`, `BOSS_ROOM`) verifying zero door obstructions, non-facing-wall benches, symmetric focal lights, and compliance with lighting budgets.

- [x] **Step 2: Run test to verify it fails**
Run test. Expected: FAIL.

- [x] **Step 3: Implement planner orchestration and resolver integration**
Connect all modules in `decoration_composition_planner.gd`.

- [x] **Step 4: Run test to verify it passes**
Run `test_crypt_vertical_slice_e2e.gd` and `tests/run_all_tests.gd`. Expected: 100% PASS.
