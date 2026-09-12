# Confluence Longitudinal Transition & Multi-Station Junction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement continuous, multi-station longitudinal transition surfaces for river confluences ($N \to 1$), separating lateral branch resolution from longitudinal station resolution, eliminating geometry overlap with main ribbons, and ensuring seamless width and water elevation interpolation without gaps or radial center-fans.

**Architecture:** A dedicated multi-station junction generator in `river_mesh_builder.gd` that: (1) establishes non-overlapping boundary interfaces between tributary ribbons and the confluence, (2) builds $M \ge 3$ intermediate longitudinal transition cross-sections along the convergence path, (3) dynamically bridges $N$ incoming branches into the $M$ longitudinal strips with wedge sealing across inner crooks, (4) interpolates widths and water heights continuously towards the downstream receiver, (5) validates against degenerate triangles, winding inversion, and edge crossings, and (6) emits ephemeral telemetry per junction.

**Tech Stack:** Godot 4.6.1 GDScript, `RiverNetwork`, `River`, `WaterSurfaceData`, `RiverMeshBuilder`, `WaterRenderer`.

**Spec:** User technical specification: "Añadir estaciones de transición longitudinales entre cada upstream y la zona de junction — Items 1 al 15".

## Global Constraints
- **Hydrology Immutability:** Never modify `HydrologyStage`, `River`, `RiverNetwork`, `accumulation`, or terrain carving.
- **Independence of Resolutions:** The number of upstream branches $N$ must NOT dictate the longitudinal station count $M$. Longitudinal transition resolution is independent ($M \ge 3$).
- **Zero Overlap & Zero Gaps:** Ribbons and confluence surfaces must share exact boundary cross-sections or cleanly demarcate handoff boundaries without z-fighting overlap or holes.
- **Arbitrary Branch Count ($N \to 1$):** Seamlessly support $2 \to 1$, $3 \to 1$, $4 \to 1$, and beyond.
- **Vertical and Lateral Smoothness:** No vertical height steps; width smoothly interpolates: $w(t) = \text{lerp}(w_{\text{upstream}}, w_D, t)$.

---

### Task 1: Non-Overlapping Boundary Demarcation & Station Extraction

**Files:**
- Modify: `src/world_generator/presentation/water/river_mesh_builder.gd:550-680`
- Test: `src/world_generator/tests/test_confluence_boundary_handoff.gd`

**Interfaces:**
- Consumes: `conf: Dictionary`, `network: RiverNetwork`, `result: WorldResult`, `profile: WorldProfile`.
- Produces: `Dictionary` with exact boundary stations:
  - `upstream_entries`: Array of stations at tributary termination.
  - `downstream_exit`: Station at receiver channel start.
  - `transition_length`: Longitudinal span $L_J$ computed from tributary widths and convergence angles.

- [ ] **Step 1: Write test verifying non-overlapping station handoff**

```gdscript
# src/world_generator/tests/test_confluence_boundary_handoff.gd
extends SceneTree

const _RiverMeshBuilder = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _River = preload("res://src/world_generator/hydrology/river.gd")
const _RiverNetwork = preload("res://src/world_generator/hydrology/river_network.gd")

func _init() -> void:
	print("--- Test Confluence Boundary Handoff ---")
	var net = _RiverNetwork.new()
	var r1 = _River.new(0, Vector2i(0, 0), [])
	r1.points = [Vector3(0, 0, 0), Vector3(5, 0, 3)]
	r1.widths = [1.2, 1.4]
	r1.depths = [0.2, 0.2]
	r1.downstream_river = 2

	var r2 = _River.new(1, Vector2i(0, 6), [])
	r2.points = [Vector3(0, 0, 6), Vector3(5, 0, 3)]
	r2.widths = [1.2, 1.4]
	r2.depths = [0.2, 0.2]
	r2.downstream_river = 2

	var r_down = _River.new(2, Vector2i(5, 3), [])
	r_down.points = [Vector3(5, 0, 3), Vector3(10, 0, 3)]
	r_down.widths = [2.0, 2.2]
	r_down.depths = [0.3, 0.3]
	r_down.upstream_rivers = [0, 1]

	net.add_river(r1)
	net.add_river(r2)
	net.add_river(r_down)

	var conf := {"position": Vector2i(5, 3), "upstream_rivers": [0, 1], "downstream_river": 2}
	var dummy_profile = WorldProfile.new()
	var boundaries = _RiverMeshBuilder._extract_confluence_boundaries(conf, net, null, dummy_profile)

	assert(boundaries != null, "Boundaries must exist")
	assert(boundaries["upstreams"].size() == 2, "Must have 2 upstream boundaries")
	assert(boundaries["downstream"] != null, "Must have 1 downstream boundary")
	assert(boundaries["transition_length"] > 0.5, "Transition length must be non-zero")

	print("Test Confluence Boundary Handoff: PASSED")
	quit(0)
```

