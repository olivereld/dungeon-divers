# Necropolis Entrance Environment v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the exterior surroundings of Necropolis dungeon entrances into an immersive, atmospheric graveyard and corrupted zone using existing project assets (`assets/texture/world/corruption`, `assets/texture/foliage/Bones`, and `models/nature/dead_tree/dead_tree_01.glb`), with procedural influence masks, clustered bone patches, dead trees, dark rocks, and vegetation dampening.

**Architecture:** A dedicated `NecropolisEntranceProfile` defines environmental parameters and radii. A deterministic evaluator (`NecropolisInfluenceEvaluator`) calculates distance-based corrupted falloff with noise perturbation. `DungeonEntrancePOIView` and `ChunkWorld` orchestrate terrain texture blending, bone patch MultiMeshes, dead tree placement, and standard vegetation reduction without modifying core game logic or breaking seed determinism.

**Tech Stack:** Godot 4.6 GDScript, MultiMeshInstance3D, Spatial Shaders (GLSL/Godot shading language), FastNoiseLite / WorldSeedSystem determinism.

**Spec:** User specification provided in chat detailing the 15 design rules and 12 MVP phases for the Necropolis Entrance Environment v1.

## Global Constraints
- Must be 100% deterministic: every entrance with the same seed and POI id generates identical visual layout.
- Strictly reuse existing assets without downloading or generating new 3D models or textures.
- Do not disrupt standard taiga or overworld biomes outside the entrance's transition radius.
- Maintain solid performance by using MultiMeshInstance3D for bone patches, dead trees, and rocks.
- All tests must run headless with Godot console and pass with exit code 0.

---

### Task 1: Necropolis Entrance Configuration Profile (`NecropolisEntranceProfile`)

**Files:**
- Create: `src/world_generator/poi/necropolis_entrance_profile.gd`
- Test: `tests/world_generator/test_necropolis_entrance_profile.gd`

**Interfaces:**
- Produces: `NecropolisEntranceProfile` Resource with exported properties:
  - `entrance_clear_radius: float = 4.5`
  - `funeral_ground_radius: float = 14.0`
  - `corruption_radius: float = 24.0`
  - `transition_radius: float = 32.0`
  - `bone_patch_density: float = 0.45`
  - `bone_patch_min_distance: float = 2.0`
  - `bone_patch_scale_min: float = 0.8`
  - `bone_patch_scale_max: float = 1.6`
  - `dead_tree_density: float = 0.25`
  - `dead_tree_min_distance: float = 4.0`
  - `dead_tree_scale_min: float = 2.5`
  - `dead_tree_scale_max: float = 4.2`
  - `dark_rock_density: float = 0.30`
  - `normal_vegetation_multiplier: float = 0.15`
  - `noise_frequency: float = 0.08`

- [x] **Step 1: Write the unit test for profile initialization and defaults**

Create `tests/world_generator/test_necropolis_entrance_profile.gd`:
```gdscript
extends SceneTree

const _ProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")

func _init() -> void:
	print("Running test_necropolis_entrance_profile...")
	var prof = _ProfileScript.new()
	assert(prof != null, "Profile must instantiate")
	assert(prof.entrance_clear_radius == 4.5, "Clear radius must default to 4.5m")
	assert(prof.funeral_ground_radius == 14.0, "Funeral ground radius must default to 14.0m")
	assert(prof.corruption_radius == 24.0, "Corruption radius must default to 24.0m")
	assert(prof.transition_radius == 32.0, "Transition radius must default to 32.0m")
	assert(prof.normal_vegetation_multiplier <= 0.2, "Normal vegetation must be heavily dampened")
	assert(prof.dead_tree_scale_max > prof.dead_tree_scale_min, "Dead tree scale max must exceed min")
	print("[PASS] test_necropolis_entrance_profile")
	quit(0)
```

- [x] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_necropolis_entrance_profile.gd`
Expected: FAIL with "File not found: necropolis_entrance_profile.gd"

- [x] **Step 3: Implement `NecropolisEntranceProfile`**

Create `src/world_generator/poi/necropolis_entrance_profile.gd`:
```gdscript
class_name NecropolisEntranceProfile
extends Resource

