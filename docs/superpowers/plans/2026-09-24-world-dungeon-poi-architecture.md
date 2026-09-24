# World ↔ Dungeon POI Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish a deterministic causal pipeline from World Master Seed to lazy Dungeon generation ($\text{Master Seed} \to \text{World Macro-Grid} \to \text{DungeonIdentity} \to \text{DungeonSeed} \to \text{DungeonPipeline}$) without pre-generating intermediate chunks.

**Architecture:**
- Extend `WorldSeedSystem` with `DOMAIN_DUNGEON` and seed derivation from `dungeon_id`.
- Introduce `DungeonIdentity` as an immutable canonical identifier decoupled from world position, chunk coords, and visual themes.
- Introduce `DungeonPOI` to represent the exterior manifestation in world space (position, entrance transform, archetype, bounding footprint).
- Implement `DungeonPOIGenerator` executing macro-grid distribution ($M \times M$ cells), fast environmental queries (elevation, slope, hydrology, footprint clearance, minimum spacing) without chunk generation, and deterministic archetype/orientation derivation.
- Implement `DungeonWorldBridge` translating `DungeonPOI` into `DungeonConfig` with fixed `dungeon_seed` for execution in `DungeonPipeline`.
- Hook POI query/attachment into `ChunkManager` and `ChunkData` so chunks only materialize exterior POI references lazily.
- Validate via a single comprehensive integration test: `res://src/world_generator/tests/test_world_dungeon_pipeline_integration.gd`.

**Tech Stack:** Godot 4.6 GDScript (`RefCounted`, `Vector2i`, `Vector3`, `Transform3D`, `Rect2i`, `DungeonPipeline`, `WorldSeedSystem`).

**Spec:** Provided in user prompt (`# Plan Técnico y Estructurado: Integración Arquitectónica Mundo ↔ Mazmorras (World & Dungeon POI Architecture)`).

## Global Constraints

- Authority is strictly with the master seed: no independent second master seed.
- Use `DOMAIN_POI = "poi"` for candidate generation and `DOMAIN_DUNGEON = "dungeon"` for interior seeds.
- `DungeonIdentity` must NOT contain as primary authority: `world_position`, `archetype`, `tier`, `orientation`, `total_floors`, or `chunk_coord`.
- Macro-cell size $M$ is decoupled from chunk size (e.g. 256 or 512).
- Candidate evaluation must NOT generate intermediate chunks or re-run heavy pipeline stages (must query environmental context).
- Interior dungeon generation must be lazy: executed only when player enters or when requested via `DungeonWorldBridge`.
- Exactly one integration test file: `res://src/world_generator/tests/test_world_dungeon_pipeline_integration.gd`.

---

### Task 1: Canonical Dungeon Identity & Seed System Extension

**Files:**
- Modify: `src/world_generator/data/world_seed_system.gd`
- Create: `src/world_generator/poi/dungeon_identity.gd`
- Test: `src/world_generator/tests/test_world_dungeon_pipeline_integration.gd` (scaffold test file)

**Interfaces:**
- Consumes: `WorldSeedSystem.VERSION_TAG`
- Produces:
  - `WorldSeedSystem.DOMAIN_DUNGEON: String = "dungeon"`
  - `WorldSeedSystem.derive_dungeon_seed(master_seed: int, dungeon_id: StringName) -> int`
  - `DungeonIdentity` class with:
    - `dungeon_id: StringName`
    - `macro_coord: Vector2i`
    - `candidate_index: int`
    - `dungeon_seed: int`
    - `static func create(master_seed: int, macro_coord: Vector2i, candidate_index: int = 0) -> DungeonIdentity`

- [ ] **Step 1: Scaffold integration test with identity & seed determinism assertions**

Create `src/world_generator/tests/test_world_dungeon_pipeline_integration.gd` with initial test methods testing `derive_dungeon_seed` and `DungeonIdentity`.

- [ ] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe" --headless --script res://src/world_generator/tests/test_world_dungeon_pipeline_integration.gd`
Expected: FAIL (types / methods not found).

- [ ] **Step 3: Update `WorldSeedSystem` with `DOMAIN_DUNGEON` and `derive_dungeon_seed`**

In `src/world_generator/data/world_seed_system.gd`:
```gdscript
const DOMAIN_DUNGEON: String = "dungeon"

static func derive_dungeon_seed(master_seed: int, dungeon_id: StringName) -> int:
	var hash_input: String = "%s:%d:%s:%s" % [VERSION_TAG, master_seed, DOMAIN_DUNGEON, String(dungeon_id)]
	return int(hash_input.hash()) & 0x7FFFFFFF
```

- [ ] **Step 4: Implement `DungeonIdentity`**

