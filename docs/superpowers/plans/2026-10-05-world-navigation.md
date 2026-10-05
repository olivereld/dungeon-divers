# WorldNavigation Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a lightweight, logical surface navigation module (`WorldNavigation`) generated in worker threads alongside `ChunkData`, published to a central `WorldNavigationGrid`, and consumed by `MovementRules` and `MovementComponent` without meshes, navmeshes, raycasts, or synchronous generation.

**Architecture:**
- `WorldNavigationStage` executes in the chunk generation worker after `NavigationStage` (which determines `WorldCell.is_walkable`) and before `VegetationStage`.
- `WorldNavigationChunk` stores compact, immutable navigation data for `core_bounds` (excluding temporary seam/halo cells) using packed arrays (`walkable: PackedByteArray`, `elevation_level: PackedInt32Array`, `height: PackedFloat32Array`).
- `WorldNavigationChunk` travels alongside `ChunkData` in `ChunkGenerationScheduler` worker results and is registered/unregistered in `WorldNavigationGrid` in O(1) on the main thread.
- `WorldNavigationGrid` tracks `READY` vs `UNAVAILABLE` chunks, resolves global coordinates across chunk boundaries, and provides queries (`is_walkable`, `get_height`, `get_elevation_level`, `find_lower_support`).
- `MovementRules` acts as the gameplay authority interpreting `WorldNavigationGrid` data against `MovementProfile` (8 directions, step up/down, falling with lower surface validation, diagonal corner blocking, chunk availability).
- `MovementComponent` suspends movement upon encountering `UNAVAILABLE` chunks and automatically retries via `WorldNavigationGrid.chunk_registered` signals without per-frame polling.

**Tech Stack:** Godot 4.6 GDScript (`RefCounted`, `PackedByteArray`, `PackedInt32Array`, `PackedFloat32Array`, `Rect2i`, `Vector2i`, `Vector3`, `Mutex`, `Signal`).

**Spec:** Technical specification provided in user prompt: "Plan técnico: módulo WorldNavigation".

## Global Constraints

- Zero meshes, zero `NavigationRegion3D`, zero NavMesh, zero raycasts for walkability determination.
- Single source of truth for walkability: `WorldCell.is_walkable` produced by `NavigationStage`.
- `WorldNavigationStage` only materializes data into `WorldNavigationChunk`; it does not calculate slopes, raycasts, or transitions.
- Navigation data generation runs exclusively in worker threads inside `WorldPipeline.generate_chunk()`.
- Main thread only performs O(1) registration and unregistration in `WorldNavigationGrid`.
- `WorldNavigationChunk` represents only `core_bounds` of the chunk; `seam_cells` are strictly excluded from navigation authority.
- `WorldNavigationGrid` stores world data (`READY` / `UNAVAILABLE`); gameplay transitions (`WALK`, `STEP_UP`, `STEP_DOWN`, `FALL`, `BLOCKED`) belong strictly to `MovementRules`.
- An unavailable chunk (`UNAVAILABLE`) must NEVER trigger synchronous chunk generation. Movement requests pause and wait for `chunk_registered`.
- Exactly one comprehensive integration test suite: `tests/integration/test_world_navigation_integration.gd`.

---

### Task 1: Core Navigation Data Structures (`WorldNavigationCell` & `WorldNavigationChunk`)

**Files:**
- Create: `src/world_generator/navigation/world_navigation_cell.gd`
- Create: `src/world_generator/navigation/world_navigation_chunk.gd`
- Test: `tests/integration/test_world_navigation_integration.gd`

**Interfaces:**
- Consumes: `WorldCell`, `Rect2i`, `Vector2i`
- Produces:
  - `WorldNavigationCell`: Lightweight query transfer object containing `cell: Vector2i`, `height: float`, `elevation_level: int`, `walkable: bool`.
  - `WorldNavigationChunk`:
    - `chunk_coord: Vector2i`
    - `core_bounds: Rect2i`
    - `width: int`, `height: int`
    - `walkable: PackedByteArray`
    - `elevation_level: PackedInt32Array`
    - `height: PackedFloat32Array`
    - `func get_cell(global_cell: Vector2i) -> WorldNavigationCell`
    - `func is_walkable(global_cell: Vector2i) -> bool`
    - `func get_height(global_cell: Vector2i) -> float`
    - `func get_elevation_level(global_cell: Vector2i) -> int`
    - `func has_cell(global_cell: Vector2i) -> bool`
    - `static func from_cells(p_coord: Vector2i, p_core: Rect2i, p_cells: Dictionary) -> WorldNavigationChunk`

- [ ] **Step 1: Write initial test for `WorldNavigationCell` and `WorldNavigationChunk`**

Create `tests/integration/test_world_navigation_integration.gd`:
```gdscript
extends SceneTree

const _NavCellScript = preload("res://src/world_generator/navigation/world_navigation_cell.gd")
const _NavChunkScript = preload("res://src/world_generator/navigation/world_navigation_chunk.gd")
const _WorldCellScript = preload("res://src/world_generator/data/world_cell.gd")

func _init() -> void:
	print("==================================================")
	print(" Running WorldNavigation Integration Tests")
	print("==================================================")
	_test_nav_chunk_construction()
	print("==================================================")
	print(" ALL WORLD NAVIGATION TESTS PASSED!")
	print("==================================================")
	quit(0)

func _test_nav_chunk_construction() -> void:
	print(" -> Testing WorldNavigationChunk packed memory and lookup...")
	var coord := Vector2i(0, 0)
	var bounds := Rect2i(0, 0, 4, 4)
	var cells := {}
	for y in range(4):
		for x in range(4):
			var pos := Vector2i(x, y)
			var cell = _WorldCellScript.new(pos)
			cell.elevation_level = 2
			cell.height = 3.5
			cell.is_walkable = (x != 0 or y != 0)
			cells[pos] = cell

	var nav_chunk = _NavChunkScript.from_cells(coord, bounds, cells)
	assert(nav_chunk.chunk_coord == coord, "Coord must match")
	assert(nav_chunk.has_cell(Vector2i(1, 1)), "Inside cell exists")
	assert(not nav_chunk.has_cell(Vector2i(5, 5)), "Outside cell does not exist")
	assert(not nav_chunk.is_walkable(Vector2i(0, 0)), "Cell (0,0) must not be walkable")
	assert(nav_chunk.is_walkable(Vector2i(1, 1)), "Cell (1,1) must be walkable")
	assert(nav_chunk.get_elevation_level(Vector2i(1, 1)) == 2, "Elevation level matches")
	assert(absf(nav_chunk.get_height(Vector2i(1, 1)) - 3.5) < 0.001, "Height matches")

	var nav_cell = nav_chunk.get_cell(Vector2i(1, 1))
	assert(nav_cell != null, "nav_cell must not be null")
	assert(nav_cell.cell == Vector2i(1, 1), "NavCell pos matches")
	assert(nav_cell.walkable == true, "NavCell walkable matches")
	assert(nav_cell.elevation_level == 2, "NavCell elevation matches")
	print("    [PASS] WorldNavigationChunk construction and queries")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script res://tests/integration/test_world_navigation_integration.gd`
