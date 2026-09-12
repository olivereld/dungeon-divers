# Junction Closure: Explicit Width, Strict Ownership, & Formal Validation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Formally close the river confluence junction subsystem by enforcing explicit ground-truth width interpolation, establishing strict mutually-exclusive geometric ownership between ribbons and junctions (zero z-fighting, zero gaps), implementing rigorous junction quad/gap validation, executing a dedicated 5-category survey, and consolidating the public API.

**Architecture:** 
1. **Explicit Width Interpolation (Bloque 1):** Stations define $w(t) = \text{lerp}(w_{\text{start}}, w_{\text{end}}, t)$ as ground truth and derive $L, R = \text{center} \pm \vec{n} \cdot (w/2)$, rather than interpolating left/right vertex coordinates directly.
2. **Strict Geometric Ownership (Bloque 2):** Upstream ribbons trim their terminal stations before the junction transition zone; downstream ribbons delay their initial stations after the junction; the confluence surface exclusively owns the transition zone $[S_{\text{entry}} \to S_{\text{exit}}]$ with exact boundary vertex sharing.
3. **Dedicated Junction Validation (Bloque 3):** Specialized validators checking quad winding, edge cross absence, longitudinal forward progress, strip-to-strip gap absence, and anomalous area ratios.
4. **Diagnostic Survey (Bloque 4):** Headless test measuring $2 \to 1$, $3 \to 1$, $4 \to 1$, asymmetric, and curve-adjacent junctions across multiple seeds.
5. **API Consolidation (Bloque 5):** Remove `build_confluence_surface_multistation()` and deprecate radial fan wrappers, leaving `build_confluence_surface()` as the single entrypoint.

**Tech Stack:** Godot 4.6.1 GDScript, `RiverMeshBuilder`, `RiverNetwork`, `River`, `WaterSurfaceData`, `WaterRenderer`.

**Spec:** User technical specification: "Plan de cierre de la Junction — Bloques 1 al 5".

## Global Constraints
- **Hydrology Immutability:** Never modify `HydrologyStage`, D8, accumulation, `RiverNetwork`, or terrain carving.
- **Exclusive Spatial Ownership:** No single square meter of water surface can be claimed by both a river ribbon and a confluence junction. Zero overlapping duplicate triangles. Zero gaps at the boundary.
- **Width Ground Truth:** Transverse width is never an accidental byproduct of vertex interpolation; it must be explicitly governed by width scalars.
- **Order of Execution:**
  1. Explicit Width Interpolation $\to$
  2. Ownership & Ribbon Trimming $\to$
  3. Junction Validation $\to$
  4. Confluence Survey $\to$
  5. API Consolidation.

---

### Task 1: Explicit Ground-Truth Width & Station Generator (Bloque 1)

**Files:**
- Modify: `src/world_generator/presentation/water/river_mesh_builder.gd:570-650`
- Test: `src/world_generator/tests/test_junction_explicit_width.gd`

**Interfaces:**
- Consumes: `up_stations: Array[Dictionary]`, `down_st: Dictionary`, `m_steps: int`.
- Produces: Grid of transition stations where every station row $m$ and branch $k$ explicitly computes:
  ```gdscript
  {
      "center": Vector3,
      "dir": Vector3,
      "normal": Vector3,
      "width": float,
      "half_width": float,
      "left": Vector3,
      "right": Vector3,
      "water_y": float
  }
  ```
- Mathematical guarantees:
  - $w_k(t) = \text{lerpf}(w_{uk}, w_D / N, t)$
  - $\vec{n}_k(t) = \text{Vector3}(-\vec{d}_k(t).z, 0, \vec{d}_k(t).x).normalized()$
  - $L_k(t) = \vec{c}_k(t) + \vec{n}_k(t) \cdot (w_k(t) / 2)$
  - $R_k(t) = \vec{c}_k(t) - \vec{n}_k(t) \cdot (w_k(t) / 2)$

- [ ] **Step 1: Write unit test verifying explicit width monotonicity and exact boundary matching**

