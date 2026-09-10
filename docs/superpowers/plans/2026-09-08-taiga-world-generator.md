# Taiga World Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a modular, deterministic world generator pipeline that transforms a single World Seed into a fully navigable 128x128 Taiga 3D world with cohesive terrain, ecology fields, vegetation distribution, walkability analysis, and a decoupled 3D renderer.

**Architecture:** Pure data-driven pipeline structured as `World Generator -> DATA (WorldResult) -> World Renderer -> GODOT SceneTree`. The generator core (`src/world_generator/`) contains zero `Node3D`, mesh, or presentation dependencies, operating exclusively with `RefCounted` objects, deterministic PRNG seed derivation, FastNoiseLite fields, and discrete stages (`TerrainStage`, `EcologyStage`, `VegetationStage`, `NavigationStage`). The presentation layer (`src/world_renderer/`) consumes the immutable `WorldResult` to generate terrain meshes and MultiMeshInstance3D vegetation.

**Tech Stack:** Godot 4.6.1 GDScript (static typing), FastNoiseLite (simplex/perlin + domain warp), ArrayMesh, MultiMeshInstance3D, headless SceneTree test harnesses.

**Spec:** User specification for Taiga World Generation (Phase 1):
- Dimensions: 128x128 cells.
- Exact 20-step execution order covering 15 blocks: Directory & Architecture, Core Contracts, Seed System, WorldProfile, TaigaWorldProfile, TerrainStage, Terrain Tests, Visual Calibration, EcologyStage, Ecology Calibration, VegetationStage, Deterministic Placement, Navigation/Walkability, WorldResult, WorldValidator, WorldRenderer, Floor Tile/Mesh Integration, Playable Taiga Scene, Visual Polish, Final Contract Tests.
- Explicitly excluded: second biome, chunks, infinite streaming, weather, seasons, rivers, cities, NPCs, quests, dungeon generation.

## Global Constraints

- GDScript static typing enabled across all classes.
- Zero Node/Node3D/SceneTree dependencies inside `src/world_generator/` (except headless test harnesses in `tests/`).
- Master seed hierarchical derivation: no shared global state; changes to vegetation parameters do not mutate terrain topology.
- Pure determinism: `generate(seed, profile)` with the same inputs produces byte-for-byte identical `WorldResult`.
- All tests must pass cleanly in headless mode via `Godot_v4.6.1-stable_win64_console.exe --headless -s`.

---

### Task 1: Directory Structure & Core Contracts Scaffold

**Files:**
- Create: `src/world_generator/core/world_stage.gd`
- Create: `src/world_generator/core/world_generation_context.gd`
- Create: `src/world_generator/data/world_cell.gd`
- Create: `src/world_generator/data/world_result.gd`
- Create: `src/world_generator/config/world_profile.gd`
- Create: `src/world_generator/facade/world_pipeline.gd`
- Test: `src/world_generator/tests/test_world_contracts.gd`

**Interfaces:**
- Consumes: None
- Produces:
  - `WorldGenerationContext`: holds `master_seed: int`, `profile: WorldProfile`, `data: Dictionary`
  - `WorldCell`: holds `position: Vector2i`, `height: float`, `normalized_height: float`, `slope: float`, `is_walkable: bool`
  - `WorldResult`: holds `dimensions: Vector2i`, `master_seed: int`, `cells: Dictionary`, `vegetation: Array`, `spawn_position: Vector3`, `metadata: Dictionary`
  - `WorldStage`: base class with virtual `execute(context: WorldGenerationContext) -> void`
  - `WorldPipeline`: `generate(seed: int, profile: WorldProfile) -> WorldResult`

- [ ] **Step 1: Write the failing contract test**

```gdscript
# src/world_generator/tests/test_world_contracts.gd
extends SceneTree

func _init() -> void:
	var profile := WorldProfile.new()
	profile.width = 128
	profile.height = 128
	var result := WorldPipeline.generate(12345, profile)
	assert(result != null, "WorldResult must not be null")
	assert(result.dimensions == Vector2i(128, 128), "Dimensions must match profile")
	assert(result.master_seed == 12345, "Master seed must match")
	print("test_world_contracts: OK")
	quit()
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_world_contracts.gd"
```
Expected: FAIL (classes not defined).

- [ ] **Step 3: Implement core contract classes and minimal pipeline**

Create:
- `src/world_generator/config/world_profile.gd`:
```gdscript
class_name WorldProfile
extends RefCounted

var width: int = 128
var height: int = 128
var cell_size: float = 1.0
```

- `src/world_generator/data/world_cell.gd`:
```gdscript
class_name WorldCell
extends RefCounted

var position: Vector2i
var height: float = 0.0
var normalized_height: float = 0.0
var slope: float = 0.0
var slope_category: int = 0
var is_walkable: bool = true

# Ecology
var forest_density: float = 0.0
var clearing_density: float = 0.0
var moisture: float = 0.0

func _init(p_pos: Vector2i = Vector2i.ZERO) -> void:
	position = p_pos
```

- `src/world_generator/data/world_result.gd`:
```gdscript
class_name WorldResult
extends RefCounted

var dimensions: Vector2i = Vector2i.ZERO
var master_seed: int = 0
var cells: Dictionary = {}  # Vector2i -> WorldCell
var vegetation: Array = []  # Array[WorldVegetationItem]
var spawn_position: Vector3 = Vector3.ZERO
var metadata: Dictionary = {}

func get_cell(pos: Vector2i) -> WorldCell:
	return cells.get(pos, null)

func has_cell(pos: Vector2i) -> bool:
	return cells.has(pos)
```

