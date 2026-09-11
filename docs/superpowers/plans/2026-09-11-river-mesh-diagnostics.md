# River Mesh In-Flight Diagnostics & Ribbon Telemetry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Instrument `RiverMeshBuilder.build_river_surface()` with lightweight, zero-overhead diagnostic telemetry to measure quad failure rates, fallback usage, turn angle correlation, and skipped triangle occurrences across 5-10 seeds, without altering existing geometry or hydrology truth.

**Architecture:** Inject an ephemeral `diagnostics` accumulator into `build_river_surface()` in `river_mesh_builder.gd`, recording section counts, width/segment metrics, turn angles (>30°, >60°, >90°), fallback paths (prev normal, next normal, width pinch 85/70/55/40, safe), and valid vs skipped triangles. Print a single compact `[RiverMeshDiagnostics]` line per river, run a fast survey script across representative seeds (including 12345), and evaluate against the decision gate before touching confluences.

**Tech Stack:** Godot 4.6.1 GDScript, `RiverMeshBuilder`, `WorldPipeline`, `TaigaWorldProfile`.

**Spec:** User technical request: "BLOQUE DE INSTRUMENTACIÓN — Items 1 al 9".

## Global Constraints
- **Zero Geometry Changes:** The telemetry is strictly non-invasive measurement; it must not modify vertex positions, UVs, normals, or triangle generation logic.
- **Zero Hydrology Changes:** Do not touch `HydrologyStage`, `River`, `RiverNetwork`, `accumulation`, or terrain carving.
- **No Heavy Test Suites:** Avoid massive test suites, snapshots, fixtures, or new UI scenes. Only a fast headless survey script to gather quantitative data.
- **Single Log Line Per River:** Emit exactly one formatted `[RiverMeshDiagnostics]` log line per river surface generated.

---

### Task 1: Add Ephemeral Diagnostics Accumulator to `RiverMeshBuilder`

**Files:**
- Modify: `src/world_generator/presentation/water/river_mesh_builder.gd:65-350`

**Interfaces:**
- Produces: formatted `[RiverMeshDiagnostics]` output per river during mesh generation.
- Internal metrics recorded:
  ```gdscript
  {
      "sections": int,
      "quads": int,
      "fallback_normal_previous": int,
      "fallback_normal_next": int,
      "fallback_width_85": int,
      "fallback_width_70": int,
      "fallback_width_55": int,
      "fallback_width_40": int,
      "fallback_safe": int,
      "invalid_quads_before_fallback": int,
      "invalid_quads_after_fallback": int,
      "skipped_triangles": int,
      "valid_triangles": int,
      "min_width": float,
      "max_width": float,
      "min_segment_length": float,
      "max_segment_length": float,
      "turns_gt_30": int,
      "turns_gt_60": int,
      "turns_gt_90": int
  }
  ```

- [ ] **Step 1: Initialize `diagnostics` dictionary at the top of `build_river_surface()`**
- [ ] **Step 2: Track effective widths, segment lengths, and turn angles**
  - Compute turn angle:
    ```gdscript
    if i > 0 and i < pts.size() - 1:
        var a := (pts[i] - pts[i - 1]).normalized()
        var b := (pts[i + 1] - pts[i]).normalized()
        a.y = 0.0
        b.y = 0.0
        if a.length_squared() > 0.0001 and b.length_squared() > 0.0001:
            var turn_angle := rad_to_deg(acos(clampf(a.dot(b), -1.0, 1.0)))
            if turn_angle > 90.0: diagnostics["turns_gt_90"] += 1
            elif turn_angle > 60.0: diagnostics["turns_gt_60"] += 1
            elif turn_angle > 30.0: diagnostics["turns_gt_30"] += 1
    ```
  - Accumulate min/max width and min/max segment spacing.
- [ ] **Step 3: Instrument quad validation failure and fallback triggers**
  - If initial quad invalid: `diagnostics["invalid_quads_before_fallback"] += 1`.
  - Fallback A match: `diagnostics["fallback_normal_previous"] += 1`.
  - Fallback B match: `diagnostics["fallback_normal_next"] += 1`.
  - Fallback C match: increment `fallback_width_85`, `fallback_width_70`, `fallback_width_55`, or `fallback_width_40`.
  - Unresolved fallback: `diagnostics["fallback_safe"] += 1` and `diagnostics["invalid_quads_after_fallback"] += 1`.