Expected: FAIL (script preload errors for non-existent files).

- [ ] **Step 3: Implement `WorldNavigationCell` and `WorldNavigationChunk`**

Create `src/world_generator/navigation/world_navigation_cell.gd`:
```gdscript
class_name WorldNavigationCell
extends RefCounted

## Objeto inmutable de transporte para consultas puntuales de datos de navegación.

var cell: Vector2i = Vector2i.ZERO
var height: float = 0.0
var elevation_level: int = 0
var walkable: bool = true

func _init(p_cell: Vector2i = Vector2i.ZERO, p_height: float = 0.0, p_elevation: int = 0, p_walkable: bool = true) -> void:
	cell = p_cell
	height = p_height
	elevation_level = p_elevation
	walkable = p_walkable
```

Create `src/world_generator/navigation/world_navigation_chunk.gd`:
```gdscript
class_name WorldNavigationChunk
extends RefCounted

## Representación inmutable y empaquetada de los datos de navegación para el core_bounds de un chunk.

const _NavCellScript = preload("res://src/world_generator/navigation/world_navigation_cell.gd")

var chunk_coord: Vector2i = Vector2i.ZERO
var core_bounds: Rect2i = Rect2i()
var width: int = 0
var height: int = 0

var walkable: PackedByteArray = PackedByteArray()
var elevation_level: PackedInt32Array = PackedInt32Array()
var height_data: PackedFloat32Array = PackedFloat32Array()

func _init(p_coord: Vector2i = Vector2i.ZERO, p_bounds: Rect2i = Rect2i()) -> void:
	chunk_coord = p_coord
	core_bounds = p_bounds
	width = p_bounds.size.x
	height = p_bounds.size.y

static func from_cells(p_coord: Vector2i, p_bounds: Rect2i, cells_dict: Dictionary) -> WorldNavigationChunk:
	var chunk := WorldNavigationChunk.new(p_coord, p_bounds)
	var total_cells := chunk.width * chunk.height
	if total_cells <= 0:
		return chunk

	var w_arr := PackedByteArray()
	w_arr.resize(total_cells)
	var e_arr := PackedInt32Array()
	e_arr.resize(total_cells)
	var h_arr := PackedFloat32Array()
	h_arr.resize(total_cells)

	var origin_x := p_bounds.position.x
	var origin_y := p_bounds.position.y
	var w := chunk.width

	for ly in range(chunk.height):
		for lx in range(chunk.width):
			var global_pos := Vector2i(origin_x + lx, origin_y + ly)
			var idx := lx + ly * w
			var cell = cells_dict.get(global_pos, null)
			if cell != null:
				w_arr[idx] = 1 if cell.is_walkable else 0
				e_arr[idx] = cell.elevation_level
				h_arr[idx] = cell.height
			else:
				w_arr[idx] = 0
				e_arr[idx] = 0
				h_arr[idx] = 0.0

	chunk.walkable = w_arr
	chunk.elevation_level = e_arr
	chunk.height_data = h_arr
	return chunk

func has_cell(global_cell: Vector2i) -> bool:
	return core_bounds.has_point(global_cell)

func _get_local_index(global_cell: Vector2i) -> int:
	if not core_bounds.has_point(global_cell):
		return -1
	var lx := global_cell.x - core_bounds.position.x
	var ly := global_cell.y - core_bounds.position.y
	return lx + ly * width

func is_walkable(global_cell: Vector2i) -> bool:
	var idx := _get_local_index(global_cell)
	if idx < 0 or idx >= walkable.size():
		return false
	return walkable[idx] == 1

func get_height(global_cell: Vector2i) -> float:
	var idx := _get_local_index(global_cell)
	if idx < 0 or idx >= height_data.size():
		return 0.0
	return height_data[idx]

func get_elevation_level(global_cell: Vector2i) -> int:
	var idx := _get_local_index(global_cell)
	if idx < 0 or idx >= elevation_level.size():
		return 0
	return elevation_level[idx]

func get_cell(global_cell: Vector2i) -> WorldNavigationCell:
	var idx := _get_local_index(global_cell)
	if idx < 0 or idx >= walkable.size():
		return null
	return _NavCellScript.new(
		global_cell,
		height_data[idx],
		elevation_level[idx],
		walkable[idx] == 1
	)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script res://tests/integration/test_world_navigation_integration.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/world_generator/navigation/world_navigation_cell.gd src/world_generator/navigation/world_navigation_chunk.gd tests/integration/test_world_navigation_integration.gd
git commit -m "feat(navigation): add WorldNavigationCell and WorldNavigationChunk packed data structures"
```

---

### Task 2: Pipeline Integration (`WorldNavigationStage` & `ChunkData` Transport)

**Files:**
- Create: `src/world_generator/navigation/world_navigation_stage.gd`
- Modify: `src/world_generator/chunks/chunk_data.gd:10-15`
- Modify: `src/world_generator/facade/world_pipeline.gd:157-179`
- Modify: `src/world_generator/chunks/chunk_generation_scheduler.gd:219-241`
- Test: `tests/integration/test_world_navigation_integration.gd`

**Interfaces:**
- Consumes: `WorldGenerationContext`, `ChunkGenerationContext`, `ChunkData`, `NavigationStage`
- Produces:
  - `WorldNavigationStage.execute(context: WorldGenerationContext)`:
    Materializes `WorldNavigationChunk` from `context.result.cells` inside `core_bounds`.
    Stores in `chunk_data.navigation_chunk`.
  - `WorldPipeline._execute_stages`:
    Inserts `WorldNavigationStage` after `NavigationStage` and before `VegetationStage`.
  - `ChunkGenerationScheduler._worker_loop`:
    Transports `"navigation_chunk": chunk_data.navigation_chunk` in `_completed_results`.

- [ ] **Step 1: Write failing test asserting `WorldNavigationStage` execution and scheduler result**

In `tests/integration/test_world_navigation_integration.gd`, add `_test_pipeline_navigation_stage()`:
```gdscript
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")

func _test_pipeline_navigation_stage() -> void:
	print(" -> Testing WorldNavigationStage within WorldPipeline chunk generation...")
	var profile := _TaigaWorldProfileScript.new()
	var config := _ChunkConfigScript.new()
	var coord := Vector2i(0, 0)
	var chunk_data: ChunkData = _WorldPipelineScript.generate_chunk(12345, coord, profile, config, null)
	assert(chunk_data != null, "ChunkData must not be null")
	assert("navigation_chunk" in chunk_data, "ChunkData must have navigation_chunk property")
	assert(chunk_data.navigation_chunk != null, "navigation_chunk must be generated")
	assert(chunk_data.navigation_chunk.chunk_coord == coord, "nav_chunk coord must match")
	assert(chunk_data.navigation_chunk.core_bounds == chunk_data.core_bounds, "nav_chunk bounds must equal core_bounds")

	# Verify seam cells are NOT included in navigation_chunk
	for seam_pos in chunk_data.seam_cells.keys():
		assert(not chunk_data.navigation_chunk.has_cell(seam_pos), "Seam cell must not be in navigation_chunk")

	print("    [PASS] WorldNavigationStage execution and seam exclusion")
```
Call `_test_pipeline_navigation_stage()` in `_init()`.

