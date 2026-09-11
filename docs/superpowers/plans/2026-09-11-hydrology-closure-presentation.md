# Hydrology Closure & Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close all hydrological debts and unify water presentation (RiverNetwork contract, causal confluences, Strahler order, formal structural validation, monotonic geometry, RiverRenderer, waterways, unified lake-river rendering, and 30-seed closure).

**Architecture:** Model decoupling with explicit `River` and `RiverNetwork` contracts, causal confluence topology, Strahler stream order DAG traversal, pure structural observer `HydrologyValidation`, dedicated `RiverRenderer` and `Waterway` abstraction, and multi-seed survey.

**Tech Stack:** Godot 4.6.1 GDScript (headless execution).

**Spec:** User request: BLOQUE DE CIERRE — DEUDAS HIDROLÓGICAS + PRESENTACIÓN.

## Global Constraints
- Truth vs Representation separation: Truth (`RiverNetwork`, `flow_to`, `accumulation`, `basin`, `River.path`, `River.order`) is immutable once `HydrologyStage` finishes.
- The renderer (`RiverRenderer`) only consumes the truth and NEVER modifies `WorldCell.height` nor recalculates hydrology/cuencas.
- No uphill segments in 3D river points (`pts[i+1].y <= pts[i].y + 0.0001`).
- Headless test command: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script <script_path>`

---

### Task 1: Explicit River & RiverNetwork Contracts

**Files:**
- Create: `src/world_generator/hydrology/river.gd`
- Create: `src/world_generator/hydrology/river_network.gd`
- Modify: `src/world_generator/hydrology/hydrology_result.gd:40-60`

**Interfaces:**
- Consumes: None (base models)
- Produces: `class_name River`, `class_name RiverNetwork`, `HydrologyResult.river_network` typed reference

- [ ] **Step 1: Implement `River` data class**
  - Attributes: `id`, `source`, `path`, `length`, `upstream_rivers`, `downstream_river`, `order`, `accumulation_start`, `accumulation_end`, `outlet`, `is_outflow`.
- [ ] **Step 2: Implement `RiverNetwork` container class**
  - Attributes: `rivers`, `sources`, `confluences`, `lakes`, `outlets`.
  - Helpers: `get_river(id: int) -> River`, `get_headwaters() -> Array[River]`, `get_root_rivers() -> Array[River]`.
- [ ] **Step 3: Update `HydrologyResult`**
  - Add `var river_network: RiverNetwork = null`.
  - Maintain compatibility for `hydro.rivers` and `hydro.confluences`.

---

### Task 2: Causal Confluences & Strahler Stream Order

**Files:**
- Modify: `src/world_generator/stages/hydrology_stage.gd:975-1070`

**Interfaces:**
- Consumes: `headwaters`, `flow_to`, `accumulation`, `hydro`
- Produces: Causal graph links (`downstream_river`, `upstream_rivers`) and true Strahler `River.order`

- [ ] **Step 1: Update confluence tracking in `_trace_river_network`**
  - When River A meets River B at node P: set `A.downstream_river = B.id`, `A.outlet = P`, add `A.id` to `B.upstream_rivers`.
- [ ] **Step 2: Implement topological Strahler order calculation**
  - Source rivers (`upstream_rivers.is_empty()`): order = 1.
  - Recurse/traverse DAG: if max upstream order $M$ occurs $\ge 2$ times: order = $M + 1$, else order = $M$.
- [ ] **Step 3: Populate `RiverNetwork` instance with strongly-typed `River` objects in `generate`**

---

### Task 3: Formal Structural Validator (`HydrologyValidation`)

**Files:**
- Create: `src/world_generator/validation/hydrology_validation.gd`

**Interfaces:**
- Consumes: `WorldResult`, `WorldProfile`
- Produces: Pure diagnostic report `{ "is_valid": bool, "errors": Array[String], "warnings": Array[String], "metrics": Dictionary }`

- [ ] **Step 1: Implement topological validations**
  - Unique River ID, source is path[0], path size >= 2, no cycles, bounds check, path follows `flow_to`, valid terminal endpoints (boundary, lake, or confluence), valid confluence links, lake spillways.
- [ ] **Step 2: Implement hydrological validations**
  - Monotonic accumulation downstream, source not downstream of self, width > 0, depth > 0, 3D points strictly non-ascending.
- [ ] **Step 3: Implement lake-river interaction validations**
  - Lake -> spillway -> river and river -> lake.

---

### Task 4: Monotonic 3D Geometry, Conconfined Meanders & Hydrological Width/Depth

**Files:**
- Modify: `src/world_generator/stages/hydrology_stage.gd:1100-1250`

**Interfaces:**
- Consumes: `RiverNetwork`, `accumulation`, `profile`
- Produces: `widths`, `points` (strictly non-ascending 3D coordinates), `depths`

- [ ] **Step 1: Enforce monotonic 3D descent in `_build_river_geometry`**
  - Ensure `pts[i+1].y <= pts[i].y + 0.0001`.
- [ ] **Step 2: Confine lateral meanders to valley width**
  - Taper meander offset to 0 at sources, confluences, and lake outlets/inlets.
- [ ] **Step 3: Calibrate width and depth as functions of accumulation, Strahler order, and slope**
  - Width scales organically from headwater to confluence to mouth.

---

### Task 5: Waterway Abstraction & Dedicated RiverRenderer

**Files:**
- Create: `src/world_renderer/waterway.gd`
- Create: `src/world_renderer/river_renderer.gd`
- Modify: `src/world_renderer/hydrology_renderer.gd`
- Modify: `src/world_renderer/world_renderer.gd`

**Interfaces:**
- Consumes: `HydrologyResult`, `RiverNetwork`, `WorldProfile`
- Produces: Continuous water mesh and draped physical banks without touching `WorldCell.height`

- [ ] **Step 1: Define `Waterway` contract (RIVER, LAKE)**
- [ ] **Step 2: Implement `RiverRenderer` for river meshes and physical bank geometry**
  - Bank vertices follow `river_bank_width` and `river_bank_falloff`.
- [ ] **Step 3: Unify water material and shading across rivers and lakes**
  - Shared depth, transparency, roughness, and color transitions.
- [ ] **Step 4: Ensure seamless visual continuity at river-lake junctions**

---

### Task 6: Visual Debug Overlays in Lab (TaigaWorld)

**Files:**
- Modify: `src/world_renderer/scenes/taiga_world.gd`

**Interfaces:**
- Consumes: `current_result.hydrology`, `river_network`
- Produces: Debug views for River Network IDs, Strahler Order ($R_1, R_2, R_3$), and Accumulation Heatmap

- [ ] **Step 1: Add debug visual modes to `HydroDebugMode` enum in `taiga_world.gd`**
  - `RIVER_NETWORK_IDS`, `STRAHLER_ORDER`, `ACCUMULATION_HEATMAP`.
- [ ] **Step 2: Implement overlay texture generators for the new modes in `_update_hydrology_debug_view`**
- [ ] **Step 3: Add legend annotations showing river IDs and Strahler hierarchies**

---

### Task 7: 30-Seed Survey & Automated Hydrology Contract Closure

**Files:**
- Create: `src/world_generator/tests/test_hydrology_closure_survey.gd`
- Modify: `src/world_generator/tests/test_hydrology_stage.gd`

**Interfaces:**
- Consumes: `WorldPipeline.generate`, `HydrologyValidation`
- Produces: Multi-seed verification report and integrated CI contract check

- [ ] **Step 1: Create standalone 30-seed closure script `test_hydrology_closure_survey.gd`**
- [ ] **Step 2: Integrate `HydrologyValidation.validate(result, profile)` into `test_hydrology_stage.gd`**
- [ ] **Step 3: Run survey and confirm 30/30 valid seeds with 0 structural or geometric errors**
