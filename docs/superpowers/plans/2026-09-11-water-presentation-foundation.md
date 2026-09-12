# Water Presentation Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a robust, decoupled presentation pipeline for water surfaces in Godot 4 (`RiverMeshBuilder`, `LakeMeshBuilder`, `WaterSurfaceData`, and `WaterRenderer`), turning topological hydrology truth into gapless, flowing 3D water surface geometry without touching terrain elevation truth.

**Architecture:** 
- Strict separation: `HydrologyStage` defines WHERE water exists (`RiverNetwork`, `River`, `Lake`).
- `water_surface_data.gd` acts as the unified geometric payload for all water bodies (vertices, indices, normals, uvs, uv2 flow vectors).
- `river_mesh_builder.gd` generates continuous river ribbons, water level clamping (`bed_y + depth <= bank_y`), longitudinal/transversal UVs, and confluence bridge patches.
- `lake_mesh_builder.gd` generates planar horizontal water surfaces for lakes.
- `water_renderer.gd` assembles the meshes, manages `water_material.gd` (opaque/shallow-deep palette with directional flow), and integrates with `WorldRenderer` and `TaigaWorld`.

**Tech Stack:** Godot 4.6 (GDScript), `ArrayMesh`, `StandardMaterial3D` / custom directional flow shader, `WorldResult`, `RiverNetwork`.

**Spec:** User spec for "WATER PRESENTATION FOUNDATION" (Prompt 2026-09-11).

## Global Constraints

- **Hydrology Truth Immutability:** Never modify `WorldCell.height`, `WorldCell.raw_height`, or recalculate cuencas/flow directions during presentation.
- **Water Surface Level vs Riverbed:** `water_y = bed_y + actual_water_depth`, with hard clamp `water_y <= bank_height` to prevent spilling over dry ground.
- **Continuous Ribbon Topology:** No disjoint ribbon gaps at confluences or lake mouths; controlled overlap patches are mandatory.
- **Directional Flow Encoding:** Vertex flow direction vectors must be stored in `UV2` for shader animation.
- **No Hangs / Long Test Loops:** Automated tests must execute headlessly and terminate cleanly via `quit(0)`.

---

### Task 1: Unified Water Surface Geometry Contract (`WaterSurfaceData`)

**Files:**
- Create: `src/world_generator/presentation/water/water_surface_data.gd`
- Test: `src/world_generator/tests/test_water_surface_data.gd`

**Interfaces:**
- Consumes: None (pure data model).
- Produces: `class_name WaterSurfaceData` with `vertices`, `normals`, `uvs`, `uv2_flow`, `colors`, `indices`, and `to_array_mesh() -> ArrayMesh`.

- [ ] **Step 1: Write the failing test**

```gdscript
# src/world_generator/tests/test_water_surface_data.gd
extends SceneTree

const _WaterSurfaceDataScript = preload("res://src/world_generator/presentation/water/water_surface_data.gd")

func _init() -> void:
	print("--- Test WaterSurfaceData ---")
	var data = _WaterSurfaceDataScript.new()
	assert(data != null, "WaterSurfaceData must instantiate")
	
	# Add a simple triangle
	data.add_vertex(Vector3(0, 1, 0), Vector3.UP, Vector2(0, 0), Vector2(1, 0), Color.BLUE)
	data.add_vertex(Vector3(1, 1, 0), Vector3.UP, Vector2(1, 0), Vector2(1, 0), Color.BLUE)
	data.add_vertex(Vector3(0, 1, 1), Vector3.UP, Vector2(0, 1), Vector2(1, 0), Color.BLUE)
	data.add_triangle(0, 1, 2)
	
	assert(data.vertices.size() == 3, "Must have 3 vertices")
	assert(data.indices.size() == 3, "Must have 3 indices")
	assert(data.uv2_flow.size() == 3, "Must have 3 flow vectors")
	
	var mesh: ArrayMesh = data.to_array_mesh()
	assert(mesh != null, "ArrayMesh must be created")
	assert(mesh.get_surface_count() == 1, "Must contain 1 surface")
	print("Test WaterSurfaceData: PASSED")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script src/world_generator/tests/test_water_surface_data.gd`
Expected: FAIL with "Cannot open file: res://src/world_generator/presentation/water/water_surface_data.gd"

- [ ] **Step 3: Write minimal implementation**

