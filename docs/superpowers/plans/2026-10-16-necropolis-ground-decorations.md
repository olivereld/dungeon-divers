# Necropolis Exterior Ground Decoration & Dead Tree Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor Necropolis exterior decoration into a unified, deterministic ground placement architecture (`PoiGroundDecorationSpawner`), correct physical scale and density contracts for dead trees, integrate fallen wood props (stumps and logs) with relational micro-compositions, and modernize foliage filtering to support corrupted mushroom accents without code duplication.

**Architecture:** Maintain `NecropolisEntranceProfile` as the single environmental source of truth and `NecropolisInfluenceEvaluator` for annular corruption falloff. Decouple `DeadTreeSpawner` from hardcoded dimensions to use semantic height and density bounds while preserving its framing-sector composition. Introduce `PoiGroundDecorationSpawner` as a lightweight, deterministic MultiMesh scatterer parameterized by `DecorationSpec` for ground props (stumps, fallen logs, fungal clusters) with annular zoning, terrain alignment, clearance, and relational bias. Refactor `ChunkWorld` foliage filtering from naive string matching to semantic categories.

**Tech Stack:** Godot 4.6 GDScript, MultiMeshInstance3D, Transform3D, WorldSeedSystem determinism, ResourceLoader GLB baking.

**Spec:** User architecture guidance:
1. Fix `DeadTreeSpawner` contract: base mesh is 5.8m; profile defines `dead_tree_height_min: float = 4.8` and `dead_tree_height_max: float = 7.0`; scale = `height / 5.8`; instance count derived from `dead_tree_density`.
2. Consolidate secondary ground props into `PoiGroundDecorationSpawner` rather than individual spawners (`StumpSpawner`, `LogSpawner`, `MushroomSpawner`).
3. Fallen wood zoning: Core (0–5m) 0%, Funeral ground (5–12m) low, Corruption (12–22m) medium, Transition (22–40m) sparse.
4. Physical scales: Stumps (0.35–0.80m), Logs (1.5–4.0m with tilt/roll variation), Mushrooms (0.15–0.60m accent clusters).
5. Relational micro-compositions: dead trees -> nearby stumps -> fallen logs -> mushroom/bone clusters.
6. Semantic foliage filtering in `ChunkWorld`: stop blanket deletion of mushrooms; differentiate living flora vs. necrotic/corrupted flora.

## Global Constraints
- 100% deterministic: every POI generates identical prop transforms for the same world seed and macro coordinate.
- Zero new external assets: strictly reuse `models/nature/dead_tree/dead_tree_01.glb`, `models/nature/stump/STUMP.glb`, `models/nature/wood_log/wood_log.glb`, and `assets/texture/foliage/mushrooms/`.
- Clear ceremonial axis: 0% obstacle placement inside `entrance_clear_radius` (4.5m) and the frontal exit corridor (`is_in_frontal_corridor`).
- MultiMesh batching: all high-density ground props must use `MultiMeshInstance3D` to ensure solid performance.
- Independent testability: all test scripts run headlessly via Godot console (`Godot_v4.6.1-stable_win64_console.exe --headless -s <script>`) and exit with code 0.

---

### Task 1: Fix Scale & Density Contracts in `NecropolisEntranceProfile` and `DeadTreeSpawner`

**Files:**
- Modify: `src/world_generator/poi/necropolis_entrance_profile.gd:19-24`
- Modify: `src/world_generator/poi/dead_tree_spawner.gd:104-175`
- Test: `tests/world_generator/test_necropolis_entrance_profile.gd`
- Test: `tests/world_generator/test_dead_tree_spawner.gd`

**Interfaces:**
- Consumes: `NecropolisEntranceProfile`
- Produces: Corrected `DeadTreeSpawner.generate_dead_trees` adhering to profile height range `[4.8, 7.0]` and `dead_tree_density`.

- [x] **Step 1: Write the failing tests for updated profile and dead tree height calculation**

Update `tests/world_generator/test_necropolis_entrance_profile.gd`:
```gdscript
extends SceneTree

const _ProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")

func _init() -> void:
	print("Running test_necropolis_entrance_profile...")
	var prof = _ProfileScript.new()
	assert(prof != null, "Profile must instantiate")
	assert(prof.entrance_clear_radius == 4.5, "Clear radius must default to 4.5m")
	assert(prof.funeral_ground_radius == 12.0, "Funeral ground radius must default to 12.0m")
	assert(prof.corruption_radius == 22.0, "Corruption radius must default to 22.0m")
	assert(prof.transition_radius == 40.0, "Transition radius must default to 40.0m")

	# Dead trees semantic height bounds
	assert(prof.dead_tree_height_min == 4.8, "Dead tree height min must default to 4.8m")
	assert(prof.dead_tree_height_max == 7.0, "Dead tree height max must default to 7.0m")
	assert(prof.dead_tree_density == 0.25, "Dead tree density must default to 0.25")

	# Fallen wood profile parameters
	assert(prof.stump_density == 0.12, "Stump density must default to 0.12")
	assert(prof.stump_height_min == 0.35, "Stump height min must default to 0.35m")
	assert(prof.stump_height_max == 0.80, "Stump height max must default to 0.80m")
	assert(prof.log_density == 0.10, "Log density must default to 0.10")
	assert(prof.log_length_min == 1.5, "Log length min must default to 1.5m")
	assert(prof.log_length_max == 4.0, "Log length max must default to 4.0m")
	assert(prof.fallen_wood_min_distance == 2.0, "Fallen wood min distance must default to 2.0m")

	# Fungal accent parameters
	assert(prof.mushroom_density == 0.08, "Mushroom density must default to 0.08")
	assert(prof.mushroom_scale_min == 0.65, "Mushroom scale min must default to 0.65")
	assert(prof.mushroom_scale_max == 1.15, "Mushroom scale max must default to 1.15")

	print("[PASS] test_necropolis_entrance_profile")
	quit(0)
```

