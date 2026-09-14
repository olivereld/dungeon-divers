# Chunk-Compatible Confluence Lakes & Depression Interception Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform river-lake generation from a blind global-border tracer into a local, chunk-compatible hydrological system where rivers intercept depressions and low-relief multi-river convergence zones to form clean, unified lakes (eliminating chaotic river knots like in Seed 283362).

**Architecture:** River tracing detects when channels enter local depressions ($H_{\text{filled}} > H_{\text{raw}} + 0.05$) or multi-river convergence zones in flat valleys ($\text{slope} \le 1.5^\circ$). Rather than tracing meandering ribbons through the flat basin, incoming rivers terminate at the lake perimeter as `TRANSITION` inlets, the basin is flooded to its local spillway elevation $H_{\text{water}} = H_{\text{spillway}}$, and a single consolidated outflow river is emitted from the spillway.

**Tech Stack:** Godot 4.6 GDScript, RefCounted data structures, BFS local basin expansion, continuous analytical gradient $\nabla H$.

**Spec:** User directive: *"muchos rios se cruzan y generan un candidato perfecto de lago... tomar en cuenta que el mapa va ser generado proceduralmente por chunks en el futuro, por lo que no existira un borde definido como tal"*.

## Global Constraints
- No reliance on global map boundaries ($X=0, X=W-1$) to decide lake or destination status.
- Strict downward carving invariant: $H_{\text{carved}}(x, z) \le H_{\text{raw}}(x, z)$ across all cells.
- Zero floating water surfaces: $H_{\text{water}} \le H_{\text{raw}} + 0.05\text{m}$ at lake perimeter.
- Deterministic: identical seed produces identical lake geometry, spillways, and outflow rivers.
- Watertight mesh integration: single continuous `WaterRegion` mesh via `WaterTopologyBuilder` and `WaterMeshBuilder`.

---

### Task 1: Local Hydraulic Depression & Valley Convergence Classifier

**Files:**
- Create: `src/world_generator/hydrology/hydraulic_basin_classifier.gd`
- Test: `src/world_generator/tests/test_hydraulic_basin_classifier.gd`

**Interfaces:**
- Consumes: `WorldCell`, `cells: Dictionary`, `filled_height: Dictionary`, `width: int`, `height: int`
- Produces:
  - `is_local_depression(pos: Vector2i, cells: Dictionary, filled_height: Dictionary, threshold: float = 0.05) -> bool`
  - `find_local_spillway(seed_pos: Vector2i, cells: Dictionary, filled_height: Dictionary, max_radius: int = 32) -> Dictionary`
  - `detect_convergence_zone(active_river_cells: Dictionary, pos: Vector2i, slope: float, radius: int = 4) -> bool`

- [ ] **Step 1: Write failing test for local basin classifier**

```gdscript
# src/world_generator/tests/test_hydraulic_basin_classifier.gd
extends SceneTree

const _ClassifierScript = preload("res://src/world_generator/hydrology/hydraulic_basin_classifier.gd")

func _init() -> void:
	print("--- Running test_hydraulic_basin_classifier ---")
	var classifier = _ClassifierScript.new()

	# 1. Local depression test
	var cells: Dictionary = {}
	var filled: Dictionary = {}
	# Create a 5x5 bowl centered at (2, 2)
	for x in range(5):
		for y in range(5):
			var p := Vector2i(x, y)
			var rim_dist: float = maxf(absf(x - 2), absf(y - 2))
			var raw_h: float = 10.0 + rim_dist * 2.0 # center is 10.0, rim is 14.0
			var dummy_cell = RefCounted.new()
			dummy_cell.set("raw_height", raw_h)
			cells[p] = dummy_cell
			filled[p] = 14.0 # filled to rim

	assert(classifier.is_local_depression(Vector2i(2, 2), cells, filled, 0.05) == true, "Center must be local depression")
	assert(classifier.is_local_depression(Vector2i(0, 0), cells, filled, 0.05) == false, "Rim must not be depression")

	# 2. Convergence detection in flat valley
	var active_rivers: Dictionary = {
		Vector2i(2, 1): 0,
		Vector2i(1, 2): 1
	}
	assert(classifier.detect_convergence_zone(active_rivers, Vector2i(2, 2), 0.5, 3) == true, "Adjacent rivers in flat valley must trigger convergence")
	assert(classifier.detect_convergence_zone(active_rivers, Vector2i(2, 2), 15.0, 3) == false, "Steep slope must NOT trigger convergence")

	print("test_hydraulic_basin_classifier: PASSED")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_hydraulic_basin_classifier.gd"`
Expected: FAIL (`hydraulic_basin_classifier.gd` does not exist)

- [ ] **Step 3: Implement `HydraulicBasinClassifier`**