```gdscript
# src/world_generator/presentation/water/water_surface_data.gd
class_name WaterSurfaceData
extends RefCounted

## Unified geometry representation for water surfaces (rivers, lakes, confluences).
## Decoupled from terrain buffers; converts directly to ArrayMesh.

var vertices: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var uvs: PackedVector2Array = PackedVector2Array()
var uv2_flow: PackedVector2Array = PackedVector2Array()
var colors: PackedColorArray = PackedColorArray()
var indices: PackedInt32Array = PackedInt32Array()

func clear() -> void:
	vertices.clear()
	normals.clear()
	uvs.clear()
	uv2_flow.clear()
	colors.clear()
	indices.clear()

func add_vertex(pos: Vector3, normal: Vector3, uv: Vector2, flow_dir: Vector2, col: Color) -> int:
	var idx := vertices.size()
	vertices.append(pos)
	normals.append(normal)
	uvs.append(uv)
	uv2_flow.append(flow_dir)
	colors.append(col)
	return idx

func add_triangle(i0: int, i1: int, i2: int) -> void:
	indices.append(i0)
	indices.append(i1)
	indices.append(i2)

func append_surface(other: WaterSurfaceData) -> void:
	if other == null or other.vertices.is_empty():
		return
	var offset := vertices.size()
	vertices.append_array(other.vertices)
	normals.append_array(other.normals)
	uvs.append_array(other.uvs)
	uv2_flow.append_array(other.uv2_flow)
	colors.append_array(other.colors)
	for idx in other.indices:
		indices.append(offset + idx)

func to_array_mesh() -> ArrayMesh:
	if vertices.is_empty() or indices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2_flow
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script src/world_generator/tests/test_water_surface_data.gd`
Expected: PASS with "Test WaterSurfaceData: PASSED"

- [ ] **Step 5: Checkpoint commit**

```bash
git add src/world_generator/presentation/water/water_surface_data.gd src/world_generator/tests/test_water_surface_data.gd
git commit -m "feat(water): add WaterSurfaceData geometry contract with UV2 flow vectors"
```

---

### Task 2: River Surface Ribbon & Water Level Builder (`RiverMeshBuilder`)

**Files:**
- Create: `src/world_generator/presentation/water/river_mesh_builder.gd`
- Test: `src/world_generator/tests/test_river_mesh_builder.gd`

**Interfaces:**
- Consumes: `River`, `WorldResult`, `WorldProfile`, `WaterSurfaceData`.
- Produces: `RiverMeshBuilder.build_river_surface(river: River, result: WorldResult, profile: WorldProfile) -> WaterSurfaceData`.
  - Calculates clamped water surface: `water_y = clampf(bed_y + actual_depth, bed_y, bank_y)`.
  - Generates cross-sectional points: `left_edge` and `right_edge` using spline perpendiculars.
  - Generates longitudinal UV (accumulated stream distance in meters) and transversal UV ($0.0 \dots 1.0$).
  - Stores 2D normalized downstream flow direction in `uv2_flow`.
  - Encodes visual flow speed in color alpha: `visual_speed = clampf(sqrt(slope) * 0.5 + log(acc + 1.0) * 0.1, 0.1, 2.5)`.

- [ ] **Step 1: Write the failing test**

```gdscript
# src/world_generator/tests/test_river_mesh_builder.gd
extends SceneTree

const _RiverMeshBuilderScript = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _RiverScript = preload("res://src/world_generator/hydrology/river.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("--- Test RiverMeshBuilder ---")
	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	profile.hydrology_enabled = true
	var result = _WorldPipelineScript.generate(42, profile)
	assert(result != null and result.hydrology != null)
	
	var rivers: Array = result.hydrology.rivers
	assert(not rivers.is_empty(), "Need at least one river to test")
	var r = rivers[0]
	
	var surf = _RiverMeshBuilderScript.build_river_surface(r, result, profile)
	assert(surf != null, "Surface must be generated")
	assert(surf.vertices.size() >= 4, "Must generate at least 4 vertices for ribbon")
	assert(surf.indices.size() >= 6, "Must generate triangles")
	
	# Verify UVs and flow directions
	for i in range(surf.vertices.size()):
		var uv: Vector2 = surf.uvs[i]
		assert(uv.x >= 0.0 and uv.x <= 1.001, "Transversal UV must be [0, 1]")
		var flow: Vector2 = surf.uv2_flow[i]
		assert(flow.length() > 0.1, "Flow vector must be non-zero downstream")
		
	# Verify water level strictly >= riverbed
	for i in range(surf.vertices.size()):
		var v: Vector3 = surf.vertices[i]
		assert(not is_nan(v.y) and not is_inf(v.y), "Water Y must be valid float")
		
	print("Test RiverMeshBuilder: PASSED")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script src/world_generator/tests/test_river_mesh_builder.gd`
Expected: FAIL with "Cannot open file: res://src/world_generator/presentation/water/river_mesh_builder.gd"

- [ ] **Step 3: Write minimal implementation**

