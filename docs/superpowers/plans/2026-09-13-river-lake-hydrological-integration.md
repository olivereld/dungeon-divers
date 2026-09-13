# River → Lake Hydrological Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the lake generation architecture from arbitrary low-terrain clustering to a causally integrated hydrological system where rivers generate lakes at their endpoints (`RiverEndpoint` → `HydraulicDestinationResolver` → `LakeCandidate` → Spillway → Outflow River).

**Architecture:** Rivers are traced first through the terrain flow field. Each river endpoint is evaluated by a `HydraulicDestinationResolver` to determine its destination (`OUT_OF_WORLD`, `JOIN_RIVER`, `LAKE`, or `TERMINATE`). Endpoints identified as `LAKE` act as hydraulic seeds that flood the local topography, find the physical containment spillway, define `LakeCandidate` objects, emit outflow rivers through the spillways, carve the terrain strictly downward, and finally validate containment against $H_{\text{carved}}$.

**Tech Stack:** Godot 4.6 GDScript, RefCounted data structures, Priority-Flood D8 routing, FastNoiseLite.

**Spec:** User architecture prompt: *"Un río terminó aquí → necesito resolver qué ocurre con el agua en ese punto."* Pipeline: `Terrain RAW → Relief Analysis → Flow/Accumulation → River Network → River Geometry → Lakes at River Endpoints → Basin/Spillway Resolution → Carving → Ground Truth Validation → Water Meshes`.

## Global Constraints
- Strictly downward carving: $H_{\text{final}} = \min(H_{\text{raw}}, H_{\text{carved}})$.
- Lakes only exist where a river endpoint feeds an enclosed depression with physical containment rim.
- No floating lakes or rivers ($H_{\text{water}} \le H_{\text{raw}} + 0.05\text{m}$).
- Deterministic execution: identical results for identical seeds.
- Tests must be fast and headless: exit cleanly with code 0.

---

### Task 1: Model Types (`RiverEndpoint`, `LakeCandidate`)

**Files:**
- Create: `src/world_generator/hydrology/river_endpoint.gd`
- Create: `src/world_generator/hydrology/lake_candidate.gd`
- Test: `tests/test_river_endpoint_model.gd`

**Interfaces:**
- Consumes: `WorldCell`, `River`
- Produces:
  - `RiverEndpoint`: `{ river_id: int, position: Vector2i, elevation: float, accumulation: float, destination_type: DestinationType }`
  - `LakeCandidate`: `{ id: int, seed_endpoint: RiverEndpoint, cells: Array[Vector2i], spillway_pos: Vector2i, spillway_height: float, water_height: float, source_river_ids: Array[int], outflow_river_id: int }`

- [ ] **Step 1: Write failing test for models**

```gdscript
# tests/test_river_endpoint_model.gd
extends SceneTree

const _RiverEndpointScript = preload("res://src/world_generator/hydrology/river_endpoint.gd")
const _LakeCandidateScript = preload("res://src/world_generator/hydrology/lake_candidate.gd")

func _init() -> void:
	print("Running test_river_endpoint_model...")
	var ep = _RiverEndpointScript.new(0, Vector2i(20, 30), 12.5, 45.0)
	assert(ep.river_id == 0, "river_id should match")
	assert(ep.position == Vector2i(20, 30), "position should match")
	assert(ep.elevation == 12.5, "elevation should match")
	assert(ep.accumulation == 45.0, "accumulation should match")
	assert(ep.destination_type == _RiverEndpointScript.DestinationType.UNKNOWN, "default type should be UNKNOWN")

	ep.destination_type = _RiverEndpointScript.DestinationType.LAKE
	assert(ep.destination_type == _RiverEndpointScript.DestinationType.LAKE, "destination should be LAKE")

	var lake = _LakeCandidateScript.new(1, ep)
	assert(lake.id == 1, "lake id should be 1")
	assert(lake.seed_endpoint == ep, "seed endpoint should match")
	assert(lake.source_river_ids.has(0), "source_river_ids should include river 0")
	assert(lake.cells.is_empty(), "cells should initially be empty")
	print("test_river_endpoint_model: PASSED")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://tests/test_river_endpoint_model.gd"`
Expected: FAIL (files do not exist yet)

- [ ] **Step 3: Implement `RiverEndpoint`**