Update `tests/world_generator/test_dead_tree_spawner.gd`:
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
	
	var transforms: Array = mmi.get_meta("tree_transforms", [])
	assert(transforms.size() >= 3, "Must spawn trees according to density")
	
	const _EvaluatorScript = preload("res://src/world_generator/poi/necropolis_influence_evaluator.gd")
	for i in range(transforms.size()):
		var t: Transform3D = transforms[i]
		var dist = Vector2(t.origin.x, t.origin.z).length()
		assert(dist >= prof.entrance_clear_radius - 0.1, "Dead tree #%d is too close to entrance" % i)
		var in_corridor = _EvaluatorScript.is_in_frontal_corridor(Vector2(t.origin.x, t.origin.z), Vector2.ZERO, poi.orientation_deg, 8.5, 3.5)
		assert(not in_corridor, "Dead tree #%d must not block frontal corridor" % i)

		# Verify physical height: base mesh height is 5.8m
		var tree_scale = t.basis.get_scale().y
		var tree_height = tree_scale * 5.8
		assert(tree_height >= prof.dead_tree_height_min - 0.05 and tree_height <= prof.dead_tree_height_max + 0.05,
			"Tree #%d height %.2fm outside [%.2f, %.2f]" % [i, tree_height, prof.dead_tree_height_min, prof.dead_tree_height_max])

	# Test density scaling
	prof.dead_tree_density = 0.05
	var low_density_node = _SpawnerScript.generate_dead_trees(poi, prof, query)
	var low_mmi = low_density_node.get_node_or_null("DeadTreesMultiMesh") as MultiMeshInstance3D
	var low_transforms: Array = low_mmi.get_meta("tree_transforms", []) if low_mmi != null else []
	assert(low_transforms.size() < transforms.size(), "Lower density must yield fewer trees")

	node.free()
	if low_density_node != null:
		low_density_node.free()
	print("[PASS] test_dead_tree_spawner")
	quit(0)
```

- [x] **Step 2: Run tests to verify they fail**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_necropolis_entrance_profile.gd`
Expected: FAIL (missing `dead_tree_height_min`, `stump_density`, etc.)

- [x] **Step 3: Update `NecropolisEntranceProfile` and `DeadTreeSpawner`**

In `src/world_generator/poi/necropolis_entrance_profile.gd`:
```gdscript
class_name NecropolisEntranceProfile
extends Resource

## Parámetros de configuración ambiental para el entorno exterior de la entrada de Necrópolis.
## Define radios concéntricos de influencia, densidades y magnitudes físicas semánticas.

@export_group("Radii")
@export var entrance_clear_radius: float = 4.5
@export var funeral_ground_radius: float = 12.0
@export var corruption_radius: float = 22.0
@export var transition_radius: float = 40.0

@export_group("Bone Patches")
@export var bone_patch_density: float = 0.45
@export var bone_patch_min_distance: float = 2.0
@export var bone_patch_scale_min: float = 0.7
@export var bone_patch_scale_max: float = 1.15

@export_group("Dead Trees")
@export var dead_tree_density: float = 0.25
@export var dead_tree_min_distance: float = 4.0
@export var dead_tree_height_min: float = 4.8
@export var dead_tree_height_max: float = 7.0

@export_group("Fallen Wood")
@export var stump_density: float = 0.12
@export var stump_height_min: float = 0.35
@export var stump_height_max: float = 0.80
@export var log_density: float = 0.10
@export var log_length_min: float = 1.5
@export var log_length_max: float = 4.0
@export var fallen_wood_min_distance: float = 2.0

@export_group("Fungal Accents")
@export var mushroom_density: float = 0.08
@export var mushroom_scale_min: float = 0.65
@export var mushroom_scale_max: float = 1.15
@export var mushroom_cluster_radius: float = 1.5

@export_group("Rocks and Atmosphere")
@export var dark_rock_density: float = 0.30
@export var normal_vegetation_multiplier: float = 0.15
@export var noise_frequency: float = 0.08
@export var ambient_darkening: float = 0.35
```

In `src/world_generator/poi/dead_tree_spawner.gd`:
Update `target_count` and scale resolution to use profile:
```gdscript
	var density: float = profile.dead_tree_density if "dead_tree_density" in profile else 0.25
	var h_min: float = profile.dead_tree_height_min if "dead_tree_height_min" in profile else 4.8
	var h_max: float = profile.dead_tree_height_max if "dead_tree_height_max" in profile else 7.0
	const BASE_MESH_HEIGHT: float = 5.8

	# Target count proportionally scales from dead_tree_density
	# density 0.25 -> 4 to 5 trees; density 0.05 -> 1 to 2 trees; density 0.50 -> 6 trees
	var max_candidates: int = framing_sectors.size()
	var base_count: int = clampi(int(round(float(max_candidates) * (density / 0.30))), 1, max_candidates)
	var target_count: int = clampi(base_count + rng.randi_range(-1, 0), 1, max_candidates)
```
And replace the scale sampling:
```gdscript
			var target_height: float = rng.randf_range(h_min, h_max)
			var s: float = target_height / BASE_MESH_HEIGHT
			var rot_y: float = rng.randf() * TAU

			var t := Transform3D()
			t = t.scaled(Vector3.ONE * s)
			t = t.rotated(Vector3.UP, rot_y)
			t.origin = Vector3(wx - poi_pos.x, wy - poi_pos.y, wz - poi_pos.z)
```