## Parámetros de configuración ambiental para el entorno exterior de la entrada de Necrópolis.
## Define radios concéntricos de influencia, densidades y escalas sin lógica de generación acoplada.

@export_group("Radii")
@export var entrance_clear_radius: float = 4.5
@export var funeral_ground_radius: float = 14.0
@export var corruption_radius: float = 24.0
@export var transition_radius: float = 32.0

@export_group("Bone Patches")
@export var bone_patch_density: float = 0.45
@export var bone_patch_min_distance: float = 2.0
@export var bone_patch_scale_min: float = 0.8
@export var bone_patch_scale_max: float = 1.6

@export_group("Dead Trees")
@export var dead_tree_density: float = 0.25
@export var dead_tree_min_distance: float = 4.0
@export var dead_tree_scale_min: float = 2.5
@export var dead_tree_scale_max: float = 4.2

@export_group("Rocks and Atmosphere")
@export var dark_rock_density: float = 0.30
@export var normal_vegetation_multiplier: float = 0.15
@export var noise_frequency: float = 0.08
@export var ambient_darkening: float = 0.35
```

- [x] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_necropolis_entrance_profile.gd`
Expected: `[PASS] test_necropolis_entrance_profile`

- [x] **Step 5: Commit**

```bash
git add src/world_generator/poi/necropolis_entrance_profile.gd tests/world_generator/test_necropolis_entrance_profile.gd
git commit -m "feat(poi): create NecropolisEntranceProfile configuration resource"
```

---

### Task 2: Deterministic Influence & Radial Noise Evaluator (`NecropolisInfluenceEvaluator`)

**Files:**
- Create: `src/world_generator/poi/necropolis_influence_evaluator.gd`
- Test: `tests/world_generator/test_necropolis_influence_evaluator.gd`

**Interfaces:**
- Consumes: `NecropolisEntranceProfile`
- Produces: `NecropolisInfluenceEvaluator`:
  - `evaluate_point(world_pos_2d: Vector2, poi_pos_2d: Vector2, seed_val: int, profile: NecropolisEntranceProfile) -> Dictionary`
    - Returns `{ "influence": float, "zone": int, "is_cleared": bool }` where:
      - `zone = ZONE_CLEAR | ZONE_FUNERAL | ZONE_CORRUPTION | ZONE_TRANSITION | ZONE_WILD`
      - `influence`: continuous value from `1.0` (deep core) to `0.0` (outside transition).

- [x] **Step 1: Write unit test for the influence evaluator**

Create `tests/world_generator/test_necropolis_influence_evaluator.gd`:
```gdscript
extends SceneTree

const _ProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")
const _EvaluatorScript = preload("res://src/world_generator/poi/necropolis_influence_evaluator.gd")

func _init() -> void:
	print("Running test_necropolis_influence_evaluator...")
	var prof = _ProfileScript.new()
	var poi_center := Vector2(100.0, 100.0)
	var seed_val := 424242

	# 1. At center -> Clear zone, maximum influence (1.0)
	var eval_center = _EvaluatorScript.evaluate_point(poi_center, poi_center, seed_val, prof)
	assert(eval_center.influence == 1.0, "Center influence must be 1.0")
	assert(eval_center.is_cleared == true, "Center must be in cleared zone")
	assert(eval_center.zone == _EvaluatorScript.ZONE_CLEAR, "Zone must be ZONE_CLEAR")

	# 2. At 8m (funeral ground)
	var eval_funeral = _EvaluatorScript.evaluate_point(poi_center + Vector2(8.0, 0.0), poi_center, seed_val, prof)
	assert(eval_funeral.is_cleared == false, "8m must not be cleared")
	assert(eval_funeral.zone == _EvaluatorScript.ZONE_FUNERAL, "Zone at 8m must be ZONE_FUNERAL")
	assert(eval_funeral.influence >= 0.7, "Funeral influence must be high")

	# 3. Outside 50m -> Wild zone, influence 0.0
	var eval_far = _EvaluatorScript.evaluate_point(poi_center + Vector2(60.0, 0.0), poi_center, seed_val, prof)
	assert(eval_far.influence == 0.0, "Influence at 60m must be 0.0")
	assert(eval_far.zone == _EvaluatorScript.ZONE_WILD, "Zone at 60m must be ZONE_WILD")

	# 4. Organic border noise test (different angles at same distance have subtle perturbation)
	var eval_a = _EvaluatorScript.evaluate_point(poi_center + Vector2(20.0, 0.0), poi_center, seed_val, prof)
	var eval_b = _EvaluatorScript.evaluate_point(poi_center + Vector2(0.0, 20.0), poi_center, seed_val, prof)
	assert(eval_a.influence != eval_b.influence, "Noise perturbation must create organic non-circular borders")

	print("[PASS] test_necropolis_influence_evaluator")
	quit(0)
```

