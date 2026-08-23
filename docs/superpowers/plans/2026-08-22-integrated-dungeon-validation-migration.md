# Integrated Dungeon Validation & Migration Plan (Phase 10.19)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate the production pipeline by ensuring `dungeon_level.tscn` and `DungeonPresentationBuilder` exclusively consume the Semantic Spatial Composition Engine, eliminate any legacy lighting/prop placement leftovers, provide rich real-time F3 debug overlay metrics, and validate Crypt generation across 20+ deterministic seeds.

**Architecture:** 
`DungeonPipeline` -> `DungeonSemanticResult` -> `PresentationContextBuilder` -> `GeometryPartition` -> `DecorationCompositionResolver` (`DecorationCompositionPlanner`) -> `PropSpawner` / `FixtureSpawner` -> `dungeon_level.tscn`. 

**Tech Stack:** Godot 4.x, GDScript, Presentation Pipeline, Real-time Diagnostics, Heuristic Determinism.

**Spec:** Generic Intelligent Decoration & Composition System Architecture (Phases 10.19 - 10.22).

## Global Constraints
- Core generation (`DungeonPipeline`, `CellGrid`, `RoomData`, `DungeonSemanticResult`) remains 100% pure and independent of 3D nodes or asset names.
- Zero legacy lighting or prop spawners called outside `DecorationCompositionResolver`.
- No `randomize()` or unseeded random calls in presentation or decoration logic.
- Spawners only materialize (`Directive` -> `Node3D`); they never make placement or clearance decisions.

---

### Task 1: Audit & Clean Legacy Presentation Pathways

**Files:**
- Modify: `src/dungeon_generator/presentation/dungeon_presentation_builder.gd`
- Test: `tests/integration/test_dungeon_presentation_pipeline_purity.gd`

**Interfaces:**
- `DungeonPresentationBuilder`: Clean out unused legacy generators (`_lighting_generator`, `_light_spawner`) and verify that 100% of light and prop instances originate from `DecorationComposition.fixture_directives` and `DecorationComposition.prop_directives`.

- [x] **Step 1: Write the failing test**
Create `test_dungeon_presentation_pipeline_purity.gd` asserting that `build_presentation` produces a scene tree where all lights and props match the exact count and IDs of the directives emitted by `DecorationCompositionResolver`.

- [x] **Step 2: Run test to verify it fails**
Run: `Godot_v4.6.1-stable_win64.exe --headless -s res://tests/integration/test_dungeon_presentation_pipeline_purity.gd`
Expected: FAIL (file not found).

- [x] **Step 3: Clean up and verify `dungeon_presentation_builder.gd`**
Remove unused legacy lighting scripts/preloads and ensure both single-floor and multi-floor presentations strictly route decoration through `_composition_resolver`.

- [x] **Step 4: Run test to verify it passes**
Run test again. Expected: PASS.

---

### Task 2: Enhanced Room Composition & Spatial Debug Overlay (F3)

**Files:**
- Modify: `scenes/dungeon/dungeon_level_controller.gd`
- Test: `tests/presentation/decoration/test_composition_debug_overlay_metrics.gd`

**Interfaces:**
- `DungeonLevelController`:
  - Enhance `_update_debug_overlay()` to show real-time composition details for the room containing the player / camera pivot:
    - Archetype name & Room Purpose
    - Active Zone (e.g. `FOCAL`, `PERIMETER`, `ENTRY`)
    - Directives summary (Primary props, Secondary props, Fixture lights)
    - Lighting budget consumed vs allocated (e.g. `3.5 / 4.0`)
    - Clearance checks: Door clearance (`PASS`), Player clearance (`PASS`), Occupancy status.

- [x] **Step 1: Write the failing test**
Create `test_composition_debug_overlay_metrics.gd` verifying that the overlay data generator formats all composition metrics correctly.

- [x] **Step 2: Run test to verify it fails**
Run test. Expected: FAIL.

- [x] **Step 3: Implement overlay enhancement in `dungeon_level_controller.gd`**
Update `_update_debug_overlay()` with room composition metrics.

- [x] **Step 4: Run test to verify it passes**
Run test. Expected: PASS.

---

### Task 3: Multi-Seed Deterministic Sweep for Crypt (20 Seeds)

**Files:**
- Create: `tests/integration/test_crypt_multi_seed_sweep.gd`

**Interfaces:**
- Test suite running Crypt generation across seeds `100` to `120`:
  - 0 props overlapping doors or door clearances
  - 0 props overlapping stairs
  - 0 forbidden tags placed per room purpose (no benches in `TOMB`, no massive sarcophagi in `ANTECHAMBER`, high clearance in `ENTRANCE`)
  - 100% valid orientation degrees (multiples of 90° or aligned facing inward)
  - Lighting budget strictly respected across all rooms.

- [x] **Step 1: Write multi-seed sweep test**
Create `test_crypt_multi_seed_sweep.gd`.

- [x] **Step 2: Run test to verify it passes**
Run: `Godot_v4.6.1-stable_win64.exe --headless -s res://tests/integration/test_crypt_multi_seed_sweep.gd`
Expected: PASS (100% verified across all 20 seeds).

---

### Task 4: Full Test Runner Integration & Regression Verification

**Files:**
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Add all new integration and purity tests to `TEST_SUITES` in `tests/run_all_tests.gd`.

- [x] **Step 1: Update test runner**
Add `test_dungeon_presentation_pipeline_purity.gd`, `test_composition_debug_overlay_metrics.gd`, and `test_crypt_multi_seed_sweep.gd`.

- [x] **Step 2: Run unified test suite**
Run: `Godot_v4.6.1-stable_win64.exe --headless -s res://tests/run_all_tests.gd`
Expected: 100% PASS on all suites.