- [x] **Step 4: Run tests to verify they pass**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_necropolis_entrance_profile.gd`
Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_dead_tree_spawner.gd`
Expected: PASS with `[PASS] test_necropolis_entrance_profile` and `[PASS] test_dead_tree_spawner`.

- [x] **Step 5: Commit**

```bash
git add src/world_generator/poi/necropolis_entrance_profile.gd src/world_generator/poi/dead_tree_spawner.gd tests/world_generator/test_necropolis_entrance_profile.gd tests/world_generator/test_dead_tree_spawner.gd
git commit -m "fix(poi): align DeadTreeSpawner scale and density with NecropolisEntranceProfile"
```

---

### Task 2: Deterministic Ground Decoration Scatterer (`PoiGroundDecorationSpawner`)

**Files:**
- Create: `src/world_generator/poi/poi_ground_decoration_spawner.gd`
- Test: `tests/world_generator/test_poi_ground_decoration_spawner.gd`

**Interfaces:**
- Consumes: `NecropolisEntranceProfile`, `NecropolisInfluenceEvaluator`
- Produces: `PoiGroundDecorationSpawner` capable of instantiating batched MultiMesh ground props according to concentric annular zones with clearance checks.

- [x] **Step 1: Write unit test for `PoiGroundDecorationSpawner`**

Create `tests/world_generator/test_poi_ground_decoration_spawner.gd`:
```gdscript
extends SceneTree

const _ScattererScript = preload("res://src/world_generator/poi/poi_ground_decoration_spawner.gd")
const _ProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")
const _DungeonPOIScript = preload("res://src/world_generator/poi/dungeon_poi.gd")
const _DungeonIdentityScript = preload("res://src/world_generator/poi/dungeon_identity.gd")

class MockQuery extends RefCounted:
	func get_elevation(_x: int, _z: int) -> float:
		return 3.0
	func is_water(_x: int, _z: int) -> bool:
		return false

func _init() -> void:
	print("Running test_poi_ground_decoration_spawner...")
	var ident = _DungeonIdentityScript.new(&"necropolis_01", Vector2i(0, 0), 0, 888)
	var poi = _DungeonPOIScript.new(ident, Vector3(0.0, 3.0, 0.0), Transform3D.IDENTITY, &"necropolis", 1)
	var prof = _ProfileScript.new()
	var query = MockQuery.new()

	var test_box := BoxMesh.new()
	test_box.size = Vector3(1.0, 0.5, 2.0)

	var spec := _ScattererScript.DecorationSpec.new()
	spec.id = "test_prop"
	spec.mesh = test_box
	spec.density = 0.20
	spec.min_distance = 2.5
	spec.scale_min = 0.8
	spec.scale_max = 1.2
	spec.radius_min = 5.0
	spec.radius_max = 20.0
	spec.forbidden_radius = prof.entrance_clear_radius

	var container = _ScattererScript.scatter_decorations(poi, prof, query, [spec])
	assert(container != null, "Container must generate")
	var mmi = container.get_node_or_null("MultiMesh_test_prop") as MultiMeshInstance3D
	assert(mmi != null, "MultiMesh_test_prop must be created")
	assert(mmi.multimesh != null, "MultiMesh must be assigned")
	assert(mmi.multimesh.instance_count > 0, "Must place instances")

	var transforms: Array = mmi.get_meta("placed_transforms", [])
	const _EvaluatorScript = preload("res://src/world_generator/poi/necropolis_influence_evaluator.gd")
	for i in range(transforms.size()):
		var t: Transform3D = transforms[i]
		var dist = Vector2(t.origin.x, t.origin.z).length()
		assert(dist >= prof.entrance_clear_radius, "Instance #%d too close to entrance" % i)
		assert(not _EvaluatorScript.is_in_frontal_corridor(Vector2(t.origin.x, t.origin.z), Vector2.ZERO, poi.orientation_deg),
			"Instance #%d inside frontal corridor" % i)

	# Verify determinism: same seed produces identical transforms
	var container2 = _ScattererScript.scatter_decorations(poi, prof, query, [spec])
	var mmi2 = container2.get_node_or_null("MultiMesh_test_prop") as MultiMeshInstance3D
	assert(mmi2.multimesh.instance_count == mmi.multimesh.instance_count, "Instance counts must match across identical seed")

	container.free()
	container2.free()
	print("[PASS] test_poi_ground_decoration_spawner")
	quit(0)
```

- [x] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_poi_ground_decoration_spawner.gd`
Expected: FAIL (missing `poi_ground_decoration_spawner.gd`)

- [x] **Step 3: Implement `PoiGroundDecorationSpawner`**

Create `src/world_generator/poi/poi_ground_decoration_spawner.gd`:
```gdscript
class_name PoiGroundDecorationSpawner
extends RefCounted

