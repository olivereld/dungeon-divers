# Continuous Confluence Junctions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the isolated radial center-fan with continuous, topographically-coherent junction surfaces between upstream rivers and downstream channels ($N \to 1$), eliminating star-burst spikes and gap artifacts while maintaining strict ribbon quad continuity.

**Architecture:** A dedicated confluence junction builder in `river_mesh_builder.gd` (called by `WaterRenderer`) that: (1) queries `RiverNetwork` for confluence topology and tributary vectors, (2) identifies boundary transition cross-sections on each incident river ribbon, (3) constructs an ordered outer contour polygon connecting upstream $(L_k, R_k)$ to downstream $(L_D, R_D)$, (4) bridges the junction using longitudinal quad/triangle strips rather than a radial hub-and-spoke fan, (5) interpolates surface elevation and channel width smoothly downstream, and (6) emits telemetry on junction quad validity.

**Tech Stack:** Godot 4.6.1 GDScript, `RiverNetwork`, `River`, `WaterSurfaceData`, `RiverMeshBuilder`, `WaterRenderer`.

**Spec:** User technical specification: "Bloque de Confluencias — BLOQUES C1 al C11".

## Global Constraints
- **Hydrology Immutability:** Never modify `HydrologyStage`, `River`, `RiverNetwork`, or heightmaps. All topological adjacency comes directly from `RiverNetwork.confluences` and `River.upstream_rivers`.
- **No Radial Fans:** Absolute ban on center-vertex triangle fans (`center + radius * circle + radial triangles`). All junction topology must use oriented bridge strips matching ribbon stations.
- **Generalized $N \to 1$ Topology:** Algorithm must support 2 upstream tributaries, 3 upstream tributaries, and $N$ upstream tributaries merging into 1 downstream channel without hardcoded 2-way assumptions.
- **Vertical Clamping:** Junction water height must smoothly interpolate tributary water levels down to the receiver channel, with local bed and bank clamping preserving water containment.

---

### Task 1: Model Confluence Topology & Extract Boundary Stations (Bloque C1, C3)

**Files:**
- Modify: `src/world_generator/presentation/water/river_mesh_builder.gd`
- Test: `src/world_generator/tests/test_confluence_network_topology.gd`

**Interfaces:**
- Consumes: `conf: Dictionary`, `network: RiverNetwork`, `result: WorldResult`, `profile: WorldProfile`.
- Produces: `Dictionary` with structured confluence data:
  ```gdscript
  {
      "pos": Vector3,
      "downstream_river": River,
      "upstream_rivers": Array[River],
      "downstream_station": {"left": Vector3, "right": Vector3, "center": Vector3, "dir": Vector3, "width": float, "water_y": float},
      "upstream_stations": Array[Dictionary] # each with left, right, center, dir, width, water_y
  }
  ```

- [ ] **Step 1: Write unit test verifying topology extraction for 2->1 confluence**

```gdscript
# src/world_generator/tests/test_confluence_network_topology.gd
extends SceneTree

const _RiverMeshBuilder = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _River = preload("res://src/world_generator/hydrology/river.gd")
const _RiverNetwork = preload("res://src/world_generator/hydrology/river_network.gd")

func _init() -> void:
	print("--- Test Confluence Network Topology ---")
	var net = _RiverNetwork.new()

	var r_up1 = _River.new(1, Vector2i(0, 0), [Vector2i(0, 0), Vector2i(5, 5)])
	var r_up2 = _River.new(2, Vector2i(0, 10), [Vector2i(0, 10), Vector2i(5, 5)])
	var r_down = _River.new(3, Vector2i(5, 5), [Vector2i(5, 5), Vector2i(10, 5)])

	r_up1.points = [Vector3(0, 0, 0), Vector3(5, 0, 5)]
	r_up1.widths = [1.0, 1.2]
	r_up1.depths = [0.2, 0.2]
	r_up1.downstream_river = 3

	r_up2.points = [Vector3(0, 0, 10), Vector3(5, 0, 5)]
	r_up2.widths = [1.0, 1.2]
	r_up2.depths = [0.2, 0.2]
	r_up2.downstream_river = 3

	r_down.points = [Vector3(5, 0, 5), Vector3(10, 0, 5)]
	r_down.widths = [1.5, 1.8]
	r_down.depths = [0.3, 0.3]
	r_down.upstream_rivers = [1, 2]

	net.add_river(r_up1)
	net.add_river(r_up2)
	net.add_river(r_down)

	var conf_dict := {
		"position": Vector2i(5, 5),
		"upstream_rivers": [1, 2],
		"downstream_river": 3
	}

	var dummy_profile = WorldProfile.new()
	var junction_data = _RiverMeshBuilder._extract_confluence_stations(conf_dict, net, null, dummy_profile)
	assert(junction_data != null, "Junction data must be extracted")
	assert(junction_data["upstream_stations"].size() == 2, "Must have 2 upstream stations")
	assert(junction_data["downstream_station"] != null, "Must have 1 downstream station")

	print("Test Confluence Network Topology: PASSED")
	quit(0)
```