- `src/world_generator/core/world_stage.gd`:
```gdscript
class_name WorldStage
extends RefCounted

func execute(_context: WorldGenerationContext) -> void:
	pass
```

- `src/world_generator/core/world_generation_context.gd`:
```gdscript
class_name WorldGenerationContext
extends RefCounted

var master_seed: int
var profile: WorldProfile
var result: WorldResult

func _init(p_seed: int, p_profile: WorldProfile) -> void:
	master_seed = p_seed
	profile = p_profile
	result = WorldResult.new()
	result.master_seed = p_seed
	result.dimensions = Vector2i(p_profile.width, p_profile.height)
	for y in range(p_profile.height):
		for x in range(p_profile.width):
			var pos := Vector2i(x, y)
			result.cells[pos] = WorldCell.new(pos)
```

- `src/world_generator/facade/world_pipeline.gd`:
```gdscript
class_name WorldPipeline
extends RefCounted

static func generate(seed_val: int, profile: WorldProfile) -> WorldResult:
	var context := WorldGenerationContext.new(seed_val, profile)
	return context.result
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_world_contracts.gd"
```
Expected: PASS (`test_world_contracts: OK`).

---

### Task 2: Hierarchical World Seed System

**Files:**
- Create: `src/world_generator/data/world_seed_system.gd`
- Test: `src/world_generator/tests/test_world_seed_system.gd`

**Interfaces:**
- Consumes: None
- Produces:
  - `WorldSeedSystem.derive_seed(master_seed: int, domain: String, index: int = 0) -> int`
  - Constants: `DOMAIN_TERRAIN`, `DOMAIN_ECOLOGY`, `DOMAIN_VEGETATION`, `DOMAIN_POI`

- [ ] **Step 1: Write failing test for seed system**

```gdscript
# src/world_generator/tests/test_world_seed_system.gd
extends SceneTree

func _init() -> void:
	var seed_1 := WorldSeedSystem.derive_seed(12345, WorldSeedSystem.DOMAIN_TERRAIN)
	var seed_2 := WorldSeedSystem.derive_seed(12345, WorldSeedSystem.DOMAIN_TERRAIN)
	assert(seed_1 == seed_2, "Same master seed and domain must produce identical child seed")

	var seed_eco := WorldSeedSystem.derive_seed(12345, WorldSeedSystem.DOMAIN_ECOLOGY)
	assert(seed_1 != seed_eco, "Different domains must produce distinct seeds")

	var seed_other_master := WorldSeedSystem.derive_seed(99999, WorldSeedSystem.DOMAIN_TERRAIN)
	assert(seed_1 != seed_other_master, "Different master seeds must produce distinct child seeds")

	print("test_world_seed_system: OK")
	quit()
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_world_seed_system.gd"
```
Expected: FAIL.

- [ ] **Step 3: Implement WorldSeedSystem**

Create `src/world_generator/data/world_seed_system.gd`:
```gdscript
class_name WorldSeedSystem
extends RefCounted

const VERSION_TAG: String = "world_v1"

const DOMAIN_TERRAIN: String = "terrain"
const DOMAIN_ECOLOGY: String = "ecology"
const DOMAIN_VEGETATION: String = "vegetation"
const DOMAIN_POI: String = "poi"

static func derive_seed(master_seed: int, domain: String, index: int = 0) -> int:
	var hash_input: String = "%s:%d:%s:%d" % [VERSION_TAG, master_seed, domain, index]
	return int(hash_input.hash()) & 0x7FFFFFFF
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_world_seed_system.gd"
```
Expected: PASS (`test_world_seed_system: OK`).

---

### Task 3: Configurable WorldProfile & TaigaWorldProfile

**Files:**
- Modify: `src/world_generator/config/world_profile.gd`
- Create: `src/world_generator/profiles/taiga_world_profile.gd`
- Test: `src/world_generator/tests/test_world_profile.gd`

**Interfaces:**
- Consumes: `WorldProfile`
- Produces:
  - `TaigaWorldProfile`: rich parameter set for macro/medium/detail noise, domain warp, ecology thresholds, vegetation densities, and navigation limits.

- [ ] **Step 1: Write test validating TaigaWorldProfile defaults**

```gdscript
# src/world_generator/tests/test_world_profile.gd
extends SceneTree

func _init() -> void:
	var profile := TaigaWorldProfile.new()
	assert(profile.width == 128)
	assert(profile.height == 128)
	assert(profile.macro_frequency > 0.0)
	assert(profile.height_scale > 0.0)
	assert(profile.max_walkable_slope > 0.0)
	assert(profile.tree_density >= 0.0 and profile.tree_density <= 1.0)
	print("test_world_profile: OK")
	quit()
```

- [ ] **Step 2: Implement full parameter set in WorldProfile and TaigaWorldProfile**