- [x] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_necropolis_influence_evaluator.gd`
Expected: FAIL with "File not found: necropolis_influence_evaluator.gd"

- [x] **Step 3: Implement `NecropolisInfluenceEvaluator`**

Create `src/world_generator/poi/necropolis_influence_evaluator.gd`:
```gdscript
class_name NecropolisInfluenceEvaluator
extends RefCounted

const _ProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")

## Evalúa la influencia espacial determinista de una entrada de Necrópolis sobre el terreno y vegetación.
## Aplica una perturbación fractal sobre la distancia para que el perímetro de corrupción sea orgánico y no un círculo plano.

enum {
	ZONE_CLEAR = 0,
	ZONE_FUNERAL = 1,
	ZONE_CORRUPTION = 2,
	ZONE_TRANSITION = 3,
	ZONE_WILD = 4,
}

static func evaluate_point(
	world_pos_2d: Vector2,
	poi_pos_2d: Vector2,
	seed_val: int,
	profile: RefCounted
) -> Dictionary:
	var raw_dist: float = (world_pos_2d - poi_pos_2d).length()

	# Zona inmediata de despeje absoluto (entrada sin obstrucción)
	if raw_dist <= profile.entrance_clear_radius:
		return {
			"influence": 1.0,
			"zone": ZONE_CLEAR,
			"is_cleared": true
		}

	# Perturbación angular/espacial determinista basada en funciones armónicas
	var angle: float = atan2(world_pos_2d.y - poi_pos_2d.y, world_pos_2d.x - poi_pos_2d.x)
	var noise_val: float = sin(angle * 3.0 + float(seed_val % 100)) * 2.2 + cos(angle * 5.0 + float(seed_val % 73)) * 1.5
	var effective_dist: float = raw_dist + noise_val

	if effective_dist <= profile.funeral_ground_radius:
		var t: float = 1.0 - (effective_dist / profile.funeral_ground_radius) * 0.25
		return {
			"influence": clampf(t, 0.75, 1.0),
			"zone": ZONE_FUNERAL,
			"is_cleared": false
		}
	elif effective_dist <= profile.corruption_radius:
		var span: float = profile.corruption_radius - profile.funeral_ground_radius
		var t: float = 1.0 - ((effective_dist - profile.funeral_ground_radius) / span)
		return {
			"influence": clampf(0.35 + t * 0.40, 0.35, 0.75),
			"zone": ZONE_CORRUPTION,
			"is_cleared": false
		}
	elif effective_dist <= profile.transition_radius:
		var span: float = profile.transition_radius - profile.corruption_radius
		var t: float = 1.0 - ((effective_dist - profile.corruption_radius) / span)
		return {
			"influence": clampf(t * 0.35, 0.0, 0.35),
			"zone": ZONE_TRANSITION,
			"is_cleared": false
		}
	else:
		return {
			"influence": 0.0,
			"zone": ZONE_WILD,
			"is_cleared": false
		}
```

- [x] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_necropolis_influence_evaluator.gd`
Expected: `[PASS] test_necropolis_influence_evaluator`

- [x] **Step 5: Commit**

```bash
git add src/world_generator/poi/necropolis_influence_evaluator.gd tests/world_generator/test_necropolis_influence_evaluator.gd
git commit -m "feat(poi): implement NecropolisInfluenceEvaluator with organic border noise"
```

---

### Task 3: Ground Corruption & Funeral Earth Shading

**Files:**
- Modify: `src/world_renderer/shaders/terrain.gdshader:1-60`
- Modify: `src/world_generator/presentation/terrain_material.gd:1-65`
- Test: `tests/world_generator/test_terrain_corruption_material.gd`

