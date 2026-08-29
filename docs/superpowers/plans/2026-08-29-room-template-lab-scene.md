# Room Template Lab & 2D Interactive Editor Implementation Plan (v2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create an interactive 2D Lab and Visual Editor Scene in Godot (`room_template_lab.tscn`) to view, design, paint, edit parameters, validate in real time, simulate carving, and save/export room templates directly into the project's canonical JSON catalogs.

**Architecture:**
1. **Model & State**: `RoomTemplateLabState` manages the active template, grid canvas layers (Floor cells, Boundary Rect, Entrances, Anchors, ZoneMap), brush tools, and undo/redo history via a Command pattern.
2. **Pure Geometry Layer (`GridTransform`)**: A `RefCounted` (non-node) class handling screen↔cell coordinate math, isolated from rendering/input, so it's cheaply unit-testable headless.
3. **Visual Canvas View (`RoomTemplateCanvasView`)**: 2D custom Control/Node2D drawing a modern dark dot-grid matching the design reference, with panning, zooming, viewport-culled rendering, brush drawing (floor/erase), rect-fill preview, mirror-paint guides, interactive entrance/anchor placement, and toggleable overlay layers.
4. **Floating Tool Palette (`RoomTemplateToolbar`)**: Floating bottom toolbar matching the design reference with modes: Brush (Piso), Eraser (Pared), Rectangle Fill, Place Entrance, Place Anchor, Inspect/Select, Clear, Center View, and Zoom.
5. **Parameter Inspector (`RoomTemplateInspector`)**: Comprehensive tabbed/accordion side panel providing editable controls for all schema contracts: Identity, Geometry Policy (with "Auto-fit to Canvas" button), Entrance Policy, Symmetry Policy (live mirror-paint toggle), Anchors Editor (canvas-click AND numeric field entry), Clearances, and Semantic Constraints.
6. **Real-time Validator & Stats HUD (`RoomTemplateStatsHud`)**: Displays live, debounced metrics (dimensions $W\times H$, area, walkability ratio $\ge 70\%$, symmetry check) and error/warning diagnostics powered by `RoomTemplateDefinitionValidator` and `RoomTemplateValidator`.
7. **Carving Simulator & Tester**: Runs `RoomTemplateShapeCarver` with configurable room rects and entrance positions to preview how the engine carves zones, clearances, and anchor placements in real time.
8. **File I/O**: Isolated load/save layer for `resources/dungeon_profiles/room_templates/`, independent of UI, plus New/Clone/Open/Save/Export flows.

**Tech Stack:** Godot 4.6.1 GDScript, UI Controls, Custom `_draw()` rendering, JSON serialization, Headless verification tests.

## Global Constraints

- **Single Test Suite Execution Only**: NEVER execute `tests/run_all_tests.gd`. Only execute individual test files via `cmd /c "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe" --headless -s res://tests/<path>.gd`.
- **Zero Golden Drift**: Maintain 20/20 PASS on `test_golden_fixtures.gd`.
- **Pure Separation of Concerns**: The Lab is a tool/editor layer; it reuses core data contracts (`RoomTemplate`, `RoomTemplateZoneMap`, `RoomTemplateDefinitionValidator`, `RoomTemplateShapeCarver`) without modifying core generation logic.
- **Prefer pure (non-Node) classes for anything testable headless without a scene tree.** Reserve Node/Control classes strictly for rendering and input glue.

---

### Task 0 (Decide before Task 3/7c): Standalone Scene vs. EditorPlugin Dock

- [x] **Step 1: Decide standalone vs. dock (standalone scene `room_template_lab.tscn` implemented with decoupled components ready for dock packaging)**
- [x] **Step 2: Document decision in this plan / project README**

---

### Task 1: Core Lab State & Canvas Data Model (`RoomTemplateLabState`)

- [x] **Step 1: Write unit test for LabState (tile painting, anchor placement, auto-geometry extraction, JSON serialization)**
- [x] **Step 2: Run test to verify failure**
- [x] **Step 3: Implement RoomTemplateLabState**
- [x] **Step 4: Run test to verify pass**
- [x] **Step 5: Commit**

---

### Task 1.5: Command Pattern & Undo/Redo History (NEW)

- [x] **Step 1: Design command interface (`do`/`undo`/optional `merge_with` for coalescing consecutive brush strokes into one undo step)**
- [x] **Step 2: Write unit tests: single command undo/redo, multi-command chains, rect-fill undo restoring all affected cells, undo-after-redo-then-new-action truncates redo stack, max stack depth eviction**
- [x] **Step 3: Implement `LabCommand` subclasses and `CommandHistory`**
- [x] **Step 4: Wire `RoomTemplateLabState` to route all mutations through commands**
- [x] **Step 5: Run tests to verify pass**
- [x] **Step 6: Commit**

---

### Task 2: Pure Grid Transform Layer (`GridTransform`) (NEW — extracted from old Task 2)

- [x] **Step 1: Write unit tests for screen↔cell conversion at various zoom/pan combinations, including edge rounding cases**
- [x] **Step 2: Write unit test for `visible_cell_range` culling bounds**
- [x] **Step 3: Implement `GridTransform`**
- [x] **Step 4: Run tests to verify pass**
- [x] **Step 5: Commit**

---

### Task 3: Interactive 2D Dot-Grid Canvas (`RoomTemplateCanvasView`)

