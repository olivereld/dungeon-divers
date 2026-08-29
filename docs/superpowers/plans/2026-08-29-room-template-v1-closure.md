# Room Template V1 Closure & End-to-End Infrastructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finalize and close the `dungeon_template` module (V1 Infrastructure Freeze). Ensure complete end-to-end integration: Schema audit $\to$ Canonical 7 base architectural templates $\to$ Loader & Registry $\to$ Deterministic shape & orientation selection with real physical entrances $\to$ Concrete anchor/zone resolution $\to$ 6 core unit/integration tests $\to$ 20/20 Golden Seeds regression guarantee.

**Architecture:** 
1. **Contract Freeze**: No prop/mesh/visual decoration in templates. Spatial geometry, entrance policy, clearances, symmetry, and semantic anchors only.
2. **Canonical 7 Base Templates**: `open_chamber`, `octagonal_chamber`, `cruciform_sanctuary`, `pillared_hall`, `chapel`, `central_nave`, `niched_hall` with strict semantic/range validation.
3. **Single Registry Scan**: `RoomTemplateRegistry` discovered once per `ProfileBundle` and passed directly to `RoomTemplateResolver`.
4. **Deterministic Shape Choice**: In `RoomTemplateShapeCarver`, when a template permits multiple shapes, use derived `room_rng` to deterministically choose among viable shapes instead of defaulting to index 0.
5. **Full Physical Entrance Integration**: `DungeonEntranceStage` passes resolved `inner_cell` entrance positions to `RoomTemplateResolver` and `RoomTemplateShapeCarver`, ensuring dynamic orientation away from primary entrance and synchronized `room_owner`.
6. **Robust Fallback**: `procedural_fallback` guarantees 100% walkability and connectivity if no template is compatible, without hiding malformed JSON definition errors.

**Tech Stack:** Godot 4.6.1 GDScript, JSON template definitions, CellGrid, headless test runner.

## Global Constraints

- **Single Test Suite Execution Only**: NEVER execute `tests/run_all_tests.gd`. Only execute individual test files via `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe" --headless -s res://tests/<path>.gd`.
- **Zero Golden Drift**: `test_golden_fixtures.gd` must pass 20/20 with 0 drift at all times. Never modify golden snapshot fixtures.
- **Zero Double-Carving**: Template carving occurs strictly with full entrance knowledge, maintaining strict `CellGrid` and `room_owner` synchronization.

---

### Task 1: Audit Base Templates & Complete 7 Canonical Architectural Definitions

**Files:**
- Audit & Standardize: `resources/dungeon_profiles/room_templates/generic/open_hall_template.json`
- Audit & Standardize: `resources/dungeon_profiles/room_templates/generic/octagonal_chamber_template.json`
- Audit & Standardize: `resources/dungeon_profiles/room_templates/generic/cruciform_sanctuary_template.json`
- Audit & Standardize: `resources/dungeon_profiles/room_templates/generic/pillared_hall_template.json`
- Audit & Standardize: `resources/dungeon_profiles/room_templates/ceremonial/ceremonial_chapel_template.json`
- Audit & Standardize: `resources/dungeon_profiles/room_templates/necropolis/catacomb_gallery_template.json` (Central Nave)
- Audit & Standardize: `resources/dungeon_profiles/room_templates/necropolis/ossuary_hall_template.json` (Niched Hall)
- Test: `tests/room_templates/test_room_template_definition_validator.gd`

**Interfaces:**
- Consumes: JSON template files.
- Produces: 100% schema-valid definitions satisfying `RoomTemplateDefinitionValidator` without range or enum errors.

- [x] **Step 1: Write test verifying all 7 canonical templates validate cleanly**
- [x] **Step 2: Run test to check current status**
- [x] **Step 3: Refine JSON files if any warnings/errors exist**
- [x] **Step 4: Verify test passes 100%**
- [x] **Step 5: Commit**

---

### Task 2: Deterministic Shape Selection & Anchor Failure Semantics

**Files:**
- Modify: `src/dungeon_generator/core/room_templates/generation/room_template_shape_carver.gd`
- Test: `tests/room_templates/test_room_template_shape_carver.gd`

**Interfaces:**
- Consumes: `RoomTemplate.geometry.allowed_shapes`, `RandomNumberGenerator`, `room.rect`.
- Produces: Deterministic shape selection among feasible shapes (using `rng.randi_range`), and strict anchor validation (required anchors mark `is_success = false` if impossible, optional anchors omit gracefully).

- [x] **Step 1: Write unit test for multi-shape deterministic selection and anchor failure handling**
- [x] **Step 2: Run test to verify failure**
- [x] **Step 3: Implement deterministic multi-shape selection and anchor validation in RoomTemplateShapeCarver**
- [x] **Step 4: Run test to verify pass**
- [x] **Step 5: Commit**

---

### Task 3: DungeonRoomStage & DungeonEntranceStage Pipeline Harmonization

**Files:**
- Modify: `src/dungeon_generator/core/stages/dungeon_room_stage.gd`
- Modify: `src/dungeon_generator/core/stages/dungeon_entrance_stage.gd`
- Test: `tests/room_templates/test_room_template_pipeline_integration.gd`

**Interfaces:**
- Consumes: `DungeonConfig` (`algorithm == "Template"`), `MissionGraph`, `ProfileBundle`.
- Produces: Clean non-interfering stage lifecycle: `DungeonRoomStage` initializes baseline layout; `DungeonEntranceStage` executes full template resolution, orientation, carving, anchor storage, and room ownership synchronization with physical entrance knowledge.

- [x] **Step 1: Review and refine stage execution lifecycle for Template algorithm**
- [x] **Step 2: Run test_room_template_pipeline_integration.gd**
- [x] **Step 3: Verify zero side-effects on CA / BSP / Hybrid algorithms**
- [x] **Step 4: Commit**

---

### Task 4: Definitive 6-Test V1 Verification Suite

**Files:**
- Test 1: `tests/room_templates/test_room_template_definition_validator.gd`
- Test 2: `tests/room_templates/test_room_template_loader.gd`
- Test 3: `tests/room_templates/test_room_template_registry.gd`
- Test 4: `tests/room_templates/test_room_template_resolver.gd`
- Test 5: `tests/room_templates/test_room_template_shape_carver.gd`
- Test 6: `tests/room_templates/test_room_template_pipeline_integration.gd`

**Interfaces:**
- Consumes: Complete room template subsystem.
- Produces: 6/6 PASS across the entire unit and integration test surface.

- [x] **Step 1: Run Test 1 (Definition Validator)**
- [x] **Step 2: Run Test 2 (Loader)**
- [x] **Step 3: Run Test 3 (Registry)**
- [x] **Step 4: Run Test 4 (Resolver)**
- [x] **Step 5: Run Test 5 (Shape Carver)**
- [x] **Step 6: Run Test 6 (Pipeline Integration)**
- [x] **Step 7: Commit test updates**

---

### Task 5: Final Golden Fixtures Regression & V1 Module Closure

**Files:**
- Test: `tests/test_golden_fixtures.gd`
- Test: `tests/test_pipeline_integration.gd`
- Test: `tests/test_fase_9_horizontal_integration.gd`

**Interfaces:**
- Consumes: Whole dungeon generator.
- Produces: 20/20 PASS on Golden Seeds, 0 drift, 100% stable integration.

- [x] **Step 1: Run test_pipeline_integration.gd**
- [x] **Step 2: Run test_fase_9_horizontal_integration.gd**
- [x] **Step 3: Run test_golden_fixtures.gd (20/20 PASS, 0 drift)**
- [x] **Step 4: Final freeze commit**