**Interfaces:**
- Consumes:
  - Textures: `res://assets/texture/world/corruption/floor_corrupted_01.jpg`
  - Textures: `res://assets/texture/world/corruption/floor_corrupted_cemetary_01.jpg`
- Produces:
  - Shader uniforms in `terrain.gdshader`:
    - `corrupted_ground_texture`
    - `funeral_ground_texture`
    - `poi_nec_center` (vec3: center coordinate of the entrance in world space)
    - `poi_nec_radii` (vec4: clear, funeral, corruption, transition)
  - Color cross-fade in fragment shader with desaturation and dark tinting.

- [x] **Step 1: Write test for corruption material texture loading and shader parameters**

Create `tests/world_generator/test_terrain_corruption_material.gd`:
```gdscript
extends SceneTree

const _TerrainMatScript = preload("res://src/world_generator/presentation/terrain_material.gd")

func _init() -> void:
	print("Running test_terrain_corruption_material...")
	var mat = _TerrainMatScript.create_material(null, true) as ShaderMaterial
	assert(mat != null, "Material must be ShaderMaterial")
	
	var corrupted_tex = mat.get_shader_parameter("corrupted_ground_texture")
	assert(corrupted_tex != null, "corrupted_ground_texture must be set on material")
	var funeral_tex = mat.get_shader_parameter("funeral_ground_texture")
	assert(funeral_tex != null, "funeral_ground_texture must be set on material")
	
	print("[PASS] test_terrain_corruption_material")
	quit(0)
```

- [x] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_terrain_corruption_material.gd`
Expected: FAIL

- [x] **Step 3: Update `terrain.gdshader` and `terrain_material.gd`**

In `src/world_renderer/shaders/terrain.gdshader`:
Add uniforms:
```glsl
uniform sampler2D corrupted_ground_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D funeral_ground_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float corruption_uv_scale : hint_range(0.05, 2.0) = 0.35;
uniform vec3 poi_nec_center = vec3(0.0, -999.0, 0.0);
uniform vec4 poi_nec_radii = vec4(4.5, 14.0, 24.0, 32.0);
```

Blend in fragment:
```glsl
if (poi_nec_center.y > -900.0) {
    float dist = length(v_world_pos.xz - poi_nec_center.xz);
    if (dist < poi_nec_radii.w) {
        float f_w = clamp(1.0 - (dist / poi_nec_radii.y), 0.0, 1.0);
        float c_w = clamp(1.0 - ((dist - poi_nec_radii.y) / (poi_nec_radii.z - poi_nec_radii.y)), 0.0, 1.0);
        float t_w = clamp(1.0 - ((dist - poi_nec_radii.z) / (poi_nec_radii.w - poi_nec_radii.z)), 0.0, 1.0);
        vec3 fun_col = texture(funeral_ground_texture, v_world_pos.xz * corruption_uv_scale).rgb;
        vec3 cor_col = texture(corrupted_ground_texture, v_world_pos.xz * corruption_uv_scale).rgb;
        vec3 nec_mix = mix(cor_col, fun_col, f_w);
        float total_inf = max(f_w, max(c_w * 0.75, t_w * 0.35));
        albedo_tex = mix(albedo_tex, nec_mix * vec3(0.75, 0.70, 0.80), total_inf);
    }
}
```

In `src/world_generator/presentation/terrain_material.gd`:
Add texture constants and assign shader parameters in `create_material()`.

- [x] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_terrain_corruption_material.gd`
Expected: `[PASS] test_terrain_corruption_material`

- [x] **Step 5: Commit**

```bash
git add src/world_renderer/shaders/terrain.gdshader src/world_generator/presentation/terrain_material.gd tests/world_generator/test_terrain_corruption_material.gd
git commit -m "feat(terrain): integrate corrupted ground and funeral earth shaders"
```

---

### Task 4: Clustered Bone Patches (`BonePatchGenerator`)

**Files:**
- Create: `src/world_generator/poi/bone_patch_generator.gd`
- Test: `tests/world_generator/test_bone_patch_generator.gd`

**Interfaces:**
- Consumes:
  - Textures: `res://assets/texture/foliage/Bones/bones_patch_01.jpg` .. `04`, `web_patch_01.jpg`
  - `NecropolisEntranceProfile`