Create `src/world_generator/poi/dungeon_identity.gd`:
```gdscript
class_name DungeonIdentity
extends RefCounted

var dungeon_id: StringName = &""
var macro_coord: Vector2i = Vector2i.ZERO
var candidate_index: int = 0
var dungeon_seed: int = 0

func _init(p_dungeon_id: StringName = &"", p_macro_coord: Vector2i = Vector2i.ZERO, p_candidate_index: int = 0, p_dungeon_seed: int = 0) -> void:
	dungeon_id = p_dungeon_id
	macro_coord = p_macro_coord
	candidate_index = p_candidate_index
	dungeon_seed = p_dungeon_seed

static func create(master_seed: int, macro_coord: Vector2i, candidate_index: int = 0) -> DungeonIdentity:
	var id_str: String = "dungeon_m%d_%d_%d" % [macro_coord.x, macro_coord.y, candidate_index]
	var d_id: StringName = StringName(id_str)
	var d_seed: int = WorldSeedSystem.derive_dungeon_seed(master_seed, d_id)
	return DungeonIdentity.new(d_id, macro_coord, candidate_index, d_seed)
```

- [ ] **Step 5: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe" --headless --script res://src/world_generator/tests/test_world_dungeon_pipeline_integration.gd`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/world_generator/data/world_seed_system.gd src/world_generator/poi/dungeon_identity.gd src/world_generator/tests/test_world_dungeon_pipeline_integration.gd
git commit -m "feat(poi): implement DungeonIdentity and derive_dungeon_seed"
```

---

### Task 2: World POI Entity (`DungeonPOI`)

**Files:**
- Create: `src/world_generator/poi/dungeon_poi.gd`
- Modify: `src/world_generator/tests/test_world_dungeon_pipeline_integration.gd`

**Interfaces:**
- Consumes: `DungeonIdentity`
- Produces: `DungeonPOI` class with:
  - `identity: DungeonIdentity`
  - `world_position: Vector3`
  - `entrance_transform: Transform3D`
  - `archetype_id: StringName`
  - `tier: int`
  - `total_floors: int`
  - `orientation_deg: float`
  - `bounding_rect: Rect2i`
  - Helper `get_chunk_coord(chunk_size: int = 16) -> Vector2i`

- [ ] **Step 1: Add DungeonPOI test step in integration test**

Add assertions verifying properties and chunk coordinate derivation from world position without tight coupling.

- [ ] **Step 2: Run test to verify it fails**

Run headless test command. Expected: FAIL (`DungeonPOI` not found).

- [ ] **Step 3: Implement `DungeonPOI`**

Create `src/world_generator/poi/dungeon_poi.gd` matching spec section 2.2.

- [ ] **Step 4: Run test to verify it passes**

Run headless test command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/world_generator/poi/dungeon_poi.gd src/world_generator/tests/test_world_dungeon_pipeline_integration.gd
git commit -m "feat(poi): implement DungeonPOI entity"
```

---

### Task 3: Macro-Grid Distribution & Candidate Evaluation (`DungeonPOIGenerator`)

**Files:**
- Create: `src/world_generator/poi/dungeon_poi_generator.gd`
- Modify: `src/world_generator/tests/test_world_dungeon_pipeline_integration.gd`

**Interfaces:**
- Consumes: `WorldSeedSystem`, `DungeonIdentity`, `DungeonPOI`
- Produces: `DungeonPOIGenerator` class:
  - Macro cell size `macro_cell_size: int = 256` (or configurable)
  - `margin: int = 32`
  - `min_distance_between_pois: float = 120.0`
  - Environmental query interface / adapter (callable or `WorldContext` answering height, slope, water presence, biome)
  - `generate_candidate_for_macro_cell(master_seed: int, macro_coord: Vector2i, candidate_idx: int = 0) -> Dictionary`
  - `evaluate_and_create_poi(master_seed: int, macro_coord: Vector2i, world_query: Object) -> DungeonPOI`
  - Deterministic archetype selection based on biome/height (e.g. mountain -> crypt/fortress, plains -> catacombs, forest -> ruins)
  - Deterministic orientation based on local terrain slope/normal

- [ ] **Step 1: Add generator assertions to integration test**

Test macro-grid generation, determinism (same seed & cell = same candidate position and identity), rejection on water or steep slopes, and archetype determination.

- [ ] **Step 2: Run test to verify it fails**

Run headless test command. Expected: FAIL.

- [ ] **Step 3: Implement `DungeonPOIGenerator`**

Write `src/world_generator/poi/dungeon_poi_generator.gd` implementing:
- Deterministic candidate derivation using `WorldSeedSystem.derive_seed(master_seed, DOMAIN_POI, ...)`
- Footprint clearance checks and environmental validation (no water, slope <= max_slope, elevation range)
- Archetype mapping from environmental conditions
- Orientation derivation along terrain slope facing away from high ground
- Returns null if cell candidate is invalid, or returns populated `DungeonPOI`

