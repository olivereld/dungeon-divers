# Room Template Selection + Application Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a complete, deterministic, decoupled Room Template Selection and Application pipeline (Matcher → Resolver → ShapeCarver → Entrance Integration) with canonical template catalogs and strict 20/20 regression safety.

**Architecture:** 
1. `RoomTemplateMatcher` evaluates pure boolean compatibility (dimensions, aspect ratio, purpose, tags, entrance constraints, clearance, symmetry).
2. `RoomTemplateResolver` scores and selects the best template deterministically using explicit priority tiers and derived RNG seeds without side effects.
3. `RoomTemplateShapeCarver` hardens shape generation to guarantee entrance accessibility, floor connectivity, >= 70% walkability, and strict room ownership synchronization.
4. Clean decoupling across 4 independent dimensions: `DungeonArchetype` (thematic container) vs `RoomPurpose` (semantic role) vs `RoomTemplate` (spatial geometry) vs `DecorationProfile` (visual dressing).

**Tech Stack:** Godot 4.6.1 GDScript, JSON template definitions, CellGrid rasterization, headless test runner.

**Spec:** Architectural design for decoupled Room Template Selection and Application pipeline.

## Global Constraints

- **Single Test Suite Execution Only**: NEVER execute `tests/run_all_tests.gd`. Only execute individual test files via `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe" --headless -s res://tests/<path>.gd`.
- **Pure Data-Driven Separation**: Room Templates describe spatial geometry only; they never contain decoration props or decide overall dungeon connectivity.
- **Strict Invariance Contract**: 20/20 Golden Seeds must pass with 0 drift at every integration step.
- **Walkability Guarantee**: Minimum 70% walkable floor ratio with all walkable floor cells connected and entrance cells unblocked.
- **Deterministic**: All variation calculations use derived seeds.

---

### Task 1: Audit and Consolidate RoomTemplate Data Contracts

**Files:**
- Modify: `src/dungeon_generator/core/room_templates/data/room_template.gd`
- Modify: `src/dungeon_generator/core/room_templates/data/room_template_geometry_policy.gd`
- Modify: `src/dungeon_generator/core/room_templates/data/room_template_entrance_policy.gd`
- Modify: `src/dungeon_generator/core/room_templates/data/room_template_clearance_policy.gd`
- Modify: `src/dungeon_generator/core/room_templates/data/room_template_symmetry_policy.gd`
- Test: `tests/room_templates/test_room_template_data_contracts.gd`

**Interfaces:**
- Consumes: JSON dictionaries from template loader.
- Produces: Strongly-typed `RoomTemplate` and policy value objects with `from_dictionary()` and `to_dictionary()`.

- [x] **Step 1: Write the failing unit test**
- [x] **Step 2: Run test to verify failure**
- [x] **Step 3: Update data contracts**
- [x] **Step 4: Run test to verify pass**
- [x] **Step 5: Commit**

---

### Task 2: Pure Compatibility RoomTemplateMatcher

**Files:**
- Modify: `src/dungeon_generator/core/room_templates/matcher/room_template_matcher.gd`
- Test: `tests/room_templates/test_room_template_matcher.gd`

**Interfaces:**
- Consumes: `RoomTemplate`, `RoomData`, `ProfileRoom`, `Array[Vector2i]` (entrances).
- Produces: `is_compatible(template: RoomTemplate, room: RoomData, profile: ProfileRoom, entrances: Array[Vector2i]) -> bool` and `filter_compatible_templates(templates: Array[RoomTemplate], room: RoomData, profile: ProfileRoom, entrances: Array[Vector2i]) -> Array[RoomTemplate]`.

- [x] **Step 1: Write the failing unit test**
- [x] **Step 2: Run test to verify failure**
- [x] **Step 3: Implement pure compatibility logic**
- [x] **Step 4: Run test to verify pass**
- [x] **Step 5: Commit**

---

### Task 3: Prioritized Deterministic RoomTemplateResolver

**Files:**
- Modify: `src/dungeon_generator/core/room_templates/resolver/room_template_resolver.gd`
- Test: `tests/room_templates/test_room_template_resolver_priorities.gd`

**Interfaces:**
- Consumes: `RoomTemplateRegistry`, `RoomTemplateMatcher`, `RoomData`, `ProfileRoom`, `Array[Vector2i]` (entrances), `seed: int`.
- Produces: `resolve_template(room: RoomData, profile: ProfileRoom, entrances: Array[Vector2i], seed: int) -> RoomTemplate` (deterministic with fallback).