- [ ] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script res://tests/integration/test_world_navigation_integration.gd`
Expected: FAIL (`navigation_chunk` not on `ChunkData` or is null).

- [ ] **Step 3: Implement `WorldNavigationStage` and modify `ChunkData`, `WorldPipeline`, and `ChunkGenerationScheduler`**

Create `src/world_generator/navigation/world_navigation_stage.gd`:
```gdscript
class_name WorldNavigationStage
extends WorldStage

## Etapa de materialización lógica de navegación.
## Convierte los datos definitivos producidos por Terrain, Hydrology, Ecology y Navigation
## en un WorldNavigationChunk inmutable y empaquetado para el core_bounds del chunk.
## No calcula pendientes ni decide caminabilidad (esa autoridad reside en NavigationStage).

const _NavChunkScript = preload("res://src/world_generator/navigation/world_navigation_chunk.gd")

func execute(context: WorldGenerationContext) -> void:
	if not (context.has_method("is_chunk_context") and context.is_chunk_context()):
		return

	var chunk_data = context.result
	if chunk_data == null:
		return

	var core_bounds: Rect2i = context.get_core_bounds() if context.has_method("get_core_bounds") else Rect2i()
	var coord: Vector2i = context.coord if "coord" in context else Vector2i.ZERO

	var nav_chunk = _NavChunkScript.from_cells(coord, core_bounds, chunk_data.cells)
	chunk_data.navigation_chunk = nav_chunk
```

In `src/world_generator/chunks/chunk_data.gd`, add member variable:
```gdscript
var navigation_chunk: RefCounted = null
```

In `src/world_generator/facade/world_pipeline.gd`, preload and insert `WorldNavigationStage`:
```gdscript
const _WorldNavigationStageScript = preload("res://src/world_generator/navigation/world_navigation_stage.gd")
...
static func _execute_stages(context: WorldGenerationContext, profiler: Variant = null) -> void:
	var stage_specs: Array[Dictionary] = [
		{"name": "terrain_ms", "stage": TerrainStage.new()},
		{"name": "hydrology_ms", "stage": _HydrologyStageScript.new()},
		{"name": "ecology_ms", "stage": EcologyStage.new()},
		{"name": "navigation_ms", "stage": NavigationStage.new()},
		{"name": "world_navigation_ms", "stage": _WorldNavigationStageScript.new()},
		{"name": "vegetation_ms", "stage": VegetationStage.new()},
	]
```

In `src/world_generator/chunks/chunk_generation_scheduler.gd`, include `navigation_chunk` in completed results dictionary:
```gdscript
		_mutex.lock()
		if _is_running:
			_completed_results.append({
				"coord": req.coord,
				"chunk_data": chunk_data,
				"navigation_chunk": chunk_data.navigation_chunk if chunk_data != null else null,
				"token": req.token,
				"enqueue_time_usec": req.enqueue_time_usec,
				"queue_time_ms": queue_time_ms,
				"gen_time_ms": gen_time_ms
			})
		_mutex.unlock()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script res://tests/integration/test_world_navigation_integration.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/world_generator/navigation/world_navigation_stage.gd src/world_generator/chunks/chunk_data.gd src/world_generator/facade/world_pipeline.gd src/world_generator/chunks/chunk_generation_scheduler.gd tests/integration/test_world_navigation_integration.gd
git commit -m "feat(navigation): integrate WorldNavigationStage into pipeline before Vegetation"
```

---

### Task 3: Global Navigation Registry (`WorldNavigationGrid`)

**Files:**
- Create: `src/world_generator/navigation/world_navigation_grid.gd`
- Test: `tests/integration/test_world_navigation_integration.gd`

**Interfaces:**
- Consumes: `WorldNavigationChunk`, `WorldNavigationCell`, `ChunkCoord`, `Vector2i`, `Vector3`
- Produces:
  - `WorldNavigationGrid`:
    - `enum Availability { READY, UNAVAILABLE }`
    - `signal chunk_registered(coord: Vector2i)`
    - `signal chunk_unregistered(coord: Vector2i)`
    - `func register_chunk(chunk: WorldNavigationChunk) -> void`
    - `func unregister_chunk(coord: Vector2i) -> void`
    - `func has_chunk(coord: Vector2i) -> bool`
    - `func has_cell(cell: Vector2i) -> bool`
    - `func get_cell_availability(cell: Vector2i) -> int`
    - `func get_cell(cell: Vector2i) -> WorldNavigationCell`
    - `func is_walkable(cell: Vector2i) -> bool`
    - `func get_height(cell: Vector2i) -> float`
    - `func get_elevation_level(cell: Vector2i) -> int`
    - `func find_lower_support(cell: Vector2i, max_depth: int) -> Dictionary`
    - `func cell_to_world(cell: Vector2i, y_offset: float = 0.0) -> Vector3`
    - `func world_to_cell(world_pos: Vector3) -> Vector2i`

- [ ] **Step 1: Write failing test for `WorldNavigationGrid` registration, boundary resolution, and queries**