- [ ] **Step 4: Instrument triangle validity and skipped triangle counter**
  - Track `triangle_a_valid` and `triangle_b_valid`.
  - Increment `valid_triangles` on success, `skipped_triangles` on rejection.
- [ ] **Step 5: Compute `fallback_ratio` and print unified single-line log**
  ```gdscript
  print(
      "[RiverMeshDiagnostics] ",
      "sections=", diagnostics["sections"],
      " quads=", diagnostics["quads"],
      " invalid_before=", diagnostics["invalid_quads_before_fallback"],
      " invalid_after=", diagnostics["invalid_quads_after_fallback"],
      " prev_normal=", diagnostics["fallback_normal_previous"],
      " next_normal=", diagnostics["fallback_normal_next"],
      " width85=", diagnostics["fallback_width_85"],
      " width70=", diagnostics["fallback_width_70"],
      " width55=", diagnostics["fallback_width_55"],
      " width40=", diagnostics["fallback_width_40"],
      " safe=", diagnostics["fallback_safe"],
      " skipped_triangles=", diagnostics["skipped_triangles"],
      " valid_triangles=", diagnostics["valid_triangles"],
      " fallback_ratio=", "%.4f" % fallback_ratio,
      " turns>30=", diagnostics["turns_gt_30"],
      " turns>60=", diagnostics["turns_gt_60"],
      " turns>90=", diagnostics["turns_gt_90"],
      " min_width=", "%.2f" % diagnostics["min_width"],
      " max_width=", "%.2f" % diagnostics["max_width"],
      " min_segment=", "%.2f" % diagnostics["min_segment_length"],
      " max_segment=", "%.2f" % diagnostics["max_segment_length"]
  )
  ```

---

### Task 2: Fast Headless Diagnostic Survey Script

**Files:**
- Create: `src/world_generator/tests/survey_river_mesh_diagnostics.gd`
- Output: `docs/river_mesh_diagnostics_report.txt`

**Interfaces:**
- Runs generation for seeds: `[12345, 42, 101, 202, 303, 404, 505, 777, 888, 999]`.
- Map dimensions: $64 \times 64$, Taiga profile.
- Emits formatted telemetry lines and writes aggregate statistical summary to `docs/river_mesh_diagnostics_report.txt`.

- [ ] **Step 1: Write `survey_river_mesh_diagnostics.gd`**
- [ ] **Step 2: Execute survey headlessly**
  ```powershell
  & "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script res://src/world_generator/tests/survey_river_mesh_diagnostics.gd
  ```
- [ ] **Step 3: Collect report and verify execution completed in under 5 seconds**

---

### Task 3: Decision Gate Evaluation

**Files:**
- Review: `docs/river_mesh_diagnostics_report.txt`
- Update: `walkthrough.md`

- [ ] **Step 1: Compare metrics against the specification criteria:**
  - 🟢 **Green Path:** `fallback_ratio <= 0.05`, `skipped_triangles == 0`, `safe == 0`.
    - Conclusion: Main river ribbon is fully stable. Ready to advance directly to continuous confluence patch redesign.
  - 🟡 **Yellow Path:** `0.05 < fallback_ratio <= 0.25` or high width85/70 usage.
    - Conclusion: Aggressive curves present. Fine-tune pre-confluence transition before confluences.
  - 🔴 **Red Path:** `fallback_ratio > 0.25`, `safe > 0`, or `skipped_triangles > 0`.
    - Conclusion: Ribbon algorithm is struggling with centerline or water height clamping; fix lateral generation before touching confluences.

---

## Verification Plan

### Automated Verification
- Run headless survey script:
  ```powershell
  & "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script res://src/world_generator/tests/survey_river_mesh_diagnostics.gd
  ```
- Verify that `docs/river_mesh_diagnostics_report.txt` is populated with actual seed data.

### Manual Verification
- Launch `TaigaWorld` in Godot:
  - Check the Godot output console when generating Seed `12345` with map size $64 \times 64$.
  - Confirm single-line `[RiverMeshDiagnostics]` output per generated river.