- [ ] **Step 2: Implement `_extract_confluence_stations` in `river_mesh_builder.gd`**
- Query `network.get_river(id)` for all upstream and downstream river references.
- For each upstream river: determine entry vector, endpoint station $(L, R)$, and entry width/depth.
- For downstream river: determine start station $(L_D, R_D)$ and initial width/depth.
- Return structured station data.

---

### Task 2: Build Contour Polygon and Strip-Bridge Surface (Bloque C2, C4, C5)

**Files:**
- Modify: `src/world_generator/presentation/water/river_mesh_builder.gd`
- Test: `src/world_generator/tests/test_confluence_strip_bridge.gd`

**Interfaces:**
- Consumes: structured junction data from Task 1.
- Produces: `WaterSurfaceData` containing strip-triangulated junction geometry (zero radial center vertices).

- [ ] **Step 1: Write test verifying zero radial fan triangles in junction patch**

```gdscript
# src/world_generator/tests/test_confluence_strip_bridge.gd
extends SceneTree

const _RiverMeshBuilder = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _River = preload("res://src/world_generator/hydrology/river.gd")
const _RiverNetwork = preload("res://src/world_generator/hydrology/river_network.gd")

func _init() -> void:
	print("--- Test Confluence Strip Bridge ---")
	var net = _RiverNetwork.new()
	var r_up1 = _River.new(1, Vector2i(0, 0), [Vector2i(0, 0), Vector2i(5, 5)])
	var r_up2 = _River.new(2, Vector2i(0, 10), [Vector2i(0, 10), Vector2i(5, 5)])
	var r_down = _River.new(3, Vector2i(5, 5), [Vector2i(5, 5), Vector2i(10, 5)])
	r_up1.points = [Vector3(0, 0, 0), Vector3(5, 0, 5)]
	r_up1.widths = [1.0, 1.2]
	r_up1.depths = [0.2, 0.2]
	r_up2.points = [Vector3(0, 0, 10), Vector3(5, 0, 5)]
	r_up2.widths = [1.0, 1.2]
	r_up2.depths = [0.2, 0.2]
	r_down.points = [Vector3(5, 0, 5), Vector3(10, 0, 5)]
	r_down.widths = [1.6, 2.0]
	r_down.depths = [0.3, 0.3]
	net.add_river(r_up1)
	net.add_river(r_up2)
	net.add_river(r_down)

	var conf_dict := {"position": Vector2i(5, 5), "upstream_rivers": [1, 2], "downstream_river": 3}
	var dummy_profile = WorldProfile.new()
	var surf = _RiverMeshBuilder.build_confluence_surface(conf_dict, net, null, dummy_profile)

	assert(surf != null, "Confluence surface must be built")
	assert(surf.vertices.size() >= 6, "Must have boundary vertices")
	assert(surf.indices.size() >= 6, "Must have bridge triangles")

	# Verify no single vertex is shared by > 5 triangles (no central radial hub)
	var vertex_triangle_count: Dictionary = {}
	for idx in surf.indices:
		vertex_triangle_count[idx] = vertex_triangle_count.get(idx, 0) + 1
	for idx in vertex_triangle_count.keys():
		assert(vertex_triangle_count[idx] <= 5, "No vertex should act as a radial star hub")

	print("Test Confluence Strip Bridge: PASSED")
	quit(0)
```

- [ ] **Step 2: Implement `build_confluence_surface` replacing the radial fan**
- Sort upstream tributaries angularly relative to the downstream outflow direction.
- Build contour vertices along tributary mouths.
- Bridge adjacent tributaries with quad/strip triangulation down to the downstream mouth $(L_D, R_D)$.
- Connect $(L_{up\_left}, R_{up\_left})$ to the left bank of downstream, $(L_{up\_right}, R_{up\_right})$ to the right bank, and bridge the interior gap between tributary mouths using a smooth wedge-quad strip.
- Validate all generated triangles with `_triangle_is_valid`.