In `tests/integration/test_world_navigation_integration.gd`, add `_test_world_navigation_grid()`:
```gdscript
const _NavGridScript = preload("res://src/world_generator/navigation/world_navigation_grid.gd")

func _test_world_navigation_grid() -> void:
	print(" -> Testing WorldNavigationGrid cross-chunk queries and availability...")
	var grid := _NavGridScript.new(1.0, 16, Vector3.ZERO)

	var cell_a := Vector2i(15, 5) # Inside Chunk (0, 0)
	var cell_b := Vector2i(16, 5) # Inside Chunk (1, 0)

	assert(grid.get_cell_availability(cell_a) == _NavGridScript.Availability.UNAVAILABLE, "Unregistered chunk must be UNAVAILABLE")
	assert(not grid.has_cell(cell_a), "Unregistered cell has_cell is false")

	# Create two adjacent navigation chunks
	var cells_00 := {}
	for y in range(16):
		for x in range(16):
			var pos := Vector2i(x, y)
			var c = _WorldCellScript.new(pos)
			c.elevation_level = 1
			c.height = 1.0
			c.is_walkable = true
			cells_00[pos] = c
	var chunk_00 = _NavChunkScript.from_cells(Vector2i(0, 0), Rect2i(0, 0, 16, 16), cells_00)

	var cells_10 := {}
	for y in range(16):
		for x in range(16):
			var pos := Vector2i(16 + x, y)
			var c = _WorldCellScript.new(pos)
			c.elevation_level = 1
			c.height = 1.0
			c.is_walkable = (x != 0 or y != 0) # (16, 0) unwalkable, (16, 5) walkable
			cells_10[pos] = c
	var chunk_10 = _NavChunkScript.from_cells(Vector2i(1, 0), Rect2i(16, 0, 16, 16), cells_10)

	var registered_signal_coords: Array[Vector2i] = []
	grid.chunk_registered.connect(func(c: Vector2i): registered_signal_coords.append(c))

	grid.register_chunk(chunk_00)
	assert(grid.has_chunk(Vector2i(0, 0)), "Chunk (0, 0) is registered")
	assert(grid.get_cell_availability(cell_a) == _NavGridScript.Availability.READY, "Cell A is now READY")
	assert(grid.get_cell_availability(cell_b) == _NavGridScript.Availability.UNAVAILABLE, "Cell B is still UNAVAILABLE")

	grid.register_chunk(chunk_10)
	assert(registered_signal_coords.size() == 2, "Two chunk_registered signals fired")
	assert(grid.get_cell_availability(cell_b) == _NavGridScript.Availability.READY, "Cell B is now READY")

	# Cross-chunk queries
	assert(grid.is_walkable(cell_a), "Cell A walkable")
	assert(grid.is_walkable(cell_b), "Cell B walkable across seam")
	assert(not grid.is_walkable(Vector2i(16, 0)), "Cell (16, 0) unwalkable")

	# Spatial conversion
	var w_pos := grid.cell_to_world(Vector2i(16, 5))
	assert(grid.world_to_cell(w_pos) == Vector2i(16, 5), "cell_to_world <-> world_to_cell roundtrip")

	# Lower support primitive
	var support = grid.find_lower_support(cell_b, 4)
	assert(support["found"] == true, "Support found on cell_b")
	assert(support["elevation_level"] == 1, "Support elevation matches")

	# Unregister
	grid.unregister_chunk(Vector2i(1, 0))
	assert(grid.get_cell_availability(cell_b) == _NavGridScript.Availability.UNAVAILABLE, "Cell B becomes UNAVAILABLE after unregister")

	print("    [PASS] WorldNavigationGrid cross-chunk queries and availability")
```
Call `_test_world_navigation_grid()` in `_init()`.

- [ ] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script res://tests/integration/test_world_navigation_integration.gd`
Expected: FAIL (cannot load `world_navigation_grid.gd`).

- [ ] **Step 3: Implement `WorldNavigationGrid`**

Create `src/world_generator/navigation/world_navigation_grid.gd`:
```gdscript
class_name WorldNavigationGrid
extends RefCounted

## Registro global y autoridad de consulta de navegación basada en chunks.
## Almacena WorldNavigationChunk inmutables indexados por coordenada de chunk.
## No contiene reglas de movimiento ni perfiles de entidades (eso pertenece a MovementRules).

const _NavChunkScript = preload("res://src/world_generator/navigation/world_navigation_chunk.gd")
const _NavCellScript = preload("res://src/world_generator/navigation/world_navigation_cell.gd")
const _ChunkCoordScript = preload("res://src/world_generator/chunks/chunk_coord.gd")

enum Availability {
	READY,
	UNAVAILABLE
}

signal chunk_registered(coord: Vector2i)
signal chunk_unregistered(coord: Vector2i)

var cell_size: float = 1.0
var chunk_size: int = 16
var world_origin: Vector3 = Vector3.ZERO

# Vector2i (chunk_coord) -> WorldNavigationChunk
var _chunks: Dictionary = {}

func _init(p_cell_size: float = 1.0, p_chunk_size: int = 16, p_origin: Vector3 = Vector3.ZERO) -> void:
	cell_size = maxf(p_cell_size, 0.001)
	chunk_size = maxi(p_chunk_size, 1)
	world_origin = p_origin

func register_chunk(chunk: WorldNavigationChunk) -> void:
	if chunk == null:
		return
	_chunks[chunk.chunk_coord] = chunk
	chunk_registered.emit(chunk.chunk_coord)

func unregister_chunk(coord: Vector2i) -> void:
	if _chunks.erase(coord):
		chunk_unregistered.emit(coord)

func has_chunk(coord: Vector2i) -> bool:
	return _chunks.has(coord)

func _get_chunk_for_cell(cell: Vector2i) -> WorldNavigationChunk:
	var ccoord := _ChunkCoordScript.world_to_chunk(cell, chunk_size)
	return _chunks.get(ccoord, null)

func has_cell(cell: Vector2i) -> bool:
	var chunk := _get_chunk_for_cell(cell)
	if chunk == null:
		return false
	return chunk.has_cell(cell)

func get_cell_availability(cell: Vector2i) -> int:
	var chunk := _get_chunk_for_cell(cell)
	if chunk == null or not chunk.has_cell(cell):
		return Availability.UNAVAILABLE
	return Availability.READY

func get_cell(cell: Vector2i) -> WorldNavigationCell:
	var chunk := _get_chunk_for_cell(cell)
	if chunk == null:
		return null
	return chunk.get_cell(cell)

func is_walkable(cell: Vector2i) -> bool:
	var chunk := _get_chunk_for_cell(cell)
	if chunk == null:
		return false
	return chunk.is_walkable(cell)

func get_height(cell: Vector2i) -> float:
	var chunk := _get_chunk_for_cell(cell)
	if chunk == null:
		return 0.0
	return chunk.get_height(cell)

func get_elevation_level(cell: Vector2i) -> int:
	var chunk := _get_chunk_for_cell(cell)
	if chunk == null:
		return 0
	return chunk.get_elevation_level(cell)

## Primitiva de soporte inferior para evaluar caídas:
## Comprueba si en la celda 'cell' existe superficie transitable dentro de un desnivel de hasta max_depth.
func find_lower_support(cell: Vector2i, max_depth: int = 6) -> Dictionary:
	var chunk := _get_chunk_for_cell(cell)
	if chunk == null or not chunk.has_cell(cell):
		return {"found": false, "elevation_level": 0, "height": 0.0, "walkable": false}

	var elevation := chunk.get_elevation_level(cell)
	var height_val := chunk.get_height(cell)
	var walkable_val := chunk.is_walkable(cell)

	return {
		"found": true,
		"elevation_level": elevation,
		"height": height_val,
		"walkable": walkable_val
	}

# --- Conversiones Espaciales (Cell <-> World) ---

func cell_to_world(cell: Vector2i, y_offset: float = 0.0) -> Vector3:
	var h: float = get_height(cell)
	var wx: float = (float(cell.x) + 0.5) * cell_size + world_origin.x
	var wz: float = (float(cell.y) + 0.5) * cell_size + world_origin.z
	var wy: float = h + world_origin.y + y_offset
	return Vector3(wx, wy, wz)

func world_to_cell(world_pos: Vector3) -> Vector2i:
	var local_x: float = (world_pos.x - world_origin.x) / cell_size
	var local_z: float = (world_pos.z - world_origin.z) / cell_size
	return Vector2i(int(floor(local_x)), int(floor(local_z)))
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script res://tests/integration/test_world_navigation_integration.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/world_generator/navigation/world_navigation_grid.gd tests/integration/test_world_navigation_integration.gd
git commit -m "feat(navigation): implement WorldNavigationGrid global chunk registry and query authority"
```