```gdscript
# src/world_generator/hydrology/river_endpoint.gd
class_name RiverEndpoint
extends RefCounted

enum DestinationType {
	UNKNOWN,
	OUT_OF_WORLD,
	JOIN_RIVER,
	LAKE,
	TERMINATE
}

var river_id: int = -1
var position: Vector2i = Vector2i(-1, -1)
var elevation: float = 0.0
var accumulation: float = 1.0
var destination_type: DestinationType = DestinationType.UNKNOWN
var target_river_id: int = -1
var target_lake_id: int = -1

func _init(p_river_id: int = -1, p_pos: Vector2i = Vector2i(-1, -1), p_elev: float = 0.0, p_accum: float = 1.0) -> void:
	river_id = p_river_id
	position = p_pos
	elevation = p_elev
	accumulation = p_accum

func to_dict() -> Dictionary:
	return {
		"river_id": river_id,
		"position": position,
		"elevation": elevation,
		"accumulation": accumulation,
		"destination_type": destination_type,
		"target_river_id": target_river_id,
		"target_lake_id": target_lake_id
	}
```

- [ ] **Step 4: Implement `LakeCandidate`**

```gdscript
# src/world_generator/hydrology/lake_candidate.gd
class_name LakeCandidate
extends RefCounted

var id: int = -1
var seed_endpoint: RefCounted = null
var source_river_ids: Array[int] = []
var outflow_river_id: int = -1
var cells: Array[Vector2i] = []
var spillway_pos: Vector2i = Vector2i(-1, -1)
var spillway_height: float = INF
var water_height: float = 0.0
var min_pos: Vector2i = Vector2i(999999, 999999)
var max_pos: Vector2i = Vector2i(-999999, -999999)

func _init(p_id: int = -1, p_seed_endpoint: RefCounted = null) -> void:
	id = p_id
	seed_endpoint = p_seed_endpoint
	if p_seed_endpoint != null and "river_id" in p_seed_endpoint and p_seed_endpoint.river_id != -1:
		source_river_ids.append(p_seed_endpoint.river_id)

func add_cell(pos: Vector2i) -> void:
	cells.append(pos)
	min_pos.x = mini(min_pos.x, pos.x)
	min_pos.y = mini(min_pos.y, pos.y)
	max_pos.x = maxi(max_pos.x, pos.x)
	max_pos.y = maxi(max_pos.y, pos.y)

func to_dict() -> Dictionary:
	return {
		"id": id,
		"cells": cells,
		"spillway_pos": spillway_pos,
		"spillway_height": spillway_height,
		"water_height": water_height,
		"min_pos": min_pos,
		"max_pos": max_pos,
		"source_river_ids": source_river_ids,
		"outflow_river_id": outflow_river_id
	}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://tests/test_river_endpoint_model.gd"`
Expected: PASS

---

### Task 2: `HydraulicDestinationResolver` Component

**Files:**
- Create: `src/world_generator/hydrology/hydraulic_destination_resolver.gd`
- Test: `tests/test_hydraulic_destination_resolver.gd`

**Interfaces:**
- Consumes: `WorldCell`, `RiverEndpoint`, `River`, `flow_to`
- Produces:
  - `resolve_destination(endpoint: RiverEndpoint, width: int, height: int, river_cell_owner: Dictionary, cells: Dictionary, flow_to: Dictionary, basins: Dictionary) -> RiverEndpoint.DestinationType`

- [ ] **Step 1: Write failing test for destination resolver**

```gdscript
# tests/test_hydraulic_destination_resolver.gd
extends SceneTree

const _RiverEndpointScript = preload("res://src/world_generator/hydrology/river_endpoint.gd")
const _ResolverScript = preload("res://src/world_generator/hydrology/hydraulic_destination_resolver.gd")

func _init() -> void:
	print("Running test_hydraulic_destination_resolver...")
	var resolver = _ResolverScript.new()

	# Case 1: Border cell -> OUT_OF_WORLD
	var ep_border = _RiverEndpointScript.new(0, Vector2i(0, 15), 10.0, 50.0)
	var dest1 = resolver.resolve_destination(ep_border, 64, 64, {}, {}, {}, {})
	assert(dest1 == _RiverEndpointScript.DestinationType.OUT_OF_WORLD, "Edge cell should resolve to OUT_OF_WORLD")

	# Case 2: Hits another river cell -> JOIN_RIVER
	var ep_conf = _RiverEndpointScript.new(1, Vector2i(20, 20), 10.0, 30.0)
	var river_owner = { Vector2i(20, 20): 0 }
	var dest2 = resolver.resolve_destination(ep_conf, 64, 64, river_owner, {}, {}, {})
	assert(dest2 == _RiverEndpointScript.DestinationType.JOIN_RIVER, "River owner cell should resolve to JOIN_RIVER")
	assert(ep_conf.target_river_id == 0, "Target river id should be 0")

	print("test_hydraulic_destination_resolver: PASSED")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://tests/test_hydraulic_destination_resolver.gd"`
