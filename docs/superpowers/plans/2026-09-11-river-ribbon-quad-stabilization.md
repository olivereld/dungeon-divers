# River Ribbon Quad Stabilization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform raw `River.points` into a stable, non-self-intersecting, gapless 3D river ribbon mesh with strictly 2 vertices per cross-section, 2 triangles per longitudinal segment, bounded unit normals, quad inversion protection, and progressive sharp-bend fallbacks.

**Architecture:** Pure presentation-layer pipeline in `river_mesh_builder.gd` consisting of: (1) centerline deduplication and uniform arc-length resampling, (2) unit blended normal generation, (3) 2D XZ quad segment validation and edge crossing detection, (4) progressive localized fallbacks (alternate normal, progressive width reduction), (5) exact 2-triangle quad ribbon assembly, leaving hydrological truth completely untouched.

**Tech Stack:** Godot 4.6.1 GDScript, `WorldResult`, `WorldProfile`, `River`, `WaterSurfaceData`, `ArrayMesh`.

**Spec:** User technical specification: "Plan técnico para cerrar el problema — BLOQUES 1 al 9".

## Global Constraints
- **Hydrology Immutability:** Never modify `HydrologyStage`, `River`, `RiverNetwork`, `accumulation`, `flow_to`, or elevation field truth. All fixes are strictly within `RiverMeshBuilder`.
- **Topological Invariant:** Exactly 2 vertices per cross-section station ($L_i, R_i$) and exactly 2 triangles per longitudinal quad segment $(L_0, R_0, L_1)$ and $(R_0, R_1, L_1)$. Zero radial fans, zero Catmull-Rom splines, zero additional intermediate vertices.
- **Confluence Isolation:** Keep `build_confluence_patch()` isolated for a subsequent dedicated phase; do not mix confluence patch geometry with ribbon stabilization.
- **Shader Preservation:** Maintain flow vectors in `UV2` and directional water shader bindings in `WaterRenderer`.

---

### Task 1: Centerline Data Sanitation & Uniform Arc-Length Resampling (Bloque 1)

**Files:**
- Modify: `src/world_generator/presentation/water/river_mesh_builder.gd:330-490`
- Test: `src/world_generator/tests/test_river_centerline_sanitation.gd`

**Interfaces:**
- Consumes: `raw_pts: Array`, `raw_widths: Array`, `raw_depths: Array`, `target_spacing: float` (default `0.75`).
- Produces: `Dictionary` with `{"points": Array[Vector3], "widths": Array[float], "depths": Array[float]}`.

- [ ] **Step 1: Write unit test for centerline deduplication and arc-length resampling**

```gdscript
# src/world_generator/tests/test_river_centerline_sanitation.gd
extends SceneTree

const _RiverMeshBuilder = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")

func _init() -> void:
	print("--- Test River Centerline Sanitation ---")
	# Case with duplicate points and uneven distances
	var raw_pts: Array = [
		Vector3(0, 0, 0),
		Vector3(0, 0, 0.0001), # duplicate
		Vector3(0, 0, 2.0),
		Vector3(3.0, 0, 2.0)
	]
	var raw_w: Array = [1.0, 1.0, 1.2, 1.5]
	var raw_d: Array = [0.2, 0.2, 0.3, 0.4]

	var sampled: Dictionary = _RiverMeshBuilder._clean_and_resample_centerline(raw_pts, raw_w, raw_d, 0.75)
	var pts: Array[Vector3] = sampled["points"]
	var widths: Array[float] = sampled["widths"]
	var depths: Array[float] = sampled["depths"]

	assert(pts.size() >= 4, "Must sample at regular intervals")
	assert(pts[0].distance_to(Vector3(0, 0, 0)) < 0.001, "First point must be preserved")
	assert(pts[-1].distance_to(Vector3(3.0, 0, 2.0)) < 0.001, "Last point must be preserved")

	for i in range(1, pts.size()):
		var d: float = pts[i].distance_to(pts[i - 1])
		assert(d > 0.01, "No duplicate points allowed in resampled output")
		assert(is_finite(widths[i]) and widths[i] > 0.0, "Width must be positive finite")
		assert(is_finite(depths[i]) and depths[i] > 0.0, "Depth must be positive finite")

	print("Test River Centerline Sanitation: PASSED")
	quit(0)
```

- [ ] **Step 2: Implement `_clean_and_resample_centerline` in `river_mesh_builder.gd`**
- Deduplicate adjacent points closer than 0.001m.
- Compute cumulative arc lengths along the deduplicated path.
- Interpolate positions, widths, and depths every 0.75m.
- Strictly clamp the first and last points to match original start and end.
- Verify array bounds and fallbacks.