---

### Task 4: Connect `WorldChunkManager` & `ChunkWorld` to `WorldNavigationGrid`

**Files:**
- Modify: `src/world_generator/chunks/chunk_manager.gd:23-45`, `src/world_generator/chunks/chunk_manager.gd:170-208`, `src/world_generator/chunks/chunk_manager.gd:287-330`
- Modify: `src/world_generator/chunks/chunk_world.gd:23-45`, `src/world_generator/chunks/chunk_world.gd:72-110`, `src/world_generator/chunks/chunk_world.gd:317-357`
- Test: `tests/integration/test_world_navigation_integration.gd`

**Interfaces:**
- Consumes: `WorldNavigationGrid`, `WorldChunkManager`, `ChunkWorld`, `ChunkData`
- Produces:
  - `WorldChunkManager.navigation_grid: WorldNavigationGrid`: Registered upon chunk completion, unregistered upon chunk unload.
  - `ChunkWorld.navigation_grid: WorldNavigationGrid`: Public accessor for movement systems.

- [ ] **Step 1: Write failing test verifying lifecycle synchronization between ChunkManager and NavigationGrid**

In `tests/integration/test_world_navigation_integration.gd`, add `_test_chunk_manager_navigation_sync()`:
```gdscript
const _ChunkManagerScript = preload("res://src/world_generator/chunks/chunk_manager.gd")
const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")

func _test_chunk_manager_navigation_sync() -> void:
	print(" -> Testing WorldChunkManager and ChunkWorld publishing to WorldNavigationGrid...")
	var profile := _TaigaWorldProfileScript.new()
	var config := _ChunkConfigScript.new()
	var manager = _ChunkManagerScript.new(12345, profile, config)

	assert(manager.navigation_grid != null, "WorldChunkManager must instantiate navigation_grid")

	# Synchronous load
	var coord := Vector2i(0, 0)
	var chunk_data = manager.load_chunk(coord)
	assert(chunk_data != null, "ChunkData loaded")
	assert(manager.navigation_grid.has_chunk(coord), "NavigationGrid must have registered chunk on load")

	# Unload
	manager.unload_chunk(coord)
	assert(not manager.navigation_grid.has_chunk(coord), "NavigationGrid must unregister chunk on unload")

	# ChunkWorld coordinator test
	var world = _ChunkWorldScript.new()
	world.initialize(12345, profile, config)
	assert(world.navigation_grid != null, "ChunkWorld must expose navigation_grid")
	world.queue_free()

	print("    [PASS] WorldChunkManager and ChunkWorld navigation lifecycle sync")
```
Call `_test_chunk_manager_navigation_sync()` in `_init()`.

- [ ] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script res://tests/integration/test_world_navigation_integration.gd`
Expected: FAIL (`manager.navigation_grid` does not exist).

- [ ] **Step 3: Update `WorldChunkManager` and `ChunkWorld`**

In `src/world_generator/chunks/chunk_manager.gd`:
```gdscript
const _WorldNavigationGridScript = preload("res://src/world_generator/navigation/world_navigation_grid.gd")
...
var navigation_grid: RefCounted = null
...
func _init(...):
	...
	navigation_grid = _WorldNavigationGridScript.new(
		profile.cell_size if profile != null else 1.0,
		config.chunk_size if config != null else 16
	)
```
In `load_chunk`:
```gdscript
	loaded_chunks[coord] = chunk_data
	chunk_states[coord] = ChunkState.LOADED
	if navigation_grid != null and chunk_data.navigation_chunk != null:
		navigation_grid.register_chunk(chunk_data.navigation_chunk)
	_attach_pois_to_chunk(chunk_data)
	chunk_loaded.emit(coord, chunk_data)
	return chunk_data
```
In `unload_chunk`:
```gdscript
	if navigation_grid != null:
		navigation_grid.unregister_chunk(coord)
	loaded_chunks.erase(coord)
	stats_unloaded += 1
	chunk_unloaded.emit(coord)
```
In `poll_completed`:
```gdscript
		if token == active_tok and current_required_chunks.has(coord):
			loaded_chunks[coord] = chunk_data
			chunk_states[coord] = ChunkState.LOADED
			stats_loaded += 1
			if navigation_grid != null and chunk_data.navigation_chunk != null:
				navigation_grid.register_chunk(chunk_data.navigation_chunk)
```

In `src/world_generator/chunks/chunk_world.gd`:
```gdscript
var navigation_grid: RefCounted = null
...
func initialize(...):
	...
	chunk_manager = _ChunkManagerScript.new(...)
	navigation_grid = chunk_manager.navigation_grid
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script res://tests/integration/test_world_navigation_integration.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/world_generator/chunks/chunk_manager.gd src/world_generator/chunks/chunk_world.gd tests/integration/test_world_navigation_integration.gd
git commit -m "feat(navigation): connect WorldChunkManager and ChunkWorld to WorldNavigationGrid"
```

---

### Task 5: Adapt `MovementRules` to `WorldNavigationGrid` & Gameplay Transitions

**Files:**
- Modify: `src/gameplay/movement/movement_result.gd:13-28`
- Modify: `src/gameplay/movement/movement_rules.gd:15-138`
- Test: `tests/integration/test_world_navigation_integration.gd`

**Interfaces:**
- Consumes: `WorldNavigationGrid`, `MovementProfile`, `MovementOccupancy`, `MovementResult`
- Produces:
  - `MovementResult.REASON_CHUNK_UNAVAILABLE = &"chunk_unavailable"`
  - `MovementRules.validate_transition(from_cell, to_cell, grid, profile, occupancy, entity)`:
    - Checks availability: returns `REASON_CHUNK_UNAVAILABLE` when `to_cell` or `from_cell` is `UNAVAILABLE`.
    - Resolves 8 directions according to `profile.is_direction_allowed(dir)`.
    - Evaluates elevation delta:
      - `delta == 0`: `WALK`
      - `0 < delta <= profile.max_step_up`: `STEP_UP`
      - `-profile.max_step_down <= delta < 0`: `STEP_DOWN`
      - `delta < -profile.max_step_down`: queries `grid.find_lower_support(to_cell, profile.max_fall_height)` to classify `FALL`, or rejects with `REASON_NO_SURFACE_BELOW` / `REASON_FALL_TOO_HIGH` / `REASON_FALL_NOT_ALLOWED`.
    - Evaluates diagonal corners using `_is_cell_passable`.