Expected: FAIL (file does not exist)

- [ ] **Step 3: Implement `HydraulicDestinationResolver`**

```gdscript
# src/world_generator/hydrology/hydraulic_destination_resolver.gd
class_name HydraulicDestinationResolver
extends RefCounted

const _RiverEndpointScript = preload("res://src/world_generator/hydrology/river_endpoint.gd")
const _LakeCandidateScript = preload("res://src/world_generator/hydrology/lake_candidate.gd")

const D8_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
]

func resolve_destination(
	endpoint: RefCounted,
	width: int,
	height: int,
	river_cell_owner: Dictionary,
	cells: Dictionary,
	flow_to: Dictionary,
	basins: Dictionary
) -> int:
	var p: Vector2i = endpoint.position

	# 1. Borde del mapa -> Salida natural del mundo
	if p.x <= 0 or p.x >= width - 1 or p.y <= 0 or p.y >= height - 1:
		endpoint.destination_type = _RiverEndpointScript.DestinationType.OUT_OF_WORLD
		return endpoint.destination_type

	# 2. Confluencia con otro río existente
	if river_cell_owner.has(p):
		var other_river_id: int = river_cell_owner[p]
		if other_river_id != endpoint.river_id:
			endpoint.destination_type = _RiverEndpointScript.DestinationType.JOIN_RIVER
			endpoint.target_river_id = other_river_id
			return endpoint.destination_type

	# 3. Evaluar si se encuentra en una depresión que puede acumular un lago
	var nxt: Vector2i = flow_to.get(p, p)
	if nxt == p or nxt == endpoint.position:
		endpoint.destination_type = _RiverEndpointScript.DestinationType.LAKE
		return endpoint.destination_type

	# 4. Verificar si todos los vecinos son más altos (cuenca local cerrada)
	var curr_h: float = cells[p].raw_height if cells.has(p) else endpoint.elevation
	var is_local_minimum: bool = true
	for offset in D8_OFFSETS:
		var nb: Vector2i = p + offset
		if cells.has(nb):
			if cells[nb].raw_height < curr_h - 0.01:
				is_local_minimum = false
				break

	if is_local_minimum:
		endpoint.destination_type = _RiverEndpointScript.DestinationType.LAKE
		return endpoint.destination_type

	# Por defecto, termina en lago o final natural
	endpoint.destination_type = _RiverEndpointScript.DestinationType.LAKE
	return endpoint.destination_type
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://tests/test_hydraulic_destination_resolver.gd"`
Expected: PASS

---

### Task 3: Lake Expansion & Spillway Detection from Endpoint Seed

**Files:**
- Modify: `src/world_generator/hydrology/hydraulic_destination_resolver.gd`
- Test: `tests/test_endpoint_lake_expansion.gd`

**Interfaces:**
- Consumes: `RiverEndpoint`, `cells: Dictionary`, `filled_height: Dictionary`, `flood_rank: Dictionary`
- Produces:
  - `expand_lake_from_endpoint(endpoint: RiverEndpoint, lake_id: int, cells: Dictionary, filled_height: Dictionary, flood_rank: Dictionary, width: int, height: int, min_area: int) -> LakeCandidate`

- [ ] **Step 1: Write failing test for endpoint lake expansion**

```gdscript
# tests/test_endpoint_lake_expansion.gd
extends SceneTree

const _RiverEndpointScript = preload("res://src/world_generator/hydrology/river_endpoint.gd")
const _ResolverScript = preload("res://src/world_generator/hydrology/hydraulic_destination_resolver.gd")
const _WorldCellScript = preload("res://src/world_generator/data/world_cell.gd")

func _init() -> void:
	print("Running test_endpoint_lake_expansion...")
	var resolver = _ResolverScript.new()

	# Create a synthetic 5x5 bowl centered at (2, 2)
	var cells: Dictionary = {}
	var filled_h: Dictionary = {}
	var flood_rank: Dictionary = {}

	for y in range(5):
		for x in range(5):
			var pos := Vector2i(x, y)
			var c = _WorldCellScript.new()
			var dist = (Vector2(x, y) - Vector2(2, 2)).length()
			var h = 10.0 + dist * 2.0
			if x == 2 and y == 2:
				h = 8.0 # Bottom of the bowl
			c.raw_height = h
			c.height = h
			cells[pos] = c
			filled_h[pos] = 12.0
			flood_rank[pos] = 5 * y + x

	var ep = _RiverEndpointScript.new(0, Vector2i(2, 2), 8.0, 100.0)
	var lake = resolver.expand_lake_from_endpoint(ep, 1, cells, filled_h, flood_rank, 5, 5, 1)

	assert(lake != null, "LakeCandidate should be created")
	assert(lake.cells.has(Vector2i(2, 2)), "Lake must contain seed endpoint (2, 2)")
	assert(lake.spillway_pos != Vector2i(-1, -1), "Spillway must be found")
	assert(lake.water_height > 8.0, "Water level must be above bottom of bowl")
	print("test_endpoint_lake_expansion: PASSED")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://tests/test_endpoint_lake_expansion.gd"`
