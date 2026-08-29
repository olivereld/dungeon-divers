# Parametric Room Template Subsystem Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decouple Room Profile semantics (purpose, composition, lighting, style) from Room Template spatial geometries (parametric shapes, clearances, zone reservations, entrance compatibility) with deterministic resolution and zero-failure procedural fallback.

**Architecture:** A data-driven subsystem where `ProfileRoom` declares template constraints, `RoomTemplateRegistry` indexes parametric spatial templates from JSON, `RoomTemplateResolver` scores and matches valid templates based on room dimensions, purpose, and entrance sides, and `RoomTemplateShapeCarver` carves cell grids while strictly maintaining >= 70% walkability and safe fallback.

**Tech Stack:** Godot 4.6.1 GDScript, JSON schemas, CellGrid rasterization, headless test runner.

**Spec:** User architecture requirements for decoupled Room Profile / Room Template subsystem.

## Global Constraints

- **Single Test Suite Execution Only**: NEVER execute `tests/run_all_tests.gd`. Only execute individual test files via `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/<path>.gd`.
- **Pure Data-Driven Separation**: No room decoration or prop placement inside Room Templates; no hardcoded shape logic inside Room Profiles.
- **Walkability Guarantee**: Minimum 70% walkable floor ratio with all walkable floor cells connected and entrance cells unblocked.
- **Safe Procedural Fallback**: Incompatible templates must never halt dungeon generation; always fallback cleanly to a standard rectangular floor.
- **Deterministic**: All variation calculations use derived seeds.

---

### Task 1: Spatial Zones and Zone Map Model

**Files:**
- Create: `src/dungeon_generator/core/room_templates/data/room_template_zone_map.gd`
- Test: `tests/room_templates/test_room_template_zone_map.gd`

**Interfaces:**
- Consumes: `CellGrid`, `RoomData`, `Rect2i`, `Vector2i`
- Produces: `RoomTemplateZoneMap` with methods `set_zone(cell: Vector2i, zone_type: StringName)`, `get_zone(cell: Vector2i) -> StringName`, `get_cells_in_zone(zone_type: StringName) -> Array[Vector2i]`, `has_zone(zone_type: StringName) -> bool`

- [x] **Step 1: Write the failing test**

```gdscript
# tests/room_templates/test_room_template_zone_map.gd
extends SceneTree

const _ZoneMapScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_zone_map.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_zone_map ---")
	var rect := Rect2i(10, 10, 8, 8)
	var zm = _ZoneMapScript.new(rect)
	
	assert(zm.room_rect == rect, "FAIL: room_rect mismatch")
	zm.set_zone(Vector2i(12, 12), &"focal")
	zm.set_zone(Vector2i(10, 10), &"entrance_clearance")
	
	assert(zm.get_zone(Vector2i(12, 12)) == &"focal", "FAIL: focal zone mismatch")
	assert(zm.get_zone(Vector2i(10, 10)) == &"entrance_clearance", "FAIL: entrance zone mismatch")
	assert(zm.get_zone(Vector2i(11, 11)) == &"unassigned", "FAIL: default zone should be unassigned")
	assert(zm.get_cells_in_zone(&"focal").size() == 1, "FAIL: cells count mismatch")
	
	print("PASS: test_room_template_zone_map passed successfully!")
	quit(0)
```

- [x] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/room_templates/test_room_template_zone_map.gd`
Expected: FAIL (file not found)

- [x] **Step 3: Write minimal implementation**

```gdscript
# src/dungeon_generator/core/room_templates/data/room_template_zone_map.gd
class_name RoomTemplateZoneMap
extends RefCounted

## Mapa de zonas de reserva espacial de una sala (focal, entrance_clearance, circulation, perimeter, wall_niche).

var room_rect: Rect2i = Rect2i()
var _cell_zones: Dictionary = {} # Vector2i -> StringName

func _init(p_rect: Rect2i = Rect2i()) -> void:
	room_rect = p_rect

