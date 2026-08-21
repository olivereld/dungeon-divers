# Unified Geometry Architecture & Procedural De-duplication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor procedural 3D generation into a clean, unified geometry architecture (`src/geometry_generator/`) with a non-monolithic orchestrating facade (`DungeonMeshGenerator`), eliminate the legacy/duplicate `wall_mesh_generator/`, and cleanly separate geometry algorithms from presentation spawners (`DungeonStairSpawner`, `DungeonLightSpawner`).

**Architecture:** 
- `DungeonMeshGenerator` acts as a high-level coordinator delegating to dedicated domain builders (`DungeonGeometryGenerator` for walls, `DungeonFloorGenerator` for floors, `ArchGeometryBuilder` for arches, `DoorGeometryBuilder` for door leaves, `StairGeometryBuilder` for stairs, `TorchGeometryBuilder` for fixtures).
- Geometry builders are 100% headless `RefCounted` classes returning `ArrayMesh` / `GeneratedMesh` / `GeneratedAsset`.
- Presentation spawners (`DungeonDoorSpawner`, `DungeonStairSpawner`, `DungeonLightSpawner`, `DungeonPresentationBuilder`) only handle `Node3D` instantiation, positioning, collision bodies, interaction triggers, and metadata—no procedural mesh generation.
- `MeshGalleryRenderer` and `DungeonPresentationBuilder` consume the exact same `DungeonMeshGenerator` pipeline.

**Tech Stack:** Godot 4.6.1 GDScript, SurfaceTool, ArrayMesh, PBR StandardMaterial3D (`WallMaterialFactory`), Headless Test Runner.

**Spec:** Architectural Audit and Requirements from User Directive (August 21, 2026).

## Global Constraints

- **Invariant 1:** Presentation layer (`presentation/`) MUST NOT contain geometry algorithms (`SurfaceTool`, `_add_quad`, manual vertex assembly).
- **Invariant 2:** Each geometric element type has exactly ONE dedicated `GeometryBuilder`.
- **Invariant 3:** `MeshGallery` and `DungeonPresentation` consume the exact same generator pipeline.
- **Invariant 4:** `DungeonFloorGenerator` is the single source of truth for floors (zero floor generation inside wall builders).
- **Invariant 5:** `DungeonMeshGenerator` is a pure coordinator and DOES NOT construct meshes directly.
- **Invariant 6:** CULL_DISABLED must NOT be used as a hack to mask bad winding; all outer normals must point outward.
- **Invariant 7:** All tests must be executed and confirmed by the user in batches/checkpoints.

---

### Task 1: Architectural Contracts & Data Containers

**Files:**
- Create: `src/geometry_generator/data/generated_asset.gd`
- Modify: `src/geometry_generator/data/generated_mesh.gd`
- Modify: `src/geometry_generator/data/geometry_result.gd`
- Test: `tests/geometry/test_geometry_contracts.gd`

**Interfaces:**
- Consumes: None (Core data layer).
- Produces: `GeneratedAsset` with typed meshes, collision shapes, transform offsets and material slots.

- [ ] **Step 1: Write test for geometry contracts (`test_geometry_contracts.gd`)**

```gdscript
extends SceneTree

const GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_geometry_contracts ---")
	var asset = GeneratedAssetScript.new()
	asset.asset_id = &"test_asset"
	assert(asset.asset_id == &"test_asset", "Asset ID mismatch")
	
	var g_mesh = GeneratedMeshScript.new()
	g_mesh.component_id = 1
	asset.add_mesh("main", g_mesh)
	assert(asset.get_mesh("main") != null, "Mesh retrieval failed")
	print("[PASS] test_geometry_contracts")
	quit(0)
```

- [ ] **Step 2: Implement `src/geometry_generator/data/generated_asset.gd`**