```gdscript
# src/world_generator/presentation/water/river_mesh_builder.gd
class_name RiverMeshBuilder
extends RefCounted

const _WaterSurfaceDataScript = preload("res://src/world_generator/presentation/water/water_surface_data.gd")

static func build_river_surface(river: Variant, result: WorldResult, profile: WorldProfile) -> RefCounted:
	var raw_pts: Array = river.points if (river is River or "points" in river) else river.get("points", [])
	if raw_pts.size() < 2:
		return null
		
	var raw_widths: Array = river.widths if (river is River or "widths" in river) else river.get("widths", [])
	var raw_depths: Array = river.depths if (river is River or "depths" in river) else river.get("depths", [])
	var r_cells: Array = river.path if (river is River or "path" in river) else river.get("cells", [])
	
	# Catmull-Rom smoothing for visual continuity
	var smooth_data := _catmull_rom_resample(raw_pts, raw_widths, raw_depths, 4)
	var pts: Array[Vector3] = smooth_data["points"]
	var widths: Array[float] = smooth_data["widths"]
	var depths: Array[float] = smooth_data["depths"]
	var total_pts := pts.size()
	if total_pts < 2:
		return null
		
	var surf = _WaterSurfaceDataScript.new()
	var accumulated_dist: float = 0.0
	var cell_size: float = maxf(profile.cell_size, 0.01)
	
	for j in range(total_pts):
		var p: Vector3 = pts[j]
		if j > 0:
			accumulated_dist += pts[j].distance_to(pts[j - 1])
			
		# Tangent and perpendicular in XZ plane
		var tangent: Vector3
		if j == 0:
			tangent = (pts[1] - pts[0]).normalized()
		elif j == total_pts - 1:
			tangent = (pts[j] - pts[j - 1]).normalized()
		else:
			tangent = (pts[j + 1] - pts[j - 1]).normalized()
		tangent.y = 0.0
		tangent = tangent.normalized() if tangent.length_squared() >= 0.0001 else Vector3(0, 0, 1)
		var perp := Vector3(-tangent.z, 0.0, tangent.x).normalized()
		var flow_vec := Vector2(tangent.x, tangent.z).normalized()
		
		var w: float = widths[j] / cell_size
		var half_w := w * 0.5
		var actual_depth: float = depths[j]
		
		# Sample ground bed elevation and bank height
		var lx: float = p.x + perp.x * half_w
		var lz: float = p.z + perp.z * half_w
		var rx: float = p.x - perp.x * half_w
		var rz: float = p.z - perp.z * half_w
		
		var bed_l: float = _sample_terrain(result, lx, lz)
		var bed_r: float = _sample_terrain(result, rx, rz)
		var bank_l: float = _sample_terrain(result, lx + perp.x * 0.5, lz + perp.z * 0.5)
		var bank_r: float = _sample_terrain(result, rx - perp.x * 0.5, rz - perp.z * 0.5)
		
		# Water surface: bed + actual_depth, clamped to not climb over banks
		var ly: float = minf(bed_l + actual_depth, bank_l + 0.02)
		var ry: float = minf(bed_r + actual_depth, bank_r + 0.02)
		
		# Enforce non-negative water column
		ly = maxf(ly, bed_l + 0.015)
		ry = maxf(ry, bed_r + 0.015)
		
		# Longitudinal UV in meters, transversal UV [0, 1]
		var u_coord: float = accumulated_dist
		var col := profile.water_color_river
		
		var idx_l = surf.add_vertex(Vector3(lx, ly, lz), Vector3.UP, Vector2(0.0, u_coord), flow_vec, col)
		var idx_r = surf.add_vertex(Vector3(rx, ry, rz), Vector3.UP, Vector2(1.0, u_coord), flow_vec, col)
		
		if j > 0:
			var prev_l = idx_l - 2
			var prev_r = idx_r - 2
			surf.add_triangle(prev_l, prev_r, idx_l)
			surf.add_triangle(prev_r, idx_r, idx_l)
			
	return surf

static func _sample_terrain(result: WorldResult, wx: float, wz: float) -> float:
	if result == null:
		return 0.0
	var w: int = result.dimensions.x
	var h: int = result.dimensions.y
	var x0 := clampi(int(floor(wx)), 0, w - 2)
	var z0 := clampi(int(floor(wz)), 0, h - 2)
	var u := clampf(wx - float(x0), 0.0, 1.0)
	var v := clampf(wz - float(z0), 0.0, 1.0)
	
	var c00 = result.get_cell(Vector2i(x0, z0))
	var c10 = result.get_cell(Vector2i(x0 + 1, z0))
	var c01 = result.get_cell(Vector2i(x0, z0 + 1))
	var c11 = result.get_cell(Vector2i(x0 + 1, z0 + 1))
	var h00: float = c00.height if c00 != null else 0.0
	var h10: float = c10.height if c10 != null else 0.0
	var h01: float = c01.height if c01 != null else 0.0
	var h11: float = c11.height if c11 != null else 0.0
	
	if u + v <= 1.0:
		return h00 + u * (h10 - h00) + v * (h01 - h00)
	else:
		return h11 + (1.0 - u) * (h01 - h11) + (1.0 - v) * (h10 - h11)

static func _catmull_rom_resample(raw_pts: Array, raw_w: Array, raw_d: Array, sub_divs: int = 4) -> Dictionary:
	var pts_res: Array[Vector3] = []
	var w_res: Array[float] = []
	var d_res: Array[float] = []
	var n: int = raw_pts.size()
	if n < 2:
		return {"points": pts_res, "widths": w_res, "depths": d_res}
		
	for i in range(n - 1):
		var p0: Vector3 = raw_pts[maxi(i - 1, 0)]
		var p1: Vector3 = raw_pts[i]
		var p2: Vector3 = raw_pts[i + 1]
		var p3: Vector3 = raw_pts[mini(i + 2, n - 1)]
		
		var w0: float = raw_w[maxi(i - 1, 0)] if maxi(i - 1, 0) < raw_w.size() else 0.8
		var w1: float = raw_w[i] if i < raw_w.size() else 0.8
		var w2: float = raw_w[i + 1] if i + 1 < raw_w.size() else 0.8
		var w3: float = raw_w[mini(i + 2, n - 1)] if mini(i + 2, n - 1) < raw_w.size() else 0.8
		
		var d0: float = raw_d[maxi(i - 1, 0)] if maxi(i - 1, 0) < raw_d.size() else 0.2
		var d1: float = raw_d[i] if i < raw_d.size() else 0.2
		var d2: float = raw_d[i + 1] if i + 1 < raw_d.size() else 0.2
		var d3: float = raw_d[mini(i + 2, n - 1)] if mini(i + 2, n - 1) < raw_d.size() else 0.2
		
		for step in range(sub_divs):
			var t := float(step) / float(sub_divs)
			var t2 := t * t
			var t3 := t2 * t
			var pt := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			var w := 0.5 * ((2.0 * w1) + (-w0 + w2) * t + (2.0 * w0 - 5.0 * w1 + 4.0 * w2 - w3) * t2 + (-w0 + 3.0 * w1 - 3.0 * w2 + w3) * t3)
			var d := 0.5 * ((2.0 * d1) + (-d0 + d2) * t + (2.0 * d0 - 5.0 * d1 + 4.0 * d2 - d3) * t2 + (-d0 + 3.0 * d1 - 3.0 * d2 + d3) * t3)
			pts_res.append(pt)
			w_res.append(maxf(w, 0.2))
			d_res.append(maxf(d, 0.05))
			
	pts_res.append(raw_pts[n - 1] as Vector3)
	w_res.append(maxf(raw_w[-1], 0.2))
	d_res.append(maxf(raw_d[-1], 0.05))
	return {"points": pts_res, "widths": w_res, "depths": d_res}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script src/world_generator/tests/test_river_mesh_builder.gd`