## Spawner determinista y modular de decoración exterior de terreno para POIs.
## Utiliza MultiMeshInstance3D y especificaciones de colocación por anillos concéntricos
## (clearance, zona funeraria, corrupción y transición) con validación de pendiente y agua.

const _EvaluatorScript = preload("res://src/world_generator/poi/necropolis_influence_evaluator.gd")

class DecorationSpec extends RefCounted:
	var id: String = "prop"
	var mesh: Mesh = null
	var material: Material = null
	var density: float = 0.10
	var min_distance: float = 2.0
	var scale_min: float = 0.8
	var scale_max: float = 1.2
	var radius_min: float = 5.0
	var radius_max: float = 25.0
	var forbidden_radius: float = 4.5
	var max_slope: float = 25.0
	var allow_frontal_corridor: bool = false
	var align_to_terrain: bool = false
	var tilt_max_deg: float = 12.0
	var ground_embed_m: float = 0.05
	var cluster_anchor_points: Array[Vector2] = []
	var cluster_bias: float = 0.0

static func scatter_decorations(
	poi: RefCounted,
	profile: RefCounted,
	world_query: Object,
	specs: Array
) -> Node3D:
	var container := Node3D.new()
	container.name = "GroundDecorations"

	var seed_val: int = poi.identity.dungeon_seed if (poi != null and "identity" in poi and poi.identity != null and "dungeon_seed" in poi.identity) else 12345
	var poi_pos: Vector3 = poi.world_position if (poi != null and "world_position" in poi) else Vector3.ZERO
	var ori_deg: float = poi.orientation_deg if (poi != null and "orientation_deg" in poi) else 0.0

	var global_placed_points: Array[Vector2] = []

	for spec_obj in specs:
		var spec: DecorationSpec = spec_obj as DecorationSpec
		if spec == null or spec.mesh == null or spec.density <= 0.0:
			continue

		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val ^ (spec.id.hash() & 0x7FFFFFFF)

		# Cantidad objetivo proporcional al área anular y la densidad
		var inner_r: float = maxf(spec.radius_min, spec.forbidden_radius)
		var outer_r: float = spec.radius_max
		var ring_area: float = PI * (outer_r * outer_r - inner_r * inner_r)
		var target_count: int = clampi(int(round(ring_area * spec.density * 0.035)), 1, 60)

		var transforms: Array[Transform3D] = []
		var placed_for_spec: Array[Vector2] = []
		var max_attempts: int = target_count * 14

		for attempt in range(max_attempts):
			if transforms.size() >= target_count:
				break

			var sample_pos_2d: Vector2
			if not spec.cluster_anchor_points.is_empty() and rng.randf() < spec.cluster_bias:
				var anchor: Vector2 = spec.cluster_anchor_points[rng.randi() % spec.cluster_anchor_points.size()]
				var offset_ang: float = rng.randf() * TAU
				var offset_dist: float = rng.randf_range(0.8, 3.2)
				sample_pos_2d = anchor + Vector2(cos(offset_ang), sin(offset_ang)) * offset_dist
			else:
				var ang: float = rng.randf() * TAU
				var dist: float = sqrt(rng.randf_range(inner_r * inner_r, outer_r * outer_r))
				sample_pos_2d = Vector2(poi_pos.x + cos(ang) * dist, poi_pos.z + sin(ang) * dist)

			var d_poi: float = (sample_pos_2d - Vector2(poi_pos.x, poi_pos.z)).length()
			if d_poi < spec.forbidden_radius:
				continue

			if not spec.allow_frontal_corridor:
				if _EvaluatorScript.is_in_frontal_corridor(sample_pos_2d, Vector2(poi_pos.x, poi_pos.z), ori_deg, 8.5, 3.5):
					continue

			# Espaciado mínimo
			var too_close := false
			for pt in placed_for_spec:
				if (pt - sample_pos_2d).length() < spec.min_distance:
					too_close = true
					break
			if too_close:
				continue

			var wx: int = int(round(sample_pos_2d.x))
			var wz: int = int(round(sample_pos_2d.y))

			# Hidrología y pendiente
			if world_query != null and world_query.has_method("is_water") and world_query.is_water(wx, wz):
				continue
			if world_query != null and world_query.has_method("get_slope") and world_query.get_slope(wx, wz) > spec.max_slope:
				continue

			var wy: float = poi_pos.y
			var ground_normal := Vector3.UP
			if world_query != null and world_query.has_method("get_elevation"):
				wy = world_query.get_elevation(wx, wz)
				var h_e: float = world_query.get_elevation(wx + 1, wz)
				var h_s: float = world_query.get_elevation(wx, wz + 1)
				ground_normal = Vector3(wy - h_e, 1.0, wy - h_s).normalized()

			var s: float = rng.randf_range(spec.scale_min, spec.scale_max)
			var rot_y: float = rng.randf() * TAU

			var t := Transform3D()
			t = t.scaled(Vector3.ONE * s)
			t = t.rotated(Vector3.UP, rot_y)

			if spec.align_to_terrain and ground_normal.dot(Vector3.UP) < 0.999:
				var align_axis: Vector3 = Vector3.UP.cross(ground_normal).normalized()
				var align_angle: float = minf(acos(clampf(Vector3.UP.dot(ground_normal), -1.0, 1.0)), deg_to_rad(spec.tilt_max_deg))
				if align_axis.length_squared() > 0.001:
					t.basis = Basis(align_axis, align_angle) * t.basis

			if spec.tilt_max_deg > 0.0 and not spec.align_to_terrain:
				var pitch: float = deg_to_rad(rng.randf_range(-spec.tilt_max_deg, spec.tilt_max_deg))
				var roll: float = deg_to_rad(rng.randf_range(-spec.tilt_max_deg, spec.tilt_max_deg))
				t = t.rotated_local(Vector3.RIGHT, pitch)
				t = t.rotated_local(Vector3.FORWARD, roll)

			t.origin = Vector3(sample_pos_2d.x - poi_pos.x, wy - poi_pos.y - spec.ground_embed_m, sample_pos_2d.y - poi_pos.z)

			transforms.append(t)
			placed_for_spec.append(sample_pos_2d)
			global_placed_points.append(sample_pos_2d)

		if not transforms.is_empty():
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "MultiMesh_" + spec.id
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = spec.mesh
			mm.instance_count = transforms.size()

			for i in range(transforms.size()):
				mm.set_instance_transform(i, transforms[i])

			mmi.multimesh = mm
			if spec.material != null:
				mmi.material_override = spec.material
			mmi.set_meta("placed_transforms", transforms)
			container.add_child(mmi)

	return container