- [ ] **Step 3: Run test to confirm sanitation passes**

---

### Task 2: Robust Tangents, Unit Lateral Normals & Initial Left/Right Calculation (Bloque 2)

**Files:**
- Modify: `src/world_generator/presentation/water/river_mesh_builder.gd:80-210`

**Interfaces:**
- Consumes: `pts: Array[Vector3]`, `widths: Array[float]`, `cell_size: float`.
- Produces: Station data array containing `tangent: Vector3`, `unit_normal: Vector3`, `half_width: float`, `left: Vector3`, `right: Vector3`.

- [ ] **Step 1: Write helper for tangent and unit normal calculation**
- For station $i$:
  - $i = 0$: `tangent = (pts[1] - pts[0]).normalized()`
  - $i = N - 1$: `tangent = (pts[N - 1] - pts[N - 2]).normalized()`
  - $0 < i < N - 1$: `prev_dir = (pts[i] - pts[i - 1]).normalized()`, `next_dir = (pts[i + 1] - pts[i]).normalized()`. `tangent = prev_dir + next_dir`. If `tangent.length_squared() < 0.0001`, fallback to `next_dir`.
- Compute horizontal normal:
  - `prev_norm = Vector3(-prev_dir.z, 0, prev_dir.x)`
  - `next_norm = Vector3(-next_dir.z, 0, next_dir.x)`
  - `blended_normal = prev_norm + next_norm`
  - If `blended_normal.length_squared() > 0.0001`: normalize to unit length 1.0.
  - Else: use `next_norm.normalized()`.
- Guaranteed unit normal length: $|\text{normal}| = 1.0$ (no unbounded miter scaling).
- Offset:
  - `left = center + normal * half_width`
  - `right = center - normal * half_width`

- [ ] **Step 2: Connect into station generation loop**

---

### Task 3: Quad Geometry Validation & XZ Edge Intersection Detection (Bloque 3)

**Files:**
- Modify: `src/world_generator/presentation/water/river_mesh_builder.gd`
- Test: `src/world_generator/tests/test_river_quad_validation.gd`

**Interfaces:**
- Consumes: $L_0, R_0, L_1, R_1$ (Vector3 coordinates).
- Produces: `bool` (`is_quad_valid(l0, r0, l1, r1) -> bool`).

- [ ] **Step 1: Write unit test for quad validation and segment edge crossing**

```gdscript
# src/world_generator/tests/test_river_quad_validation.gd
extends SceneTree

const _RiverMeshBuilder = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")

func _init() -> void:
	print("--- Test River Quad Validation ---")
	# Valid quad
	var l0 := Vector3(-1, 0, 0)
	var r0 := Vector3(1, 0, 0)
	var l1 := Vector3(-1, 0, 2)
	var r1 := Vector3(1, 0, 2)
	assert(_RiverMeshBuilder._quad_is_valid(l0, r0, l1, r1), "Standard quad must be valid")

	# Crossed quad (bowtie / self-intersecting edges L0->L1 and R0->R1)
	var l1_crossed := Vector3(1.5, 0, 2)
	var r1_crossed := Vector3(-1.5, 0, 2)
	assert(not _RiverMeshBuilder._quad_is_valid(l0, r0, l1_crossed, r1_crossed), "Crossed quad must be invalid")

	# Degenerate collapsed quad
	assert(not _RiverMeshBuilder._quad_is_valid(l0, l0, l1, r1), "Zero width quad must be invalid")

	print("Test River Quad Validation: PASSED")
	quit(0)
```

- [ ] **Step 2: Implement 2D XZ edge-intersection and winding validation in `river_mesh_builder.gd`**
- `_segments_intersect_2d(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool` using cross product orientation.
- Validate:
  1. All 4 points finite.
  2. Central segment length > 0.001.
  3. Station widths ($L_0 \to R_0$, $L_1 \to R_1$) > 0.01.
  4. Both triangles $(L_0, R_0, L_1)$ and $(R_0, R_1, L_1)$ pass area and finiteness checks.
  5. Segment $L_0 \to L_1$ does NOT intersect $R_0 \to R_1$ in the XZ plane.
  6. Consistent 2D cross product sign (no twisted bowtie).

---

### Task 4: Local Fallback Pipeline for Sharp Bends (Normals & Width Pinching) (Bloque 4)

**Files:**
- Modify: `src/world_generator/presentation/water/river_mesh_builder.gd`
- Test: `src/world_generator/tests/test_river_sharp_bend_fallback.gd`