```gdscript
# src/world_generator/hydrology/hydraulic_basin_classifier.gd
class_name HydraulicBasinClassifier
extends RefCounted

## Clasificador geomorfológico local para depresiones y zonas de convergencia fluvial.
## No depende de los bordes del mapa global, permitiendo portabilidad directa a arquitecturas por Chunks.

const D8_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
]

func is_local_depression(
	pos: Vector2i,
	cells: Dictionary,
	filled_height: Dictionary,
	threshold: float = 0.05
) -> bool:
	if not cells.has(pos):
		return false
	var cell = cells[pos]
	var raw_h: float = float(cell.raw_height if "raw_height" in cell else cell.get("raw_height", 0.0))
	var fill_h: float = float(filled_height.get(pos, raw_h))
	return fill_h > raw_h + threshold

func detect_convergence_zone(
	active_river_cells: Dictionary,
	pos: Vector2i,
	slope: float,
	radius: int = 3,
	slope_threshold: float = 2.0
) -> bool:
	if slope > slope_threshold:
		return false

	var nearby_rivers: Dictionary = {}
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var check_p := pos + Vector2i(dx, dy)
			if active_river_cells.has(check_p):
				var r_id: int = int(active_river_cells[check_p])
				nearby_rivers[r_id] = true

	return nearby_rivers.size() >= 2
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_hydraulic_basin_classifier.gd"`
Expected: PASS

- [ ] **Step 5: Commit Task 1**

```bash
git add src/world_generator/hydrology/hydraulic_basin_classifier.gd src/world_generator/tests/test_hydraulic_basin_classifier.gd
git commit -m "feat(hydrology): add HydraulicBasinClassifier for chunk-friendly local depression and convergence detection"
```

---

### Task 2: River Inflow Interception at Depressions & Valley Confluences

**Files:**
- Modify: `src/world_generator/stages/hydrology_stage.gd:1080-1150`
- Test: `src/world_generator/tests/test_river_depression_interception.gd`

**Interfaces:**
- Consumes: `HydraulicBasinClassifier`, `cells`, `filled_height`, `flow_to`
- Produces:
  - Rivers stop tracing upon entering an enclosed depression or convergence zone.
  - River endpoints record `destination_type = LAKE`.

- [ ] **Step 1: Write test for river depression interception**

```gdscript
# src/world_generator/tests/test_river_depression_interception.gd
extends SceneTree

const _TaigaWorldProfile = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipeline = preload("res://src/world_generator/facade/world_pipeline.gd")
const _RiverEndpoint = preload("res://src/world_generator/hydrology/river_endpoint.gd")

func _init() -> void:
	print("--- Running test_river_depression_interception ---")
	var profile = _TaigaWorldProfile.new()
	profile.width = 64
	profile.height = 64
	profile.hydrology_enabled = true

	# Test across a seed known to contain depressions (e.g. Seed 2)
	var result = _WorldPipeline.generate(2, profile)
	assert(result != null and result.hydrology != null)

	var hydro = result.hydrology
	var lakes: Array = hydro.lakes
	print("  Seed 2 generated %d lakes" % lakes.size())
	assert(not lakes.is_empty(), "Seed 2 with large depression must generate at least 1 lake")

	var found_lake_dest: bool = false
	for r in hydro.rivers:
		if r.destination_type == _RiverEndpoint.DestinationType.LAKE:
			found_lake_dest = true
			break
	assert(found_lake_dest, "At least one river must have destination_type == LAKE")

	print("test_river_depression_interception: PASSED")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_river_depression_interception.gd"`
Expected: FAIL (`lakes.is_empty()` is currently true for Seed 2)

- [ ] **Step 3: Update `_trace_river_network` in `hydrology_stage.gd`**

In `src/world_generator/stages/hydrology_stage.gd`:
- Preload `_HydraulicBasinClassifierScript = preload("res://src/world_generator/hydrology/hydraulic_basin_classifier.gd")`.
- Instantiate classifier before tracing.
- In `_trace_river_network`, when stepping from `curr` to `nxt`:
  - Check `classifier.is_local_depression(nxt, cells, filled_height, 0.05)`:
    - If `nxt` is in a depression:
      - If the river has already accumulated at least `min_acceptable_pts` points:
        - Append `nxt` to `path`.
        - Break out of river tracing loop! The river terminates at the lake entrance.
        - Mark destination as `LAKE`.
  - Check `classifier.detect_convergence_zone(river_cell_owner, nxt, cells[nxt].slope, 3)`:
    - If 2 or more rivers are converging in flat valley, pause and break out to form a confluence lake.

- [ ] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_river_depression_interception.gd"`
Expected: PASS

- [ ] **Step 5: Commit Task 2**

```bash
git add src/world_generator/stages/hydrology_stage.gd src/world_generator/tests/test_river_depression_interception.gd
git commit -m "feat(hydrology): intercept rivers at local depressions and flat convergence zones"
```

---

### Task 3: Local Spillway Expansion & Outflow Consolidation

**Files:**
- Modify: `src/world_generator/hydrology/hydraulic_destination_resolver.gd:57-140`
- Modify: `src/world_generator/stages/hydrology_stage.gd:420-510`
- Test: `src/world_generator/tests/test_confluence_lake_outflow.gd`