```

- [x] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_poi_ground_decoration_spawner.gd`
Expected: PASS with `[PASS] test_poi_ground_decoration_spawner`.

- [x] **Step 5: Commit**

```bash
git add src/world_generator/poi/poi_ground_decoration_spawner.gd tests/world_generator/test_poi_ground_decoration_spawner.gd
git commit -m "feat(poi): implement modular PoiGroundDecorationSpawner for deterministic MultiMesh scatter"
```

---

### Task 3: Fallen Wood Props (Stumps & Wood Logs) Integration

**Files:**
- Create: `src/world_generator/poi/necropolis_wood_props.gd`
- Test: `tests/world_generator/test_necropolis_fallen_wood.gd`

**Interfaces:**
- Consumes: `models/nature/stump/STUMP.glb`, `models/nature/wood_log/wood_log.glb`, `PoiGroundDecorationSpawner`
- Produces: `NecropolisWoodProps.build_specs(profile, tree_transforms)` returning calibrated `DecorationSpec` array for stumps and fallen logs.

- [x] **Step 1: Write the failing unit test for fallen wood generation**

Create `tests/world_generator/test_necropolis_fallen_wood.gd`:
```gdscript
extends SceneTree

const _WoodPropsScript = preload("res://src/world_generator/poi/necropolis_wood_props.gd")
const _ScattererScript = preload("res://src/world_generator/poi/poi_ground_decoration_spawner.gd")
const _ProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")
const _DungeonPOIScript = preload("res://src/world_generator/poi/dungeon_poi.gd")
const _DungeonIdentityScript = preload("res://src/world_generator/poi/dungeon_identity.gd")

class MockQuery extends RefCounted:
	func get_elevation(_x: int, _z: int) -> float:
		return 2.5
	func is_water(_x: int, _z: int) -> bool:
		return false
	func get_slope(_x: int, _z: int) -> float:
		return 3.0

func _init() -> void:
	print("Running test_necropolis_fallen_wood...")
	var ident = _DungeonIdentityScript.new(&"necropolis_01", Vector2i(0, 0), 0, 777)
	var poi = _DungeonPOIScript.new(ident, Vector3(0.0, 2.5, 0.0), Transform3D.IDENTITY, &"necropolis", 1)
	var prof = _ProfileScript.new()
	var query = MockQuery.new()

	var dummy_tree_pos := [Vector2(8.0, 4.0), Vector2(-7.0, -8.0)]
	var specs = _WoodPropsScript.build_specs(prof, dummy_tree_pos)
	assert(specs.size() >= 2, "Must build specs for stumps and logs")

	var container = _ScattererScript.scatter_decorations(poi, prof, query, specs)
	assert(container != null, "Container must generate")

	var stump_mmi = container.get_node_or_null("MultiMesh_stump") as MultiMeshInstance3D
	var log_mmi = container.get_node_or_null("MultiMesh_wood_log") as MultiMeshInstance3D

	assert(stump_mmi != null and stump_mmi.multimesh.instance_count > 0, "Stumps must spawn")
	assert(log_mmi != null and log_mmi.multimesh.instance_count > 0, "Wood logs must spawn")

	var log_transforms: Array = log_mmi.get_meta("placed_transforms", [])
	for i in range(log_transforms.size()):
		var t: Transform3D = log_transforms[i]
		var dist = Vector2(t.origin.x, t.origin.z).length()
		assert(dist >= prof.entrance_clear_radius, "Log #%d must not block crypt door" % i)

	container.free()
	print("[PASS] test_necropolis_fallen_wood")
	quit(0)
```

- [x] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_necropolis_fallen_wood.gd`
Expected: FAIL (missing `necropolis_wood_props.gd`)

- [x] **Step 3: Implement `NecropolisWoodProps`**

Create `src/world_generator/poi/necropolis_wood_props.gd`:
```gdscript
class_name NecropolisWoodProps
extends RefCounted

## Proveedor y configurador de mallas y especificaciones de tocones y troncos caídos
## para el entorno exterior de Necrópolis.

const _ScattererScript = preload("res://src/world_generator/poi/poi_ground_decoration_spawner.gd")
const _WorldRendererScript = preload("res://src/world_renderer/world_renderer.gd")