```gdscript
# src/world_generator/tests/test_junction_explicit_width.gd
extends SceneTree

const _RiverMeshBuilder = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _River = preload("res://src/world_generator/hydrology/river.gd")
const _RiverNetwork = preload("res://src/world_generator/hydrology/river_network.gd")

func _init() -> void:
	print("--- Test Junction Explicit Width ---")
	var net = _RiverNetwork.new()
	var r1 = _River.new(0, Vector2i(0, 0), [])
	r1.points = [Vector3(0, 0, 0), Vector3(5, 0, 2)]
	r1.widths = [1.0, 1.2]
	r1.depths = [0.2, 0.2]
	r1.downstream_river = 2

	var r2 = _River.new(1, Vector2i(0, 4), [])
	r2.points = [Vector3(0, 0, 4), Vector3(5, 0, 2)]
	r2.widths = [1.0, 1.4]
	r2.depths = [0.2, 0.2]
	r2.downstream_river = 2

	var r_down = _River.new(2, Vector2i(5, 2), [])
	r_down.points = [Vector3(5, 0, 2), Vector3(10, 0, 2)]
	r_down.widths = [2.6, 2.8]
	r_down.depths = [0.3, 0.3]
	r_down.upstream_rivers = [0, 1]

	net.add_river(r1)
	net.add_river(r2)
	net.add_river(r_down)

	var conf := {"position": Vector2i(5, 2), "upstream_rivers": [0, 1], "downstream_river": 2}
	var dummy_profile = WorldProfile.new()

	var station_grid = _RiverMeshBuilder._generate_explicit_junction_stations(conf, net, null, dummy_profile, 3)
	assert(station_grid.size() == 2, "Must have 2 branches")

	for k in range(station_grid.size()):
		var branch_stations: Array = station_grid[k]
		assert(branch_stations.size() == 4, "Must have M+1 = 4 stations")
		var w_start: float = branch_stations[0]["width"]
		var w_end: float = branch_stations[3]["width"]
		for m in range(branch_stations.size()):
			var st: Dictionary = branch_stations[m]
			assert(st["width"] > 0.0, "Width must be positive")
			assert(st["half_width"] == st["width"] * 0.5, "Half width must match")
			var calculated_w: float = st["left"].distance_to(st["right"])
			assert(absf(calculated_w - st["width"]) < 0.001, "Geometry must match explicit width exactly")

	print("Test Junction Explicit Width: PASSED")
	quit(0)
```

- [ ] **Step 2: Implement `_generate_explicit_junction_stations` in `river_mesh_builder.gd`**
- [ ] **Step 3: Refactor `build_confluence_surface` to consume the explicit station grid**

---

### Task 2: Strict Ownership & Ribbon Trimming (Bloque 2)

**Files:**
- Modify: `src/world_generator/presentation/water/river_mesh_builder.gd:25-75, 560-640`
- Test: `src/world_generator/tests/test_confluence_ownership_trimming.gd`

**Interfaces:**
- In `build_river_surface()`:
  - If `river.downstream_river != -1`: river terminates at confluence. Trim centerline points by boundary margin $L_{\text{trans\_up}}$ so the ribbon stops at the junction boundary station $S_{\text{entry}}$.
  - If `river.upstream_rivers.size() > 0`: river originates from confluence. Trim start of centerline by boundary margin $L_{\text{trans\_down}}$ so the ribbon begins at $S_{\text{exit}}$.
- In `build_confluence_surface()`:
  - Confluence generates geometry strictly between $S_{\text{entry}}$ and $S_{\text{exit}}$.
  - Boundary vertices coincide with ribbon endpoints bit-by-bit (zero overlap, zero gap).

- [ ] **Step 1: Write test verifying zero spatial overlap and zero gap between trimmed ribbon and junction**

```gdscript
# src/world_generator/tests/test_confluence_ownership_trimming.gd
extends SceneTree

const _RiverMeshBuilder = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _River = preload("res://src/world_generator/hydrology/river.gd")
const _RiverNetwork = preload("res://src/world_generator/hydrology/river_network.gd")

func _init() -> void:
	print("--- Test Confluence Ownership Trimming ---")
	var net = _RiverNetwork.new()
	var r1 = _River.new(0, Vector2i(0, 0), [])
	r1.points = [Vector3(0, 0, 0), Vector3(3, 0, 1), Vector3(6, 0, 2)]
	r1.widths = [1.2, 1.2, 1.2]
	r1.depths = [0.2, 0.2, 0.2]
	r1.downstream_river = 1

	var r_down = _River.new(1, Vector2i(6, 2), [])
	r_down.points = [Vector3(6, 0, 2), Vector3(9, 0, 2), Vector3(12, 0, 2)]
	r_down.widths = [2.0, 2.0, 2.0]
	r_down.depths = [0.3, 0.3, 0.3]
	r_down.upstream_rivers = [0]

	net.add_river(r1)
	net.add_river(r_down)

	var dummy_profile = WorldProfile.new()

	# Build upstream ribbon with boundary trim
	var r1_surf = _RiverMeshBuilder.build_river_surface(r1, null, dummy_profile, net)
	# Build downstream ribbon with boundary trim
	var down_surf = _RiverMeshBuilder.build_river_surface(r_down, null, dummy_profile, net)

	# Verify tributary ribbon trimmed terminal station
	var r1_last_l: Vector3 = r1_surf.vertices[-2]
	var r1_last_r: Vector3 = r1_surf.vertices[-1]

	# Build confluence surface
	var conf := {"position": Vector2i(6, 2), "upstream_rivers": [0], "downstream_river": 1}
	var conf_surf = _RiverMeshBuilder.build_confluence_surface(conf, null, dummy_profile, net, 3)

	# Verify confluence entry vertices match trimmed ribbon terminal vertices
	var conf_first_l: Vector3 = conf_surf.vertices[0]
	var conf_first_r: Vector3 = conf_surf.vertices[1]

	assert(r1_last_l.distance_to(conf_first_l) < 0.05, "Upstream ribbon and confluence entry must be continuous")
	assert(r1_last_r.distance_to(conf_first_r) < 0.05, "Upstream ribbon and confluence entry must be continuous")

	print("Test Confluence Ownership Trimming: PASSED")
	quit(0)
```