- Produces:
  - `BonePatchGenerator.generate_bone_patches(poi: RefCounted, profile: NecropolisEntranceProfile, world_query: Object) -> Node3D`

- [x] **Step 1: Write unit test for BonePatchGenerator**

Create `tests/world_generator/test_bone_patch_generator.gd`:
```gdscript
extends SceneTree

const _BonePatchGenScript = preload("res://src/world_generator/poi/bone_patch_generator.gd")
const _ProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")
const _DungeonPOIScript = preload("res://src/world_generator/poi/dungeon_poi.gd")
const _DungeonIdentityScript = preload("res://src/world_generator/poi/dungeon_identity.gd")

class MockQuery extends RefCounted:
	func get_elevation(_x: int, _z: int) -> float:
		return 6.0

func _init() -> void:
	print("Running test_bone_patch_generator...")
	var ident = _DungeonIdentityScript.new(&"necropolis_01", Vector2i(0, 0), 0, 777)
	var poi = _DungeonPOIScript.new(ident, Vector3(50.0, 6.0, 50.0), Transform3D.IDENTITY, &"necropolis", 1)
	var prof = _ProfileScript.new()
	var query = MockQuery.new()

	var patch_node = _BonePatchGenScript.generate_bone_patches(poi, prof, query)
	assert(patch_node != null, "BonePatch node must be generated")
	assert(patch_node.get_child_count() > 0, "Must contain MultiMeshInstance3D children for bone textures")
	
	var mmi = patch_node.get_child(0) as MultiMeshInstance3D
	assert(mmi != null and mmi.multimesh != null, "Child must be MultiMeshInstance3D")
	assert(mmi.multimesh.instance_count > 0, "Must have generated bone instances")
	
	patch_node.free()
	print("[PASS] test_bone_patch_generator")
	quit(0)
```

- [x] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_bone_patch_generator.gd`
Expected: FAIL

- [x] **Step 3: Implement `BonePatchGenerator`**

Create `src/world_generator/poi/bone_patch_generator.gd`:
- Use horizontal ground quad meshes with alpha blend/cutout for bones and web textures.
- Group by texture and pack into `MultiMeshInstance3D` instances.
- Generate organic clusters around funeral ground ($R \in [4.8, 16.0]$m), with random rotation, scale variance ($[0.8, 1.6]$), and elevation tracking.

- [x] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_bone_patch_generator.gd`
Expected: `[PASS] test_bone_patch_generator`

- [x] **Step 5: Commit**

```bash
git add src/world_generator/poi/bone_patch_generator.gd tests/world_generator/test_bone_patch_generator.gd
git commit -m "feat(poi): implement clustered BonePatchGenerator using MultiMesh"
```

---

### Task 5: Dead Tree Spawner (`DeadTreeSpawner`)

**Files:**
- Create: `src/world_generator/poi/dead_tree_spawner.gd`
- Test: `tests/world_generator/test_dead_tree_spawner.gd`

**Interfaces:**
- Consumes:
  - Model: `res://models/nature/dead_tree/dead_tree_01.glb`
  - Texture: `res://models/nature/dead_tree/dead_tree_01_Arbol.png`
  - `NecropolisEntranceProfile`
- Produces:
  - `DeadTreeSpawner.generate_dead_trees(poi: RefCounted, profile: NecropolisEntranceProfile, world_query: Object) -> Node3D`

- [x] **Step 1: Write unit test for DeadTreeSpawner**