const STUMP_GLB_PATH: String = "res://models/nature/stump/STUMP.glb"
const STUMP_TEX_PATH: String = "res://models/nature/stump/STUMP_stump.png"
const WOOD_LOG_GLB_PATH: String = "res://models/nature/wood_log/wood_log.glb"
const WOOD_LOG_TEX_PATH: String = "res://models/nature/wood_log/wood_log_tree_log.png"

static var _cached_stump_mesh: Mesh = null
static var _cached_log_mesh: Mesh = null

static func get_stump_mesh() -> Mesh:
	if _cached_stump_mesh != null:
		return _cached_stump_mesh
	_cached_stump_mesh = _WorldRendererScript._create_stump_mesh()
	return _cached_stump_mesh

static func get_log_mesh() -> Mesh:
	if _cached_log_mesh != null:
		return _cached_log_mesh
	_cached_log_mesh = _WorldRendererScript._create_wood_log_mesh()
	return _cached_log_mesh

static func build_specs(profile: RefCounted, tree_anchor_points: Array = []) -> Array:
	var specs: Array = []

	var stump_mesh := get_stump_mesh()
	var log_mesh := get_log_mesh()

	# 1. Stumps (Tocones): anclados cerca de árboles muertos y en la zona funeraria/corrupción
	var stump_spec := _ScattererScript.DecorationSpec.new()
	stump_spec.id = "stump"
	stump_spec.mesh = stump_mesh
	stump_spec.density = profile.stump_density if "stump_density" in profile else 0.12
	stump_spec.min_distance = profile.fallen_wood_min_distance if "fallen_wood_min_distance" in profile else 2.0
	stump_spec.scale_min = 0.85
	stump_spec.scale_max = 1.35
	stump_spec.radius_min = profile.entrance_clear_radius + 1.0
	stump_spec.radius_max = profile.corruption_radius + 4.0
	stump_spec.forbidden_radius = profile.entrance_clear_radius
	stump_spec.ground_embed_m = 0.08
	stump_spec.align_to_terrain = true
	stump_spec.tilt_max_deg = 8.0
	stump_spec.cluster_anchor_points = tree_anchor_points
	stump_spec.cluster_bias = 0.45
	specs.append(stump_spec)

	# 2. Fallen Wood Logs (Troncos caídos): más densos en la zona de corrupción, orientados naturalmente
	var log_spec := _ScattererScript.DecorationSpec.new()
	log_spec.id = "wood_log"
	log_spec.mesh = log_mesh
	log_spec.density = profile.log_density if "log_density" in profile else 0.10
	log_spec.min_distance = profile.fallen_wood_min_distance if "fallen_wood_min_distance" in profile else 2.0
	log_spec.scale_min = 0.90
	log_spec.scale_max = 1.60
	log_spec.radius_min = profile.funeral_ground_radius - 2.0
	log_spec.radius_max = profile.transition_radius
	log_spec.forbidden_radius = profile.entrance_clear_radius + 0.5
	log_spec.ground_embed_m = 0.10
	log_spec.align_to_terrain = true
	log_spec.tilt_max_deg = 14.0
	log_spec.cluster_anchor_points = tree_anchor_points
	log_spec.cluster_bias = 0.30
	specs.append(log_spec)

	return specs
```

- [x] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_necropolis_fallen_wood.gd`
Expected: PASS with `[PASS] test_necropolis_fallen_wood`.

- [x] **Step 5: Commit**

```bash
git add src/world_generator/poi/necropolis_wood_props.gd tests/world_generator/test_necropolis_fallen_wood.gd
git commit -m "feat(poi): configure NecropolisWoodProps with stump and log mesh baking and relational specs"
```

---

### Task 4: Fungal Accents & Semantic Foliage Filtering in ChunkWorld

**Files:**
- Modify: `src/world_generator/chunks/chunk_world.gd:493-545`
- Create: `src/world_generator/poi/necropolis_mushroom_cluster.gd`
- Test: `tests/world_generator/test_necropolis_mushroom_accents.gd`

**Interfaces:**
- Consumes: `assets/texture/foliage/mushrooms/`, `PoiGroundDecorationSpawner`
- Produces: `NecropolisMushroomCluster.build_specs()` and semantic foliage filtering allowing necrotic/corrupted flora while eliminating lush flowers in the Necropolis zone.

- [x] **Step 1: Write the failing unit test for mushroom accents and semantic foliage**

Create `tests/world_generator/test_necropolis_mushroom_accents.gd`:
```gdscript
extends SceneTree

const _MushroomClusterScript = preload("res://src/world_generator/poi/necropolis_mushroom_cluster.gd")
const _ScattererScript = preload("res://src/world_generator/poi/poi_ground_decoration_spawner.gd")
const _ProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")
const _DungeonPOIScript = preload("res://src/world_generator/poi/dungeon_poi.gd")
const _DungeonIdentityScript = preload("res://src/world_generator/poi/dungeon_identity.gd")

class MockQuery extends RefCounted:
	func get_elevation(_x: int, _z: int) -> float:
		return 1.0
	func is_water(_x: int, _z: int) -> bool:
		return false
	func get_slope(_x: int, _z: int) -> float:
		return 2.0

func _init() -> void:
	print("Running test_necropolis_mushroom_accents...")
	var ident = _DungeonIdentityScript.new(&"necropolis_01", Vector2i(0, 0), 0, 555)
	var poi = _DungeonPOIScript.new(ident, Vector3(0.0, 1.0, 0.0), Transform3D.IDENTITY, &"necropolis", 1)
	var prof = _ProfileScript.new()
	var query = MockQuery.new()

	var dummy_anchors := [Vector2(6.0, 5.0), Vector2(-5.0, 7.0)]
	var specs = _MushroomClusterScript.build_specs(prof, dummy_anchors)
	assert(not specs.is_empty(), "Must build mushroom accent specs")

	var container = _ScattererScript.scatter_decorations(poi, prof, query, specs)
	assert(container != null, "Container must generate")

	var mush_mmi = container.get_node_or_null("MultiMesh_necropolis_mushrooms") as MultiMeshInstance3D
	assert(mush_mmi != null and mush_mmi.multimesh.instance_count > 0, "Mushrooms must spawn")

	var transforms: Array = mush_mmi.get_meta("placed_transforms", [])
	for i in range(transforms.size()):
		var t: Transform3D = transforms[i]
		var dist = Vector2(t.origin.x, t.origin.z).length()
		assert(dist >= prof.entrance_clear_radius, "Mushroom #%d must respect clear radius" % i)

	container.free()
	print("[PASS] test_necropolis_mushroom_accents")
	quit(0)
```

