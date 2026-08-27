# WallSection: Procedural Wall Partitioning & Profile-Driven Wall Variants Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Evolve the wall geometry pipeline from monolithic component meshes into discrete, profile-driven `WallSection` units that support deterministic visual variants (e.g. cracked, ornate, damaged) and selective camera occlusion fading without fading the entire dungeon.

**Architecture:** Introduce `WallSection` as the discrete procedural wall unit extracted from `WallComponent` loops and chains. `WallSectionExtractor` partitions boundary loops at corners, doors, and length intervals (e.g. 2-6 tiles). `WallVariantResolver` deterministically assigns visual variants based on room-specific JSON policies. `WallGeometryBuilder` generates independent `GeneratedMesh` and collision instances per section, enabling isolated camera occlusion fading.

**Tech Stack:** Godot 4.6 GDScript, SurfaceTool, ArrayMesh, Compound Collision Shapes, PhysicsRayQueryParameters3D.

**Spec:** User request and architectural specification for discrete wall sections, JSON-driven variant policies, and selective occlusion.

## Global Constraints
- Strictly maintain separation of concerns: JSON defines WHAT and HOW MUCH (variants, weights, section bounds); Algorithm defines HOW and WHERE (extraction, miter joints, collision, raycast occlusion).
- Preserve existing `build_component_mesh()` during migration so legacy pipelines don't break.
- No monolithic `ContinuousWalls` merging when section presentation is active; each section receives its own `MeshInstance3D` and collider in `CAMERA_OCCLUDER_GROUP`.
- Deterministic output: same seed + room_id + section_id must always produce identical variants and geometry.

---

### Task 1: Core Data Models (`WallSection`, `WallVariantPolicy`)

**Files:**
- Create: `src/geometry_generator/data/wall_section.gd`
- Create: `src/geometry_generator/data/wall_variant_policy.gd`
- Modify: `src/geometry_generator/data/generated_mesh.gd`
- Test: `tests/geometry/test_wall_section_data.gd`

**Interfaces:**
- `WallSection`: Holds `id: int`, `component_id: int`, `start_point: Vector2i`, `end_point: Vector2i`, `points: Array[Vector2i]`, `orientation: Vector2i`, `length: float`, `room_id: int`, `variant_id: StringName`, `is_closed_loop: bool`.
- `WallVariantPolicy`: Holds `enabled: bool`, `allowed_variants: Array[StringName]`, `variant_weights: Dictionary`.
- `GeneratedMesh`: Adds `section_id: int = -1`, `variant_id: StringName = &""`, `room_id: int = -1`.

- [ ] **Step 1: Create `src/geometry_generator/data/wall_section.gd`**

```gdscript
class_name WallSection
extends RefCounted

## Unidad arquitectónica discreta de muro entre puntos significativos (esquinas, puertas, límites).

var id: int = 0
var component_id: int = 0
var room_id: int = -1
var start_point: Vector2i = Vector2i.ZERO
var end_point: Vector2i = Vector2i.ZERO
var points: Array[Vector2i] = []
var orientation: Vector2i = Vector2i.ZERO
var length: float = 0.0
var variant_id: StringName = &"normal"
var is_closed_loop: bool = false
var bounds: Rect2i = Rect2i()

func _init(
	p_id: int = 0,
	p_comp_id: int = 0,
	p_pts: Array[Vector2i] = [],
	p_room_id: int = -1,
	p_variant: StringName = &"normal",
	p_is_loop: bool = false
) -> void:
	id = p_id
	component_id = p_comp_id
	points = p_pts
	room_id = p_room_id
	variant_id = p_variant
	is_closed_loop = p_is_loop
	if not points.is_empty():
		start_point = points[0]
		end_point = points[points.size() - 1]
		_calculate_bounds_and_metrics()

func _calculate_bounds_and_metrics() -> void:
	if points.is_empty():
		return
	bounds = Rect2i(points[0], Vector2i.ONE)
	var total_len: float = 0.0
	for i in range(points.size()):
		bounds = bounds.expand(points[i])
		if i > 0:
			total_len += float(points[i - 1].distance_to(points[i]))
	length = total_len
	if points.size() >= 2:
		var diff = points[points.size() - 1] - points[0]
		orientation = Vector2i(signi(diff.x), signi(diff.y))
```

- [ ] **Step 2: Create `src/geometry_generator/data/wall_variant_policy.gd`**

```gdscript
class_name WallVariantPolicy
extends RefCounted

## Política de selección y distribución de variantes de muro.

var enabled: bool = true
var allowed_variants: Array[StringName] = [&"normal"]
var variant_weights: Dictionary = { &"normal": 100.0 }

func _init(p_enabled: bool = true, p_allowed: Array[StringName] = [&"normal"], p_weights: Dictionary = {}) -> void:
	enabled = p_enabled
	allowed_variants = p_allowed
	if p_weights.is_empty():
		variant_weights = { &"normal": 100.0 }
	else:
		variant_weights = p_weights
```