Create `tests/world_generator/test_dead_tree_spawner.gd`:
```gdscript
extends SceneTree

const _SpawnerScript = preload("res://src/world_generator/poi/dead_tree_spawner.gd")
const _ProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")
const _DungeonPOIScript = preload("res://src/world_generator/poi/dungeon_poi.gd")
const _DungeonIdentityScript = preload("res://src/world_generator/poi/dungeon_identity.gd")

class MockQuery extends RefCounted:
	func get_elevation(_x: int, _z: int) -> float:
		return 4.0
	func is_water(_x: int, _z: int) -> bool:
		return false

func _init() -> void:
	print("Running test_dead_tree_spawner...")
	var ident = _DungeonIdentityScript.new(&"necropolis_01", Vector2i(0, 0), 0, 999)
	var poi = _DungeonPOIScript.new(ident, Vector3(0.0, 4.0, 0.0), Transform3D.IDENTITY, &"necropolis", 1)
	var prof = _ProfileScript.new()
	var query = MockQuery.new()

	var node = _SpawnerScript.generate_dead_trees(poi, prof, query)
	assert(node != null, "Dead tree node must generate")
	var mmi = node.get_node_or_null("DeadTreesMultiMesh") as MultiMeshInstance3D
	assert(mmi != null, "Must contain DeadTreesMultiMesh")
	assert(mmi.multimesh.instance_count >= 3, "Must spawn at least 3 dead trees in funeral/corruption zones")
	
	for i in range(mmi.multimesh.instance_count):
		var t = mmi.multimesh.get_instance_transform(i)
		var dist = Vector2(t.origin.x, t.origin.z).length()
		assert(dist >= prof.entrance_clear_radius, "Dead tree #%d at %.2fm is too close to entrance" % [i, dist])

	node.free()
	print("[PASS] test_dead_tree_spawner")
	quit(0)
```

- [x] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_dead_tree_spawner.gd`
Expected: FAIL

- [x] **Step 3: Implement `DeadTreeSpawner`**

Create `src/world_generator/poi/dead_tree_spawner.gd`:
- Extract mesh from `res://models/nature/dead_tree/dead_tree_01.glb`.
- Apply a desaturated, high-roughness bark material.
- Position dead trees deterministically with Poisson rejection sampling outside `entrance_clear_radius`.

- [x] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_dead_tree_spawner.gd`
Expected: `[PASS] test_dead_tree_spawner`

- [x] **Step 5: Commit**

```bash
git add src/world_generator/poi/dead_tree_spawner.gd tests/world_generator/test_dead_tree_spawner.gd
git commit -m "feat(poi): implement DeadTreeSpawner using MultiMesh and Poisson placement"
```

---

### Task 5: Dark Rocks & Living Vegetation Dampening

**Files:**
- Modify: `src/world_generator/chunks/chunk_world.gd:410-440`
- Create: `src/world_generator/poi/necropolis_rock_cluster.gd`
- Test: `tests/world_generator/test_necropolis_vegetation_dampening.gd`

**Interfaces:**
- Consumes:
  - `WorldRenderer._create_rock_mesh()`
  - `NecropolisInfluenceEvaluator`
- Produces:
  - `NecropolisRockCluster`: generates dark weathered granite rocks around the cemetery perimeter.
  - In `ChunkWorld._spawn_chunk_vegetation`:
    - Dampen standard living taiga vegetation within the influence zone by `profile.normal_vegetation_multiplier` (85% reduction).

- [x] **Step 1: Write unit test for vegetation dampening and dark rock clusters**

Create `tests/world_generator/test_necropolis_vegetation_dampening.gd`:
```gdscript
extends SceneTree

const _RockClusterScript = preload("res://src/world_generator/poi/necropolis_rock_cluster.gd")
const _ProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")
const _DungeonPOIScript = preload("res://src/world_generator/poi/dungeon_poi.gd")
const _DungeonIdentityScript = preload("res://src/world_generator/poi/dungeon_identity.gd")

class MockQuery extends RefCounted:
	func get_elevation(_x: int, _z: int) -> float:
		return 2.0
	func is_water(_x: int, _z: int) -> bool:
		return false

func _init() -> void:
	print("Running test_necropolis_vegetation_dampening...")
	var ident = _DungeonIdentityScript.new(&"necropolis_01", Vector2i(0, 0), 0, 555)
	var poi = _DungeonPOIScript.new(ident, Vector3(0.0, 2.0, 0.0), Transform3D.IDENTITY, &"necropolis", 1)
	var prof = _ProfileScript.new()
	var query = MockQuery.new()

	var rock_node = _RockClusterScript.generate_dark_rocks(poi, prof, query)
	assert(rock_node != null, "Rock cluster node must generate")
	var mmi = rock_node.get_node_or_null("DarkRocksMultiMesh") as MultiMeshInstance3D
	assert(mmi != null and mmi.multimesh != null, "Must contain DarkRocksMultiMesh")
	assert(mmi.multimesh.instance_count >= 2, "Must spawn dark rock clusters")
	
	rock_node.free()
	print("[PASS] test_necropolis_vegetation_dampening")
	quit(0)