- [x] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_necropolis_mushroom_accents.gd`
Expected: FAIL (missing `necropolis_mushroom_cluster.gd`)

- [x] **Step 3: Implement `NecropolisMushroomCluster` and refactor `ChunkWorld` foliage filtering**

Create `src/world_generator/poi/necropolis_mushroom_cluster.gd`:
```gdscript
class_name NecropolisMushroomCluster
extends RefCounted

## Generador de micro-racimos de hongos corruptos/necróticos (0.15m–0.60m)
## para acentuar tocones, troncos caídos y rocas oscuras de la Necrópolis.

const _ScattererScript = preload("res://src/world_generator/poi/poi_ground_decoration_spawner.gd")
const MUSHROOM_TEX_PATH: String = "res://assets/texture/foliage/mushrooms/mushroom_budge_1.jpg"

static var _cached_mesh: Mesh = null
static var _cached_mat: StandardMaterial3D = null

static func get_mushroom_mesh() -> Mesh:
	if _cached_mesh != null:
		return _cached_mesh

	# Crear quad vertical doble cruzado (estilo billboard foliage de bajo perfil)
	var arr_mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	var w: float = 0.40
	var h: float = 0.35

	# Plano 1 (Z)
	verts.append(Vector3(-w * 0.5, 0.0, 0.0))
	verts.append(Vector3(w * 0.5, 0.0, 0.0))
	verts.append(Vector3(w * 0.5, h, 0.0))
	verts.append(Vector3(-w * 0.5, h, 0.0))
	for _i in range(4):
		normals.append(Vector3.UP)
	uvs.append(Vector2(0, 1))
	uvs.append(Vector2(1, 1))
	uvs.append(Vector2(1, 0))
	uvs.append(Vector2(0, 0))
	indices.append_array([0, 1, 2, 0, 2, 3])

	# Plano 2 (X) cruzado a 90°
	verts.append(Vector3(0.0, 0.0, -w * 0.5))
	verts.append(Vector3(0.0, 0.0, w * 0.5))
	verts.append(Vector3(0.0, h, w * 0.5))
	verts.append(Vector3(0.0, h, -w * 0.5))
	for _i in range(4):
		normals.append(Vector3.UP)
	uvs.append(Vector2(0, 1))
	uvs.append(Vector2(1, 1))
	uvs.append(Vector2(1, 0))
	uvs.append(Vector2(0, 0))
	indices.append_array([4, 5, 6, 4, 6, 7])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cached_mesh = arr_mesh
	return _cached_mesh

static func get_material() -> StandardMaterial3D:
	if _cached_mat != null:
		return _cached_mat
	var mat := StandardMaterial3D.new()
	if ResourceLoader.exists(MUSHROOM_TEX_PATH):
		mat.albedo_texture = load(MUSHROOM_TEX_PATH) as Texture2D
	mat.albedo_color = Color(0.68, 0.65, 0.72) # Matiz pálido/micótico frío
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.35
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_cached_mat = mat
	return _cached_mat

static func build_specs(profile: RefCounted, anchor_points: Array = []) -> Array:
	var spec := _ScattererScript.DecorationSpec.new()
	spec.id = "necropolis_mushrooms"
	spec.mesh = get_mushroom_mesh()
	spec.material = get_material()
	spec.density = profile.mushroom_density if "mushroom_density" in profile else 0.08
	spec.min_distance = 1.0
	spec.scale_min = profile.mushroom_scale_min if "mushroom_scale_min" in profile else 0.65
	spec.scale_max = profile.mushroom_scale_max if "mushroom_scale_max" in profile else 1.15
	spec.radius_min = profile.entrance_clear_radius + 0.8
	spec.radius_max = profile.corruption_radius + 6.0
	spec.forbidden_radius = profile.entrance_clear_radius
	spec.ground_embed_m = 0.02
	spec.align_to_terrain = true
	spec.cluster_anchor_points = anchor_points
	spec.cluster_bias = 0.65 # Fuerte atracción hacia tocones, troncos y rocas

	return [spec]