```gdscript
class_name GeneratedAsset
extends RefCounted

## Contenedor semántico para un elemento arquitectónico ensamblado (ej. Puerta = Arco + Hoja).
var asset_id: StringName = &""
var meshes: Dictionary = {} # StringName -> GeneratedMesh
var metadata: Dictionary = {}
var bounds: AABB = AABB()

func add_mesh(slot: StringName, g_mesh: GeneratedMesh) -> void:
	if g_mesh != null:
		meshes[slot] = g_mesh
		if bounds == AABB():
			bounds = g_mesh.bounds
		else:
			bounds = bounds.merge(g_mesh.bounds)

func get_mesh(slot: StringName) -> GeneratedMesh:
	return meshes.get(slot, null)

func to_node3d(prefix: String = "Asset") -> Node3D:
	var root := Node3D.new()
	root.name = "%s_%s" % [prefix, String(asset_id)]
	for slot in meshes.keys():
		var gm: GeneratedMesh = meshes[slot]
		var mi: MeshInstance3D = gm.to_mesh_instance(String(slot))
		root.add_child(mi)
		if not gm.collision_shapes.is_empty():
			var body := gm.create_collision_body()
			root.add_child(body)
	return root
```

---

### Task 2: Arch Geometry Builder (`arch_geometry_builder.gd`)

**Files:**
- Create: `src/geometry_generator/geometry/arch_geometry_builder.gd`
- Create: `src/geometry_generator/config/arch_geometry_config.gd`
- Test: `tests/geometry/test_arch_geometry_builder.gd`

**Interfaces:**
- Consumes: `ArchGeometryConfig`
- Produces: `GeneratedMesh` containing stone arch (Trims, WallPanel, Bricks) with correct normals and CCW winding.

- [ ] **Step 1: Write test `tests/geometry/test_arch_geometry_builder.gd`**

```gdscript
extends SceneTree

const ArchGeometryBuilderScript = preload("res://src/geometry_generator/geometry/arch_geometry_builder.gd")
const ArchGeometryConfigScript = preload("res://src/geometry_generator/config/arch_geometry_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("--- Running test_arch_geometry_builder ---")
	var builder = ArchGeometryBuilderScript.new()
	var cfg = ArchGeometryConfigScript.new()
	cfg.width = 2.0
	cfg.height = 4.0
	cfg.opening_width = 1.06
	cfg.opening_height = 2.5
	cfg.seed = 1337

	var g_mesh = builder.build_arch_mesh(cfg)
	assert(g_mesh != null and g_mesh.mesh != null, "FAIL: Arch mesh must be created")
	assert(g_mesh.mesh.get_surface_count() >= 2, "FAIL: Arch must have at least Trims and WallPanel surfaces")
	print("[PASS] test_arch_geometry_builder")
	quit(0)
```

- [ ] **Step 2: Implement `src/geometry_generator/config/arch_geometry_config.gd` and `src/geometry_generator/geometry/arch_geometry_builder.gd`**
- [ ] **Step 3: Verify arch normals and watertight bounds with user execution checkpoint.**

---

### Task 3: Door Geometry Builder & Assembly (`door_geometry_builder.gd`)

**Files:**
- Create: `src/geometry_generator/geometry/door_geometry_builder.gd`
- Create: `src/geometry_generator/config/door_geometry_config.gd`
- Test: `tests/geometry/test_door_geometry_builder.gd`

**Interfaces:**
- Consumes: `DoorGeometryConfig`
- Produces: `GeneratedMesh` for door leaf (`DoorWood`, `DoorIron`), plus composition `build_portal_assembly(arch_cfg, door_cfg)` returning `GeneratedAsset`.

- [ ] **Step 1: Write test `tests/geometry/test_door_geometry_builder.gd`**
- [ ] **Step 2: Migrate procedural door algorithm from `wall_mesh_generator/core/door_geometry_builder.gd` into `src/geometry_generator/geometry/door_geometry_builder.gd`**
- [ ] **Step 3: Implement portal composition (`GeneratedAsset` with `arch` and `leaf` slots).**

---

### Task 4: Stair Geometry Builder (`stair_geometry_builder.gd`)

**Files:**
- Create: `src/geometry_generator/geometry/stair_geometry_builder.gd`
- Create: `src/geometry_generator/config/stair_geometry_config.gd`
- Modify: `src/dungeon_generator/presentation/dungeon_stair_spawner.gd` (remove geometry methods)
- Test: `tests/geometry/test_stair_geometry_builder.gd`

**Interfaces:**
- Consumes: `StairGeometryConfig` (steps, width, height, is_downward, side_walls)
- Produces: `GeneratedMesh` (treads, risers, stringers) with collision boxes.