- [x] **Step 1: Write test verifying `RoomTemplateCanvasView` delegates coordinate math to `GridTransform` (no duplicated math in the node)**
- [x] **Step 2: Implement dot-grid rendering with viewport culling (only draw dots within `visible_cell_range`)**
- [x] **Step 3: Implement brush/eraser painting, wiring strokes through `Task 1.5` commands (coalesce a drag into one command via `merge_with`)**
- [x] **Step 4: Implement rectangle-fill tool with live ghost-rectangle preview while dragging**
- [x] **Step 5: Implement entrance/anchor placement interactions**
- [x] **Step 6: Implement symmetry-axis guide rendering (visual only; actual mirroring logic lives in Task 5)**
- [x] **Step 7: Verify rendering and interaction logic**
- [x] **Step 8: Commit**

---

### Task 4: Floating Bottom Toolbar & Tool Switcher (`RoomTemplateToolbar`)

- [x] **Step 1: Create floating toolbar component and button bindings**
- [x] **Step 2: Connect toolbar actions to `RoomTemplateLabState`**
- [x] **Step 3: Wire Undo/Redo buttons + shortcuts to `CommandHistory`, subscribing to `history_changed` for enabled/disabled state**
- [x] **Step 4: Commit**

---

### Task 5: Comprehensive Inspector Panel (`RoomTemplateInspector`)

- [x] **Step 1: Implement form fields for all schema contracts**
- [x] **Step 2: Implement dynamic Anchors list editor — supports BOTH click-to-place-on-canvas AND direct numeric X/Y field entry, kept in sync bidirectionally**
- [x] **Step 3: Implement "Auto-calculate Bounds & Area" from painted floor tiles**
- [x] **Step 4: Implement Symmetry Policy toggle that activates live "mirror paint" mode on the canvas — when enabled, every brush/eraser stroke is mirrored across the configured axis in real time (emitted as a single coalesced command pair, not doubled undo steps)**
- [x] **Step 5: Commit**

---

### Task 6: Live Stats HUD & Shape Carver Simulation Mode

- [x] **Step 1: Implement debounce timer (~120-150ms) on `canvas_modified` before triggering validation/stats recompute, to avoid running full validation on every single painted cell during a drag stroke**
- [x] **Step 2: Implement live stats HUD with validation badge**
- [x] **Step 3: Implement Carving Simulation mode with slider for room dimensions**
- [x] **Step 4: Commit**

---

### Task 7a: File I/O Layer (isolated, UI-independent) (SPLIT from old Task 6)

- [x] **Step 1: Write unit tests for load/save/export round-trip, name-collision detection, clone-from-existing, and malformed-JSON handling**
- [x] **Step 2: Implement `RoomTemplateRepository`, decoupled from any UI node**
- [x] **Step 3: Run tests to verify pass**
- [x] **Step 4: Commit**

---

### Task 7b: New/Open/Clone Template Flow (NEW — previously undefined)

- [x] **Step 1: Design and implement "New Template" flow: prompt for id + starting size, initialize blank `RoomTemplateLabState`**
- [x] **Step 2: Implement "Clone" flow: duplicate an existing template's full data as the starting point for a new id**
- [x] **Step 3: Implement "Open" browser wired to `RoomTemplateRepository.list_templates()`**
- [x] **Step 4: Commit**

---

### Task 7c: Master Scene Assembly (`room_template_lab.tscn`) (SPLIT from old Task 6)

- [x] **Step 1: Assemble `room_template_lab.tscn`, connecting canvas, toolbar, inspector, HUD, and file dialogs**
- [x] **Step 2: Wire signal chain: canvas paint → LabState → command history → stats HUD (debounced) → inspector sync**
- [x] **Step 3: Commit**

---

### Task 7d: End-to-End Integration Test & Golden Fixtures (SPLIT from old Task 6)

**Why:** This affects how the root window/viewport is structured, so it should be decided early rather than retrofitted after Task 7c.

**Options:**
- **Standalone scene** (as originally planned): run via F6, simplest to build first, fully isolated from editor internals.
- **EditorPlugin with dock**: lives inside the Godot editor as a dock panel; enables iterating on templates without leaving the editor, drag-and-drop of `.tres`/`.json` resources from the FileSystem dock, and reuse of native inspector widgets — better long-term ergonomics if this tool will be used frequently during level design.

- [ ] **Step 1: Decide standalone vs. dock (recommendation: build as standalone first per this plan for fast iteration/testing; consider wrapping in an `EditorPlugin` dock as a later enhancement once the standalone version is stable, since the dock is mostly a thin host around the same nodes)**
- [ ] **Step 2: Document decision in this plan / project README**

---

## Summary of Changes from v1

| Change | Reason |
|---|---|
| Added Task 1.5 (Command pattern + Undo/Redo, tested) | Previously mentioned but never designed or tested — highest bug-risk area |
| Added Task 2 (`GridTransform` pure class) | Coordinate math now headless-testable, no scene tree needed |
| Task 2→3 (Canvas): added culling, rect-fill preview, symmetry guide | Performance + previously-missing outputs |
| Task 4 (Toolbar): added Undo/Redo wiring | Closes the loop with Task 1.5 |
| Task 5 (Inspector): added live mirror-paint + bidirectional anchor editing | Symmetry policy was previously dead metadata; anchor UX gap |
| Task 6 (Stats HUD): added debounce step | Avoids validation running on every painted cell during drag |
| Old Task 6 split into 7a/7b/7c/7d | Original task was oversized and highest-risk; now isolated, independently testable pieces |
| Added Task 7b (New/Clone/Open flow) | Previously undefined despite being referenced |
| Added Task 0 (standalone vs. EditorPlugin dock decision) | Architectural decision that affects root window setup; better decided early |