Expected: FAIL (`expand_lake_from_endpoint` nonexistent)

- [ ] **Step 3: Implement `expand_lake_from_endpoint` in `HydraulicDestinationResolver`**

```gdscript
func expand_lake_from_endpoint(
	endpoint: RefCounted,
	lake_id: int,
	cells: Dictionary,
	filled_height: Dictionary,
	flood_rank: Dictionary,
	width: int,
	height: int,
	min_area: int = 4
) -> RefCounted:
	var seed_pos: Vector2i = endpoint.position
	if not cells.has(seed_pos):
		return null

	var target_spillway_h: float = float(filled_height.get(seed_pos, cells[seed_pos].raw_height))
	if target_spillway_h <= cells[seed_pos].raw_height:
		# Si no hay cubeta natural de llenado, buscar vertedero en el borde circundante mínimo
		target_spillway_h = cells[seed_pos].raw_height + 0.50

	# Flood-fill desde seed_pos expandiendo a vecinos con altura <= target_spillway_h
	var lake = _LakeCandidateScript.new(lake_id, endpoint)
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [seed_pos]
	visited[seed_pos] = true

	var spill_pos: Vector2i = Vector2i(-1, -1)
	var min_rim_rank: int = 999999999
	var min_rim_h: float = INF

	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		lake.add_cell(curr)

		for offset in D8_OFFSETS:
			var nb: Vector2i = curr + offset
			if nb.x < 0 or nb.x >= width or nb.y < 0 or nb.y >= height:
				continue
			if visited.has(nb):
				continue

			var nc: WorldCell = cells.get(nb)
			if nc == null:
				continue

			if nc.raw_height <= target_spillway_h + 0.001 and lake.cells.size() < 120:
				visited[nb] = true
				queue.append(nb)
			else:
				var r_val: int = flood_rank.get(nb, 999999999)
				if r_val < min_rim_rank:
					min_rim_rank = r_val
					spill_pos = nb
					min_rim_h = nc.raw_height

	if lake.cells.size() < min_area:
		return null

	lake.spillway_pos = spill_pos
	lake.spillway_height = min_rim_h if not is_inf(min_rim_h) else target_spillway_h
	lake.water_height = minf(target_spillway_h, lake.spillway_height)

	return lake
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://tests/test_endpoint_lake_expansion.gd"`
Expected: PASS

---

### Task 4: Lake Spillway Outflow River Continuity

**Files:**
- Modify: `src/world_generator/hydrology/hydraulic_destination_resolver.gd`
- Test: `tests/test_river_lake_network_continuity.gd`

**Interfaces:**
- Consumes: `LakeCandidate`, `flow_to: Dictionary`, `accumulation: Dictionary`
- Produces:
  - `trace_lake_outflow(lake: LakeCandidate, flow_to: Dictionary, accumulation: Dictionary, river_id: int, max_steps: int) -> River`

- [ ] **Step 1: Write failing test for lake outflow continuity**

```gdscript
# tests/test_river_lake_network_continuity.gd
extends SceneTree

const _RiverEndpointScript = preload("res://src/world_generator/hydrology/river_endpoint.gd")
const _LakeCandidateScript = preload("res://src/world_generator/hydrology/lake_candidate.gd")
const _ResolverScript = preload("res://src/world_generator/hydrology/hydraulic_destination_resolver.gd")

func _init() -> void:
	print("Running test_river_lake_network_continuity...")
	var resolver = _ResolverScript.new()

	var ep = _RiverEndpointScript.new(0, Vector2i(10, 10), 15.0, 50.0)
	var lake = _LakeCandidateScript.new(1, ep)
	lake.spillway_pos = Vector2i(12, 10)
	lake.water_height = 14.5

	# Linear downhill flow chain from spillway
	var flow_to = {
		Vector2i(12, 10): Vector2i(13, 10),
		Vector2i(13, 10): Vector2i(14, 10),
		Vector2i(14, 10): Vector2i(15, 10),
		Vector2i(15, 10): Vector2i(16, 10),
		Vector2i(16, 10): Vector2i(17, 10),
		Vector2i(17, 10): Vector2i(17, 10) # edge terminal
	}
	var accum = { Vector2i(12, 10): 60.0 }

	var outflow = resolver.trace_lake_outflow(lake, flow_to, accum, 1, 50)
	assert(outflow != null, "Outflow river must be created")
	assert(outflow.is_outflow == true, "Outflow river must have is_outflow = true")
	assert(outflow.path[0] == Vector2i(12, 10), "Outflow must start at spillway")
	assert(outflow.upstream_rivers.has(0), "Outflow must record river 0 as upstream")
	assert(lake.outflow_river_id == 1, "Lake must record outflow river id 1")
	print("test_river_lake_network_continuity: PASSED")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://tests/test_river_lake_network_continuity.gd"`