- [ ] **Step 2: Implement `_extract_confluence_boundaries` in `river_mesh_builder.gd`**
  - Calculate confluence entry stations for each upstream river at its final station.
  - Calculate confluence exit station for downstream river at its initial station.
  - Compute transition length based on incoming river widths: $L_J = \max(w_{u1}, w_{u2}, w_D) \times 1.25$.

---

### Task 2: Multi-Station Longitudinal Transition Construction ($M \ge 3$)

**Files:**
- Modify: `src/world_generator/presentation/water/river_mesh_builder.gd`
- Test: `src/world_generator/tests/test_confluence_multi_station.gd`

**Interfaces:**
- Consumes: Boundary stations, `longitudinal_steps: int = 3`.
- Produces: Array of $M$ transverse cross-sections along the junction, where each station has $N$ branch subsections.

- [ ] **Step 1: Write test verifying longitudinal station count $M$ is independent of branch count $N$**

```gdscript
# src/world_generator/tests/test_confluence_multi_station.gd
extends SceneTree

const _RiverMeshBuilder = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _River = preload("res://src/world_generator/hydrology/river.gd")
const _RiverNetwork = preload("res://src/world_generator/hydrology/river_network.gd")

func _init() -> void:
	print("--- Test Confluence Multi-Station Independence ---")
	var net = _RiverNetwork.new()
	# 2 branches
	var r1 = _River.new(0, Vector2i(0, 0), [])
	r1.points = [Vector3(0, 0, 0), Vector3(6, 0, 3)]
	r1.widths = [1.2, 1.2]
	r1.depths = [0.2, 0.2]
	r1.downstream_river = 2

	var r2 = _River.new(1, Vector2i(0, 6), [])
	r2.points = [Vector3(0, 0, 6), Vector3(6, 0, 3)]
	r2.widths = [1.2, 1.2]
	r2.depths = [0.2, 0.2]
	r2.downstream_river = 2

	var r_down = _River.new(2, Vector2i(6, 3), [])
	r_down.points = [Vector3(6, 0, 3), Vector3(12, 0, 3)]
	r_down.widths = [2.0, 2.0]
	r_down.depths = [0.3, 0.3]
	r_down.upstream_rivers = [0, 1]

	net.add_river(r1)
	net.add_river(r2)
	net.add_river(r_down)

	var conf := {"position": Vector2i(6, 3), "upstream_rivers": [0, 1], "downstream_river": 2}
	var dummy_profile = WorldProfile.new()
	var surf = _RiverMeshBuilder.build_confluence_surface_multistation(conf, null, dummy_profile, net, 3)

	assert(surf != null, "Surface must be generated")
	# With M=3 longitudinal segments (4 stations) and N=2 branches, minimum vertex count > 10
	assert(surf.vertices.size() >= 12, "Must contain multi-station vertices across longitudinal depth")
	assert(surf.indices.size() >= 18, "Must contain multi-segment triangles")

	print("Test Confluence Multi-Station Independence: PASSED")
	quit(0)
```

- [ ] **Step 2: Implement multi-station interpolation in `river_mesh_builder.gd`**
  - Define $M$ longitudinal progress steps $t \in [0.0, 1.0]$: $t_m = m / M$.
  - At $t = 0.0$: stations match tributary mouths ($L_k, R_k$).
  - At $t = 1.0$: stations match downstream receiver intervals ($D_k, D_{k+1}$).
  - For $0 < t < 1.0$: generate intermediate guide stations by spherical linear interpolation of directions, linear interpolation of positions, and smooth cubic interpolation of widths.

---

### Task 3: Strip-Bridge Triangulation Across Longitudinal Stations ($N \times M$)

**Files:**
- Modify: `src/world_generator/presentation/water/river_mesh_builder.gd`

