# DungeonLevelLab Implementation Plan (v2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a modular, decoupled Integration & Authoring Lab (`DungeonLevelLab`) that directly exercises the real generation pipeline (`DungeonPipeline`, `MultiFloorGenerator`), offering 5 comprehensive execution modes: Full Dungeon Generation, Single Template Test, Profile Template Showcase, Multi-Seed Template Coverage, and Golden Fixtures Regression.

**Architecture:** A clean UI/Debug subsystem in `src/dungeon_generator/debug/lab/` that consumes only public Core APIs (`DungeonPipeline`, `MultiFloorGenerator`, `RoomTemplateRegistry`, `RoomTemplateShapeCarver`, `RoomTemplateResolver`, `GoldenFixtureManager`), ensuring zero reverse dependencies from Core into the Lab. Long-running batch operations (Coverage, large Full-Dungeon runs) execute off the main thread with progress/cancellation, never blocking the UI.

**Tech Stack:** Godot 4.6.1 GDScript, `CellGrid`, `DungeonPipeline`, `MultiFloorGenerator`, `Control` / `SubViewport` UI, `WorkerThreadPool`/`Thread`.

**Spec:** User architecture directive for `DungeonLevelLab` integration and authoring suite.

## Global Constraints

- Never introduce dependencies from `src/dungeon_generator/core/` into `src/dungeon_generator/debug/lab/`. **This is enforced by an automated test (Task 0), not just convention.**
- The Lab must never mutate `CellGrid` manually or invent fake pipelines; it must always execute through `DungeonPipeline` / `MultiFloorGenerator`. **The Lab must never reimplement Core selection/resolution logic to obtain diagnostics — if diagnostics aren't exposed publicly, Core's public API must be extended (see Task 3).**
- All 20/20 Golden Fixture regression seeds must remain 100% passing and intact.
- Deterministic RNG seeding must be strictly preserved across all inspection and generation passes, **including when many seeds are run back-to-back in Coverage mode (Task 0 adds a regression test for this).**
- Any operation that may take more than ~200ms of wall-clock time (batch generation, coverage runs) must run off the main thread and report progress; the UI must never freeze.

---

### Task 0: Architectural Guardrails — Dependency Lint & RNG Isolation (NEW)

**Why:** Two constraints in this plan were previously declared but never mechanically enforced: (1) zero reverse dependency from `core/` into `debug/lab/`, and (2) RNG determinism holding even after many prior generations in the same session (critical for Coverage mode in Task 4, which runs up to 100 seeds in sequence). Both are cheap to test now and expensive to debug later if silently broken.

**Files:**
- Create: `tests/lab/test_lab_dependency_boundary.gd`
- Create: `tests/lab/test_rng_isolation.gd`

**Interfaces:**
- Dependency lint: scans all `.gd` files under `src/dungeon_generator/core/` for `preload`/`load`/`class_name` references pointing into `src/dungeon_generator/debug/lab/`; fails the test if any are found.
- RNG isolation test: generates the same seed twice — once as the first generation of a session, once as the 50th generation after 49 unrelated seeds — and asserts the resulting `CellGrid`/room layout is byte-for-byte identical both times.

- [ ] **Step 1: Write `test_lab_dependency_boundary.gd` scanning `core/` source files for any reference to `debug/lab/` paths**
- [ ] **Step 2: Run test to verify it currently passes (baseline — should already be true, this just locks it in)**
- [ ] **Step 3: Write `test_rng_isolation.gd`: generate seed X fresh, then generate 49 other seeds, then regenerate seed X again, and diff the two results for exact equality**
- [ ] **Step 4: Run test; if it fails, this reveals shared/global RNG state in `DungeonPipeline` that must be fixed before proceeding — flag and resolve before continuing to Task 1**
- [ ] **Step 5: Commit**

---

### Task 1: Core Models & Configuration State (`dungeon_lab_configuration.gd`, `dungeon_lab_controller.gd`)

**Files:**
- Create: `src/dungeon_generator/debug/lab/dungeon_lab_configuration.gd`
- Create: `src/dungeon_generator/debug/lab/dungeon_lab_controller.gd`
- Test: `tests/lab/test_dungeon_lab_controller.gd`

**Interfaces:**
- `DungeonLabConfiguration`:
  - Properties: `seed: int`, `generator_type: String`, `archetype_id: StringName`, `grid_size: Vector2i`, `room_count: int`, `floor_count: int`, `profile_mode: StringName`, `forced_profile_id: StringName`, `template_mode: StringName`, `forced_template_id: StringName`.
  - Methods: `to_dungeon_config() -> DungeonConfig`, `validate() -> Array[String]` (returns list of human-readable errors; empty = valid).