**Interfaces:**
- Consumes: `LakeCandidate`, `cells`, `filled_height`, `flood_rank`
- Produces:
  - `LakeCandidate` flooded to local spillway height $H_{\text{spillway}}$.
  - Consolidates multiple inlet rivers feeding the same depression into a single lake body.
  - Traces single outflow river downstream from spillway.

- [ ] **Step 1: Write test for multi-inlet lake consolidation and outflow continuity**

```gdscript
# src/world_generator/tests/test_confluence_lake_outflow.gd
extends SceneTree

const _TaigaWorldProfile = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipeline = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("--- Running test_confluence_lake_outflow ---")
	var profile = _TaigaWorldProfile.new()
	profile.width = 64
	profile.height = 64
	profile.hydrology_enabled = true

	var result = _WorldPipeline.generate(2, profile)
	assert(result != null and result.hydrology != null)

	var hydro = result.hydrology
	assert(not hydro.lakes.is_empty(), "Must have lakes")
	for lake in hydro.lakes:
		assert(lake.has("water_height"), "Lake must have water_height")
		assert(lake.has("spillway_pos"), "Lake must have spillway_pos")
		assert(lake.get("cells", []).size() >= 3, "Lake must have at least 3 cells")

	print("test_confluence_lake_outflow: PASSED")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails/passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_confluence_lake_outflow.gd"`

- [ ] **Step 3: Refine lake expansion and multi-inlet registration**

In `hydraulic_destination_resolver.gd`:
- If an endpoint reaches an existing lake body or an expanding depression that overlaps an existing `LakeCandidate`:
  - Merge the inlet into the existing lake (`lake.source_river_ids.append(r.id)`).
  - Do NOT spawn redundant duplicate lakes.
- Ensure the single outflow river from the spillway registers all upstream feeder rivers.

- [ ] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_confluence_lake_outflow.gd"`
Expected: PASS

- [ ] **Step 5: Commit Task 3**

```bash
git add src/world_generator/hydrology/hydraulic_destination_resolver.gd src/world_generator/stages/hydrology_stage.gd src/world_generator/tests/test_confluence_lake_outflow.gd
git commit -m "feat(hydrology): consolidate multi-inlet confluence lakes with clean spillway outflow"
```

---

### Task 4: Elimination of the Seed 283362 River Spaghetti Knot

**Files:**
- Test: `src/world_generator/tests/test_seed_283362_lake_resolution.gd`

**Interfaces:**
- Evaluates Seed 283362 (from user screenshot) at 256x256 resolution.
- Validates that the chaotic looping river ribbons are replaced by a clean, planar `LakeCandidate` and single outflow river.

- [ ] **Step 1: Write verification test for Seed 283362**

```gdscript
# src/world_generator/tests/test_seed_283362_lake_resolution.gd
extends SceneTree

const _TaigaWorldProfile = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipeline = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("--- Running test_seed_283362_lake_resolution ---")
	var profile = _TaigaWorldProfile.new()
	profile.width = 256
	profile.height = 256
	profile.hydrology_enabled = true

	var result = _WorldPipeline.generate(283362, profile)
	assert(result != null and result.hydrology != null)

	var hydro = result.hydrology
	print("  Seed 283362 generated %d rivers and %d lakes" % [hydro.rivers.size(), hydro.lakes.size()])

	assert(not hydro.lakes.is_empty(), "Seed 283362 must form a lake in the central convergence basin!")
	
	# Verify that no river has excessive self-intersections or infinite looping
	for r in hydro.rivers:
		var visited_cells: Dictionary = {}
		var duplicates: int = 0
		for p in r.cells:
			if visited_cells.has(p):
				duplicates += 1
			visited_cells[p] = true
		assert(duplicates <= 2, "River %d has %d looping duplicate cells (must not be a spaghetti knot)" % [r.id, duplicates])

	print("test_seed_283362_lake_resolution: PASSED")
	quit(0)
```

- [ ] **Step 2: Run test to verify**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_seed_283362_lake_resolution.gd"`
Expected: PASS

- [ ] **Step 3: Commit Task 4**

```bash
git add src/world_generator/tests/test_seed_283362_lake_resolution.gd
git commit -m "test(hydrology): verify Seed 283362 resolves valley convergence into a clean lake without knots"
```

---

### Task 5: Full Regression & Multi-Seed Validation Suite

**Files:**
- Test: `src/world_generator/tests/test_water_presentation_validation.gd`
- Test: `src/world_generator/tests/test_hydraulic_cycle_closure.gd`
- Test: `src/world_generator/tests/test_world_all.gd`

- [ ] **Step 1: Run comprehensive water presentation validation**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_water_presentation_validation.gd"`
Expected: PASS (0 degenerate triangles)

- [ ] **Step 2: Run hydraulic cycle closure test**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_hydraulic_cycle_closure.gd"`
Expected: PASS

- [ ] **Step 3: Run full world generator test suite**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_world_all.gd"`
Expected: PASS

- [ ] **Step 4: Commit plan documentation and test suite**

```bash
git commit -m "docs: finalize chunk-compatible confluence lakes implementation plan and test suite"
```