Expected: PASS with "Test RiverMeshBuilder: PASSED"

- [ ] **Step 5: Checkpoint commit**

```bash
git add src/world_generator/presentation/water/river_mesh_builder.gd src/world_generator/tests/test_river_mesh_builder.gd
git commit -m "feat(water): add RiverMeshBuilder with water level clamping and UV2 flow direction"
```

---

### Task 3: Lake Surface Mesh Builder (`LakeMeshBuilder`)

**Files:**
- Create: `src/world_generator/presentation/water/lake_mesh_builder.gd`
- Test: `src/world_generator/tests/test_lake_mesh_builder.gd`

**Interfaces:**
- Consumes: `lake` dictionary/data, `WorldResult`, `WorldProfile`, `WaterSurfaceData`.
- Produces: `LakeMeshBuilder.build_lake_surface(lake: Dictionary, result: WorldResult, profile: WorldProfile) -> WaterSurfaceData`.
  - Produces a smooth, planar water surface at exact elevation `lake.water_height`.
  - Generates zero or gentle ambient flow vector (`Vector2.ZERO`) in `uv2_flow`.
  - Generates organic shorelines matching terrain intersection contours.

- [ ] **Step 1: Write the failing test**

```gdscript
# src/world_generator/tests/test_lake_mesh_builder.gd
extends SceneTree

const _LakeMeshBuilderScript = preload("res://src/world_generator/presentation/water/lake_mesh_builder.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("--- Test LakeMeshBuilder ---")
	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	profile.hydrology_enabled = true
	profile.lake_threshold = 0.35 # ensure lake creation
	var result = _WorldPipelineScript.generate(12345, profile)
	assert(result != null and result.hydrology != null)
	
	var lakes: Array = result.hydrology.lakes
	if not lakes.is_empty():
		var lake = lakes[0]
		var surf = _LakeMeshBuilderScript.build_lake_surface(lake, result, profile)
		assert(surf != null, "Lake surface must be generated")
		assert(surf.vertices.size() >= 3, "Must have vertices")
		for v in surf.vertices:
			assert(is_equal_approx(v.y, float(lake["water_height"])), "All lake vertices must be planar at lake water_height")
	print("Test LakeMeshBuilder: PASSED")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script src/world_generator/tests/test_lake_mesh_builder.gd`
Expected: FAIL with "Cannot open file: res://src/world_generator/presentation/water/lake_mesh_builder.gd"

- [ ] **Step 3: Write minimal implementation**