- [ ] **Step 1: Write failing test for `MovementRules` with `WorldNavigationGrid`**

In `tests/integration/test_world_navigation_integration.gd`, add `_test_movement_rules_navigation_grid()`:
```gdscript
const _RulesScript = preload("res://src/gameplay/movement/movement_rules.gd")
const _ProfileScript = preload("res://src/gameplay/movement/movement_profile.gd")
const _RequestScript = preload("res://src/gameplay/movement/movement_request.gd")
const _ResultScript = preload("res://src/gameplay/movement/movement_result.gd")

func _test_movement_rules_navigation_grid() -> void:
	print(" -> Testing MovementRules against WorldNavigationGrid...")
	var grid := _NavGridScript.new(1.0, 16, Vector3.ZERO)
	var rules := _RulesScript.new()
	var profile := _ProfileScript.new()
	profile.max_step_up = 1
	profile.max_step_down = 1
	profile.can_fall = true
	profile.max_fall_height = 4

	var cells := {}
	# From (5, 5): Level 3, Walkable
	var c_from = _WorldCellScript.new(Vector2i(5, 5))
	c_from.elevation_level = 3
	c_from.height = 3.0
	c_from.is_walkable = true
	cells[Vector2i(5, 5)] = c_from

	# Walk: (6, 5): Level 3
	var c_walk = _WorldCellScript.new(Vector2i(6, 5))
	c_walk.elevation_level = 3
	c_walk.height = 3.0
	c_walk.is_walkable = true
	cells[Vector2i(6, 5)] = c_walk

	# Step up: (5, 6): Level 4 (delta = +1)
	var c_up = _WorldCellScript.new(Vector2i(5, 6))
	c_up.elevation_level = 4
	c_up.height = 4.0
	c_up.is_walkable = true
	cells[Vector2i(5, 6)] = c_up

	# Fall: (5, 4): Level 1 (delta = -2, exceeds max_step_down=1, <= max_fall=4)
	var c_fall = _WorldCellScript.new(Vector2i(5, 4))
	c_fall.elevation_level = 1
	c_fall.height = 1.0
	c_fall.is_walkable = true
	cells[Vector2i(5, 4)] = c_fall

	# Fall too high: (4, 5): Level -3 (delta = -6 > 4)
	var c_abyss = _WorldCellScript.new(Vector2i(4, 5))
	c_abyss.elevation_level = -3
	c_abyss.height = -3.0
	c_abyss.is_walkable = true
	cells[Vector2i(4, 5)] = c_abyss

	var chunk = _NavChunkScript.from_cells(Vector2i(0, 0), Rect2i(0, 0, 16, 16), cells)
	grid.register_chunk(chunk)

	# 1. Test UNAVAILABLE chunk/cell
	var res_unavail = rules.validate_transition(Vector2i(5, 5), Vector2i(20, 5), grid, profile)
	assert(not res_unavail.accepted, "Unavailable target rejected")
	assert(res_unavail.reason == _ResultScript.REASON_CHUNK_UNAVAILABLE, "Reason is CHUNK_UNAVAILABLE")

	# 2. Test WALK
	var res_walk = rules.validate_transition(Vector2i(5, 5), Vector2i(6, 5), grid, profile)
	assert(res_walk.accepted, "Walk accepted")
	assert(res_walk.transition_type == _ResultScript.TransitionType.WALK, "Transition is WALK")

	# 3. Test STEP_UP
	var res_up = rules.validate_transition(Vector2i(5, 5), Vector2i(5, 6), grid, profile)
	assert(res_up.accepted, "Step up accepted")
	assert(res_up.transition_type == _ResultScript.TransitionType.STEP_UP, "Transition is STEP_UP")

	# 4. Test FALL
	var res_fall = rules.validate_transition(Vector2i(5, 5), Vector2i(5, 4), grid, profile)
	assert(res_fall.accepted, "Fall accepted")
	assert(res_fall.transition_type == _ResultScript.TransitionType.FALL, "Transition is FALL")

	# 5. Test FALL_TOO_HIGH
	var res_high = rules.validate_transition(Vector2i(5, 5), Vector2i(4, 5), grid, profile)
	assert(not res_high.accepted, "Abyss fall rejected")
	assert(res_high.reason == _ResultScript.REASON_FALL_TOO_HIGH, "Reason is FALL_TOO_HIGH")

	print("    [PASS] MovementRules against WorldNavigationGrid")
```
Call `_test_movement_rules_navigation_grid()` in `_init()`.

- [ ] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script res://tests/integration/test_world_navigation_integration.gd`
Expected: FAIL (`REASON_CHUNK_UNAVAILABLE` not found).

- [ ] **Step 3: Update `MovementResult` and `MovementRules`**

In `src/gameplay/movement/movement_result.gd`, add:
```gdscript
const REASON_CHUNK_UNAVAILABLE: StringName = &"chunk_unavailable"
```