- [ ] **Step 4: Run test to verify it passes**

Run headless test command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/world_generator/poi/dungeon_poi_generator.gd src/world_generator/tests/test_world_dungeon_pipeline_integration.gd
git commit -m "feat(poi): implement DungeonPOIGenerator with macro-grid distribution"
```

---

### Task 4: Pipeline Bridge (`DungeonWorldBridge`)

**Files:**
- Create: `src/world_generator/poi/dungeon_world_bridge.gd`
- Modify: `src/world_generator/tests/test_world_dungeon_pipeline_integration.gd`

**Interfaces:**
- Consumes: `DungeonPOI`, `DungeonConfig` (`res://src/dungeon_generator/config/dungeon_config.gd`), `DungeonPipeline` (`res://src/dungeon_generator/core/dungeon_pipeline.gd`)
- Produces: `DungeonWorldBridge`:
  - `static func create_dungeon_config(poi: DungeonPOI) -> DungeonConfig`
  - `static func generate_dungeon_from_poi(poi: DungeonPOI) -> DungeonResult`

- [ ] **Step 1: Add DungeonWorldBridge assertions to integration test**

Verify that `create_dungeon_config` sets `use_fixed_seed = true`, sets `cfg.seed = poi.identity.dungeon_seed`, binds `dungeon_id`, and that `generate_dungeon_from_poi` successfully generates a valid, reproducible `DungeonResult`.

- [ ] **Step 2: Run test to verify it fails**

Run headless test command. Expected: FAIL.

- [ ] **Step 3: Implement `DungeonWorldBridge`**

Write `src/world_generator/poi/dungeon_world_bridge.gd` translating POI parameters into `DungeonConfig` and triggering `DungeonPipeline.generate`.

- [ ] **Step 4: Run test to verify it passes**

Run headless test command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/world_generator/poi/dungeon_world_bridge.gd src/world_generator/tests/test_world_dungeon_pipeline_integration.gd
git commit -m "feat(poi): implement DungeonWorldBridge connecting POI to DungeonPipeline"
```

---

### Task 5: Chunk Streaming Integration (Lazy POI Discovery)

**Files:**
- Modify: `src/world_generator/chunks/chunk_data.gd`
- Modify: `src/world_generator/chunks/chunk_manager.gd`
- Modify: `src/world_generator/tests/test_world_dungeon_pipeline_integration.gd`

**Interfaces:**
- Consumes: `DungeonPOIGenerator`, `DungeonPOI`
- Produces:
  - `ChunkData.pois: Array[DungeonPOI]`
  - Query in `ChunkManager` to attach intersecting POIs to `ChunkData` without generating intermediate chunks or generating dungeon interiors.

- [ ] **Step 1: Add chunk streaming POI query test in integration test**

Verify querying POIs for a chunk bounds returns intersecting `DungeonPOI` without loading or generating intermediate chunks.

- [ ] **Step 2: Run test to verify it fails**

Run headless test command. Expected: FAIL.

- [ ] **Step 3: Update `ChunkData` and `ChunkManager`**

- In `ChunkData`: add `var pois: Array = []`
- In `ChunkManager`: add POI cache / macro-query so when a chunk is assembled, any POI whose bounding_rect intersects the chunk's core_bounds is attached to `chunk_data.pois`.

- [ ] **Step 4: Run test to verify it passes**

Run headless test command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/world_generator/chunks/chunk_data.gd src/world_generator/chunks/chunk_manager.gd src/world_generator/tests/test_world_dungeon_pipeline_integration.gd
git commit -m "feat(chunks): integrate lazy POI association in chunk streaming"
```

---

### Task 6: Complete Integration Verification & Edge Cases

**Files:**
- Modify: `src/world_generator/tests/test_world_dungeon_pipeline_integration.gd`

**Scope:**
- Verify all 5 mandatory checks from the spec:
  1. Determinism (same seed + macro_cell = identical identity, position, seed, and generated dungeon layout).
  2. Separation (different seed or macro_coord produces different identity/seed).
  3. Environmental validity (POI rejected on water / steep slopes; footprint respected).
  4. Integration with `DungeonPipeline` (`generate_dungeon_from_poi` reproduces exact room count and connections).
  5. Independence from streaming (POI at coordinate `(1024, 1024)` can be queried and evaluated without generating chunks between `(0,0)` and `(1024,1024)`).

- [ ] **Step 1: Complete and execute full test suite**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe" --headless --script res://src/world_generator/tests/test_world_dungeon_pipeline_integration.gd`
Expected: All integration checks PASS with 0 errors.

- [ ] **Step 2: Commit final integration verification**

```bash
git add src/world_generator/tests/test_world_dungeon_pipeline_integration.gd
git commit -m "test(poi): complete full world-to-dungeon pipeline integration test"
```