```

- [x] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_necropolis_vegetation_dampening.gd`
Expected: FAIL

- [x] **Step 3: Implement `NecropolisRockCluster` and update `chunk_world.gd`**

Create `src/world_generator/poi/necropolis_rock_cluster.gd` to spawn dark tinted rock clusters.
In `src/world_generator/chunks/chunk_world.gd`:
In `_spawn_chunk_vegetation`, use `NecropolisInfluenceEvaluator.evaluate_point(...)` to cull standard living trees/shrubs in proportion to influence.

- [x] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_necropolis_vegetation_dampening.gd`
Expected: `[PASS] test_necropolis_vegetation_dampening`

- [x] **Step 5: Commit**

```bash
git add src/world_generator/poi/necropolis_rock_cluster.gd src/world_generator/chunks/chunk_world.gd tests/world_generator/test_necropolis_vegetation_dampening.gd
git commit -m "feat(poi): implement dark rock clusters and living vegetation dampening around necropolis"
```

---

### Task 6: End-to-End Composition & POI View Integration

**Files:**
- Modify: `src/world_generator/presentation/dungeon_entrance_poi_view.gd:60-110`
- Test: `tests/world_generator/test_necropolis_entrance_environment_e2e.gd`

**Interfaces:**
- Consumes: All components from Tasks 1-5 (`NecropolisEntranceProfile`, `BonePatchGenerator`, `DeadTreeSpawner`, `NecropolisRockCluster`)
- Produces: Complete atmospheric graveyard environment attached to `DungeonEntrancePOIView`.

- [x] **Step 1: Write the end-to-end integration test**

Create `tests/world_generator/test_necropolis_entrance_environment_e2e.gd`:
```gdscript
extends SceneTree

const _POIViewScript = preload("res://src/world_generator/presentation/dungeon_entrance_poi_view.gd")
const _DungeonPOIScript = preload("res://src/world_generator/poi/dungeon_poi.gd")
const _DungeonIdentityScript = preload("res://src/world_generator/poi/dungeon_identity.gd")

func _init() -> void:
	print("Running test_necropolis_entrance_environment_e2e...")
	var ident = _DungeonIdentityScript.new(&"necropolis_e2e_01", Vector2i(1, 1), 0, 88888)
	var poi = _DungeonPOIScript.new(ident, Vector3(32.0, 4.0, 32.0), Transform3D.IDENTITY, &"necropolis", 1)
	
	var view = _POIViewScript.new(poi)
	view._ready()

	assert(view.get_node_or_null("NecropolisModel") != null, "NecropolisModel must exist")
	assert(view.get_node_or_null("BonePatches") != null, "BonePatches node must be instantiated")
	assert(view.get_node_or_null("DeadTrees") != null, "DeadTrees node must be instantiated")
	assert(view.get_node_or_null("DarkRocks") != null, "DarkRocks node must be instantiated")
	assert(view.get_node_or_null("EntranceGlow") != null, "EntranceGlow must exist")

	view.free()
	print("[PASS] test_necropolis_entrance_environment_e2e")
	quit(0)
```

- [x] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_necropolis_entrance_environment_e2e.gd`
Expected: FAIL

- [x] **Step 3: Connect components in `DungeonEntrancePOIView`**

Update `src/world_generator/presentation/dungeon_entrance_poi_view.gd` to instantiate and attach `BonePatches`, `DeadTrees`, and `DarkRocks`.

- [x] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_necropolis_entrance_environment_e2e.gd`
Expected: `[PASS] test_necropolis_entrance_environment_e2e`

- [x] **Step 5: Run full existing test suite for regression verification**

Run:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/test_necropolis_entrance_poi_view.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s src/world_generator/tests/test_world_dungeon_pipeline_integration.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/test_chunk_foliage_multimesh_render.gd
```
Expected: All suites PASS.

- [x] **Step 6: Commit**

```bash
git add src/world_generator/presentation/dungeon_entrance_poi_view.gd tests/world_generator/test_necropolis_entrance_environment_e2e.gd
git commit -m "feat(poi): assemble complete necropolis entrance environment e2e"
```