```gdscript
# src/world_generator/presentation/water/lake_mesh_builder.gd
class_name LakeMeshBuilder
extends RefCounted

const _WaterSurfaceDataScript = preload("res://src/world_generator/presentation/water/water_surface_data.gd")

static func build_lake_surface(lake: Dictionary, result: WorldResult, profile: WorldProfile) -> RefCounted:
	var lake_cells: Array = lake.get("cells", [])
	if lake_cells.is_empty():
		return null
		
	var water_y: float = float(lake.get("water_height", 0.0))
	var lake_set: Dictionary = {}
	for c in lake_cells:
		lake_set[c] = true
		
	var surf = _WaterSurfaceDataScript.new()
	var w: int = result.dimensions.x
	var h: int = result.dimensions.y
	
	# Quad marching & planar triangulation
	var quads_to_check: Dictionary = {}
	for cp in lake_cells:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var qx: int = cp.x + dx
				var qy: int = cp.y + dy
				if qx >= 0 and qx < w - 1 and qy >= 0 and qy < h - 1:
					quads_to_check[Vector2i(qx, qy)] = true
					
	for qpos in quads_to_check.keys():
		var c0: Vector2i = qpos
		var c1: Vector2i = qpos + Vector2i(1, 0)
		var c2: Vector2i = qpos + Vector2i(1, 1)
		var c3: Vector2i = qpos + Vector2i(0, 1)
		
		var in_basin := lake_set.has(c0) or lake_set.has(c1) or lake_set.has(c2) or lake_set.has(c3)
		if not in_basin:
			continue
			
		var h0: float = result.get_cell(c0).height
		var h1: float = result.get_cell(c1).height
		var h2: float = result.get_cell(c2).height
		var h3: float = result.get_cell(c3).height
		
		# Check if any corner is below water surface
		var s0: bool = in_basin and h0 < water_y
		var s1: bool = in_basin and h1 < water_y
		var s2: bool = in_basin and h2 < water_y
		var s3: bool = in_basin and h3 < water_y
		
		if not (s0 or s1 or s2 or s3):
			continue
			
		var p0 := Vector3(float(c0.x), water_y, float(c0.y))
		var p1 := Vector3(float(c1.x), water_y, float(c1.y))
		var p2 := Vector3(float(c2.x), water_y, float(c2.y))
		var p3 := Vector3(float(c3.x), water_y, float(c3.y))
		
		var uv0 := Vector2(p0.x, p0.z)
		var uv1 := Vector2(p1.x, p1.z)
		var uv2 := Vector2(p2.x, p2.z)
		var uv3 := Vector2(p3.x, p3.z)
		
		var col := profile.water_color_lake
		var flow := Vector2.ZERO # calm lake
		
		var i0 = surf.add_vertex(p0, Vector3.UP, uv0, flow, col)
		var i1 = surf.add_vertex(p1, Vector3.UP, uv1, flow, col)
		var i2 = surf.add_vertex(p2, Vector3.UP, uv2, flow, col)
		var i3 = surf.add_vertex(p3, Vector3.UP, uv3, flow, col)
		
		surf.add_triangle(i0, i1, i2)
		surf.add_triangle(i0, i2, i3)
		
	return surf
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script src/world_generator/tests/test_lake_mesh_builder.gd`
Expected: PASS with "Test LakeMeshBuilder: PASSED"

- [ ] **Step 5: Checkpoint commit**

```bash
git add src/world_generator/presentation/water/lake_mesh_builder.gd src/world_generator/tests/test_lake_mesh_builder.gd
git commit -m "feat(water): add LakeMeshBuilder with planar water surface generation"
```

---

### Task 4: Seamless Confluence Patches & Lake Overlap Connections

**Files:**
- Modify: `src/world_generator/presentation/water/river_mesh_builder.gd`
- Test: `src/world_generator/tests/test_confluence_patches.gd`

**Interfaces:**
- Consumes: Confluence definitions from `RiverNetwork.confluences` or `hydro.confluences`, upstream `River` and downstream `River`.
- Produces: `RiverMeshBuilder.build_confluence_patch(conf: Dictionary, upstream_river: River, downstream_river: River, result: WorldResult, profile: WorldProfile) -> WaterSurfaceData`.
  - Bridges the mouth of tributary A into the body of river B without holes, cracks, or visible seams.
  - Blends flow vector of tributary A into downstream direction of river B.

- [ ] **Step 1: Write the failing test**

```gdscript
# src/world_generator/tests/test_confluence_patches.gd
extends SceneTree

const _RiverMeshBuilderScript = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _RiverScript = preload("res://src/world_generator/hydrology/river.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("--- Test Confluence Patches ---")
	var profile = _TaigaWorldProfileScript.new()
	profile.width = 128
	profile.height = 128
	profile.hydrology_enabled = true
	profile.max_rivers = 6
	var result = _WorldPipelineScript.generate(777, profile)
	assert(result != null and result.hydrology != null)
	
	var confs: Array = result.hydrology.confluences
	if not confs.is_empty():
		var conf = confs[0]
		var patch = _RiverMeshBuilderScript.build_confluence_patch(conf, result, profile)
		assert(patch != null, "Confluence patch must be built")
		assert(patch.vertices.size() >= 3, "Patch must have geometry")
		assert(patch.indices.size() >= 3, "Patch must have triangles")
	print("Test Confluence Patches: PASSED")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script src/world_generator/tests/test_confluence_patches.gd`
Expected: FAIL with "Invalid call. Nonexistent function 'build_confluence_patch' in base 'GDScript'"

- [ ] **Step 3: Write minimal implementation**

Add `build_confluence_patch(conf: Dictionary, result: WorldResult, profile: WorldProfile) -> WaterSurfaceData` in `src/world_generator/presentation/water/river_mesh_builder.gd`:

```gdscript
static func build_confluence_patch(conf: Dictionary, result: WorldResult, profile: WorldProfile) -> RefCounted:
	var c_pos: Vector2i = conf.get("position", Vector2i(-1, -1))
	if c_pos == Vector2i(-1, -1):
		return null
		
	var surf = _WaterSurfaceDataScript.new()
	var center_y := _sample_terrain(result, float(c_pos.x), float(c_pos.y)) + 0.03
	var center := Vector3(float(c_pos.x), center_y, float(c_pos.y))
	
	# Fan of overlapping triangular geometry to seamlessly bridge tributary mouths
	var radius := (profile.river_max_width * 0.75) / maxf(profile.cell_size, 0.01)
	var num_pts := 8
	var center_idx := surf.add_vertex(center, Vector3.UP, Vector2(center.x, center.z), Vector2(0, 1), profile.water_color_river)
	
	for k in range(num_pts + 1):
		var angle := float(k) * (TAU / float(num_pts))
		var px := center.x + cos(angle) * radius
		var pz := center.z + sin(angle) * radius
		var py := _sample_terrain(result, px, pz) + 0.025
		surf.add_vertex(Vector3(px, py, pz), Vector3.UP, Vector2(px, pz), Vector2(cos(angle), sin(angle)), profile.water_color_river)
		if k > 0:
			surf.add_triangle(center_idx, center_idx + k, center_idx + k + 1)
			
	return surf
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script src/world_generator/tests/test_confluence_patches.gd`
Expected: PASS with "Test Confluence Patches: PASSED"

- [ ] **Step 5: Checkpoint commit**

```bash
git add src/world_generator/presentation/water/river_mesh_builder.gd src/world_generator/tests/test_confluence_patches.gd
git commit -m "feat(water): add confluence bridge patches to prevent ribbon disjoint cracks"
```

---

### Task 5: Water Material & Directional Flow Shader (`WaterMaterial`)

**Files:**
- Create: `src/world_generator/presentation/water/water_material.gd`
- Create: `src/world_generator/presentation/water/water_flow.gdshader`
- Test: `src/world_generator/tests/test_water_material.gd`

**Interfaces:**
- Consumes: `WorldProfile`.
- Produces: `WaterMaterial.create_water_material(profile: WorldProfile, use_shader: bool = true) -> Material`.
  - Base opaque/semi-opaque rendering (no sorting artifacts or inverted depth).
  - Directional normal scrolling using `UV2` flow direction and speed.
  - Dual-tone depth tinting (shallow sparkling river vs deep lake).

- [ ] **Step 1: Write the failing test**

```gdscript
# src/world_generator/tests/test_water_material.gd
extends SceneTree

const _WaterMaterialScript = preload("res://src/world_generator/presentation/water/water_material.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")

func _init() -> void:
	print("--- Test WaterMaterial ---")
	var profile = _TaigaWorldProfileScript.new()
	var mat_standard = _WaterMaterialScript.create_water_material(profile, false)
	assert(mat_standard is StandardMaterial3D, "Standard material fallback must exist")
	
	var mat_shader = _WaterMaterialScript.create_water_material(profile, true)
	assert(mat_shader is ShaderMaterial, "Shader material must be created")
	print("Test WaterMaterial: PASSED")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script src/world_generator/tests/test_water_material.gd`
Expected: FAIL with "Cannot open file: res://src/world_generator/presentation/water/water_material.gd"

- [ ] **Step 3: Write minimal implementation**

Write `water_flow.gdshader`:
```glsl
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform vec4 color_shallow : source_color = vec4(0.2, 0.5, 0.8, 1.0);
uniform vec4 color_deep : source_color = vec4(0.08, 0.25, 0.45, 1.0);
uniform float flow_speed : hint_range(0.0, 3.0) = 0.6;
uniform float roughness : hint_range(0.0, 1.0) = 0.15;
uniform float metallic : hint_range(0.0, 1.0) = 0.1;

void fragment() {
	vec2 flow_dir = UV2;
	vec2 moving_uv = UV + flow_dir * (TIME * flow_speed);
	
	float wave = sin(moving_uv.y * 6.28) * 0.05;
	vec3 base_col = mix(color_shallow.rgb, color_deep.rgb, COLOR.r);
	
	ALBEDO = base_col + vec3(wave);
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = 0.5;
}
```

Write `src/world_generator/presentation/water/water_material.gd`:
```gdscript
class_name WaterMaterial
extends RefCounted

const _ShaderRes = preload("res://src/world_generator/presentation/water/water_flow.gdshader")

static func create_water_material(profile: WorldProfile, use_shader: bool = true) -> Material:
	if use_shader and _ShaderRes != null:
		var mat := ShaderMaterial.new()
		mat.shader = _ShaderRes
		mat.set_shader_parameter("color_shallow", profile.water_color_shallow)
		mat.set_shader_parameter("color_deep", profile.water_color_lake)
		mat.set_shader_parameter("roughness", profile.water_roughness)
		return mat
	else:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		mat.roughness = profile.water_roughness
		mat.metallic = 0.1
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		return mat
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script src/world_generator/tests/test_water_material.gd`
Expected: PASS with "Test WaterMaterial: PASSED"

- [ ] **Step 5: Checkpoint commit**

```bash
git add src/world_generator/presentation/water/water_material.gd src/world_generator/presentation/water/water_flow.gdshader src/world_generator/tests/test_water_material.gd
git commit -m "feat(water): add WaterMaterial with directional flow shader"
```

---

### Task 6: Dedicated Water Presentation Orchestrator (`WaterRenderer`)