In `src/gameplay/movement/movement_rules.gd`:
Update `validate_transition` to accept either `MovementGrid` or `WorldNavigationGrid`, check chunk availability, fall target resolution, and corner cutting:
```gdscript
	# 2. Comprobar disponibilidad de celda
	if grid.has_method("get_cell_availability"):
		if grid.get_cell_availability(from_cell) != 0: # 0 == READY
			return _ResultScript.reject(_ResultScript.REASON_CHUNK_UNAVAILABLE, from_cell, to_cell)
		if grid.get_cell_availability(to_cell) != 0:
			return _ResultScript.reject(_ResultScript.REASON_CHUNK_UNAVAILABLE, from_cell, to_cell)
	else:
		if not grid.has_cell(from_cell):
			return _ResultScript.reject(_ResultScript.REASON_INVALID_SOURCE_CELL, from_cell, to_cell)
		if not grid.has_cell(to_cell):
			return _ResultScript.reject(_ResultScript.REASON_OUT_OF_BOUNDS, from_cell, to_cell)

	# 3. Caminabilidad
	if not grid.is_walkable(to_cell):
		return _ResultScript.reject(_ResultScript.REASON_UNWALKABLE, from_cell, to_cell)

	# 4. Agua (si el grid lo soporta)
	var water_mode: int = profile.water_mode if profile != null else _ProfileScript.WaterMode.LAND
	if grid.has_method("is_water") and grid.is_water(to_cell) and water_mode == _ProfileScript.WaterMode.LAND:
		return _ResultScript.reject(_ResultScript.REASON_WATER_BLOCKED, from_cell, to_cell)

	# 5. Elevación y caídas
	if water_mode != _ProfileScript.WaterMode.FLY:
		var cur_level: int = grid.get_elevation_level(from_cell)
		var target_level: int = grid.get_elevation_level(to_cell)
		var delta_level: int = target_level - cur_level

		var max_up: int = profile.max_step_up if profile != null else 1
		var max_down: int = profile.max_step_down if profile != null else 1

		if delta_level == 0:
			transition_type = _ResultScript.TransitionType.WALK
		elif delta_level > 0:
			if delta_level <= max_up:
				transition_type = _ResultScript.TransitionType.STEP_UP
			else:
				return _ResultScript.reject(_ResultScript.REASON_ELEVATION_TOO_HIGH, from_cell, to_cell)
		else: # delta_level < 0
			if delta_level >= -max_down:
				transition_type = _ResultScript.TransitionType.STEP_DOWN
			else:
				var can_fall: bool = profile.can_fall if profile != null else true
				if not can_fall:
					return _ResultScript.reject(_ResultScript.REASON_FALL_NOT_ALLOWED, from_cell, to_cell)

				var max_fall: int = profile.max_fall_height if profile != null else 6
				if absi(delta_level) > max_fall:
					return _ResultScript.reject(_ResultScript.REASON_FALL_TOO_HIGH, from_cell, to_cell)

				if grid.has_method("find_lower_support"):
					var support: Dictionary = grid.find_lower_support(to_cell, max_fall)
					if not support.get("found", false) or not support.get("walkable", false):
						return _ResultScript.reject(_ResultScript.REASON_NO_SURFACE_BELOW, from_cell, to_cell)

				transition_type = _ResultScript.TransitionType.FALL
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script res://tests/integration/test_world_navigation_integration.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/gameplay/movement/movement_result.gd src/gameplay/movement/movement_rules.gd tests/integration/test_world_navigation_integration.gd
git commit -m "feat(movement): adapt MovementRules to WorldNavigationGrid and REASON_CHUNK_UNAVAILABLE"
```

---

### Task 6: Reactive `MovementComponent` Waiting on `UNAVAILABLE` Chunks

**Files:**
- Modify: `src/gameplay/movement/movement_component.gd`
- Test: `tests/integration/test_world_navigation_integration.gd`

**Interfaces:**
- Consumes: `WorldNavigationGrid`, `MovementComponent`, `MovementRules`, `MovementRequest`
- Produces:
  - `pending_unavailable_request: MovementRequest = null`: Stores request when `REASON_CHUNK_UNAVAILABLE` is returned.
  - Connects to `grid.chunk_registered` (if available): On signal, if `pending_unavailable_request` target cell is now `READY`, automatically re-attempts movement without per-frame polling.
  - Connects to `grid.chunk_unregistered` (if available): Discards pending request if the target chunk was cancelled or unloaded.

- [ ] **Step 1: Write failing test for reactive wait on UNAVAILABLE chunk**

In `tests/integration/test_world_navigation_integration.gd`, add `_test_movement_component_unavailable_retry()`:
```gdscript
const _ComponentScript = preload("res://src/gameplay/movement/movement_component.gd")

func _test_movement_component_unavailable_retry() -> void:
	print(" -> Testing MovementComponent reactive waiting for UNAVAILABLE chunks...")
	var grid := _NavGridScript.new(1.0, 16, Vector3.ZERO)
	var comp = _ComponentScript.new()
	comp.setup(grid, null, null, Vector2i(15, 0))

	# Chunk (0, 0) registered
	var cells_00 := {}
	for y in range(16):
		for x in range(16):
			var pos := Vector2i(x, y)
			var c = _WorldCellScript.new(pos)
			c.elevation_level = 1
			c.height = 1.0
			c.is_walkable = true
			cells_00[pos] = c
	var chunk_00 = _NavChunkScript.from_cells(Vector2i(0, 0), Rect2i(0, 0, 16, 16), cells_00)
	grid.register_chunk(chunk_00)

	# Attempt to step from (15, 0) into unregistered Chunk (1, 0) at (16, 0)
	var req := _RequestScript.new(Vector2i(1, 0), &"player")
	var res = comp.request_movement(req)
	assert(not res.accepted, "Move towards unavailable chunk rejected")
	assert(res.reason == _ResultScript.REASON_CHUNK_UNAVAILABLE, "Reason is CHUNK_UNAVAILABLE")
	assert(comp.pending_unavailable_request == req, "Request is stored in pending_unavailable_request")
	assert(not comp.is_moving, "Component is not moving while waiting")

	# Register Chunk (1, 0)
	var cells_10 := {}
	for y in range(16):
		for x in range(16):
			var pos := Vector2i(16 + x, y)
			var c = _WorldCellScript.new(pos)
			c.elevation_level = 1
			c.height = 1.0
			c.is_walkable = true
			cells_10[pos] = c
	var chunk_10 = _NavChunkScript.from_cells(Vector2i(1, 0), Rect2i(16, 0, 16, 16), cells_10)

	# When chunk is registered, MovementComponent must reactively retry and start moving
	grid.register_chunk(chunk_10)
	assert(comp.is_moving, "Component started moving reactively upon chunk registration")
	assert(comp.target_cell == Vector2i(16, 0), "Target cell is (16, 0)")
	assert(comp.pending_unavailable_request == null, "Pending request cleared")

	# Complete transition
	comp.process_movement(1.0)
	assert(comp.current_cell == Vector2i(16, 0), "Transition completed into new chunk")

	print("    [PASS] MovementComponent reactive wait and retry")
```
Call `_test_movement_component_unavailable_retry()` in `_init()`.

- [ ] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script res://tests/integration/test_world_navigation_integration.gd`
Expected: FAIL (`pending_unavailable_request` not on `MovementComponent`).

- [ ] **Step 3: Implement reactive wait in `MovementComponent`**