func set_zone(cell: Vector2i, zone_type: StringName) -> void:
	_cell_zones[cell] = zone_type

func get_zone(cell: Vector2i) -> StringName:
	return _cell_zones.get(cell, &"unassigned")

func get_cells_in_zone(zone_type: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _cell_zones:
		if _cell_zones[cell] == zone_type:
			result.append(cell)
	return result

func has_zone(zone_type: StringName) -> bool:
	for cell in _cell_zones:
		if _cell_zones[cell] == zone_type:
			return true
	return false

func clear() -> void:
	_cell_zones.clear()
```

- [x] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/room_templates/test_room_template_zone_map.gd`
Expected: PASS

- [x] **Step 5: Commit**

```bash
git add src/dungeon_generator/core/room_templates/data/room_template_zone_map.gd tests/room_templates/test_room_template_zone_map.gd
git commit -m "feat(templates): add RoomTemplateZoneMap data class and tests"
```

---

### Task 2: Parametric Shape Carver with Walkability & Entrance Clearance

**Files:**
- Create: `src/dungeon_generator/core/room_templates/generation/room_template_shape_carver.gd`
- Test: `tests/room_templates/test_room_template_shape_carver.gd`

**Interfaces:**
- Consumes: `CellGrid`, `RoomData`, `RoomTemplate`, `Array[Vector2i]` (entrances), `RandomNumberGenerator`
- Produces: `RoomTemplateShapeCarver.carve_room_shape(grid, room, template, entrances, rng) -> RoomTemplateZoneMap`

- [x] **Step 1: Write the failing test**

```gdscript
# tests/room_templates/test_room_template_shape_carver.gd
extends SceneTree

const _CarverScript = preload("res://src/dungeon_generator/core/room_templates/generation/room_template_shape_carver.gd")
const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _GeometryPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_geometry_policy.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_shape_carver ---")
	var grid := CellGrid.new(30, 30, CellGrid.CellType.WALL)
	var room := RoomData.new(1, Rect2i(5, 5, 12, 12), &"chamber")
	var geom := _GeometryPolicyScript.new([&"octagonal", &"chapel"], 6, 20, 6, 20, 36, 400, 0.5, 2.0)
	var tpl := _RoomTemplateScript.new(&"octagonal_test", "Octagon", [], geom)
	var entrances: Array[Vector2i] = [Vector2i(10, 5)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	
	var zone_map = _CarverScript.carve_room_shape(grid, room, tpl, entrances, rng)
	assert(zone_map != null, "FAIL: zone_map should not be null")
	assert(grid.get_cell(Vector2i(10, 5)) == CellGrid.CellType.FLOOR, "FAIL: entrance must be floor")
	
	# Walkability ratio check
	var walkable_count := 0
	for y in range(room.rect.position.y, room.rect.end.y):
		for x in range(room.rect.position.x, room.rect.end.x):
			if grid.is_walkable(Vector2i(x, y)):
				walkable_count += 1
	var ratio: float = float(walkable_count) / float(room.rect.size.x * room.rect.size.y)
	assert(ratio >= 0.70, "FAIL: walkability ratio below 70%%: %.2f" % ratio)
	
	print("PASS: test_room_template_shape_carver passed successfully!")
	quit(0)
```

- [x] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/room_templates/test_room_template_shape_carver.gd`
Expected: FAIL

- [x] **Step 3: Implement `RoomTemplateShapeCarver`**

Implement parametric shapes:
- `open_rectangle`: fills rect with floor, reserves entrance clearances and focal center.
- `octagonal_chamber`: bevels corners with walls, keeping center and entrances floor.
- `cruciform_sanctuary`: cuts corner quadrants into walls, keeping cross open.
- `pillared_hall`: symmetrical interior pillar placement ensuring aisle circulation.
- `chapel`: nave + recessed apse focal zone.
- `central_nave`: longitudinal corridor with side alcoves.
- `niched_hall`: wall recesses for shrines/niches.
- Always guarantee entrance points and immediate 1-cell clearance remain `FLOOR`.
- Always guarantee center cell remains `FLOOR`.
- Populate `RoomTemplateZoneMap` with `focal`, `entrance_clearance`, `circulation`, `perimeter`.

- [x] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/room_templates/test_room_template_shape_carver.gd`
Expected: PASS

- [x] **Step 5: Commit**

```bash
git add src/dungeon_generator/core/room_templates/generation/room_template_shape_carver.gd tests/room_templates/test_room_template_shape_carver.gd
git commit -m "feat(templates): implement parametric RoomTemplateShapeCarver and walkability checks"
```

---

### Task 3: Room Profile Template Constraints Model and Loader/Validator Integration

**Files:**
- Create: `src/dungeon_generator/profiles/profile_room_template_constraints.gd`
- Modify: `src/dungeon_generator/profiles/profile_room.gd`
- Modify: `src/dungeon_generator/profiles/profile_loader.gd`
- Modify: `src/dungeon_generator/profiles/profile_validator.gd`
- Test: `tests/room_templates/test_profile_room_template_constraints.gd`

**Interfaces:**
- Consumes: Room JSON `templates` dictionary: `allowed`, `preferred`, `forbidden`, `required_tags`
- Produces: `ProfileRoom.template_constraints: ProfileRoomTemplateConstraints`

- [x] **Step 1: Write the failing test**

```gdscript
# tests/room_templates/test_profile_room_template_constraints.gd
extends SceneTree

const _LoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _ValidatorScript = preload("res://src/dungeon_generator/profiles/profile_validator.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_profile_room_template_constraints ---")
	var loader := _LoaderScript.new()
	var json_str = """{
		"id": "sacristy_test",
		"display_name": "Sacristy",
		"templates": {
			"allowed": ["chapel", "sacristy"],
			"preferred": ["chapel"],
			"forbidden": ["corridor_grid"],
			"required_tags": ["ceremonial"]
		}
	}"""
	var room = loader.parse_room_from_json_string(json_str)
	assert(room != null, "FAIL: room should parse")
	assert(room.template_constraints != null, "FAIL: template_constraints must not be null")
	assert(room.template_constraints.is_template_allowed(&"chapel"), "FAIL: chapel should be allowed")
	assert(room.template_constraints.is_template_forbidden(&"corridor_grid"), "FAIL: corridor_grid should be forbidden")
	
	print("PASS: test_profile_room_template_constraints passed successfully!")
	quit(0)
```

- [x] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/room_templates/test_profile_room_template_constraints.gd`
Expected: FAIL

- [x] **Step 3: Implement typed constraint model & update loader/validator**

- Create `src/dungeon_generator/profiles/profile_room_template_constraints.gd`.
- Update `ProfileRoom` constructor and property.
- Update `ProfileLoader._parse_room_dictionary` to parse `"templates"` block.
- Update `ProfileValidator` to validate template references when registry is present.

- [x] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/room_templates/test_profile_room_template_constraints.gd`
Expected: PASS

- [x] **Step 5: Commit**

```bash
git add src/dungeon_generator/profiles/profile_room_template_constraints.gd src/dungeon_generator/profiles/profile_room.gd src/dungeon_generator/profiles/profile_loader.gd src/dungeon_generator/profiles/profile_validator.gd tests/room_templates/test_profile_room_template_constraints.gd
git commit -m "feat(profiles): integrate template constraints into ProfileRoom, loader and validator"
```

---

### Task 4: Deterministic Room Template Resolver with Safe Procedural Fallback

**Files:**
- Create: `src/dungeon_generator/core/room_templates/resolver/room_template_resolver.gd`
- Test: `tests/room_templates/test_room_template_resolver.gd`

**Interfaces:**
- Consumes: `RoomData`, `ProfileRoom`, `RoomTemplateRegistry`, `Array[Vector2i]` (entrances), `int` (seed)
- Produces: `RoomTemplateResolver.resolve_template(room, profile, entrances, seed) -> RoomTemplate`

- [x] **Step 1: Write the failing test**

```gdscript
# tests/room_templates/test_room_template_resolver.gd
extends SceneTree

const _ResolverScript = preload("res://src/dungeon_generator/core/room_templates/resolver/room_template_resolver.gd")
const _RegistryScript = preload("res://src/dungeon_generator/core/room_templates/loader/room_template_registry.gd")
const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _GeometryPolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_geometry_policy.gd")
const _EntrancePolicyScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_entrance_policy.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_resolver ---")
	var reg := _RegistryScript.new()
	var geom_valid := _GeometryPolicyScript.new([&"rectangle"], 5, 20, 5, 20, 25, 400)
	var ent_valid := _EntrancePolicyScript.new(1, 4, [&"north", &"south", &"east", &"west"])
	var tpl_chapel := _RoomTemplateScript.new(&"chapel", "Chapel", [&"ceremonial"], geom_valid, ent_valid)
	reg.register_template(tpl_chapel)
	
	var resolver := _ResolverScript.new(reg)
	var room := RoomData.new(1, Rect2i(0, 0, 10, 10), &"sacristy")
	var resolved = resolver.resolve_template(room, null, [Vector2i(5, 0)], 42)
	assert(resolved != null, "FAIL: should resolve a valid template")
	assert(resolved.id == &"chapel" or resolved.id == &"procedural_fallback", "FAIL: resolved invalid template")
	
	# Fallback test with impossible constraints
	var impossible_room := RoomData.new(2, Rect2i(0, 0, 2, 2), &"sacristy")
	var fallback_res = resolver.resolve_template(impossible_room, null, [], 42)
	assert(fallback_res != null, "FAIL: fallback must never return null")
	
	print("PASS: test_room_template_resolver passed successfully!")
	quit(0)
```

- [x] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/room_templates/test_room_template_resolver.gd`
Expected: FAIL

- [x] **Step 3: Implement `RoomTemplateResolver`**

- Collect candidates from `ProfileRoom.template_constraints` (or all registry templates matching room purpose/tags if constraints not specified).
- Filter out forbidden templates.
- Score candidates (+100 preferred, +50 allowed, +20 tag match, +10 generic).
- Filter candidates with `RoomTemplateValidator.validate_all(tpl, room.rect, entrance_points)`.
- If multiple candidates tie in score, select deterministically using derived seed `rng.randi_range(0, candidates.size() - 1)`.
- If no candidate passes validation, return guaranteed `default_procedural_template` (open rectangular chamber with unconstrained bounds).

- [x] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/room_templates/test_room_template_resolver.gd`
Expected: PASS

- [x] **Step 5: Commit**

```bash
git add src/dungeon_generator/core/room_templates/resolver/room_template_resolver.gd tests/room_templates/test_room_template_resolver.gd
git commit -m "feat(templates): implement deterministic RoomTemplateResolver and zero-failure fallback"
```

---

### Task 5: Pipeline Integration with DungeonRoomStage and ProfileBundle

**Files:**
- Modify: `src/dungeon_generator/profiles/profile_bundle.gd`
- Modify: `src/dungeon_generator/core/stages/dungeon_room_stage.gd`
- Modify: `src/dungeon_generator/core/dungeon_pipeline.gd`
- Test: `tests/room_templates/test_room_template_pipeline_integration.gd`

**Interfaces:**
- Consumes: `ProfileBundle.template_registry`, `DungeonGenerationContext`, `RoomData`
- Produces: Carved rooms using resolved templates with zone maps attached to `RoomData` metadata.

- [x] **Step 1: Write the failing test**

```gdscript
# tests/room_templates/test_room_template_pipeline_integration.gd
extends SceneTree

const _PipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_room_template_pipeline_integration ---")
	var loader := _ProfileLoaderScript.new()
	var bundle = loader.load_bundle("res://resources/dungeon_profiles/archetypes/necropolis.json")
	assert(bundle != null, "FAIL: bundle should load")
	
	var pipeline := _PipelineScript.new()
	var config := DungeonConfig.new()
	config.grid_width = 60
	config.grid_height = 60
	config.min_rooms = 6
	config.max_rooms = 10
	config.algorithm = "Hybrid"
	
	var result = pipeline.generate(config, 424242, bundle)
	assert(result != null and result.success, "FAIL: pipeline generation must succeed with templates")
	assert(result.grid != null, "FAIL: grid must not be null")
	
	print("PASS: test_room_template_pipeline_integration passed successfully!")
	quit(0)
```

- [x] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/room_templates/test_room_template_pipeline_integration.gd`
Expected: FAIL

- [x] **Step 3: Integrate template registry into `ProfileBundle` and `DungeonRoomStage`**

- Add `template_registry: RoomTemplateRegistry` to `ProfileBundle`.
- Update `ProfileLoader.load_bundle` to discover templates in `resources/dungeon_profiles/room_templates`.
- In `DungeonRoomStage._build_room_floors`, resolve template via `RoomTemplateResolver` for each room and carve using `RoomTemplateShapeCarver`.
- Store `zone_map` and `resolved_template_id` in `room.custom_data`.

- [x] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/room_templates/test_room_template_pipeline_integration.gd`
Expected: PASS

- [x] **Step 5: Commit**

```bash
git add src/dungeon_generator/profiles/profile_bundle.gd src/dungeon_generator/core/stages/dungeon_room_stage.gd src/dungeon_generator/core/dungeon_pipeline.gd tests/room_templates/test_room_template_pipeline_integration.gd
git commit -m "feat(templates): integrate RoomTemplateResolver and shape carving into DungeonRoomStage"
```

---

### Task 6: Parametric Template Library JSONs and Room Constraints

**Files:**
- Create: `resources/dungeon_profiles/room_templates/generic/open_hall_template.json`
- Create: `resources/dungeon_profiles/room_templates/generic/pillared_hall_template.json`
- Create: `resources/dungeon_profiles/room_templates/generic/octagonal_chamber_template.json`
- Create: `resources/dungeon_profiles/room_templates/generic/cruciform_sanctuary_template.json`
- Modify: `resources/dungeon_profiles/rooms/sacristy.json`
- Modify: `resources/dungeon_profiles/rooms/crypt.json`
- Modify: `resources/dungeon_profiles/rooms/royal_tomb.json`

- [x] **Step 1: Create canonical generic templates**
Create clean, non-decorative JSON template definitions declaring shape families, width/depth ranges, entrance allowances, and clearances.

- [x] **Step 2: Update room profiles with template constraints**
Update `sacristy.json`, `crypt.json`, and `royal_tomb.json` with `templates` block:
```json
"templates": {
    "allowed": ["chapel", "sacristy", "octagonal_chamber"],
    "preferred": ["chapel"],
    "required_tags": ["ceremonial"]
}
```

- [x] **Step 3: Run existing template tests to verify valid schemas**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/room_templates/test_room_template_loader.gd`
Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/room_templates/test_room_template_registry.gd`
Expected: PASS

- [x] **Step 4: Commit**

```bash
git add resources/dungeon_profiles/room_templates/ resources/dungeon_profiles/rooms/
git commit -m "feat(templates): add canonical parametric template library and room constraints"
```

---

### Task 7: Full Verification Across All Individual Suites

**Files:**
- Verification only

- [x] **Step 1: Execute all individual room template test suites**

```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/room_templates/test_room_template_contracts.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/room_templates/test_room_template_loader.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/room_templates/test_room_template_registry.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/room_templates/test_room_template_validator.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/room_templates/test_room_template_zone_map.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/room_templates/test_room_template_shape_carver.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/room_templates/test_profile_room_template_constraints.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/room_templates/test_room_template_resolver.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/room_templates/test_room_template_pipeline_integration.gd
```
Expected: All suites PASS.

- [x] **Step 2: Execute core regression suites individually**

```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/test_phase5_room_generation.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/test_pipeline_integration.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/test_fase_9_horizontal_integration.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/test_golden_fixtures.gd
```
Expected: All suites PASS.