In `src/world_generator/config/world_profile.gd`:
```gdscript
class_name WorldProfile
extends RefCounted

# Dimensions
var width: int = 128
var height: int = 128
var cell_size: float = 1.0

# Terrain Noise
var macro_frequency: float = 0.015
var macro_strength: float = 12.0
var medium_frequency: float = 0.045
var medium_strength: float = 4.0
var detail_frequency: float = 0.12
var detail_strength: float = 1.2
var base_height: float = 2.0
var height_scale: float = 1.0

# Domain Warp
var warp_enabled: bool = true
var warp_frequency: float = 0.02
var warp_strength: float = 15.0

# Ecology
var forest_frequency: float = 0.03
var clearing_threshold: float = 0.42
var moisture_frequency: float = 0.025

# Vegetation
var tree_density: float = 0.65
var shrub_density: float = 0.40
var rock_density: float = 0.15
var min_tree_spacing: float = 2.2

# Navigation
var max_walkable_slope: float = 35.0  # degrees
```

In `src/world_generator/profiles/taiga_world_profile.gd`:
```gdscript
class_name TaigaWorldProfile
extends WorldProfile

func _init() -> void:
	width = 128
	height = 128
	cell_size = 1.0
	
	# Taiga terrain: rolling hills, wide valleys, moderate vertical relief
	macro_frequency = 0.012
	macro_strength = 14.0
	medium_frequency = 0.035
	medium_strength = 5.0
	detail_frequency = 0.10
	detail_strength = 1.0
	base_height = 1.5
	height_scale = 1.0
	
	warp_enabled = true
	warp_frequency = 0.018
	warp_strength = 18.0
	
	# Ecology: dense boreal evergreen forests broken by open peat/moss clearings
	forest_frequency = 0.025
	clearing_threshold = 0.45
	moisture_frequency = 0.02
	
	# Vegetation: high conifer presence, dispersed shrubs and granite rocks
	tree_density = 0.70
	shrub_density = 0.45
	rock_density = 0.20
	min_tree_spacing = 2.0
	max_walkable_slope = 35.0
```

- [ ] **Step 3: Run test to verify it passes**

Run:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_world_profile.gd"
```
Expected: PASS (`test_world_profile: OK`).

---

### Task 4: Terrain Stage (Noise, Domain Warp, Height Shaping, Slope)

**Files:**
- Create: `src/world_generator/stages/terrain_stage.gd`
- Test: `src/world_generator/tests/test_terrain_stage.gd`

**Interfaces:**
- Consumes: `WorldGenerationContext`, `WorldSeedSystem`, `TaigaWorldProfile`
- Produces: Populates `height`, `normalized_height`, `slope`, and `slope_category` for every `WorldCell`.

- [ ] **Step 1: Write failing test for TerrainStage**

```gdscript
# src/world_generator/tests/test_terrain_stage.gd
extends SceneTree

func _init() -> void:
	var profile := TaigaWorldProfile.new()
	var context := WorldGenerationContext.new(12345, profile)
	var stage := TerrainStage.new()
	stage.execute(context)

	var cell_00 := context.result.get_cell(Vector2i(0, 0))
	assert(cell_00 != null)
	assert(not is_nan(cell_00.height))
	assert(cell_00.slope >= 0.0 and cell_00.slope <= 90.0)

	# Determinism check
	var context2 := WorldGenerationContext.new(12345, profile)
	stage.execute(context2)
	var cell_00_b := context2.result.get_cell(Vector2i(0, 0))
	assert(cell_00.height == cell_00_b.height, "Heights must be strictly deterministic")
	assert(cell_00.slope == cell_00_b.slope, "Slopes must be strictly deterministic")

	print("test_terrain_stage: OK")
	quit()
```

- [ ] **Step 2: Implement TerrainStage**

In `src/world_generator/stages/terrain_stage.gd`:
```gdscript
class_name TerrainStage
extends WorldStage

func execute(context: WorldGenerationContext) -> void:
	var profile: WorldProfile = context.profile
	var terrain_seed: int = WorldSeedSystem.derive_seed(context.master_seed, WorldSeedSystem.DOMAIN_TERRAIN)

	var macro_noise := FastNoiseLite.new()
	macro_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	macro_noise.seed = terrain_seed
	macro_noise.frequency = profile.macro_frequency

	var medium_noise := FastNoiseLite.new()
	medium_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	medium_noise.seed = terrain_seed + 101
	medium_noise.frequency = profile.medium_frequency

	var detail_noise := FastNoiseLite.new()
	detail_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	detail_noise.seed = terrain_seed + 202
	detail_noise.frequency = profile.detail_frequency

	var warp_noise_x := FastNoiseLite.new()
	var warp_noise_y := FastNoiseLite.new()
	if profile.warp_enabled:
		warp_noise_x.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		warp_noise_x.seed = terrain_seed + 303
		warp_noise_x.frequency = profile.warp_frequency

		warp_noise_y.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		warp_noise_y.seed = terrain_seed + 404
		warp_noise_y.frequency = profile.warp_frequency

	var min_h := INF
	var max_h := -INF

	# 1. Height computation
	for y in range(profile.height):
		for x in range(profile.width):
			var sample_x: float = float(x)
			var sample_y: float = float(y)

			if profile.warp_enabled:
				var wx := warp_noise_x.get_noise_2d(sample_x, sample_y) * profile.warp_strength
				var wy := warp_noise_y.get_noise_2d(sample_x, sample_y) * profile.warp_strength
				sample_x += wx
				sample_y += wy

			var macro_val := (macro_noise.get_noise_2d(sample_x, sample_y) + 1.0) * 0.5 * profile.macro_strength
			var med_val := medium_noise.get_noise_2d(sample_x, sample_y) * profile.medium_strength
			var det_val := detail_noise.get_noise_2d(sample_x, sample_y) * profile.detail_strength

			var h: float = (profile.base_height + macro_val + med_val + det_val) * profile.height_scale
			if h < min_h: min_h = h
			if h > max_h: max_h = h

			var cell := context.result.get_cell(Vector2i(x, y))
			cell.height = h

	# 2. Normalization & Slope computation
	var h_range := maxf(max_h - min_h, 0.001)
	for y in range(profile.height):
		for x in range(profile.width):
			var cell := context.result.get_cell(Vector2i(x, y))
			cell.normalized_height = (cell.height - min_h) / h_range

			# Central differences for slope
			var h_left: float = context.result.get_cell(Vector2i(maxi(x - 1, 0), y)).height
			var h_right: float = context.result.get_cell(Vector2i(mini(x + 1, profile.width - 1), y)).height
			var h_up: float = context.result.get_cell(Vector2i(x, maxi(y - 1, 0))).height
			var h_down: float = context.result.get_cell(Vector2i(x, mini(y + 1, profile.height - 1))).height

			var dx := (h_right - h_left) / (2.0 * profile.cell_size)
			var dy := (h_down - h_up) / (2.0 * profile.cell_size)
			var gradient := sqrt(dx * dx + dy * dy)
			cell.slope = rad_to_deg(atan(gradient))