- [ ] **Step 3: Update `src/geometry_generator/data/generated_mesh.gd`**

Add `section_id`, `variant_id`, and `room_id` fields to `GeneratedMesh`.

- [ ] **Step 4: Create and run `tests/geometry/test_wall_section_data.gd`**

Verify that `WallSection` calculates bounds, start/end points, and lengths correctly.

---

### Task 2: Wall Section Extractor (`WallSectionExtractor`)

**Files:**
- Create: `src/geometry_generator/extraction/wall_section_extractor.gd`
- Test: `tests/geometry/test_wall_section_extraction.gd`

**Interfaces:**
- Consumes: `WallComponent`, `min_section_length: int = 2`, `max_section_length: int = 6`, `opening_manifest: WallOpeningManifest = null`, `room_partition = null`.
- Produces: `Array[WallSection]`.

- [ ] **Step 1: Create `src/geometry_generator/extraction/wall_section_extractor.gd`**

```gdscript
class_name WallSectionExtractor
extends RefCounted

## Descompone los bucles y cadenas de un WallComponent en segmentos discretos WallSection.
## Detecta esquinas (cambios de dirección), aberturas/puertas y divide tramos rectos largos
## respetando [min_length, max_length] para mantener unidades arquitectónicas manejables.

const _WallSectionScript = preload("res://src/geometry_generator/data/wall_section.gd")
const _WallComponentScript = preload("res://src/geometry_generator/data/wall_component.gd")

func extract_sections(
	component: WallComponent,
	min_length: int = 2,
	max_length: int = 6,
	room_id: int = -1
) -> Array: # Array[WallSection]
	var sections: Array = []
	if component == null or component.is_empty():
		return sections

	var section_counter: int = 0

	# 1. Procesar bucles cerrados
	for loop in component.loops:
		var loop_sections = _split_polyline_into_sections(
			loop, component.id, section_counter, min_length, max_length, room_id, true
		)
		sections.append_array(loop_sections)
		section_counter += loop_sections.size()

	# 2. Procesar cadenas abiertas
	for chain in component.open_chains:
		var chain_sections = _split_polyline_into_sections(
			chain, component.id, section_counter, min_length, max_length, room_id, false
		)
		sections.append_array(chain_sections)
		section_counter += chain_sections.size()

	return sections

func _split_polyline_into_sections(
	pts: Array,
	comp_id: int,
	start_id: int,
	min_len: int,
	max_len: int,
	room_id: int,
	is_loop: bool
) -> Array:
	var result: Array = []
	if pts.size() < 2:
		return result

	# Identificar esquinas naturales (cambio de vector director)
	var split_indices: Array[int] = [0]
	var n: int = pts.size()
	for i in range(1, n - 1):
		var v_prev = (pts[i] - pts[i - 1]) as Vector2i
		var v_next = (pts[i + 1] - pts[i]) as Vector2i
		if v_prev != v_next:
			split_indices.append(i)
	split_indices.append(n - 1)

	# Subdividir tramos rectos que superen max_len
	var final_cut_indices: Array[int] = [0]
	for k in range(split_indices.size() - 1):
		var idx_a = split_indices[k]
		var idx_b = split_indices[k + 1]
		var dist = idx_b - idx_a
		if dist > max_len:
			var subdivisions = ceili(float(dist) / float(max_len))
			var step = float(dist) / float(subdivisions)
			for s in range(1, subdivisions):
				var cut_idx = idx_a + int(round(s * step))
				if cut_idx > final_cut_indices[final_cut_indices.size() - 1] and cut_idx < idx_b:
					final_cut_indices.append(cut_idx)
		if idx_b > final_cut_indices[final_cut_indices.size() - 1]:
			final_cut_indices.append(idx_b)

	# Construir WallSections a partir de los puntos de corte
	for s_idx in range(final_cut_indices.size() - 1):
		var from_i = final_cut_indices[s_idx]
		var to_i = final_cut_indices[s_idx + 1]
		var sec_pts: Array[Vector2i] = []
		for p_i in range(from_i, to_i + 1):
			sec_pts.append(pts[p_i] as Vector2i)

		var sec := _WallSectionScript.new(
			start_id + result.size(),
			comp_id,
			sec_pts,
			room_id,
			&"normal",
			is_loop and (from_i == 0 and to_i == n - 1)
		)
		result.append(sec)

	return result
```

- [ ] **Step 2: Create and run `tests/geometry/test_wall_section_extraction.gd`**

Verify that a rectangular room (loop of 20 points) extracts into discrete `WallSection` units of length between 2 and 6.

---

### Task 3: Wall Geometry Builder Section Meshing (`WallGeometryBuilder`)

**Files:**
- Modify: `src/geometry_generator/geometry/wall_geometry_builder.gd`
- Test: `tests/geometry/test_wall_section_geometry.gd`