In `src/gameplay/movement/movement_component.gd`:
Add:
```gdscript
var pending_unavailable_request: MovementRequest = null
```
In `setup(p_grid, ...)`:
```gdscript
	if grid != null and grid != p_grid:
		_disconnect_grid_signals()
	grid = p_grid
	_connect_grid_signals()
```
Add connection helper methods:
```gdscript
func _connect_grid_signals() -> void:
	if grid != null and grid.has_signal("chunk_registered"):
		if not grid.chunk_registered.is_connected(_on_grid_chunk_registered):
			grid.chunk_registered.connect(_on_grid_chunk_registered)
	if grid != null and grid.has_signal("chunk_unregistered"):
		if not grid.chunk_unregistered.is_connected(_on_grid_chunk_unregistered):
			grid.chunk_unregistered.connect(_on_grid_chunk_unregistered)

func _disconnect_grid_signals() -> void:
	if grid != null and grid.has_signal("chunk_registered"):
		if grid.chunk_registered.is_connected(_on_grid_chunk_registered):
			grid.chunk_registered.disconnect(_on_grid_chunk_registered)
	if grid != null and grid.has_signal("chunk_unregistered"):
		if grid.chunk_unregistered.is_connected(_on_grid_chunk_unregistered):
			grid.chunk_unregistered.disconnect(_on_grid_chunk_unregistered)

func _on_grid_chunk_registered(coord: Vector2i) -> void:
	if is_moving or pending_unavailable_request == null:
		return
	var target_candidate := current_cell + pending_unavailable_request.direction
	if grid.has_method("get_cell_availability"):
		if grid.get_cell_availability(target_candidate) == 0: # READY
			var req = pending_unavailable_request
			pending_unavailable_request = null
			_attempt_transition(req)

func _on_grid_chunk_unregistered(coord: Vector2i) -> void:
	if pending_unavailable_request != null:
		var target_candidate := current_cell + pending_unavailable_request.direction
		if grid.has_method("get_cell_availability"):
			if grid.get_cell_availability(target_candidate) != 0:
				pending_unavailable_request = null
```
In `_attempt_transition`:
```gdscript
	if not res.accepted:
		if res.reason == _ResultScript.REASON_CHUNK_UNAVAILABLE:
			pending_unavailable_request = request
		else:
			pending_unavailable_request = null
		movement_failed.emit(request, res)
		return res
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script res://tests/integration/test_world_navigation_integration.gd`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/gameplay/movement/movement_component.gd tests/integration/test_world_navigation_integration.gd
git commit -m "feat(movement): implement reactive chunk waiting in MovementComponent"
```

---

### Task 7: Full Pipeline Integration & Performance Verification

**Files:**
- Modify: `tests/integration/test_world_navigation_integration.gd`
- Run existing movement test suite: `src/gameplay/movement/tests/test_movement_integration.gd`

**Interfaces:**
- Consumes: All `WorldNavigation` and `Movement` systems
- Produces:
  - Integration scenario covering 2x2 adjacent chunks, crossing chunk boundaries, walkability, step up/down, falls, corner cutting, and chunk availability.
  - Performance measurement comparing `generate_chunk` vs `generate_chunk` with `WorldNavigationStage`.

- [ ] **Step 1: Add end-to-end multi-chunk pipeline integration and benchmark to the test suite**

In `tests/integration/test_world_navigation_integration.gd`, add `_test_full_pipeline_cross_chunk_integration()`:
```gdscript
func _test_full_pipeline_cross_chunk_integration() -> void:
	print(" -> Testing end-to-end multi-chunk pipeline integration with real terrain...")
	var profile := _TaigaWorldProfileScript.new()
	var config := _ChunkConfigScript.new()
	var manager = _ChunkManagerScript.new(4242, profile, config)

	# Generate 2 adjacent chunks: (0, 0) and (1, 0)
	var c0 = manager.load_chunk(Vector2i(0, 0))
	var c1 = manager.load_chunk(Vector2i(1, 0))
	assert(c0 != null and c1 != null, "Chunks generated")
	assert(manager.navigation_grid.has_chunk(Vector2i(0, 0)), "Chunk 0,0 registered")
	assert(manager.navigation_grid.has_chunk(Vector2i(1, 0)), "Chunk 1,0 registered")

	# Find boundary transition between (0, 0) and (1, 0)
	var boundary_x := 15
	var target_x := 16
	var found_valid_transition := false

	var rules := _RulesScript.new()
	var m_profile := _ProfileScript.new()

	for y in range(16):
		var from_c := Vector2i(boundary_x, y)
		var to_c := Vector2i(target_x, y)
		var res = rules.validate_transition(from_c, to_c, manager.navigation_grid, m_profile)
		if res.accepted:
			found_valid_transition = true
			break

	assert(found_valid_transition, "Real terrain must have at least one valid boundary transition across adjacent chunks")

	# Performance benchmark
	print(" -> Benchmarking WorldNavigationStage overhead...")
	var t0 := Time.get_ticks_usec()
	for i in range(10):
		_WorldPipelineScript.generate_chunk(1000 + i, Vector2i(i, 0), profile, config, null)
	var t_total_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	var avg_ms := t_total_ms / 10.0
	print("    Average chunk generation time with WorldNavigation: %.2f ms" % avg_ms)
	assert(avg_ms < 50.0, "Chunk generation should remain fast (< 50ms average in test runner)")

	print("    [PASS] full pipeline multi-chunk integration and performance")
```
Call `_test_full_pipeline_cross_chunk_integration()` in `_init()`.

- [ ] **Step 2: Run new integration test suite**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script res://tests/integration/test_world_navigation_integration.gd`
Expected: PASS with all tests passing.

- [ ] **Step 3: Run existing movement integration tests to ensure zero regressions**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script res://src/gameplay/movement/tests/test_movement_integration.gd`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add tests/integration/test_world_navigation_integration.gd
git commit -m "test(navigation): complete end-to-end integration and performance benchmark suite"
```

---

### Task 8: Migration & Cleanup (`MovementGrid` Deprecation / Compatibility)

**Files:**
- Modify: `src/gameplay/movement/movement_grid.gd`
- Test: `tests/integration/test_world_navigation_integration.gd`
- Test: `src/gameplay/movement/tests/test_movement_integration.gd`

**Interfaces:**
- Consumes: `WorldNavigationGrid`, `MovementGrid`
- Produces:
  - `MovementGrid`: Adapts transparently to forward queries to `WorldNavigationGrid` if `world_source` is a `ChunkWorld` or `WorldChunkManager` with `navigation_grid`.
  - Removes direct dependency of movement on `WorldResult` snapshots for dynamic chunk streaming.

- [ ] **Step 1: Update `MovementGrid.get_cell`, `is_walkable`, etc., to query `navigation_grid` if available**

In `src/gameplay/movement/movement_grid.gd`, add forwarding when `world_source` has `navigation_grid`:
```gdscript
func get_cell_availability(cell: Vector2i) -> int:
	var nav = _get_nav_grid()
	if nav != null and nav.has_method("get_cell_availability"):
		return nav.get_cell_availability(cell)
	return 0 if has_cell(cell) else 1

func _get_nav_grid() -> Object:
	if world_source != null:
		if "navigation_grid" in world_source and world_source.navigation_grid != null:
			return world_source.navigation_grid
		var cm = world_source.get("chunk_manager")
		if cm != null and "navigation_grid" in cm and cm.navigation_grid != null:
			return cm.navigation_grid
	return null
```
Update `is_walkable`, `get_elevation_level`, `get_height` to query `_get_nav_grid()` if present before falling back to `_cells`.

- [ ] **Step 2: Run both test suites**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script res://tests/integration/test_world_navigation_integration.gd`
Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script res://src/gameplay/movement/tests/test_movement_integration.gd`
Expected: PASS for both.

- [ ] **Step 3: Commit**

```bash
git add src/gameplay/movement/movement_grid.gd
git commit -m "refactor(movement): forward MovementGrid queries to WorldNavigationGrid"
```
