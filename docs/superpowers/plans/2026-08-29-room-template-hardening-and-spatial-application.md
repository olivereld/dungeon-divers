# Room Template Hardening & Spatial Application Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the Room Template subsystem with strict schema/definition validation (rejecting malformed JSON at load time), deep shape-geometry compatibility checks in Matcher/Validator, deterministic orientation/rotation support, structured `TemplateCarveResult`, and concrete anchor coordinate resolution.

**Architecture:** 
1. `RoomTemplateDefinitionValidator` performs schema contract validation before registering templates, rejecting invalid definitions rather than silently substituting defaults.
2. `RoomTemplateValidator` extends geometric validation to verify shape feasibility (e.g. bevel/niche depth requirements per shape family) against `RoomData.rect`.
3. `TemplateCarveResult` provides a formal return value containing carved cells, reserved zone maps, resolved anchor coordinates, chosen orientation, and diagnostics.
4. `RoomTemplateShapeCarver` applies deterministic orientation (0: NORTH, 1: EAST, 2: SOUTH, 3: WEST) from derived seeds and resolves declared anchor points (`center`, `north_wall`, `apse_altar`, `loculi_left`, etc.) into concrete `Vector2i` grid positions.
5. Invariants and 20/20 Golden Seeds regression safety are maintained throughout.

**Tech Stack:** Godot 4.6.1 GDScript, JSON template definitions, CellGrid rasterization, headless test runner.

**Spec:** User architecture requirements for Room Template Hardening & Spatial Application.

## Global Constraints

- **Single Test Suite Execution Only**: NEVER execute `tests/run_all_tests.gd`. Only execute individual test files via `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe" --headless -s res://tests/<path>.gd`.
- **No Silent Fallback in Loader**: Loader & Registry reject malformed templates with clear validation errors. Procedural fallback occurs strictly at runtime resolution.
- **Strict Invariance Contract**: 20/20 Golden Seeds must pass with 0 drift at every integration step.
- **Walkability Guarantee**: Minimum 70% walkable floor ratio with all walkable floor cells connected and entrance cells unblocked.
- **Deterministic**: All variation, orientation, and anchor selection calculations use derived seeds.

---

### Task 1: RoomTemplateDefinitionValidator & Strict Loader Validation

**Files:**
- Create: `src/dungeon_generator/core/room_templates/validation/room_template_definition_validator.gd`
- Modify: `src/dungeon_generator/core/room_templates/loader/room_template_loader.gd`
- Modify: `src/dungeon_generator/core/room_templates/loader/room_template_registry.gd`
- Test: `tests/room_templates/test_room_template_definition_validator.gd`

**Interfaces:**
- Consumes: JSON raw dictionaries from file/string input.
- Produces: `RoomTemplateValidationResult` validating schema compliance (`id`, `display_name`, `geometry` ranges, `entrances` sides/counts, `symmetry`, `clearances`, `anchors`).

- [x] **Step 1: Write the failing unit test**
- [x] **Step 2: Run test to verify failure**
- [x] **Step 3: Implement RoomTemplateDefinitionValidator**
- [x] **Step 4: Run test to verify pass**
- [x] **Step 5: Commit**

---

### Task 2: Real Shape Geometry Feasibility Validation

**Files:**
- Modify: `src/dungeon_generator/core/room_templates/validation/room_template_validator.gd`
- Test: `tests/room_templates/test_room_template_geometry_validation.gd`

**Interfaces:**
- Consumes: `RoomTemplate`, `Rect2i`.
- Produces: `RoomTemplateValidationResult` with shape-specific structural viability checks (`octagonal` minimum width/depth for chamfers, `cruciform` minimum arm widths, `pillared` minimum interior spacing, `chapel` apse bounds).

- [x] **Step 1: Write the failing unit test**
- [x] **Step 2: Run test to verify failure**
- [x] **Step 3: Implement shape feasibility validation in RoomTemplateValidator**
- [x] **Step 4: Run test to verify pass**
- [x] **Step 5: Commit**

---

### Task 3: TemplateCarveResult & Concrete Anchor Coordinate Resolution

**Files:**
- Create: `src/dungeon_generator/core/room_templates/data/template_carve_result.gd`
- Modify: `src/dungeon_generator/core/room_templates/generation/room_template_shape_carver.gd`
- Test: `tests/room_templates/test_room_template_carve_result.gd`

**Interfaces:**
- Consumes: `CellGrid`, `RoomData`, `RoomTemplate`, `Array[Vector2i]` (entrances), `RandomNumberGenerator`, `orientation: int`.
- Produces: `TemplateCarveResult` with `is_success: bool`, `zone_map: RoomTemplateZoneMap`, `resolved_anchors: Dictionary` (StringName -> Vector2i), `carved_cells: Array[Vector2i]`, `orientation: int`.

- [x] **Step 1: Write the failing unit test**
- [x] **Step 2: Run test to verify failure**
- [x] **Step 3: Create TemplateCarveResult and implement anchor resolution**
- [x] **Step 4: Run test to verify pass**
- [x] **Step 5: Commit**

---

### Task 4: Deterministic Orientation & Directional Shape Rotation

**Files:**
- Modify: `src/dungeon_generator/core/room_templates/generation/room_template_shape_carver.gd`
- Modify: `src/dungeon_generator/core/stages/dungeon_entrance_stage.gd`
- Test: `tests/room_templates/test_room_template_orientation.gd`

**Interfaces:**
- Consumes: `RoomData`, `RoomTemplate`, `entrance_cells: Array[Vector2i]`, `template_seed: int`.
- Produces: Deterministic orientation selection (0: NORTH, 1: EAST, 2: SOUTH, 3: WEST) prioritizing primary entrance axis, and applies directional shape transformations (e.g. chapel apse oriented opposite to the entrance).

- [x] **Step 1: Write the failing unit test**
- [x] **Step 2: Run test to verify failure**
- [x] **Step 3: Implement orientation-aware carving and anchor transformation**
- [x] **Step 4: Run test to verify pass**
- [x] **Step 5: Commit**

---

### Task 5: Full E2E & Golden Seeds Regression Verification

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