**Interfaces:**
- Connects station rows $m$ and $m+1$ for each branch $k \in [0, N-1]$ via clean quads:
  - Quad $k, m$: $(L_{k, m}, R_{k, m}, L_{k, m+1}, R_{k, m+1})$.
  - Two triangles per quad segment: $(L_{k, m}, R_{k, m}, L_{k, m+1})$ and $(R_{k, m}, R_{k, m+1}, L_{k, m+1})$.
- Bridges the inner crook between adjacent branches $k$ and $k+1$ across longitudinal levels $m \to m+1$:
  - Smooth triangle/quad wedge filling the fork $(R_{k, m}, L_{k+1, m}, \text{apex}_{m+1})$.

- [ ] **Step 1: Implement the $(N \times M)$ quad-strip assembly loop**
- [ ] **Step 2: Connect inner crook wedge strips across longitudinal levels**
- [ ] **Step 3: Validate all triangles with `_triangle_is_valid()`**

---

### Task 4: Smooth Width & Water Elevation Interpolation (C6 & C7)

**Files:**
- Modify: `src/world_generator/presentation/water/river_mesh_builder.gd`

**Interfaces:**
- Width formula per branch $k$ at longitudinal progress $t$:
  $$w_k(t) = \text{lerpf}(w_{uk}, w_D / N, t)$$
- Total junction width $W(t) = \sum_k w_k(t) + \text{crook\_gap}(t)$, ensuring $W(t) \ge \max(\sum w_{uk}, w_D)$ without constriction.
- Water height formula:
  $$y_k(t) = \text{lerpf}(y_{uk}, y_D, t)$$
  clamped to:
  $$y_k(t) = \text{clampf}(y_k(t), \text{bed} + 0.015, \text{bank} + 0.02)$$

- [ ] **Step 1: Integrate smooth width and elevation blending into vertex placement**
- [ ] **Step 2: Assign continuous flow directions: $\vec{F}(t) = \text{slerp}(\vec{dir}_{uk}, \vec{dir}_D, t)$ into `UV2`**

---

### Task 5: Junction Geometric Validation & Ephemeral Telemetry (C10)

**Files:**
- Modify: `src/world_generator/presentation/water/river_mesh_builder.gd`

**Interfaces:**
- Validations:
  - Finiteness of all vertices (`is_finite`).
  - Minimum triangle area ($> 0.000001$).
  - Non-inversion of quad diagonals.
  - Absence of edge self-intersection.
- Telemetry:
  - Prints `[ConfluenceDiagnostics]` per junction:
    `junctions=1 branches=N longitudinal_steps=M verts=V tris=T skipped=S valid=V_T`

- [ ] **Step 1: Implement `_confluence_triangle_valid` and junction telemetry logging**

---

### Task 6: Comprehensive Test Suite ($2 \to 1$, $3 \to 1$, $4 \to 1$) & Multi-Seed Verification

**Files:**
- Create: `src/world_generator/tests/test_confluence_transitions_comprehensive.gd`
- Output: `docs/confluence_transition_report.txt`

- [ ] **Step 1: Write comprehensive test script verifying:**
  - Case 1: $2 \to 1$ gentle angle (< 45°) with $M=3$ stations.
  - Case 2: $2 \to 1$ sharp angle (> 75°) with $M=3$ stations.
  - Case 3: $3 \to 1$ multi-tributary with $M=3$ stations.
  - Case 4: $4 \to 1$ quad-tributary with $M=3$ stations.
  - Case 5: Confluence + immediate downstream bend.
  - Case 6: Procedural world generation across seeds `12345`, `42`, `101`, `202`.
- [ ] **Step 2: Run test headlessly and verify 100% pass rate**
- [ ] **Step 3: Document findings in `docs/confluence_transition_report.txt` and `walkthrough.md`**

---

## Verification Plan

### Automated Tests
- Run test script:
  ```powershell
  & "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script res://src/world_generator/tests/test_confluence_transitions_comprehensive.gd
  ```
- Confirm: 0 skipped triangles, 0 degenerate quads, 0 gaps, smooth width transition.

### Manual Verification
- Open `TaigaWorld` in Godot:
  - Navigate to river confluence points in wireframe mode.
  - Verify that junctions exhibit $M \ge 3$ longitudinal quads rather than a single direct stretch.
  - Observe smooth surface water waves following the slerped flow directions into the receiver river.