```

- [ ] **Step 3: Run test to verify it passes**

Run:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_terrain_stage.gd"
```
Expected: PASS (`test_terrain_stage: OK`).

---

### Task 5: Ecology Stage (Forest Density, Clearings, Moisture)

**Files:**
- Create: `src/world_generator/stages/ecology_stage.gd`
- Test: `src/world_generator/tests/test_ecology_stage.gd`

**Interfaces:**
- Consumes: `WorldGenerationContext`, `WorldSeedSystem.DOMAIN_ECOLOGY`
- Produces: Populates `forest_density`, `clearing_density`, `moisture` on each `WorldCell`.

- [ ] **Step 1: Write failing test for EcologyStage**

```gdscript
# src/world_generator/tests/test_ecology_stage.gd
extends SceneTree

func _init() -> void:
	var profile := TaigaWorldProfile.new()
	var context := WorldGenerationContext.new(54321, profile)
	TerrainStage.new().execute(context)
	EcologyStage.new().execute(context)

	var cell := context.result.get_cell(Vector2i(50, 50))
	assert(cell.forest_density >= 0.0 and cell.forest_density <= 1.0)
	assert(cell.clearing_density >= 0.0 and cell.clearing_density <= 1.0)
	assert(cell.moisture >= 0.0 and cell.moisture <= 1.0)
	print("test_ecology_stage: OK")
	quit()
```

- [ ] **Step 2: Implement EcologyStage**

In `src/world_generator/stages/ecology_stage.gd`:
```gdscript
class_name EcologyStage
extends WorldStage

func execute(context: WorldGenerationContext) -> void:
	var profile: WorldProfile = context.profile
	var eco_seed: int = WorldSeedSystem.derive_seed(context.master_seed, WorldSeedSystem.DOMAIN_ECOLOGY)

	var forest_noise := FastNoiseLite.new()
	forest_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	forest_noise.seed = eco_seed
	forest_noise.frequency = profile.forest_frequency

	var moisture_noise := FastNoiseLite.new()
	moisture_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	moisture_noise.seed = eco_seed + 101
	moisture_noise.frequency = profile.moisture_frequency

	for y in range(profile.height):
		for x in range(profile.width):
			var cell := context.result.get_cell(Vector2i(x, y))
			var raw_forest := (forest_noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
			var raw_moisture := (moisture_noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5

			# Clearings appear where forest noise dips below threshold
			if raw_forest < profile.clearing_threshold:
				cell.clearing_density = 1.0 - (raw_forest / profile.clearing_threshold)
				cell.forest_density = 0.0
			else:
				cell.clearing_density = 0.0
				cell.forest_density = (raw_forest - profile.clearing_threshold) / (1.0 - profile.clearing_threshold)

			cell.moisture = clampf(raw_moisture, 0.0, 1.0)
```

- [ ] **Step 3: Run test to verify it passes**

Run:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_ecology_stage.gd"
```
Expected: PASS (`test_ecology_stage: OK`).

---

### Task 6: Vegetation Stage & Deterministic Placement

**Files:**
- Create: `src/world_generator/data/world_vegetation_item.gd`
- Create: `src/world_generator/stages/vegetation_stage.gd`
- Test: `src/world_generator/tests/test_vegetation_stage.gd`

**Interfaces:**
- Consumes: `WorldGenerationContext`, `WorldSeedSystem.DOMAIN_VEGETATION`
- Produces: `WorldVegetationItem` entries added to `context.result.vegetation`.

- [ ] **Step 1: Write failing test for VegetationStage**

```gdscript
# src/world_generator/tests/test_vegetation_stage.gd
extends SceneTree

func _init() -> void:
	var profile := TaigaWorldProfile.new()
	var context := WorldGenerationContext.new(777, profile)
	TerrainStage.new().execute(context)
	EcologyStage.new().execute(context)
	VegetationStage.new().execute(context)

	assert(context.result.vegetation.size() > 0, "Vegetation items must be generated")
	var item: WorldVegetationItem = context.result.vegetation[0]
	assert(item.type in [WorldVegetationItem.Type.CONIFER, WorldVegetationItem.Type.SHRUB, WorldVegetationItem.Type.ROCK])
	assert(item.scale > 0.0)

	# Test determinism
	var context2 := WorldGenerationContext.new(777, profile)
	TerrainStage.new().execute(context2)
	EcologyStage.new().execute(context2)
	VegetationStage.new().execute(context2)
	assert(context.result.vegetation.size() == context2.result.vegetation.size(), "Vegetation count must match")
	var item2: WorldVegetationItem = context2.result.vegetation[0]
	assert(item.position == item2.position, "Positions must match exactly")
	assert(item.rotation_y == item2.rotation_y, "Rotations must match")

	print("test_vegetation_stage: OK")
	quit()
