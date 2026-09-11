# Flow Discretization, Watersheds & Outlets Validation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement non-invasive diagnostics (Block A), run a 100-seed volumetric survey to gather quantitative metrics (Block B), execute conditional fixes if and only if justified by data (Block C), and formally close watershed and outlet topological integrity (Blocks D and E).

**Architecture:** Diagnostic measurement classes (`FlowDiscretizationMetrics`, `WatershedIntegrityChecker`, `OutletValidator`) decoupled behind a debug flag in `WorldProfile`, non-invasive candidate scoring hook in `HydrologyStage`, standalone survey script outputting to `docs/hydrology_flow_survey_report.txt`, and automated contract integration in `test_hydrology_stage.gd`.

**Tech Stack:** Godot 4.6.1 GDScript (headless CLI execution).

**Spec:** User request: Plan de Validación y Cierre — Flow Discretization / Watersheds / Outlets.

## Global Constraints
- Do not modify decision logic of `flow_to` during Block A.
- Bit-to-bit identical output when `profile.hydrology_debug_metrics_enabled = false`.
- Do not execute C1-C5 fixes unless survey data from Block B exceeds pre-established thresholds (C4 mandatory if `unreachable_cells > 0`).
- Headless command: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script <script_path>`

---

### Task 1: Add Debug Flag to WorldProfile

**Files:**
- Modify: `src/world_generator/config/world_profile.gd:124-130`

- [x] **Step 1: Add `hydrology_debug_metrics_enabled` property**
- [x] **Step 2: Verify file syntax by running existing test suite**

---

### Task 2: Block A — FlowDiscretizationMetrics & HydrologyStage Instrumentation

**Files:**
- Create: `src/world_generator/diagnostics/flow_discretization_metrics.gd`
- Modify: `src/world_generator/stages/hydrology_stage.gd:610-705`

- [x] **Step 1: Implement `FlowDiscretizationMetrics`**
- [x] **Step 2: Add non-invasive candidate scoring hook `debug_scores_out` in `_discretize_flow_field`**
- [x] **Step 3: Connect metrics computation behind `profile.hydrology_debug_metrics_enabled` in `generate`**
- [x] **Step 4: Verify bit-by-bit determinism across 5 seeds with flag disabled**

---

### Task 3: Block B — 100-Seed Volumetric Survey & Report

**Files:**
- Create: `src/world_generator/tests/test_flow_discretization_survey.gd`
- Output: `docs/hydrology_flow_survey_report.txt`

- [x] **Step 1: Create survey script iterating over 100 seeds (`1000 + i * 37`)**
- [x] **Step 2: Run survey script and generate `docs/hydrology_flow_survey_report.txt`**
- [x] **Step 3: Analyze report against decision threshold table**

---

### Task 4: Block C — Decision Gate & Conditional Fixes (C1–C5)

**Files:**
- Modify (conditionally): `src/world_generator/stages/hydrology_stage.gd`

- [x] **Step 1: Evaluate survey numbers against activation thresholds**
- [x] **Step 2: Apply only the activated fixes (C1-C5)**
- [x] **Step 3: Re-run survey to confirm improvement without regressions**

---

### Task 5: Block D & E — Watershed Integrity & Outlet Topology Verification

**Files:**
- Create: `src/world_generator/diagnostics/watershed_integrity_checker.gd`
- Create: `src/world_generator/diagnostics/outlet_validator.gd`
- Modify: `src/world_generator/tests/test_hydrology_stage.gd`

- [x] **Step 1: Implement `WatershedIntegrityChecker` (bijection, cycle absence, outlet validity)**
- [x] **Step 2: Implement `OutletValidator` (boundary, spillway, invalid)**
- [x] **Step 3: Integrate into survey and `test_hydrology_stage.gd` contracts**
- [x] **Step 4: Confirm 0 blocking violations across 100 seeds**