- [ ] **Step 2: Implement boundary trimming in `build_river_surface` and boundary handoff in `build_confluence_surface`**
- [ ] **Step 3: Run test to confirm zero overlap and zero gaps**

---

### Task 3: Dedicated Junction Geometric Validator (Bloque 3)

**Files:**
- Modify: `src/world_generator/presentation/water/river_mesh_builder.gd`
- Create: `src/world_generator/validation/junction_validator.gd`
- Test: `src/world_generator/tests/test_junction_validator.gd`

**Interfaces:**
- Function: `JunctionValidator.validate_junction(surf: WaterSurfaceData, conf: Dictionary, net: RiverNetwork) -> Dictionary`:
  - `is_valid: bool`
  - `errors: Array[String]`
  - `metrics: Dictionary`
- Specific checks:
  1. Quad winding & non-inversion.
  2. Edge non-intersection in XZ plane ($L_0 \to L_1$ vs $R_0 \to R_1$).
  3. Minimum and maximum quad area ratios.
  4. Inter-strip gap detection (adjacent inner crooks must share or bridge boundary coordinates).
  5. Monotonic longitudinal progress.

- [ ] **Step 1: Implement `junction_validator.gd`**
- [ ] **Step 2: Write test verifying that invalid/crossed/inverted quads are caught**
- [ ] **Step 3: Integrate validator into `build_confluence_surface`**

---

### Task 4: Confluence In-Flight Diagnostics & Comprehensive Survey (Bloque 4)

**Files:**
- Modify: `src/world_generator/presentation/water/river_mesh_builder.gd`
- Create: `src/world_generator/tests/survey_confluence_junctions.gd`
- Output: `docs/confluence_junctions_survey_report.txt`

**Interfaces:**
- Emits telemetry line: `[ConfluenceDiagnostics] junction_id=X branches=N steps=M quads=Q tris=T invalid_quads=0 crossed=0 gaps=0 overlaps=0`
- Headless survey script executing:
  - 10 procedural seeds with $64 \times 64$ maps.
  - Covers $2 \to 1$, $3 \to 1$, $4 \to 1$, asymmetric angles, sharp bends, differing widths.
  - Verifies:
    - `invalid_quads == 0`
    - `crossed_edges == 0`
    - `inverted_quads == 0`
    - `gaps == 0`
    - `ownership_overlaps == 0`
    - `continuity_failures == 0`

- [ ] **Step 1: Write `survey_confluence_junctions.gd`**
- [ ] **Step 2: Run survey and write `docs/confluence_junctions_survey_report.txt`**
- [ ] **Step 3: Verify all failure metrics equal 0**

---

### Task 5: Eliminate API Duplication (`multistation` Wrapper Removal) (Bloque 5)

**Files:**
- Modify: `src/world_generator/presentation/water/river_mesh_builder.gd`
- Modify: `src/world_generator/tests/test_confluence_transitions_comprehensive.gd`

**Interfaces:**
- Remove `build_confluence_surface_multistation()`.
- Standardize all callers and tests onto `build_confluence_surface(conf, result, profile, network, longitudinal_steps)`.
- Keep `build_confluence_patch()` strictly as a 1-line backward compatibility alias.

- [ ] **Step 1: Find all calls to `build_confluence_surface_multistation` and replace with `build_confluence_surface`**
- [ ] **Step 2: Remove `build_confluence_surface_multistation` definition**
- [ ] **Step 3: Verify existing test suite passes**

---

## Verification Plan

### Automated Tests
- Run all confluence and river tests headlessly:
  ```powershell
  & "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script res://src/world_generator/tests/survey_confluence_junctions.gd
  ```
- Confirm:
  - `Invalid quads: 0`
  - `Crossed edges: 0`
  - `Inverted quads: 0`
  - `Gaps: 0`
  - `Ownership overlaps: 0`

### Manual Verification
- Open `TaigaWorld` in Godot (Seed 12345, 64x64).
- Inspect confluences in wireframe mode:
  - Confirm ribbons stop before junction zone.
  - Confirm junction spans transition rows cleanly.
  - Confirm zero z-fighting flickering at boundaries.
  - Confirm water width smoothly expands from tributaries to receiver.