```

In `src/world_generator/chunks/chunk_world.gd` (around line 493):
Replace:
```gdscript
var is_flower_or_shroom: bool = (sp_id != &"grass" and not String(sp_id).begins_with("grass"))
```
With semantic classification:
```gdscript
var sp_str: String = String(sp_id).to_lower()
var is_flower: bool = sp_str.contains("flower")
var is_living_shroom: bool = sp_str.contains("mushroom") and not sp_str.contains("corrupt") and not sp_str.contains("necro")
var is_vital_flora: bool = is_flower or is_living_shroom
```
And replace the culling condition (line 524):
```gdscript
# En la Necrópolis: flores y hongos vivos mueren dentro de la zona de corrupción (< 22m),
# mientras que la flora corrupta o decorativa adaptada puede prevalecer.
if is_vital_flora and raw_dist <= nec_profile.corruption_radius:
	cull_foliage = true
	break
```

- [x] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_necropolis_mushroom_accents.gd`
Expected: PASS with `[PASS] test_necropolis_mushroom_accents`.

- [x] **Step 5: Commit**

```bash
git add src/world_generator/poi/necropolis_mushroom_cluster.gd src/world_generator/chunks/chunk_world.gd tests/world_generator/test_necropolis_mushroom_accents.gd
git commit -m "feat(poi): add NecropolisMushroomCluster and semantic flora classification in ChunkWorld"
```

---

### Task 5: Integration in `DungeonEntrancePOIView` and End-to-End Validation

**Files:**
- Modify: `src/world_generator/presentation/dungeon_entrance_poi_view.gd:13-20,130-155`
- Test: `tests/world_generator/test_necropolis_entrance_environment_e2e.gd`

**Interfaces:**
- Consumes: `DeadTreeSpawner`, `BonePatchGenerator`, `NecropolisRockCluster`, `NecropolisWoodProps`, `NecropolisMushroomCluster`, `PoiGroundDecorationSpawner`
- Produces: Complete, cohesive Necropolis exterior scene with structural framing trees, rocks, bone patches, stumps, logs, and mushroom accents.

- [x] **Step 1: Update e2e test to verify ground decorations are present in POI view**

In `tests/world_generator/test_necropolis_entrance_environment_e2e.gd`:
Add assertions ensuring `GroundDecorations` node exists and contains `MultiMesh_stump`, `MultiMesh_wood_log`, and `MultiMesh_necropolis_mushrooms`:
```gdscript
	# Verify ground decorations (stumps, wood logs, mushroom accents)
	var ground_decos = view.get_node_or_null("GroundDecorations")
	assert(ground_decos != null, "GroundDecorations node must be present in POI view")
	assert(ground_decos.has_node("MultiMesh_stump"), "Must include stump MultiMesh")
	assert(ground_decos.has_node("MultiMesh_wood_log"), "Must include wood log MultiMesh")
	assert(ground_decos.has_node("MultiMesh_necropolis_mushrooms"), "Must include mushroom MultiMesh")
```

- [x] **Step 2: Run test to verify it fails**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_necropolis_entrance_environment_e2e.gd`
Expected: FAIL (missing `GroundDecorations` in view)

- [x] **Step 3: Integrate ground decorations into `DungeonEntrancePOIView`**

In `src/world_generator/presentation/dungeon_entrance_poi_view.gd`:
Add preloads:
```gdscript
const _WoodPropsScript = preload("res://src/world_generator/poi/necropolis_wood_props.gd")
const _MushroomClusterScript = preload("res://src/world_generator/poi/necropolis_mushroom_cluster.gd")
const _GroundScattererScript = preload("res://src/world_generator/poi/poi_ground_decoration_spawner.gd")
```
In `_generate_entrance_view()`:
Collect anchor points from dead trees and rocks for micro-compositions:
```gdscript
	var anchor_points: Array[Vector2] = []
	if dead_trees != null:
		var tree_mmi = dead_trees.get_node_or_null("DeadTreesMultiMesh") as MultiMeshInstance3D
		if tree_mmi != null:
			var tree_xforms: Array = tree_mmi.get_meta("tree_transforms", [])
			for t in tree_xforms:
				anchor_points.append(Vector2(poi.world_position.x + t.origin.x, poi.world_position.z + t.origin.z))

	# Generar decoración determinista de suelo (tocones, troncos caídos y racimos de hongos)
	var wood_specs = _WoodPropsScript.build_specs(profile, anchor_points)
	var mush_specs = _MushroomClusterScript.build_specs(profile, anchor_points)
	var all_ground_specs := []
	all_ground_specs.append_array(wood_specs)
	all_ground_specs.append_array(mush_specs)

	var ground_decos = _GroundScattererScript.scatter_decorations(poi, profile, world_query, all_ground_specs)
	if ground_decos != null:
		add_child(ground_decos)
```

- [x] **Step 4: Run test to verify it passes**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_necropolis_entrance_environment_e2e.gd`
Expected: PASS with `[PASS] test_necropolis_entrance_environment_e2e`.

- [x] **Step 5: Run full suite of related tests**

Run:
```bash
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_necropolis_entrance_profile.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_dead_tree_spawner.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_poi_ground_decoration_spawner.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_necropolis_fallen_wood.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_necropolis_mushroom_accents.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s tests/world_generator/test_necropolis_entrance_environment_e2e.gd
```
Expected: All tests pass with exit code 0.

- [x] **Step 6: Commit**

```bash
git add src/world_generator/presentation/dungeon_entrance_poi_view.gd tests/world_generator/test_necropolis_entrance_environment_e2e.gd
git commit -m "feat(poi): assemble fallen wood and fungal micro-compositions in DungeonEntrancePOIView"
```