**Interfaces:**
- Consumes: `WallSection`, `WallGeometryConfig`.
- Produces: `GeneratedMesh` for the individual section, with proper trims, panel extrusions, and AABB bounds.

- [ ] **Step 1: Implement `build_section_mesh(section: WallSection, config: WallGeometryConfig) -> GeneratedMesh` in `wall_geometry_builder.gd`**

Extrude geometry specifically for `section.points`, maintaining miter joints along the section vertices and generating clean end faces. Attach `g_mesh.section_id = section.id`, `g_mesh.component_id = section.component_id`, `g_mesh.room_id = section.room_id`, `g_mesh.variant_id = section.variant_id`.

- [ ] **Step 2: Create and run `tests/geometry/test_wall_section_geometry.gd`**

Verify that `build_section_mesh` outputs a valid `GeneratedMesh` with positive vertex counts, valid UVs, and finite AABB.

---

### Task 4: Profile & JSON Architecture for Wall Variants

**Files:**
- Create: `src/dungeon_generator/profiles/profile_wall_variant_policy.gd`
- Modify: `src/dungeon_generator/profiles/profile_room_architecture.gd`
- Modify: `src/dungeon_generator/profiles/profile_loader.gd`
- Modify: `src/dungeon_generator/profiles/profile_validator.gd`
- Modify: `resources/dungeon_profiles/rooms/*.json`
- Test: `tests/profiles/test_wall_variant_profile_resolution.gd`

**Interfaces:**
- Consumes: `"wall_variants": { "enabled": true, "allowed": ["normal", "cracked"], "weights": { "normal": 80, "cracked": 20 } }` in room JSONs.
- Produces: `ProfileWallVariantPolicy` attached to `ProfileRoomArchitecture.wall_variants`.

- [ ] **Step 1: Create `profile_wall_variant_policy.gd`**
- [ ] **Step 2: Update `profile_room_architecture.gd`, `profile_loader.gd`, and `profile_validator.gd`**
- [ ] **Step 3: Update `crypt.json` (cracked: 20), `royal_tomb.json` (ornate: 20), and `catacomb.json` (damaged: 15)**
- [ ] **Step 4: Create and run `tests/profiles/test_wall_variant_profile_resolution.gd`**

---

### Task 5: Wall Variant Resolver & RNG Determinism (`WallVariantResolver`)

**Files:**
- Create: `src/geometry_generator/variants/wall_variant_resolver.gd`
- Test: `tests/geometry/test_wall_variant_determinism.gd`

**Interfaces:**
- Method: `resolve_section_variant(section: WallSection, policy: WallVariantPolicy, master_seed: int) -> StringName`.
- Guarantees deterministic variant assignment: `hash(master_seed, section.component_id, section.id, section.room_id)`.

- [ ] **Step 1: Implement `WallVariantResolver`**
- [ ] **Step 2: Create and run `tests/geometry/test_wall_variant_determinism.gd`**

Verify that identical seeds produce identical variants across 100 runs and that varying the policy weights changes the distribution accordingly.

---

### Task 6: DungeonGeometryGenerator & Presentation Integration

**Files:**
- Modify: `src/geometry_generator/facade/dungeon_geometry_generator.gd`
- Modify: `src/presentation/geometry/presentation_structural_renderer.gd`
- Modify: `src/dungeon_generator/presentation/dungeon_presentation_builder.gd`
- Test: `tests/presentation/test_wall_occlusion_isolation.gd`

**Interfaces:**
- `DungeonGeometryGenerator.generate_wall_sections_for_partition(...) -> GeometryResult`.
- `PresentationStructuralRenderer` instantiates independent `MeshInstance3D` per `WallSection` with its own `StaticBody3D` child in group `CAMERA_OCCLUDER_GROUP`.
- `WallFadeController` / `OccluderResolver` resolves only the hit section `MeshInstance3D`, fading only that specific section.

- [ ] **Step 1: Update `dungeon_geometry_generator.gd` to extract and generate sections**
- [ ] **Step 2: Update `presentation_structural_renderer.gd` and `dungeon_presentation_builder.gd` to spawn per-section mesh instances**
- [ ] **Step 3: Create and run `tests/presentation/test_wall_occlusion_isolation.gd`**

Verify that fading one section does NOT fade adjacent sections.

---

### Task 7: Full Regression & Benchmark (100 Seeds)

**Files:**
- Test: `tests/profiles/test_profile_driven_lighting.gd`
- Test: `tests/profiles/test_configuration_authority.gd`
- Test: `tests/profiles/test_architecture_profile_driven.gd`
- Test: `tests/profiles/test_profile_driven_composition.gd`
- Test: `tests/presentation/decoration/test_crypt_benchmark_100_seeds.gd`

- [ ] **Step 1: Run all test suites and verify 100% PASS**
- [ ] **Step 2: Verify 100 seeds benchmark (707 rooms) with 0 errors**

---