- [ ] **Step 1: Write test `tests/geometry/test_stair_geometry_builder.gd`**
- [ ] **Step 2: Move `_build_procedural_stair_mesh()` and `_build_side_stringer()` out of `DungeonStairSpawner` into `StairGeometryBuilder`.**
- [ ] **Step 3: Refactor `DungeonStairSpawner` to consume `StairGeometryBuilder` directly.**

---

### Task 5: Torch Geometry Builder (`torch_geometry_builder.gd`)

**Files:**
- Create: `src/geometry_generator/fixtures/torch_geometry_builder.gd`
- Modify: `src/dungeon_lighting/presentation/dungeon_light_spawner.gd` (delegate mesh construction)
- Test: `tests/geometry/test_torch_geometry_builder.gd`

**Interfaces:**
- Consumes: None / Torch parameters.
- Produces: `GeneratedAsset` with `bracket` (forged iron) and `flame` (emissive stylized sphere).

- [ ] **Step 1: Write test `tests/geometry/test_torch_geometry_builder.gd`**
- [ ] **Step 2: Implement `TorchGeometryBuilder.build_torch_fixture()` returning `GeneratedAsset`.**
- [ ] **Step 3: Update `DungeonLightSpawner` to consume `TorchGeometryBuilder`, adding `OmniLight3D` and `TorchLightController`.**

---

### Task 6: Floor De-duplication & Wall Mesh Generator Legacy Tagging

**Files:**
- Modify: `src/wall_mesh_generator/config/wall_mesh_config.gd` (deprecate FLOOR_TILE/FLOOR_GRID)
- Modify: `src/wall_mesh_generator/core/wall_mesh_builder.gd`
- Test: `tests/floor/test_floor_single_source_of_truth.gd`

- [ ] **Step 1: Verify all floor consumers exclusively use `DungeonFloorGenerator`.**
- [ ] **Step 2: Remove `floor_tile_geometry_builder.gd` from `wall_mesh_generator`.**

---

### Task 7: Unified Facade (`DungeonMeshGenerator`)

**Files:**
- Create: `src/geometry_generator/facade/dungeon_mesh_generator.gd`
- Test: `tests/geometry/test_dungeon_mesh_generator_facade.gd`

**Interfaces:**
- Consumes: Domain configs (`WallGeometryConfig`, `FloorTileConfig`, `ArchGeometryConfig`, `DoorGeometryConfig`, `StairGeometryConfig`).
- Produces: Unified orchestration methods:
  - `generate_walls(grid, opening_manifest, wall_cfg, ...)` -> `GeometryResult`
  - `generate_floors(grid, floor_cfg, seed)` -> `FloorSurfaceResult`
  - `generate_arch(arch_cfg)` -> `GeneratedMesh`
  - `generate_door(door_cfg)` -> `GeneratedMesh`
  - `generate_door_portal(arch_cfg, door_cfg, door_type)` -> `GeneratedAsset`
  - `generate_stairs(stair_cfg)` -> `GeneratedMesh`
  - `generate_torch_fixture(energy)` -> `GeneratedAsset`

- [ ] **Step 1: Write facade test `test_dungeon_mesh_generator_facade.gd`**
- [ ] **Step 2: Implement pure coordinating facade `DungeonMeshGenerator`.**

---

### Task 8: Presentation & Gallery Integration

**Files:**
- Modify: `src/dungeon_generator/presentation/dungeon_presentation_builder.gd`
- Modify: `src/presentation/showcase/mesh_gallery_renderer.gd`
- Test: `tests/presentation/test_mesh_gallery_generation.gd`

- [ ] **Step 1: Connect `DungeonPresentationBuilder` to `DungeonMeshGenerator`.**
- [ ] **Step 2: Connect `MeshGalleryRenderer` to `DungeonMeshGenerator`.**
- [ ] **Step 3: Run full suite of presentation tests.**

---

### Task 9: Deprecation & Archival of `wall_mesh_generator/`

**Files:**
- Remove/Archive: `src/wall_mesh_generator/` legacy files once 100% verified.
- Update documentation and architectural diagrams.