```

- [ ] **Step 2: Implement WorldVegetationItem and VegetationStage**

Create `src/world_generator/data/world_vegetation_item.gd`:
```gdscript
class_name WorldVegetationItem
extends RefCounted

enum Type {
	CONIFER,
	SHRUB,
	ROCK,
}

var type: Type
var position: Vector3
var rotation_y: float
var scale: float

func _init(p_type: Type, p_pos: Vector3, p_rot: float = 0.0, p_scale: float = 1.0) -> void:
	type = p_type
	position = p_pos
	rotation_y = p_rot
	scale = p_scale
```

Create `src/world_generator/stages/vegetation_stage.gd`:
```gdscript
class_name VegetationStage
extends WorldStage

func execute(context: WorldGenerationContext) -> void:
	var profile: WorldProfile = context.profile
	var veg_seed: int = WorldSeedSystem.derive_seed(context.master_seed, WorldSeedSystem.DOMAIN_VEGETATION)
	context.result.vegetation.clear()

	var placed_tree_positions: Array[Vector2] = []

	for y in range(profile.height):
		for x in range(profile.width):
			var cell := context.result.get_cell(Vector2i(x, y))

			# Hash deterministic sub-seed for cell
			var cell_hash := int(("%d:%d:%d" % [veg_seed, x, y]).hash()) & 0x7FFFFFFF
			var rng := RandomNumberGenerator.new()
			rng.seed = cell_hash

			var jitter_x := (rng.randf() - 0.5) * 0.7 * profile.cell_size
			var jitter_z := (rng.randf() - 0.5) * 0.7 * profile.cell_size
			var world_x := float(x) * profile.cell_size + jitter_x
			var world_z := float(y) * profile.cell_size + jitter_z
			var world_y := cell.height
			var pos_3d := Vector3(world_x, world_y, world_z)
			var pos_2d := Vector2(world_x, world_z)

			# 1. Conifer Placement (Forest areas, low/moderate slopes)
			if cell.forest_density > 0.1 and cell.slope < 30.0:
				var spawn_chance := cell.forest_density * profile.tree_density
				if rng.randf() < spawn_chance:
					# Spacing check
					var too_close := false
					for prev_pos in placed_tree_positions:
						if pos_2d.distance_to(prev_pos) < profile.min_tree_spacing:
							too_close = true
							break
					if not too_close:
						var rot_y := rng.randf_range(0.0, TAU)
						var sc := rng.randf_range(0.8, 1.3)
						context.result.vegetation.append(
							WorldVegetationItem.new(WorldVegetationItem.Type.CONIFER, pos_3d, rot_y, sc)
						)
						placed_tree_positions.append(pos_2d)
						continue

			# 2. Shrub Placement (Clearings and forest borders)
			if cell.slope < 25.0 and cell.clearing_density > 0.2:
				if rng.randf() < profile.shrub_density * cell.clearing_density:
					var rot_y := rng.randf_range(0.0, TAU)
					var sc := rng.randf_range(0.5, 0.9)
					context.result.vegetation.append(
						WorldVegetationItem.new(WorldVegetationItem.Type.SHRUB, pos_3d, rot_y, sc)
					)
					continue

			# 3. Rock Placement (Favored on steeper slopes or rocky patches)
			if cell.slope > 15.0 and cell.slope < 45.0:
				if rng.randf() < profile.rock_density:
					var rot_y := rng.randf_range(0.0, TAU)
					var sc := rng.randf_range(0.6, 1.4)
					context.result.vegetation.append(
						WorldVegetationItem.new(WorldVegetationItem.Type.ROCK, pos_3d, rot_y, sc)
					)
```

- [ ] **Step 3: Run test to verify it passes**

Run:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_vegetation_stage.gd"
```
Expected: PASS (`test_vegetation_stage: OK`).

---

### Task 7: Navigation Stage & Walkability

**Files:**
- Create: `src/world_generator/stages/navigation_stage.gd`
- Test: `src/world_generator/tests/test_navigation_stage.gd`

**Interfaces:**
- Consumes: `WorldGenerationContext`, `cell.slope`, `profile.max_walkable_slope`
- Produces: `cell.is_walkable`, `cell.slope_category`, `context.result.spawn_position`.

- [ ] **Step 1: Write failing test for NavigationStage**

```gdscript
# src/world_generator/tests/test_navigation_stage.gd
extends SceneTree

func _init() -> void:
	var profile := TaigaWorldProfile.new()
	var context := WorldGenerationContext.new(123, profile)
	TerrainStage.new().execute(context)
	NavigationStage.new().execute(context)

	assert(context.result.spawn_position != Vector3.ZERO)
	var spawn_cell := context.result.get_cell(Vector2i(int(context.result.spawn_position.x), int(context.result.spawn_position.z)))
	assert(spawn_cell.is_walkable, "Spawn cell must be walkable")
	assert(spawn_cell.slope <= profile.max_walkable_slope)

	print("test_navigation_stage: OK")
	quit()
```