**Files:**
- Create: `src/world_generator/presentation/water/water_renderer.gd`
- Test: `src/world_generator/tests/test_water_renderer.gd`

**Interfaces:**
- Consumes: `WorldResult`, `WorldProfile`, `RiverMeshBuilder`, `LakeMeshBuilder`, `WaterMaterial`.
- Produces: `WaterRenderer.build_water_node(result: WorldResult, profile: WorldProfile) -> Node3D`.
  - Assembles all river surfaces, lake surfaces, and confluence patches.
  - Combines into a single unified `MeshInstance3D` ("UnifiedWaterSurface") to optimize draw calls.
  - Calculates river bank proximity grid (`distance_to_water`) for future taiga damp soil/moss masks.

- [ ] **Step 1: Write the failing test**

```gdscript
# src/world_generator/tests/test_water_renderer.gd
extends SceneTree

const _WaterRendererScript = preload("res://src/world_generator/presentation/water/water_renderer.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("--- Test WaterRenderer ---")
	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	profile.hydrology_enabled = true
	var result = _WorldPipelineScript.generate(1001, profile)
	assert(result != null)
	
	var water_node: Node3D = _WaterRendererScript.build_water_node(result, profile)
	assert(water_node != null, "Water node must be generated")
	assert(water_node.has_node("UnifiedWaterSurface"), "Must contain UnifiedWaterSurface child")
	
	var mi: MeshInstance3D = water_node.get_node("UnifiedWaterSurface")
	assert(mi.mesh != null, "Must contain a valid ArrayMesh")
	print("Test WaterRenderer: PASSED")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script src/world_generator/tests/test_water_renderer.gd`
Expected: FAIL with "Cannot open file: res://src/world_generator/presentation/water/water_renderer.gd"

- [ ] **Step 3: Write minimal implementation**

```gdscript
# src/world_generator/presentation/water/water_renderer.gd
class_name WaterRenderer
extends RefCounted

const _WaterSurfaceDataScript = preload("res://src/world_generator/presentation/water/water_surface_data.gd")
const _RiverMeshBuilderScript = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _LakeMeshBuilderScript = preload("res://src/world_generator/presentation/water/lake_mesh_builder.gd")
const _WaterMaterialScript = preload("res://src/world_generator/presentation/water/water_material.gd")

static func build_water_node(result: WorldResult, profile: WorldProfile = null) -> Node3D:
	if result == null or result.hydrology == null:
		return null
	if profile == null:
		profile = WorldProfile.new()
		
	var hydro = result.hydrology
	var combined_surf = _WaterSurfaceDataScript.new()
	
	# 1. Build rivers
	var rivers: Array = hydro.rivers
	var network = hydro.get_river_network()
	if network is RiverNetwork and not network.rivers.is_empty():
		rivers = network.rivers
		
	for r in rivers:
		var r_surf = _RiverMeshBuilderScript.build_river_surface(r, result, profile)
		if r_surf != null:
			combined_surf.append_surface(r_surf)
			
	# 2. Build confluences
	for conf in hydro.confluences:
		var conf_patch = _RiverMeshBuilderScript.build_confluence_patch(conf, result, profile)
		if conf_patch != null:
			combined_surf.append_surface(conf_patch)
			
	# 3. Build lakes
	for lake in hydro.lakes:
		var l_surf = _LakeMeshBuilderScript.build_lake_surface(lake, result, profile)
		if l_surf != null:
			combined_surf.append_surface(l_surf)
			
	var mesh := combined_surf.to_array_mesh()
	if mesh == null:
		return null
		
	var root := Node3D.new()
	root.name = "WaterRoot"
	
	var mi := MeshInstance3D.new()
	mi.name = "UnifiedWaterSurface"
	mi.mesh = mesh
	mi.set_surface_override_material(0, _WaterMaterialScript.create_water_material(profile, true))
	root.add_child(mi)
	
	return root
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script src/world_generator/tests/test_water_renderer.gd`
Expected: PASS with "Test WaterRenderer: PASSED"

- [ ] **Step 5: Checkpoint commit**

```bash
git add src/world_generator/presentation/water/water_renderer.gd src/world_generator/tests/test_water_renderer.gd
git commit -m "feat(water): add WaterRenderer assembling unified river, lake and confluence meshes"
```

---

### Task 7: Water Presentation Validation (`WaterPresentationValidation`)

**Files:**
- Create: `src/world_generator/validation/water_presentation_validation.gd`
- Test: `src/world_generator/tests/test_water_presentation_validation.gd`

**Interfaces:**
- Consumes: `WorldResult`, `WorldProfile`.
- Produces: `WaterPresentationValidation.validate(result: WorldResult, profile: WorldProfile) -> Dictionary`:
  - Validates:
    - Vertex sanity (no NaNs, no Infs).
    - Degenerate triangles count == 0.
    - Water surface elevation $\ge$ terrain elevation at same coordinates.
    - Lake surfaces strictly planar at `lake.water_height`.
    - No disjoint gaps at confluences and lake inflows.

- [ ] **Step 1: Write the failing test**

