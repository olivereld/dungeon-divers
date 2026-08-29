# Declarative Room Templates Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the foundational `RoomTemplate` architectural module (MVP v1) providing purely declarative spatial and geometric constraint contracts for dungeon rooms without coupling to 3D presentation, meshes, or scenes.

**Architecture:** Pure declarative separation of concerns where `RoomTemplate` defines geometric rules (shapes, dimensions, aspect ratios, entrance rules, symmetry, architectural anchors, clearances, and hard constraints). A dedicated `RoomTemplateValidator` tests candidate room geometries, while `RoomTemplateLoader` and `RoomTemplateRegistry` handle JSON parsing and catalog management.

**Tech Stack:** Godot 4.6+ GDScript, JSON declarative schemas, strict data-driven architecture, zero Godot Node3D/scene coupling in core.

**Spec:** Defined by user architecture specification (contracts for Identity, Geometry, Entrances, Symmetry, Anchors, Clearances, Constraints, Validation, Loader, Registry).

## Global Constraints

- Pure RefCounted data contracts: No `Node3D`, `PackedScene`, `mesh`, or rendering references in `dungeon_generator/core/room_templates/`.
- Strict determinism: No internal calls to `randomize()`; all evaluation takes external seed/RNG if required.
- Full type safety: Typed GDScript properties, dictionaries with typed keys/values where applicable.
- Clean contract distinction: Archetype (theme) -> Purpose (gameplay role) -> Template (spatial form & constraints) -> Presentation (visuals) -> Decoration (props).

---

## File Structure & Responsibilities

```text
src/dungeon_generator/core/room_templates/
├── data/
│   ├── room_template_geometry_policy.gd   # Dimension limits, shape restrictions, aspect ratios, area limits
│   ├── room_template_entrance_policy.gd   # Entrance min/max, allowed sides, corner policy, min spacing
│   ├── room_template_symmetry_policy.gd   # Symmetry requirements and axes (vertical, horizontal, radial)
│   ├── room_template_anchor_def.gd        # Named architectural anchor declarations (focal, altar, etc.)
│   ├── room_template_clearance_policy.gd  # Clearance zones and safety buffers
│   └── room_template.gd                   # Primary declarative RoomTemplate contract
├── validation/
│   ├── room_template_validation_result.gd # Typed diagnostic result object for template checks
│   └── room_template_validator.gd         # Validates concrete rooms/rects against template policies
├── loader/
│   ├── room_template_schema.gd            # Schema definition and type conversion helpers
│   ├── room_template_loader.gd            # JSON parser into typed RoomTemplate instances
│   └── room_template_registry.gd          # In-memory registry & catalog of discovered room templates
└── matcher/
    └── room_template_matcher.gd           # Matches candidate templates against room purposes/criteria

resources/dungeon_profiles/room_templates/
├── crypt/
│   ├── sacristy_template.json
│   ├── chapel_template.json
│   └── reliquary_template.json
└── generic/
    ├── rectangular_chamber_template.json
    └── square_hall_template.json

tests/room_templates/
├── test_room_template_contracts.gd        # Tests data purity, policy initialization, and immutability
├── test_room_template_validator.gd        # Tests geometric, entrance, symmetry, and clearance validation
├── test_room_template_loader.gd           # Tests JSON parsing, schema validation, and error handling
└── test_room_template_registry.gd         # Tests catalog discovery, querying, and archetype matching
```

---

## Task Decomposition

### Task 1: Policy Data Contracts (`Geometry`, `Entrances`, `Symmetry`, `Anchors`, `Clearances`)

**Files:**
- Create: `src/dungeon_generator/core/room_templates/data/room_template_geometry_policy.gd`
- Create: `src/dungeon_generator/core/room_templates/data/room_template_entrance_policy.gd`
- Create: `src/dungeon_generator/core/room_templates/data/room_template_symmetry_policy.gd`
- Create: `src/dungeon_generator/core/room_templates/data/room_template_anchor_def.gd`
- Create: `src/dungeon_generator/core/room_templates/data/room_template_clearance_policy.gd`
- Test: `tests/room_templates/test_room_template_contracts.gd`

**Interfaces:**
- Produces:
  - `RoomTemplateGeometryPolicy`: `allowed_shapes: Array[StringName]`, `min_width`, `max_width`, `min_depth`, `max_depth`, `min_area`, `max_area`, `min_aspect_ratio`, `max_aspect_ratio`.
  - `RoomTemplateEntrancePolicy`: `min_count: int`, `max_count: int`, `allowed_sides: Array[StringName]`, `allow_corner: bool`, `min_spacing: int`.
  - `RoomTemplateSymmetryPolicy`: `required: bool`, `axis: StringName` (`&"none"`, `&"vertical"`, `&"horizontal"`, `&"both"`, `&"radial"`).
  - `RoomTemplateAnchorDef`: `id: StringName`, `required: bool`, `location_hint: StringName`.
  - `RoomTemplateClearancePolicy`: `entrance: int`, `focal: int`, `circulation: int`, `walls: int`.

- [ ] **Step 1: Write the failing contract test**
Create `tests/room_templates/test_room_template_contracts.gd` asserting policy initialization, defaults, and type safety.

- [ ] **Step 2: Run test to verify it fails**
User executes via `cmd /c "Godot... -s res://tests/room_templates/test_room_template_contracts.gd"`.

- [ ] **Step 3: Implement policy data classes**
Implement the 5 policy classes in `src/dungeon_generator/core/room_templates/data/`.

- [ ] **Step 4: Run test to verify it passes**
User executes test command; verify green exit code 0.

---

### Task 2: Root `RoomTemplate` Model and Schema Definition