**Interfaces:**
- Consumes: station $i$, previous station $i-1$, centerline points, candidate widths.
- Produces: corrected $L_i, R_i$ positions that ensure valid quads without dropping triangles.

- [ ] **Step 1: Write test case for sharp 90-degree and hairpin turns**

```gdscript
# src/world_generator/tests/test_river_sharp_bend_fallback.gd
extends SceneTree

const _RiverMeshBuilder = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")

func _init() -> void:
	print("--- Test River Sharp Bend Fallback ---")
	# Hairpin curve in 3 points
	var pts: Array = [
		Vector3(0, 0, 0),
		Vector3(0, 0, 2),
		Vector3(0.3, 0, 2.1),
		Vector3(0.3, 0, 0)
	]
	var widths: Array = [2.0, 2.0, 2.0, 2.0] # wide river in tight hairpin
	var depths: Array = [0.2, 0.2, 0.2, 0.2]

	# Build river dictionary
	var river_dict := {"points": pts, "widths": widths, "depths": depths}
	var dummy_profile = WorldProfile.new()
	var surf = _RiverMeshBuilder.build_river_surface(river_dict, null, dummy_profile)

	assert(surf != null, "Surface must be generated even on hairpin")
	assert(surf.indices.size() >= 6, "Must generate valid ribbon triangles")
	print("Test River Sharp Bend Fallback: PASSED")
	quit(0)
```

- [ ] **Step 2: Implement the 3-tier fallback loop in `river_mesh_builder.gd`**
- When testing quad $(i-1) \to i$:
  - **Tier 0:** Blended unit normal at $100\%$ width.
  - If invalid:
    - **Fallback A:** Try `prev_normal` at station $i$.
  - If still invalid:
    - **Fallback B:** Try `next_normal` at station $i$.
  - If still invalid:
    - **Fallback C:** Progressively pinch width locally ($85\% \to 70\% \to 55\% \to 40\%$) with the best candidate normal until `_quad_is_valid` passes.
- Ensures the ribbon never self-intersects or breaks continuity, while leaving the data in `River.widths` unchanged.

---

### Task 5: Ribbon Assembly (2 Triangles / Segment) & Confluence Separation (Bloques 5, 6, 7)

**Files:**
- Modify: `src/world_generator/presentation/water/river_mesh_builder.gd`
- Review: `src/world_generator/presentation/water/water_renderer.gd`

**Interfaces:**
- Produces: clean `WaterSurfaceData` with exact quad-strip index order:
  - Triangle 1: $(L_i, R_i, L_{i+1})$
  - Triangle 2: $(R_i, R_{i+1}, L_{i+1})$

- [ ] **Step 1: Assemble the final ribbon quad loop**
- Sample bed and bank terrain elevation per vertex.
- Compute flow vector along the segment direction: `flow_dir = Vector2(tangent.x, tangent.z).normalized()`.
- Add vertices to `WaterSurfaceData` with UV longitudinal distance and transverse coordinate (0.0 for left, 1.0 for right).
- Add exactly 2 triangles per longitudinal segment.
- Retain `build_confluence_patch()` intact as a separate phase.

---

### Task 6: Comprehensive Automated Test Suite (Bloques 8 y 9)

**Files:**
- Create: `src/world_generator/tests/test_river_ribbon_comprehensive.gd`

- [ ] **Step 1: Implement test verifying all 7 test cases from Bloque 8**
- Case A: Straight river (completely regular quad strip).
- Case B: Smooth curve (no distortion).
- Case C: Sharp 90-degree bend (no crossed triangles).
- Case D: Meander S-curve (zero edge intersections).
- Case E: Narrow river ($width = 0.25$).
- Case F: Wide river ($width = 3.0$).
- Case G: Full procedural world pipeline multi-seed test (seeds 101, 202, 303, 404).

- [ ] **Step 2: Run test suite headlessly and verify 100% pass**
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script res://src/world_generator/tests/test_river_ribbon_comprehensive.gd
```

---

## Verification Plan

### Automated Tests
- `test_river_centerline_sanitation.gd`: verifies deduplication and arc-length spacing.
- `test_river_quad_validation.gd`: verifies XZ edge intersection detection.
- `test_river_sharp_bend_fallback.gd`: verifies normal swapping and width pinching on hairpins.
- `test_river_ribbon_comprehensive.gd`: runs Cases A-G and multi-seed pipeline checks.

### Manual Verification
- Launch `TaigaWorld` lab in Godot:
  - Inspect river mesh in wireframe mode: strictly 2 triangles per quad segment.
  - Verify smooth transition around sharp river turns without spikes or visual tears.
  - Verify water shader flow alignment.