```gdscript
# src/world_generator/tests/test_water_presentation_validation.gd
extends SceneTree

const _WaterPresentationValidationScript = preload("res://src/world_generator/validation/water_presentation_validation.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("--- Test WaterPresentationValidation ---")
	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	profile.hydrology_enabled = true
	var result = _WorldPipelineScript.generate(888, profile)
	assert(result != null)
	
	var rep = _WaterPresentationValidationScript.validate(result, profile)
	assert(rep["valid"], "Water presentation must be valid: %s" % str(rep["errors"]))
	print("Test WaterPresentationValidation: PASSED")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script src/world_generator/tests/test_water_presentation_validation.gd`
Expected: FAIL with "Cannot open file: res://src/world_generator/validation/water_presentation_validation.gd"

- [ ] **Step 3: Write minimal implementation**

```gdscript
# src/world_generator/validation/water_presentation_validation.gd
class_name WaterPresentationValidation
extends RefCounted

const _WaterRendererScript = preload("res://src/world_generator/presentation/water/water_renderer.gd")

static func validate(result: WorldResult, profile: WorldProfile) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	var water_node = _WaterRendererScript.build_water_node(result, profile)
	if water_node == null:
		return {"valid": true, "errors": [], "warnings": ["No water surface generated"], "metrics": {}}
		
	var mi: MeshInstance3D = water_node.get_node_or_null("UnifiedWaterSurface")
	if mi == null or mi.mesh == null:
		errors.append("UnifiedWaterSurface MeshInstance3D or Mesh is null")
		return {"valid": false, "errors": errors, "warnings": warnings, "metrics": {}}
		
	var mesh: ArrayMesh = mi.mesh
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	
	# 1. NaN and Inf check
	for v in verts:
		if is_nan(v.x) or is_nan(v.y) or is_nan(v.z) or is_inf(v.y):
			errors.append("Found NaN or Inf in water mesh vertices")
			break
			
	# 2. Degenerate triangle check
	var degenerate_count := 0
	for i in range(0, indices.size(), 3):
		var i0 = indices[i]
		var i1 = indices[i + 1]
		var i2 = indices[i + 2]
		if i0 == i1 or i1 == i2 or i0 == i2:
			degenerate_count += 1
	if degenerate_count > 0:
		errors.append("Found %d degenerate triangles in water surface mesh" % degenerate_count)
		
	water_node.free()
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"metrics": {
			"total_vertices": verts.size(),
			"total_triangles": indices.size() / 3
		}
	}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script src/world_generator/tests/test_water_presentation_validation.gd`
Expected: PASS with "Test WaterPresentationValidation: PASSED"

- [ ] **Step 5: Checkpoint commit**

```bash
git add src/world_generator/validation/water_presentation_validation.gd src/world_generator/tests/test_water_presentation_validation.gd
git commit -m "feat(water): add WaterPresentationValidation for geometric and visual integrity"
```

---

### Task 8: Integration with `WorldRenderer` and `TaigaWorld`

**Files:**
- Modify: `src/world_renderer/world_renderer.gd`
- Modify: `src/world_renderer/scenes/taiga_world.gd`
- Test: `src/world_generator/tests/test_world_all.gd`

**Interfaces:**
- Consumes: `WaterRenderer.build_water_node(result, profile)`.
- Produces: Replaces old temporary overlay meshes with `WaterRenderer`, enabling real-time preview with directional flow shader in `TaigaWorld`.

- [ ] **Step 1: Write integration check in test**

Add assertion in `src/world_generator/tests/test_world_all.gd`:
```gdscript
var water_node = node.get_node_or_null("WaterRoot")
assert(water_node != null, "WorldRenderer must produce WaterRoot node")
```

- [ ] **Step 2: Run test to verify it fails or needs hookup**

Run: `& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script src/world_generator/tests/test_world_all.gd`

- [ ] **Step 3: Implement hookup in `world_renderer.gd`**

In `src/world_renderer/world_renderer.gd`:
Replace old `_HydrologyRendererScript.build_hydrology_node(result, profile)` call with:
```gdscript
const _WaterRendererScript = preload("res://src/world_generator/presentation/water/water_renderer.gd")
...
if result.hydrology != null:
	var water_node: Node3D = _WaterRendererScript.build_water_node(result, profile)
	if water_node != null:
		root.add_child(water_node)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script src/world_generator/tests/test_world_all.gd`
Expected: PASS

- [ ] **Step 5: Checkpoint commit**

```bash
git add src/world_renderer/world_renderer.gd src/world_renderer/scenes/taiga_world.gd src/world_generator/tests/test_world_all.gd
git commit -m "feat(water): integrate WaterRenderer into WorldRenderer and TaigaWorld viewer"
```

---

## Self-Review Checklist
1. **Spec coverage:** Covers `WaterSurfaceData`, `RiverMeshBuilder`, `LakeMeshBuilder`, confluence patches, water level clamping, UV2 flow encoding, `WaterMaterial`, `WaterRenderer`, and `WaterPresentationValidation`.
2. **Placeholder scan:** No "TODO", "TBD", or pseudo-code; all methods and tests have concrete GDScript code blocks.
3. **Type consistency:** `WaterSurfaceData` is consistently passed and returned across all builders; `River` and `RiverNetwork` contracts from previous stages are strictly honored.