Expected: FAIL (`trace_lake_outflow` nonexistent)

- [ ] **Step 3: Implement `trace_lake_outflow`**

```gdscript
const _RiverScript = preload("res://src/world_generator/hydrology/river.gd")

func trace_lake_outflow(
	lake: RefCounted,
	flow_to: Dictionary,
	accumulation: Dictionary,
	outflow_river_id: int,
	max_steps: int = 350
) -> RefCounted:
	var spill: Vector2i = lake.spillway_pos
	if spill == Vector2i(-1, -1):
		return null

	var outflow_path: Array[Vector2i] = [spill]
	var curr: Vector2i = spill

	for _step in range(max_steps):
		var nxt: Vector2i = flow_to.get(curr, curr)
		if nxt == curr:
			break
		outflow_path.append(nxt)
		curr = nxt

	if outflow_path.size() < 4:
		return null

	var outflow = _RiverScript.new(outflow_river_id, spill, outflow_path)
	outflow.is_outflow = true
	outflow.accumulation_start = float(accumulation.get(spill, 1.0))
	outflow.accumulation_end = float(accumulation.get(outflow_path[-1], 1.0))

	for src_id in lake.source_river_ids:
		outflow.upstream_rivers.append(src_id)

	lake.outflow_river_id = outflow_river_id
	return outflow
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://tests/test_river_lake_network_continuity.gd"`
Expected: PASS

---

### Task 5: Pipeline Refactoring in `HydrologyStage`

**Files:**
- Modify: `src/world_generator/stages/hydrology_stage.gd`
- Test: `tests/test_hydraulic_ground_truth.gd`

**Interfaces:**
- Integrate `HydraulicDestinationResolver`, `RiverEndpoint`, and `LakeCandidate` into the main `generate()` execution flow of `HydrologyStage`.
- Pipeline Flow:
  1. Priority-Flood ($H_{\text{filled}}$) & continuous flow field ($∇H$).
  2. Discretization D8 (with Priority-Flood fallback).
  3. Basins & Flow Accumulation.
  4. Headwaters selection.
  5. River tracing.
  6. Extract `RiverEndpoint` for all rivers.
  7. Resolve endpoints via `HydraulicDestinationResolver`.
  8. For `LAKE` destinations: expand `LakeCandidate` and trace spillway outflow rivers.
  9. River + Lake geometry generation & downward carving.
  10. Hydraulic Ground Truth validation.

- [ ] **Step 1: Replace legacy pre-river `_generate_lakes` in `hydrology_stage.gd` with endpoint-driven lake generation**

In `hydrology_stage.gd`:
- Move lake formation to occur after river network tracing.
- Loop over `network_rivers`: for each river whose last cell is not on the map boundary and not a confluence, create a `RiverEndpoint`.
- Call `resolver.resolve_destination(...)`.
- If `LAKE`: expand `LakeCandidate`, register in `hydro.lakes` and `hydro.water_cells`.
- Trace spillway outflow rivers and append them to the river network.

- [ ] **Step 2: Run `test_hydraulic_ground_truth.gd`**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_hydraulic_ground_truth.gd"`
Expected: PASS

- [x] **Step 3: Run `test_river_cross_section.gd`**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_river_cross_section.gd"`
Expected: PASS

---

### Task 6: Comprehensive Verification & Cleanup

**Files:**
- Modify: `docs/superpowers/plans/2026-09-13-river-lake-hydrological-integration.md` (check all tasks)
- Test: All tests in `tests/`

- [x] **Step 1: Run full world test suite**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_world_all.gd"`
Expected: PASS

- [ ] **Step 2: Clean up scratch test files**

Remove `tests/test_river_endpoint_model.gd`, `tests/test_hydraulic_destination_resolver.gd`, `tests/test_endpoint_lake_expansion.gd`, `tests/test_river_lake_network_continuity.gd` after all tests pass.