- [ ] **Step 2: Implement NavigationStage**

In `src/world_generator/stages/navigation_stage.gd`:
```gdscript
class_name NavigationStage
extends WorldStage

enum SlopeCategory {
	FLAT,      # 0 - 10 deg
	GENTLE,    # 10 - 25 deg
	STEEP,     # 25 - 40 deg
	CLIFF,     # > 40 deg
}

func execute(context: WorldGenerationContext) -> void:
	var profile: WorldProfile = context.profile
	var walkable_count: int = 0
	var total_cells: int = profile.width * profile.height

	var best_spawn_pos := Vector2i(-1, -1)
	var min_spawn_slope := INF
	var center := Vector2(float(profile.width) * 0.5, float(profile.height) * 0.5)

	for y in range(profile.height):
		for x in range(profile.width):
			var cell := context.result.get_cell(Vector2i(x, y))

			if cell.slope < 10.0:
				cell.slope_category = SlopeCategory.FLAT
			elif cell.slope < 25.0:
				cell.slope_category = SlopeCategory.GENTLE
			elif cell.slope < 40.0:
				cell.slope_category = SlopeCategory.STEEP
			else:
				cell.slope_category = SlopeCategory.CLIFF

			cell.is_walkable = (cell.slope <= profile.max_walkable_slope)
			if cell.is_walkable:
				walkable_count += 1

				# Prefer spawn near center with lowest slope
				var dist_to_center := Vector2(float(x), float(y)).distance_to(center)
				var score := cell.slope + (dist_to_center * 0.2)
				if score < min_spawn_slope:
					min_spawn_slope = score
					best_spawn_pos = Vector2i(x, y)

	if best_spawn_pos != Vector2i(-1, -1):
		var spawn_cell := context.result.get_cell(best_spawn_pos)
		context.result.spawn_position = Vector3(float(best_spawn_pos.x) * profile.cell_size, spawn_cell.height, float(best_spawn_pos.y) * profile.cell_size)

	context.result.metadata["walkable_ratio"] = float(walkable_count) / float(total_cells)
	context.result.metadata["walkable_cells"] = walkable_count
	context.result.metadata["total_cells"] = total_cells
```

- [ ] **Step 3: Run test to verify it passes**

Run:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_navigation_stage.gd"
```
Expected: PASS (`test_navigation_stage: OK`).

---

### Task 8: Full Pipeline Wiring & WorldValidator

**Files:**
- Modify: `src/world_generator/facade/world_pipeline.gd`
- Create: `src/world_generator/validation/world_validator.gd`
- Test: `src/world_generator/tests/test_world_validator.gd`
- Test: `src/world_generator/tests/test_world_determinism.gd`

**Interfaces:**
- Consumes: All stages (`TerrainStage`, `EcologyStage`, `VegetationStage`, `NavigationStage`)
- Produces:
  - `WorldPipeline.generate(seed: int, profile: WorldProfile) -> WorldResult`
  - `WorldValidator.validate(result: WorldResult) -> Dictionary`

- [ ] **Step 1: Implement WorldValidator**

Create `src/world_generator/validation/world_validator.gd`:
```gdscript
class_name WorldValidator
extends RefCounted

static func validate(result: WorldResult) -> Dictionary:
	var errors: Array[String] = []

	if result == null:
		return {"valid": false, "errors": ["WorldResult is null"]}

	if result.dimensions.x <= 0 or result.dimensions.y <= 0:
		errors.append("Invalid dimensions: %s" % str(result.dimensions))

	var expected_cells := result.dimensions.x * result.dimensions.y
	if result.cells.size() != expected_cells:
		errors.append("Cell count mismatch: expected %d, got %d" % [expected_cells, result.cells.size()])

	var nan_count := 0
	for cell in result.cells.values():
		if is_nan(cell.height) or is_inf(cell.height):
			nan_count += 1
		if cell.slope < 0.0 or cell.slope > 90.0:
			errors.append("Invalid slope %f at %s" % [cell.slope, str(cell.position)])
			break

	if nan_count > 0:
		errors.append("Found %d cells with NaN/Inf height" % nan_count)

	var walkable_ratio: float = result.metadata.get("walkable_ratio", 0.0)
	if walkable_ratio < 0.60:
		errors.append("Walkable ratio too low: %f (expected >= 0.60)" % walkable_ratio)

	if result.spawn_position == Vector3.ZERO and not result.cells.has(Vector2i.ZERO):
		errors.append("Invalid spawn position")

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"walkable_ratio": walkable_ratio,
		"vegetation_count": result.vegetation.size(),
	}
```

- [ ] **Step 2: Wire stages into WorldPipeline**

In `src/world_generator/facade/world_pipeline.gd`:
```gdscript
class_name WorldPipeline
extends RefCounted

static func generate(seed_val: int, profile: WorldProfile = null) -> WorldResult:
	if profile == null:
		profile = TaigaWorldProfile.new()

	var context := WorldGenerationContext.new(seed_val, profile)

	var stages: Array[WorldStage] = [
		TerrainStage.new(),
		EcologyStage.new(),
		VegetationStage.new(),
		NavigationStage.new(),
	]

	for stage in stages:
		stage.execute(context)

	return context.result
```

- [ ] **Step 3: Write tests for WorldValidator and Determinism**

Create `src/world_generator/tests/test_world_validator.gd`:
```gdscript
extends SceneTree