- [x] **Step 1: Write the failing unit test for prioritized scoring**
- [x] **Step 2: Run test to verify failure**
- [x] **Step 3: Implement scoring hierarchy**
- [x] **Step 4: Run test to verify pass**
- [x] **Step 5: Commit**

---

### Task 4: Invariants Hardening in RoomTemplateShapeCarver

**Files:**
- Modify: `src/dungeon_generator/core/room_templates/generation/room_template_shape_carver.gd`
- Test: `tests/room_templates/test_room_template_shape_carver_invariants.gd`

**Interfaces:**
- Consumes: `CellGrid`, `RoomData`, `RoomTemplate`, `Array[Vector2i]` (entrances), `RandomNumberGenerator`.
- Produces: `RoomTemplateZoneMap` (guaranteeing >= 70% walkability, 0 isolated pockets, unblocked entrances connected to center).

- [x] **Step 1: Write the failing unit test for shape invariants**
- [x] **Step 2: Run test to verify failure/pass**
- [x] **Step 3: Harden shape carver invariants**
- [x] **Step 4: Run test to verify pass**
- [x] **Step 5: Commit**

---

### Task 5: Initial Canonical Modular Template Catalog

**Files:**
- Create: `resources/dungeon_profiles/room_templates/generic/open_hall_template.json`
- Create: `resources/dungeon_profiles/room_templates/generic/pillared_hall_template.json`
- Create: `resources/dungeon_profiles/room_templates/generic/octagonal_chamber_template.json`
- Create: `resources/dungeon_profiles/room_templates/ceremonial/ceremonial_sanctum_template.json`
- Create: `resources/dungeon_profiles/room_templates/ceremonial/ceremonial_sacristy_template.json`
- Create: `resources/dungeon_profiles/room_templates/ceremonial/ceremonial_chapel_template.json`
- Create: `resources/dungeon_profiles/room_templates/necropolis/crypt_chamber_template.json`
- Create: `resources/dungeon_profiles/room_templates/necropolis/ossuary_hall_template.json`
- Create: `resources/dungeon_profiles/room_templates/necropolis/royal_mausoleum_template.json`
- Create: `resources/dungeon_profiles/room_templates/necropolis/catacomb_gallery_template.json`
- Test: `tests/room_templates/test_canonical_template_catalog.gd`

**Interfaces:**
- Consumes: JSON files loaded via `RoomTemplateRegistry`.
- Produces: Validated templates indexed across Generic, Ceremonial, and Necropolis categories.

- [x] **Step 1: Write the failing unit test for catalog registration and loading**
- [x] **Step 2: Run test to verify failure**
- [x] **Step 3: Author the 10 JSON template definitions**
- [x] **Step 4: Run test to verify pass**
- [x] **Step 5: Commit**

---

### Task 6: Architectural Dimension Decoupling and Integration Testing

**Files:**
- Modify: `src/dungeon_generator/profiles/profile_bundle.gd`
- Modify: `src/dungeon_generator/profiles/profile_loader.gd`
- Test: `tests/room_templates/test_architectural_dimension_decoupling.gd`

**Interfaces:**
- Consumes: Archetype bundles, Room Profiles, Room Templates.
- Produces: Clean runtime separation where `ProfileRoom` holds purpose & semantic rules and `RoomTemplate` provides spatial geometry.

- [x] **Step 1: Write the failing unit test**
- [x] **Step 2: Run test to verify failure/pass**
- [x] **Step 3: Implement bundle resolution and constraints binding**
- [x] **Step 4: Run test to verify pass**
- [x] **Step 5: Commit**

---

### Task 7: Full E2E & Golden Seeds Regression Verification

**Files:**
- Test: `tests/test_golden_fixtures.gd`
- Test: `tests/test_pipeline_integration.gd`
- Test: `tests/test_fase_9_horizontal_integration.gd`
- Test: `tests/room_templates/test_room_template_pipeline_integration.gd`

**Interfaces:**
- Consumes: Complete dungeon generation pipeline.
- Produces: 100% PASS across all integration suites with 20/20 Golden Seeds matching.

- [x] **Step 1: Execute test_golden_fixtures (20/20 regression gate)**
- [x] **Step 2: Execute test_pipeline_integration**
- [x] **Step 3: Execute test_fase_9_horizontal_integration**
- [x] **Step 4: Execute test_room_template_pipeline_integration**
- [x] **Step 5: Final status commit**