**Files:**
- Create: `src/dungeon_generator/core/room_templates/data/room_template.gd`
- Create: `src/dungeon_generator/core/room_templates/loader/room_template_schema.gd`
- Modify: `tests/room_templates/test_room_template_contracts.gd`

**Interfaces:**
- Consumes: Policy classes from Task 1.
- Produces:
  - `RoomTemplate`: `id: StringName`, `display_name: String`, `tags: Array[StringName]`, `geometry: RoomTemplateGeometryPolicy`, `entrances: RoomTemplateEntrancePolicy`, `symmetry: RoomTemplateSymmetryPolicy`, `anchors: Dictionary`, `clearances: RoomTemplateClearancePolicy`, `allowed_purposes: Array[StringName]`.
  - `RoomTemplateSchema`: `validate_raw_dict(dict: Dictionary) -> Array[String]`.

- [ ] **Step 1: Write test asserting RoomTemplate assembly and schema verification**
Add tests to `test_room_template_contracts.gd` for assembling a complete `RoomTemplate`.

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Implement `RoomTemplate` and `RoomTemplateSchema`**
Write `src/dungeon_generator/core/room_templates/data/room_template.gd` and `schema.gd`.

- [ ] **Step 4: Run test to verify it passes**

---

### Task 3: `RoomTemplateValidator` Engine

**Files:**
- Create: `src/dungeon_generator/core/room_templates/validation/room_template_validation_result.gd`
- Create: `src/dungeon_generator/core/room_templates/validation/room_template_validator.gd`
- Create: `tests/room_templates/test_room_template_validator.gd`

**Interfaces:**
- Consumes: `RoomTemplate`, `RoomTemplateValidationResult`, `Rect2i`.
- Produces:
  - `RoomTemplateValidationResult`: `is_valid: bool`, `errors: Array[String]`, `warnings: Array[String]`.
  - `RoomTemplateValidator`: `validate_rect(template: RoomTemplate, rect: Rect2i) -> RoomTemplateValidationResult`, `validate_entrances(template: RoomTemplate, rect: Rect2i, entrance_points: Array[Vector2i]) -> RoomTemplateValidationResult`.

- [ ] **Step 1: Write failing validation test**
Test valid rect (e.g. 9x11 within [7,13]x[7,15]), aspect ratio violations (e.g. 2x20), area bounds violations, entrance count/side checks.

- [ ] **Step 2: Run test to verify failure**

- [ ] **Step 3: Implement `RoomTemplateValidator` and `RoomTemplateValidationResult`**
Write mathematical checks for width, depth, area, aspect ratio, entrance constraints, and symmetry.

- [ ] **Step 4: Run test to verify passes**

---

### Task 4: JSON Loader and Default Templates

**Files:**
- Create: `src/dungeon_generator/core/room_templates/loader/room_template_loader.gd`
- Create: `resources/dungeon_profiles/room_templates/crypt/sacristy_template.json`
- Create: `resources/dungeon_profiles/room_templates/crypt/chapel_template.json`
- Create: `resources/dungeon_profiles/room_templates/generic/rectangular_chamber_template.json`
- Create: `tests/room_templates/test_room_template_loader.gd`

**Interfaces:**
- Consumes: `RoomTemplate`, `RoomTemplateSchema`.
- Produces:
  - `RoomTemplateLoader`: `load_from_file(path: String) -> RoomTemplate`, `load_from_json_string(json_str: String) -> RoomTemplate`.

- [ ] **Step 1: Write failing test for JSON loader**
Assert that valid JSON loads into a fully-typed `RoomTemplate` instance matching all declared policies.

- [ ] **Step 2: Run test to verify failure**

- [ ] **Step 3: Implement `RoomTemplateLoader` and JSON template files**
Write parser and create sample JSON templates.

- [ ] **Step 4: Run test to verify passes**

---

### Task 5: `RoomTemplateRegistry` and `RoomTemplateMatcher`

**Files:**
- Create: `src/dungeon_generator/core/room_templates/loader/room_template_registry.gd`
- Create: `src/dungeon_generator/core/room_templates/matcher/room_template_matcher.gd`
- Create: `tests/room_templates/test_room_template_registry.gd`
- Modify: `tests/run_all_tests.gd` (register new suite)

**Interfaces:**
- Consumes: `RoomTemplateLoader`, `RoomTemplateValidator`.
- Produces:
  - `RoomTemplateRegistry`: `register_template(template: RoomTemplate)`, `get_template(id: StringName) -> RoomTemplate`, `discover_templates_in_directory(path: String) -> int`.
  - `RoomTemplateMatcher`: `match_template_for_purpose(purpose_id: StringName, criteria: Dictionary) -> RoomTemplate`.

- [ ] **Step 1: Write failing test for registry and matcher**
Test directory scan, template retrieval by ID, purpose matching, and fallback mechanisms.

- [ ] **Step 2: Run test to verify failure**

- [ ] **Step 3: Implement `RoomTemplateRegistry` and `RoomTemplateMatcher`**
Implement storage, discovery from `res://resources/dungeon_profiles/room_templates/`, and scoring-based matching.

- [ ] **Step 4: Run full test suite including `tests/run_all_tests.gd`**
Verify zero regressions across the entire test suite.

---

## Verification Plan

### Automated Regression Commands:
```cmd
cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/room_templates/test_room_template_contracts.gd"
```

```cmd
cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/room_templates/test_room_template_validator.gd"
```

```cmd
cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/room_templates/test_room_template_loader.gd"
```

```cmd
cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/room_templates/test_room_template_registry.gd"
```

```cmd
cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe --headless -s res://tests/run_all_tests.gd"
```
