# External 3D Model Prop Pipeline (Pillar Benchmark) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate external 3D models (`.glb` / `.tscn`) into the data-driven presentation pipeline (`PropAssetProvider`, `PropAssetRegistry`, `props.json`, and room profiles) using `pillar_stone` as the first production benchmark without disrupting procedural geometry builders.

**Architecture:** Maintain a clean separation between 3D art (`assets/models/` and `assets/scenes/`), configuration authority (`resources/dungeon_profiles/`), and spatial algorithms (`DecorationCompositionPlanner`). `PropAssetProvider` transparently resolves whether a `prop_id` originates from a `PACKED_SCENE` (`.tscn` wrapping `.glb`) or `PROCEDURAL` mesh builder, keeping `PropSpawner` and room profiles decoupled from underlying geometry representations.

**Tech Stack:** Godot 4.6.1 GDScript, `PackedScene`, `PropAssetProvider`, `PropAssetRegistry`, `ProfileLoader`, JSON profiles (`props.json`, `crypt.json`).

**Spec:** [docs/superpowers/plans/2026-08-27-external-3d-model-prop-pipeline.md](file:///c:/Users/olivereld/Documents/dungeon-divers/docs/superpowers/plans/2026-08-27-external-3d-model-prop-pipeline.md)

## Global Constraints

- Never tightly couple GLB models to dungeon generation code; GLB defines geometry/visuals, JSON defines semantics and footprint, algorithms decide spatial placement.
- Do not create parallel spawners (e.g. `GlbSpawner`); reuse `PropSpawner` and `PropAssetProvider`.
- Maintain dual-source support: `PACKED_SCENE` and `PROCEDURAL` must coexist seamlessly.
- Pure spatial algorithms: zero scene tree mutation or global state in planners.

---

## File Structure & Responsibilities

```text
assets/
├── models/architecture/pillars/
│   └── pillar_stone.glb                 # 3D GLB model source
└── scenes/props/
    └── pillar_stone.tscn                # Standardized Godot scene (Mesh + Collision)

resources/dungeon_profiles/
├── assets/
│   └── props.json                       # Data authority defining prop metadata, source, tags, footprint
└── rooms/
    └── crypt.json                       # Declarative room rules matching pillar tags

src/
├── presentation/decoration/assets/
│   ├── prop_asset_source.gd             # Enum defining SourceType (PACKED_SCENE, PROCEDURAL)
│   ├── prop_asset_definition.gd         # Resource encapsulating scene or procedural parameters
│   ├── prop_asset_registry.gd           # Registry indexing prop_id -> PropAssetDefinition
│   └── prop_asset_provider.gd           # Instantiator resolving definitions to Node3D
└── dungeon_generator/profiles/
    └── profile_loader.gd                # Deserializer parsing props.json into AssetRegistry and PropAssetRegistry
```

---

## Bite-Sized Implementation Tasks

### Task 1: Asset Pipeline Hardening (Data Models & JSON Deserialization)

**Files:**
- Modify: `src/presentation/decoration/assets/prop_asset_definition.gd`
- Modify: `src/presentation/decoration/assets/prop_asset_registry.gd`
- Modify: `src/dungeon_generator/profiles/profile_loader.gd:50-90`
- Test: `tests/presentation/decoration/test_prop_asset_registry_scenes.gd`

**Interfaces:**
- Consumes: `props.json` definitions with `"source": { "type": "packed_scene", "scene": "res://..." }` or `"scene": "res://..."`.
- Produces: `PropAssetDefinition` with `source_type = PACKED_SCENE` and loaded or lazy-loaded `PackedScene`.

- [ ] **Step 1: Write failing test `test_prop_asset_registry_scenes.gd`**

```gdscript
extends SceneTree

const _PropAssetRegistryScript = preload("res://src/presentation/decoration/assets/prop_asset_registry.gd")
const _PropAssetDefinitionScript = preload("res://src/presentation/decoration/assets/prop_asset_definition.gd")
const _PropAssetSourceScript = preload("res://src/presentation/decoration/assets/prop_asset_source.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

func _init() -> void:
	print("--- Running test_prop_asset_registry_scenes ---")
	var loader := _ProfileLoaderScript.new()
	var registry := _PropAssetRegistryScript.new()
	
	# Verify that loader can register packed scene definitions from props.json
	loader.populate_prop_asset_registry(registry)
	assert(registry.has_definition(&"pillar_stone"), "FAIL: pillar_stone must be registered in PropAssetRegistry")
	
	var def = registry.get_definition(&"pillar_stone")
	assert(def.source_type == _PropAssetSourceScript.SourceType.PACKED_SCENE, "FAIL: source_type must be PACKED_SCENE")
	assert(def.scene_path != "" or def.scene != null, "FAIL: scene_path or scene must be populated")
	
	print("  [OK] PropAssetRegistry properly registers PACKED_SCENE from JSON.")
	quit(0)
```

- [ ] **Step 2: Run test to confirm it fails**

```powershell
powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/presentation/decoration/test_prop_asset_registry_scenes.gd"
```

- [ ] **Step 3: Implement polymorphic source parsing in `PropAssetDefinition`, `PropAssetRegistry`, and `ProfileLoader`**
  - Add `scene_path: String` to `PropAssetDefinition` with on-demand loading fallback if `scene == null`.
  - Add `populate_prop_asset_registry(reg: PropAssetRegistry)` helper in `ProfileLoader` that parses both `"source": {"type": "packed_scene", "scene": "..."}` and legacy `"scene": "..."`.
  - Support `default_scale` and `default_rotation_offset_y` deserialization.

- [ ] **Step 4: Run test to ensure it passes**

```powershell
powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/presentation/decoration/test_prop_asset_registry_scenes.gd"
```

- [ ] **Step 5: Commit changes**

---

### Task 2: Scene Scaffolding & Materialization for `pillar_stone`

**Files:**
- Create: `assets/scenes/props/pillar_stone.tscn`
- Modify: `resources/dungeon_profiles/assets/props.json`
- Modify: `src/presentation/decoration/assets/prop_asset_provider.gd`
- Test: `tests/presentation/decoration/test_external_prop_asset.gd`

**Interfaces:**
- Consumes: `assets/models/architecture/pillars/pillar_stone.glb`
- Produces: `assets/scenes/props/pillar_stone.tscn` instantiated via `PropAssetProvider.materialize_by_id(&"pillar_stone")` returning a valid `Node3D`.

- [ ] **Step 1: Write failing test `test_external_prop_asset.gd`**

```gdscript
extends SceneTree

const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

func _init() -> void:
	print("--- Running test_external_prop_asset ---")
	var loader := _ProfileLoaderScript.new()
	var provider := _PropAssetProviderScript.new()
	loader.populate_prop_asset_registry(provider.get_registry())

	var node = provider.materialize_by_id(&"pillar_stone")
	assert(node != null, "FAIL: Failed to materialize pillar_stone")
	assert(node is Node3D, "FAIL: Materialized prop must be Node3D")
	assert(node.get_child_count() > 0, "FAIL: Node3D must have children (mesh/collision)")
	
	node.free()
	print("  [OK] pillar_stone successfully materialized from external 3D scene.")
	quit(0)
```

- [ ] **Step 2: Run test to confirm it fails**

```powershell
powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/presentation/decoration/test_external_prop_asset.gd"
```

- [ ] **Step 3: Create `assets/scenes/props/pillar_stone.tscn` and configure `props.json`**
  - Create standard `pillar_stone.tscn` referencing `res://assets/models/architecture/pillars/pillar_stone.glb` with a `CylinderShape3D` collision body.
  - Update `PropAssetProvider.instantiate` to ensure scene instantiation applies `default_scale` and handles null scene paths gracefully.

- [ ] **Step 4: Run test to ensure it passes**

```powershell
powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/presentation/decoration/test_external_prop_asset.gd"
```

- [ ] **Step 5: Commit changes**

---

### Task 3: Integration with Crypt Composition Rules

**Files:**
- Modify: `resources/dungeon_profiles/rooms/crypt.json`
- Modify: `src/presentation/props/prop_palette_resolver.gd`
- Test: `tests/presentation/decoration/test_crypt_pillar_placement.gd`

**Interfaces:**
- Consumes: Tag matching `"asset_tags": ["pillar", "stone"]` in `crypt.json`.
- Produces: `PropDirective` instances placed at corner and perimeter positions in Crypt rooms.

- [ ] **Step 1: Write failing test `test_crypt_pillar_placement.gd`**

```gdscript
extends SceneTree

const _DecorationCompPlannerScript = preload("res://src/presentation/decoration/composition/decoration_composition_planner.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _PresentationRoomGeomScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _PresentationSeedContextScript = preload("res://src/presentation/architecture/presentation_seed_context.gd")

func _init() -> void:
	print("--- Running test_crypt_pillar_placement ---")
	var loader := _ProfileLoaderScript.new()
	var crypt_prof = loader.load_room("crypt.json")
	assert(crypt_prof != null, "FAIL: crypt.json must load")

	var pal_resolver := _DecorationPaletteResolverScript.new()
	var palette = pal_resolver.resolve_palette(1, 1, null)
	
	# Verify pillar entry exists in resolved prop palette
	var has_pillar := false
	for entry in palette.props.entries:
		if entry.style.id == &"pillar_stone" or entry.style.tags.has(&"pillar"):
			has_pillar = true
			break
	assert(has_pillar, "FAIL: Crypt prop palette must include pillar")

	print("  [OK] Crypt prop palette includes pillar_stone.")
	quit(0)
```

- [ ] **Step 2: Run test to confirm it fails**

```powershell
powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/presentation/decoration/test_crypt_pillar_placement.gd"
```

- [ ] **Step 3: Update `crypt.json` composition and `PropPaletteResolver`**
  - Add `crypt_pillars` rule into `resources/dungeon_profiles/rooms/crypt.json` (`mode: "corner"`, `asset_tags: ["pillar", "stone"]`, `min_count: 0`, `max_count: 4`).
  - Register `pillar_stone` in `PropPaletteResolver` / `DecorationPaletteResolver` with proper style and tags.

- [ ] **Step 4: Run test to ensure it passes**

```powershell
powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/presentation/decoration/test_crypt_pillar_placement.gd"
```

- [ ] **Step 5: Commit changes**

---

### Task 4: End-to-End Validation & Benchmark Regression Test

**Files:**
- Test: `tests/presentation/decoration/test_crypt_benchmark_100_seeds.gd`
- Test: `tests/profiles/test_configuration_authority.gd`

**Interfaces:**
- Consumes: Complete pipeline with procedural props + external 3D scenes.
- Produces: 100% passing test suite across 100 randomized seeds (700+ rooms).

- [ ] **Step 1: Run configuration authority tests**

```powershell
powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/profiles/test_configuration_authority.gd"
```

- [ ] **Step 2: Run 100 seeds crypt benchmark**

```powershell
powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/presentation/decoration/test_crypt_benchmark_100_seeds.gd"
```

- [ ] **Step 3: Update walkthrough with execution findings and verification evidence**