func _init() -> void:
	var result := WorldPipeline.generate(12345, TaigaWorldProfile.new())
	var report := WorldValidator.validate(result)
	assert(report["valid"], "Validation failed: %s" % str(report["errors"]))
	assert(report["walkable_ratio"] >= 0.60)
	print("test_world_validator: OK")
	quit()
```

Create `src/world_generator/tests/test_world_determinism.gd`:
```gdscript
extends SceneTree

func _init() -> void:
	var prof := TaigaWorldProfile.new()
	var res1 := WorldPipeline.generate(42, prof)
	var res2 := WorldPipeline.generate(42, prof)

	assert(res1.cells.size() == res2.cells.size())
	assert(res1.vegetation.size() == res2.vegetation.size())
	assert(res1.spawn_position == res2.spawn_position)

	for pos in res1.cells.keys():
		var c1: WorldCell = res1.cells[pos]
		var c2: WorldCell = res2.cells[pos]
		assert(c1.height == c2.height)
		assert(c1.slope == c2.slope)
		assert(c1.forest_density == c2.forest_density)
		assert(c1.is_walkable == c2.is_walkable)

	print("test_world_determinism: OK")
	quit()
```

- [ ] **Step 4: Run validator and determinism tests**

Run:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_world_validator.gd"
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_generator/tests/test_world_determinism.gd"
```
Expected: PASS.

---

### Task 9: Decoupled WorldRenderer (Terrain Mesh & MultiMesh Vegetation)

**Files:**
- Create: `src/world_renderer/terrain_mesh_builder.gd`
- Create: `src/world_renderer/world_renderer.gd`
- Test: `src/world_renderer/tests/test_world_renderer_headless.gd`

**Interfaces:**
- Consumes: `WorldResult`
- Produces:
  - `TerrainMeshBuilder.build_mesh(result: WorldResult) -> ArrayMesh`
  - `WorldRenderer.render_world(result: WorldResult) -> Node3D` with terrain `MeshInstance3D` (and `StaticBody3D` collision) plus `MultiMeshInstance3D` for conifers, shrubs, and rocks.

- [ ] **Step 1: Implement TerrainMeshBuilder**

Create `src/world_renderer/terrain_mesh_builder.gd`:
```gdscript
class_name TerrainMeshBuilder
extends RefCounted

static func build_mesh(result: WorldResult, cell_size: float = 1.0) -> ArrayMesh:
	var w := result.dimensions.x
	var h := result.dimensions.y

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	# Grid vertices
	for y in range(h):
		for x in range(w):
			var cell := result.get_cell(Vector2i(x, y))
			var pos := Vector3(float(x) * cell_size, cell.height, float(y) * cell_size)
			vertices.append(pos)
			uvs.append(Vector2(float(x) / float(w), float(y) / float(h)))

			# Vertex color encodes slope / vegetation blend:
			# R = slope intensity (rock), G = forest/grass, B = clearing/dirt
			var rock_factor := clampf(cell.slope / 45.0, 0.0, 1.0)
			var grass_factor := cell.forest_density
			colors.append(Color(rock_factor, grass_factor, cell.clearing_density, 1.0))

	# Compute indices
	for y in range(h - 1):
		for x in range(w - 1):
			var i0 := y * w + x
			var i1 := y * w + (x + 1)
			var i2 := (y + 1) * w + x
			var i3 := (y + 1) * w + (x + 1)

			# Quad triangles
			indices.append(i0)
			indices.append(i1)
			indices.append(i2)

			indices.append(i1)
			indices.append(i3)
			indices.append(i2)

	# Compute normals
	normals.resize(vertices.size())
	for i in range(normals.size()):
		normals[i] = Vector3.UP

	for i in range(0, indices.size(), 3):
		var v0 := vertices[indices[i]]
		var v1 := vertices[indices[i + 1]]
		var v2 := vertices[indices[i + 2]]
		var n := (v1 - v0).cross(v2 - v0).normalized()
		normals[indices[i]] += n
		normals[indices[i + 1]] += n
		normals[indices[i + 2]] += n

	for i in range(normals.size()):
		normals[i] = normals[i].normalized()

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
```

- [ ] **Step 2: Implement WorldRenderer**