---

### Task 3: Width Continuity & Water Elevation Interpolation (Bloque C6, C7)

**Files:**
- Modify: `src/world_generator/presentation/water/river_mesh_builder.gd`

**Interfaces:**
- Input: upstream widths $w_1, w_2, \dots$, downstream width $w_D$, upstream water heights $y_1, y_2, \dots$, downstream water height $y_D$.
- Invariant: Junction width $w_J \ge \max(w_k, w_D)$, water elevation $y(t) = \text{lerp}(y_{up}, y_{down}, t)$, clamped between bed and bank.

- [ ] **Step 1: Implement width scaling and vertical blending**
- Interpolate width across junction stations: ensure mouth width smoothly widens toward the receiving river without bottleneck constriction.
- Sample terrain bed and bank along junction vertices.
- Ensure water elevation strictly descends downstream: $y_{\text{junction}} \le \max(y_{\text{up}})$, $y_{\text{junction}} \ge y_{\text{down}}$.
- Clamp water level above local bed (`bed + 0.015`) and below banks (`bank + 0.02`).

---

### Task 4: Generalized Multi-Branch $N \to 1$ Support (Bloque C8)

**Files:**
- Modify: `src/world_generator/presentation/water/river_mesh_builder.gd`
- Test: `src/world_generator/tests/test_confluence_n_branches.gd`

**Interfaces:**
- Supports arbitrary $N \ge 1$ upstream tributaries merging into a single downstream trunk.

- [ ] **Step 1: Write test for 3->1 confluence**
- Setup 3 upstream rivers entering at angles -45°, 0°, +45° relative to the downstream channel.
- Verify `build_confluence_surface` builds a continuous junction mesh with zero NaN/Inf and valid triangle winding.

- [ ] **Step 2: Implement angular partitioning for $N$ tributaries**
- Order tributaries by incoming angle from left to right.
- Stitch tributary $k$ to tributary $k+1$ across the inner banks, and stitch outermost banks directly to $(L_D, R_D)$.

---

### Task 5: Integrate into `WaterRenderer` & Confluence Telemetry (Bloque C10)

**Files:**
- Modify: `src/world_generator/presentation/water/water_renderer.gd:20-55`
- Modify: `src/world_generator/presentation/water/river_mesh_builder.gd`

**Interfaces:**
- `WaterRenderer.build_water_node()` iterates over `network.confluences`, invokes `build_confluence_surface()`, and appends geometry to `combined_surf`.
- Telemetry: prints `[ConfluenceDiagnostics]` per junction:
  - `confluences_processed`, `junction_vertices`, `junction_triangles`, `skipped_triangles`.

- [ ] **Step 1: Hook up `build_confluence_surface` in `WaterRenderer`**
- [ ] **Step 2: Add single-line confluence diagnostic summary**

---

### Task 6: Comprehensive Confluence Test Suite & Survey (Bloques C9, C11)

**Files:**
- Create: `src/world_generator/tests/test_confluence_comprehensive.gd`
- Output: `docs/confluence_survey_report.txt`

- [ ] **Step 1: Implement test verifying Cases 1-5 from Bloque C9:**
  - Case 1: $2 \to 1$ gentle angle (< 45°)
  - Case 2: $2 \to 1$ sharp angle (> 75°)
  - Case 3: $2 \to 1$ asymmetrical entry angles
  - Case 4: $3 \to 1$ multi-tributary junction
  - Case 5: Confluence with immediate downstream bend
- [ ] **Step 2: Run test suite headlessly across seeds 12345, 42, 101, 202**
- [ ] **Step 3: Document findings in `docs/confluence_survey_report.txt` and `walkthrough.md`**

---

## Verification Plan

### Automated Tests
- Run confluence test suite:
  ```powershell
  & "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script res://src/world_generator/tests/test_confluence_comprehensive.gd
  ```
- Verify 0 skipped triangles, 0 degenerate triangles, 0 NaN coordinates.

### Manual Verification
- Open `TaigaWorld` in Godot:
  - Seed 12345, 64x64.
  - Navigate camera to river confluence junctions.
  - Confirm visually: smooth continuous water surface, absence of radial star-burst lines or needle spikes, seamless connection between tributaries and main stem.