- `DungeonLabController`:
  - Methods: `generate_dungeon(config: DungeonLabConfiguration) -> Dictionary`, `get_current_result() -> Dictionary`, `set_current_floor(floor_idx: int) -> void`, `get_current_floor_result() -> DungeonGenerationResult` (stateful, no args — matches `set_current_floor`, corrected from v1's mismatched signature).
  - Signals: `generation_started`, `generation_completed(result: Dictionary)`, `generation_failed(reason: String)` (NEW — emitted instead of silently returning a broken result), `floor_changed(floor_idx: int)`.

- [ ] **Step 1: Write the failing unit test for `DungeonLabConfiguration` and `DungeonLabController`, including: valid config round-trip, `validate()` catching zero/negative `grid_size` and `floor_count`, and a `generation_failed` test using a config that causes the pipeline to report `success = false`**

```gdscript
# tests/lab/test_dungeon_lab_controller.gd
extends SceneTree

const _LabConfigScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_configuration.gd")
const _LabControllerScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_controller.gd")

func _init() -> void:
	print("--- Running test_dungeon_lab_controller ---")
	var cfg = _LabConfigScript.new()
	cfg.seed = 100001
	cfg.generator_type = "Hybrid"
	cfg.archetype_id = &"necropolis"
	cfg.grid_size = Vector2i(64, 64)
	cfg.floor_count = 2

	var d_cfg = cfg.to_dungeon_config()
	assert(d_cfg.seed == 100001, "FAIL: seed mismatch")
	assert(d_cfg.algorithm == "Hybrid", "FAIL: algorithm mismatch")
	assert(cfg.validate().is_empty(), "FAIL: valid config should have no validation errors")

	var bad_cfg = _LabConfigScript.new()
	bad_cfg.grid_size = Vector2i(0, 0)
	bad_cfg.floor_count = 0
	var errors = bad_cfg.validate()
	assert(not errors.is_empty(), "FAIL: invalid config must report errors")

	var controller = _LabControllerScript.new()
	var failed_reason: String = ""
	controller.generation_failed.connect(func(reason: String): failed_reason = reason)

	var res = controller.generate_dungeon(cfg)
	assert(res != null and res.has("floors"), "FAIL: generation must return floors dict")
	assert(res["floors"].size() == 2, "FAIL: multi-floor must produce 2 floors")

	controller.set_current_floor(1)
	var floor_res = controller.get_current_floor_result()
	assert(floor_res != null, "FAIL: get_current_floor_result must return the selected floor")

	print("PASS: test_dungeon_lab_controller passed!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe" --headless -s res://tests/lab/test_dungeon_lab_controller.gd`
Expected: FAIL (files do not exist).

- [ ] **Step 3: Implement `dungeon_lab_configuration.gd` (with `validate()`) and `dungeon_lab_controller.gd` (with corrected `get_current_floor_result()` signature and `generation_failed` handling)**

```gdscript
# src/dungeon_generator/debug/lab/dungeon_lab_configuration.gd
class_name DungeonLabConfiguration
extends RefCounted

var seed: int = 100001
var generator_type: String = "Hybrid"
var archetype_id: StringName = &"necropolis"
var grid_size: Vector2i = Vector2i(64, 64)
var mission_depth: int = 5
var hallway_width: int = 2
var floor_count: int = 1

# Profile & Template Forcing Overrides
var profile_mode: StringName = &"normal" # &"normal", &"force_profile", &"force_template"
var forced_profile_id: StringName = &""
var template_mode: StringName = &"automatic" # &"automatic", &"specific", &"random_variant"
var forced_template_id: StringName = &""

func to_dungeon_config() -> DungeonConfig:
	var cfg := DungeonConfig.new()
	cfg.seed = seed
	cfg.algorithm = generator_type
	cfg.archetype_id = archetype_id
	cfg.grid_width = grid_size.x
	cfg.grid_height = grid_size.y
	cfg.mission_depth = mission_depth
	cfg.hallway_width = hallway_width
	cfg.floors = floor_count
	return cfg

func validate() -> Array[String]:
	var errors: Array[String] = []
	if grid_size.x <= 0 or grid_size.y <= 0:
		errors.append("grid_size must have positive width and height")
	if floor_count <= 0:
		errors.append("floor_count must be at least 1")
	if hallway_width <= 0:
		errors.append("hallway_width must be at least 1")
	if template_mode == &"specific" and forced_template_id == &"":
		errors.append("template_mode 'specific' requires forced_template_id")
	if profile_mode == &"force_profile" and forced_profile_id == &"":
		errors.append("profile_mode 'force_profile' requires forced_profile_id")
	return errors
```

```gdscript
# src/dungeon_generator/debug/lab/dungeon_lab_controller.gd
class_name DungeonLabController
extends RefCounted

signal generation_started
signal generation_completed(result: Dictionary)
signal generation_failed(reason: String)
signal floor_changed(floor_idx: int)

const _PipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _MultiFloorGenScript = preload("res://src/dungeon_generator/core/multi_floor_generator.gd")

var _pipeline: _PipelineScript
var _multi_floor_gen: _MultiFloorGenScript
var _current_result: Dictionary = {}
var _current_floor_idx: int = 0

func _init() -> void:
	_pipeline = _PipelineScript.new()
	_multi_floor_gen = _MultiFloorGenScript.new(_pipeline)

func generate_dungeon(config: DungeonLabConfiguration) -> Dictionary:
	var errors := config.validate()
	if not errors.is_empty():
		var msg := "Invalid configuration: " + ", ".join(errors)
		generation_failed.emit(msg)
		return {}

	generation_started.emit()
	var d_cfg = config.to_dungeon_config()

	var result: Dictionary
	if config.floor_count > 1:
		result = _multi_floor_gen.generate_multi_floor(d_cfg, config.floor_count)
	else:
		var single_res = _pipeline.generate(d_cfg)
		result = {
			"floors": [single_res],
			"vertical_connections": [],
			"total_floors": 1,
			"overall_success": (single_res != null and single_res.success)
		}

	if not result.get("overall_success", false):
		generation_failed.emit("Pipeline reported generation failure for seed %d" % config.seed)
		return {}

	_current_result = result
	_current_floor_idx = 0
	generation_completed.emit(_current_result)
	return _current_result

func set_current_floor(floor_idx: int) -> void:
	_current_floor_idx = floor_idx
	floor_changed.emit(floor_idx)

func get_current_floor_result() -> DungeonGenerationResult:
	var floors: Array = _current_result.get("floors", [])
	if _current_floor_idx >= 0 and _current_floor_idx < floors.size():
		return floors[_current_floor_idx]
	return null

func get_current_result() -> Dictionary:
	return _current_result
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe" --headless -s res://tests/lab/test_dungeon_lab_controller.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/dungeon_generator/debug/lab/ tests/lab/
git commit -m "feat(lab): implement DungeonLabConfiguration and DungeonLabController with validation and failure handling"
```

---

### Task 2a: Pure Coordinate/Viewport Transform (`dungeon_lab_grid_transform.gd`) (NEW — extracted ahead of the renderer)

**Why:** The Renderer needs pan/zoom to navigate large multi-floor dungeons, and `select_room_at(pos)` in the original plan never specified whether `pos` was screen-space or world-space. As with the Room Template Lab, extracting this into a pure `RefCounted` class makes the coordinate math headless-testable and removes ambiguity before the renderer is built on top of it.

**Files:**
- Create: `src/dungeon_generator/debug/lab/dungeon_lab_grid_transform.gd`
- Test: `tests/lab/test_dungeon_lab_grid_transform.gd`

**Interfaces:**
- `screen_to_world(screen_pos: Vector2) -> Vector2`, `world_to_screen(world_pos: Vector2) -> Vector2`, `visible_world_rect(viewport_size: Vector2) -> Rect2` (for culling), `pan(delta: Vector2)`, `zoom_at(screen_pos: Vector2, factor: float)`.

- [ ] **Step 1: Write unit tests for screen↔world conversion under pan/zoom, and for `visible_world_rect` culling bounds**
- [ ] **Step 2: Implement `DungeonLabGridTransform`**
- [ ] **Step 3: Run tests to verify pass**
- [ ] **Step 4: Commit**

---

### Task 2b: Multi-Floor 2D Canvas Renderer & Layer Overlays (`dungeon_lab_renderer.gd`, `dungeon_lab_overlay.gd`)

**Files:**
- Create: `src/dungeon_generator/debug/lab/dungeon_lab_overlay.gd`
- Create: `src/dungeon_generator/debug/lab/dungeon_lab_renderer.gd`
- Test: `tests/lab/test_dungeon_lab_renderer.gd`

**Interfaces:**
- `DungeonLabOverlay`:
  - Properties: `show_room_bounds: bool`, `show_template_footprint: bool`, `show_entrances: bool`, `show_corridors: bool`, `show_internal_doors: bool`, `show_semantic_labels: bool`, `show_template_id: bool`.
  - Signal: `overlay_changed` (NEW — emitted on any property change so the renderer knows to redraw without polling).
- `DungeonLabRenderer`:
  - Methods: `render_result(result: DungeonGenerationResult, overlay: DungeonLabOverlay) -> void`, `render_failure(reason: String) -> void` (NEW — draws an error banner instead of a blank/broken canvas when generation fails), `select_room_at(world_pos: Vector2) -> RoomData` (explicitly world-space; caller converts from screen via `DungeonLabGridTransform.screen_to_world`), `get_rendered_room_count() -> int`.
  - Signals: `room_selected(room: RoomData)`.
  - Uses `DungeonLabGridTransform` internally for all coordinate math and viewport-culls drawn cells to `visible_world_rect`.
  - Subscribes to `DungeonLabController.floor_changed` and `DungeonLabOverlay.overlay_changed` to trigger redraws.

- [ ] **Step 1: Write failing test for Renderer & Overlay, including a `render_failure` case and an `overlay_changed` redraw trigger**

```gdscript
# tests/lab/test_dungeon_lab_renderer.gd
extends SceneTree

const _RendererScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_renderer.gd")
const _OverlayScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_overlay.gd")
const _PipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")

func _init() -> void:
	print("--- Running test_dungeon_lab_renderer ---")
	var pipeline = _PipelineScript.new()
	var cfg := DungeonConfig.new()
	cfg.seed = 100001
	var gen_res = pipeline.generate(cfg)

	var renderer = _RendererScript.new()
	var overlay = _OverlayScript.new()
	overlay.show_template_id = true

	renderer.render_result(gen_res, overlay)
	assert(renderer.get_rendered_room_count() > 0, "FAIL: rooms must be registered in renderer")

	renderer.render_failure("test failure reason")
	assert(renderer.get_rendered_room_count() == 0, "FAIL: failure render must clear room count")

	print("PASS: test_dungeon_lab_renderer passed!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement `dungeon_lab_overlay.gd` (with `overlay_changed` signal) and `dungeon_lab_renderer.gd` (culled drawing via `DungeonLabGridTransform`, failure banner, floor/overlay change subscriptions)**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

```bash
git add src/dungeon_generator/debug/lab/ tests/lab/
git commit -m "feat(lab): implement DungeonLabRenderer and DungeonLabOverlay with culling and failure states"
```

---

### Task 3: Semantic Room & Template Inspector with Fallback Diagnostics (`dungeon_lab_inspector.gd`)

**Files:**
- Create: `src/dungeon_generator/debug/lab/dungeon_lab_inspector.gd`
- Test: `tests/lab/test_dungeon_lab_inspector.gd`
- **Prerequisite check (do this before Step 1):** Confirm whether `RoomTemplateResolver` already exposes a public diagnostics/explain method (e.g. something like `resolve_with_diagnostics(room, bundle) -> ResolutionDiagnostics`). **If it does not, this is a Core API gap, not something the Lab should work around.** Extend `RoomTemplateResolver`'s public surface with such a method as a small, isolated Core change *before* building the Inspector. The Inspector must call this method — it must never reimplement candidate filtering/rejection logic itself, since that would violate the "no fake pipelines" constraint and silently drift from real resolver behavior over time.

**Interfaces:**
- `DungeonLabInspector`:
  - Methods: `inspect_room(room: RoomData, bundle: ProfileBundle) -> Dictionary`.
  - Produces structured diagnostics: `room_id`, `purpose`, `profile_id`, `resolved_template_id`, `is_fallback`, `room_size`, `candidate_templates`, `compatible_templates`, `rejection_reasons` — **all sourced from `RoomTemplateResolver`'s public diagnostics output, not recomputed locally.**

- [ ] **Step 0: Audit `RoomTemplateResolver`'s current public API; if no diagnostics/explain method exists, add one as a minimal, additive Core change (new method only, no behavior change to existing resolution) and cover it with its own Core-level unit test**
- [ ] **Step 1: Write failing test for Inspector diagnostics, asserting `inspect_room` output matches exactly what the resolver's diagnostics method reports (no divergent logic)**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement `dungeon_lab_inspector.gd` as a thin adapter over `RoomTemplateResolver`'s diagnostics API**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

```bash
git add src/dungeon_generator/debug/lab/dungeon_lab_inspector.gd tests/lab/
git commit -m "feat(lab): implement DungeonLabInspector as a thin adapter over RoomTemplateResolver diagnostics"
```

---

### Task 4: Template Showcase & Multi-Seed Coverage Runner (`dungeon_lab_template_showcase.gd`, `dungeon_lab_coverage.gd`, `dungeon_lab_async_runner.gd`)

**Files:**
- Create: `src/dungeon_generator/debug/lab/dungeon_lab_async_runner.gd` (NEW — shared batch-execution helper)
- Create: `src/dungeon_generator/debug/lab/dungeon_lab_template_showcase.gd`
- Create: `src/dungeon_generator/debug/lab/dungeon_lab_coverage.gd`
- Test: `tests/lab/test_dungeon_lab_coverage.gd`
- Test: `tests/lab/test_dungeon_lab_async_runner.gd`

**Interfaces:**
- `DungeonLabAsyncRunner` (NEW): Generic off-main-thread batch runner used by both Coverage and any future batch mode.
  - Methods: `run_batch(seeds: Array[int], work_fn: Callable) -> void`, `cancel() -> void`.
  - Signals: `progress(completed: int, total: int)`, `batch_completed(results: Array)`, `batch_cancelled`.
  - Implementation: uses `WorkerThreadPool` (or `Thread` if pooled tasks aren't suitable given `DungeonPipeline`'s thread-safety), never blocks the calling thread.
- `DungeonLabTemplateShowcase`:
  - Methods: `showcase_profile(profile_id: StringName, registry: RoomTemplateRegistry) -> Array[Dictionary]`.
- `DungeonLabCoverage`:
  - Methods: `run_coverage(archetype_id: StringName, seed_start: int = 100001, seed_count: int = 100) -> void` (NEW — explicit `seed_start` for reproducible seed sequences; runs via `DungeonLabAsyncRunner`, non-blocking), `export_report(path: String) -> void` (NEW — writes results as JSON/CSV for offline balance tracking).
  - Signals: `coverage_progress(completed: int, total: int)`, `coverage_completed(report: Dictionary)`.
  - Produces: `seed_start`, `seed_count`, `total_rooms`, `profile_distribution`, `template_selection_counts`, `fallback_rate`, `coverage_percentage`.

- [ ] **Step 1: Write failing test for `DungeonLabAsyncRunner`: batch of N mock work items completes off-thread, `progress` fires incrementally, `cancel()` mid-batch stops further work and emits `batch_cancelled`**
- [ ] **Step 2: Implement `DungeonLabAsyncRunner`**
- [ ] **Step 3: Write failing test for Showcase & Coverage, including: deterministic seed sequence from `seed_start`/`seed_count` (re-running with the same `seed_start` reproduces identical `profile_distribution`), and `export_report` producing a valid, parseable JSON file**
- [ ] **Step 4: Run tests to verify they fail**
- [ ] **Step 5: Implement `dungeon_lab_template_showcase.gd` and `dungeon_lab_coverage.gd`, with `run_coverage` delegating batch execution to `DungeonLabAsyncRunner`**
- [ ] **Step 6: Run tests to verify pass**
- [ ] **Step 7: Commit**

```bash
git add src/dungeon_generator/debug/lab/ tests/lab/
git commit -m "feat(lab): implement async batch runner, Template Showcase, and Multi-Seed Coverage with deterministic seeds and report export"
```

---

### Task 5a: Golden Regression Runner (isolated) (SPLIT from old Task 5)

**Files:**
- Create: `src/dungeon_generator/debug/lab/dungeon_lab_golden_runner.gd`
- Test: `tests/lab/test_dungeon_lab_golden_runner.gd`

**Interfaces:**
- `DungeonLabGoldenRunner`:
  - Methods: `run_golden_suite() -> Dictionary` (wrapping `GoldenFixtureManager`, executed via `DungeonLabAsyncRunner` from Task 4 since it's effectively another batch run).

- [ ] **Step 1: Write failing test asserting `run_golden_suite()` returns a summary matching `GoldenFixtureManager`'s own pass/fail counts (no divergent logic, thin wrapper only)**
- [ ] **Step 2: Implement `dungeon_lab_golden_runner.gd` as a thin adapter, reusing `DungeonLabAsyncRunner` for progress reporting on the 20-fixture run**
- [ ] **Step 3: Run test to verify pass**
- [ ] **Step 4: Commit**

```bash
git add src/dungeon_generator/debug/lab/dungeon_lab_golden_runner.gd tests/lab/
git commit -m "feat(lab): implement DungeonLabGoldenRunner as thin GoldenFixtureManager adapter"
```

---

### Task 5b: Main Scene Assembly (`dungeon_level_lab.gd`, `dungeon_level_lab.tscn`) (SPLIT from old Task 5)

**Files:**
- Create: `src/dungeon_generator/debug/lab/dungeon_level_lab.gd`
- Create: `src/dungeon_generator/debug/lab/dungeon_level_lab.tscn`

**Interfaces:**
- `DungeonLevelLab`:
  - Coordinates Top Bar (Seed, Gen Type, Archetype, Floors), Left Sidebar (5 Mode Selectors, Parameters, Overlays), Center Canvas (Renderer + pan/zoom via `DungeonLabGridTransform`), Right Sidebar (Inspector, Diagnostics & Results, Coverage progress bar + Export button).
  - Debounces live-parameter changes (~150-200ms) before triggering auto-regeneration, so dragging a slider doesn't fire a full pipeline run per frame.
  - Wires `generation_failed` → Renderer's `render_failure` banner and a visible error toast, instead of leaving a stale/blank canvas.

- [ ] **Step 1: Assemble `dungeon_level_lab.tscn` connecting Controller, Renderer, Overlay, Inspector, Showcase, Coverage, and Golden Runner**
- [ ] **Step 2: Wire debounce timer on parameter-change auto-regeneration**
- [ ] **Step 3: Wire `generation_failed` to visible error state in both Renderer and a top-level toast/banner**
- [ ] **Step 4: Wire Coverage `coverage_progress` to a progress bar and a Cancel button calling `DungeonLabAsyncRunner.cancel()`**
- [ ] **Step 5: Commit**

```bash
git add src/dungeon_generator/debug/lab/dungeon_level_lab.gd src/dungeon_generator/debug/lab/dungeon_level_lab.tscn
git commit -m "feat(lab): assemble DungeonLevelLab main scene with 5 modes, debounced regen, and failure/progress UI"
```

---

### Task 5c: End-to-End Integration Test & Golden Fixtures (SPLIT from old Task 5)

**Files:**
- Test: `tests/lab/test_dungeon_level_lab_integration.gd`

- [ ] **Step 1: Write integration test instantiating `dungeon_level_lab.tscn`, exercising all 5 modes (Full Generation, Single Template Test, Profile Showcase, Multi-Seed Coverage, Golden Regression) end-to-end, including a deliberate failure case (invalid config) verifying the error UI path**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Fix any integration gaps surfaced**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Run Golden Fixtures 20/20 check**
- [ ] **Step 6: Run `test_lab_dependency_boundary.gd` and `test_rng_isolation.gd` from Task 0 one final time as a regression gate**
- [ ] **Step 7: Commit**

```bash
git add tests/lab/
git commit -m "test(lab): add DungeonLevelLab end-to-end integration coverage across all 5 modes"
```

---

## Summary of Changes from v1

| Change | Reason |
|---|---|
| Added Task 0 (dependency lint + RNG isolation test) | Two declared constraints had no mechanical enforcement |
| Task 1: fixed `get_current_floor_result` signature mismatch, added `validate()` and `generation_failed` signal | Interface/implementation mismatch and no failure handling in v1 |
| Added Task 2a (`DungeonLabGridTransform`, pure class) | Renderer needed pan/zoom math with no ambiguity between screen/world space |
| Task 2b (Renderer): added culling, `render_failure`, `overlay_changed` redraw trigger, floor-change subscription | Performance and UX gaps — no failure state, no auto-redraw, no culling in v1 |
| Task 3: added prerequisite audit/extension of `RoomTemplateResolver`'s public API | v1's diagnostics fields risked reimplementing Core logic inside the Lab, violating "no fake pipelines" |
| Added Task 4's `DungeonLabAsyncRunner` | Coverage running 100 sequential full generations would freeze the UI synchronously |
| Task 4: added explicit `seed_start` for reproducible coverage runs, `export_report` | v1's seed strategy was unspecified/non-reproducible; no way to track balance over time |
| Old Task 5 split into 5a/5b/5c | Original task combined Golden Runner + full scene assembly + integration test into one oversized, high-risk block |
| Task 5b: added debounce for live parameter changes, wired failure/progress UI | No debounce in v1 risked a full pipeline run per UI tick; no visible error/progress state |