Create `src/world_renderer/world_renderer.gd`:
```gdscript
class_name WorldRenderer
extends Node3D

func render_world(result: WorldResult, cell_size: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "RenderedWorld"

	# 1. Terrain Mesh & Collision
	var mesh := TerrainMeshBuilder.build_mesh(result, cell_size)
	var terrain_mi := MeshInstance3D.new()
	terrain_mi.name = "TerrainMesh"
	terrain_mi.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	terrain_mi.set_surface_override_material(0, mat)
	root.add_child(terrain_mi)

	# Static collision
	var static_body := StaticBody3D.new()
	static_body.name = "TerrainCollision"
	var col_shape := CollisionShape3D.new()
	col_shape.shape = mesh.create_trimesh_shape()
	static_body.add_child(col_shape)
	root.add_child(static_body)

	# 2. Vegetation MultiMeshes
	_spawn_vegetation_multimeshes(root, result)

	return root

func _spawn_vegetation_multimeshes(parent: Node3D, result: WorldResult) -> void:
	var conifers: Array[WorldVegetationItem] = []
	var shrubs: Array[WorldVegetationItem] = []
	var rocks: Array[WorldVegetationItem] = []

	for item in result.vegetation:
		match item.type:
			WorldVegetationItem.Type.CONIFER: conifers.append(item)
			WorldVegetationItem.Type.SHRUB: shrubs.append(item)
			WorldVegetationItem.Type.ROCK: rocks.append(item)

	_create_multimesh(parent, "Conifers", _create_conifer_mesh(), conifers)
	_create_multimesh(parent, "Shrubs", _create_shrub_mesh(), shrubs)
	_create_multimesh(parent, "Rocks", _create_rock_mesh(), rocks)

func _create_multimesh(parent: Node3D, name_id: String, base_mesh: Mesh, items: Array[WorldVegetationItem]) -> void:
	if items.is_empty():
		return

	var mmi := MultiMeshInstance3D.new()
	mmi.name = name_id
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = base_mesh
	mm.instance_count = items.size()

	for i in range(items.size()):
		var item := items[i]
		var t := Transform3D()
		t = t.scaled(Vector3.ONE * item.scale)
		t = t.rotated(Vector3.UP, item.rotation_y)
		t.origin = item.position
		mm.set_instance_transform(i, t)

	mmi.multimesh = mm
	parent.add_child(mmi)

func _create_conifer_mesh() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 1.2
	mesh.height = 4.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.28, 0.15)
	mat.roughness = 0.9
	mesh.material = mat
	return mesh

func _create_shrub_mesh() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.6
	mesh.height = 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.45, 0.20)
	mesh.material = mat
	return mesh

func _create_rock_mesh() -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.2, 0.8, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.42, 0.45)
	mesh.material = mat
	return mesh
```

- [ ] **Step 3: Test WorldRenderer in headless mode**

Create `src/world_renderer/tests/test_world_renderer_headless.gd`:
```gdscript
extends SceneTree

func _init() -> void:
	var result := WorldPipeline.generate(123, TaigaWorldProfile.new())
	var renderer := WorldRenderer.new()
	var node := renderer.render_world(result)
	assert(node != null)
	assert(node.has_node("TerrainMesh"))
	assert(node.has_node("TerrainCollision"))
	node.free()
	renderer.free()
	print("test_world_renderer_headless: OK")
	quit()
```

Run:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s "res://src/world_renderer/tests/test_world_renderer_headless.gd"
```
Expected: PASS (`test_world_renderer_headless: OK`).

---

### Task 10: Playable Taiga Scene & Visual Polish

**Files:**
- Create: `src/world_renderer/scenes/taiga_world.gd`
- Create: `src/world_renderer/scenes/taiga_world.tscn`

**Interfaces:**
- Instantiates `WorldRenderer`, calls `WorldPipeline.generate()`, attaches a camera and directional light to allow interactive inspection and traversal.

- [ ] **Step 1: Implement taiga_world.gd controller**

Create `src/world_renderer/scenes/taiga_world.gd`:
```gdscript
extends Node3D

@export var world_seed: int = 12345

func _ready() -> void:
	var profile := TaigaWorldProfile.new()
	var result := WorldPipeline.generate(world_seed, profile)

	var renderer := WorldRenderer.new()
	var world_node := renderer.render_world(result, profile.cell_size)
	add_child(world_node)

	# Position camera at spawn overlooking the terrain
	var cam := Camera3D.new()
	cam.name = "InspectionCamera"
	cam.position = result.spawn_position + Vector3(0, 15, 25)
	cam.look_at(result.spawn_position)
	add_child(cam)

	# Sun
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	light.light_energy = 1.1
	light.shadow_enabled = true
	add_child(light)

	print("Taiga World generated and ready at spawn: ", result.spawn_position)
```

- [ ] **Step 2: Create taiga_world.tscn**

Create `src/world_renderer/scenes/taiga_world.tscn` connecting `taiga_world.gd`.

---

### Task 11: Comprehensive Test Suite & Regression

**Files:**
- Create: `src/world_generator/tests/test_world_all.gd`

- [ ] **Step 1: Write and run the master test runner**

Create `src/world_generator/tests/test_world_all.gd`:
```gdscript
extends SceneTree

func _init() -> void:
	print("=== Running World Generator Master Test Suite ===")
	# 1. Contracts
	var prof := TaigaWorldProfile.new()
	var res := WorldPipeline.generate(12345, prof)
	assert(res.dimensions == Vector2i(128, 128))

	# 2. Seed system
	var s_t := WorldSeedSystem.derive_seed(12345, WorldSeedSystem.DOMAIN_TERRAIN)
	var s_v := WorldSeedSystem.derive_seed(12345, WorldSeedSystem.DOMAIN_VEGETATION)
	assert(s_t != s_v)

	# 3. Validation
	var val := WorldValidator.validate(res)
	assert(val["valid"], str(val["errors"]))

	# 4. Determinism
	var res_b := WorldPipeline.generate(12345, prof)
	assert(res.vegetation.size() == res_b.vegetation.size())
	assert(res.spawn_position == res_b.spawn_position)

	print("=== All World Generator Tests PASSED! ===")
	quit()
```

- [ ] **Step 2: Execute all World Generator and existing codebase tests**

Run:
```powershell
$godot = "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe"

& $godot --headless -s "res://src/world_generator/tests/test_world_all.gd"
& $godot --headless -s "res://src/gameplay/entities/tests/test_entity_matrix.gd"
& $godot --headless -s "res://src/gameplay/combat/tests/test_damage.gd"
& $godot --headless -s "res://src/gameplay/stats/tests/test_stat_calculator.gd"
```
Expected: All suites PASS.
