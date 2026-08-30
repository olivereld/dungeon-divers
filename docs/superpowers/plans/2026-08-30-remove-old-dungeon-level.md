# Remove Old Dungeon Level Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Completely remove the legacy dungeon level scene (`scenes/dungeon/dungeon_level.tscn`) and its controller (`scenes/dungeon/dungeon_level_controller.gd`) in an isolated, controlled, and reversible manner, establishing `DungeonLevelLab` as the sole canonical authoring & integration lab.

**Architecture:** Pure decoupling where Core generation (`DungeonPipeline`, `MultiFloorGenerator`, `RoomTemplateResolver`, etc.) is untouched. Legacy test references are migrated/cleaned up, `project.godot` `run/main_scene` is updated to `res://src/dungeon_generator/debug/lab/dungeon_level_lab.tscn`, and an automated static guardrail test prevents future reintroduction of legacy identifiers.

**Tech Stack:** Godot 4.6.1 GDScript, Git.

**Spec:** Inline spec based on `# Plan de Eliminación del Old Dungeon Level (v2)`.

## Global Constraints

- Never modify Core generator pipeline logic or break golden fixtures (20/20 PASS with 0 drift).
- Zero reverse dependencies from Core to debug/lab.
- One single canonical Lab identity: `DungeonLevelLab` (`res://src/dungeon_generator/debug/lab/dungeon_level_lab.tscn`).
- The removal of legacy files must occur in an isolated commit with a restoration tag `pre-dungeon-level-removal`.

---

### Task 1: Resolve Identity & Full Dependency Audit

**Files:**
- Audit Target: `scenes/dungeon/dungeon_level.tscn`, `scenes/dungeon/dungeon_level_controller.gd`, `project.godot`, `tests/integration/`
- Documentation: `docs/superpowers/plans/2026-08-30-remove-old-dungeon-level.md`

**Interfaces:**
- Consumes: Repository search tools across `*.gd`, `*.tscn`, `*.tres`, `*.uid`, `project.godot`.
- Produces: Definitive Dependency Audit Table classifying every reference as Core, Lab, Test, Legacy, Autoload, or CI.

- [ ] **Step 1: Perform comprehensive grep across repository for legacy symbols**

Search for `dungeon_level`, `DungeonLevel`, `DungeonLevelController`, `dungeon_level_controller` in all source, scene, test, and config files.

- [ ] **Step 2: Produce and document Dependency Classification Table**

| Old File / Symbol | Consumers | Classification | Replacement / Action |
|---|---|---|---|
| `scenes/dungeon/dungeon_level.tscn` | `project.godot` (`run/main_scene`) | Entry Point | Update to `res://src/dungeon_generator/debug/lab/dungeon_level_lab.tscn` |
| `scenes/dungeon/dungeon_level.tscn` | `tests/integration/test_dungeon_level_player_spawn.gd` | Test | Remove or migrate to direct pipeline |
| `scenes/dungeon/dungeon_level.tscn` | `tests/integration/test_dungeon_level_multifloor_integration.gd` | Test | Remove (covered by `test_dungeon_level_lab_integration.gd` & `test_multi_floor_orchestrator.gd`) |
| `scenes/dungeon/dungeon_level.tscn` | `tests/integration/test_dungeon_level_determinism.gd` | Test | Remove (covered by `test_rng_isolation.gd` & `test_seed_reactivity.gd`) |
| `scenes/dungeon/dungeon_level.tscn` | `tests/integration/test_dungeon_level_destruction_interactor.gd` | Test | Remove (destruction system has comprehensive standalone unit/integration tests) |
| `scenes/dungeon/dungeon_level_controller.gd` | `tests/integration/test_dungeon_level_destruction_vfx_wiring.gd` | Test | Remove (covered by `test_destruction_vfx_*.gd`) |
| `scenes/dungeon/dungeon_level.tscn` | Old plan docs (`docs/superpowers/plans/*.md`) | Docs | Mark as historic references |

---

### Task 2: Update Main Scene in `project.godot`

**Files:**
- Modify: `project.godot`

**Interfaces:**
- Consumes: `res://src/dungeon_generator/debug/lab/dungeon_level_lab.tscn`
- Produces: Configured `run/main_scene`

- [ ] **Step 1: Update `project.godot` to set `run/main_scene`**

Set `run/main_scene="res://src/dungeon_generator/debug/lab/dungeon_level_lab.tscn"`.

- [ ] **Step 2: Verify `[autoload]` and input maps in `project.godot`**

Ensure no autoload singletons or dangling actions reference `dungeon_level_controller.gd`.

- [ ] **Step 3: Commit `project.godot` change**

```bash
git add project.godot
git commit -m "chore(config): set run/main_scene to dungeon_level_lab.tscn"
```

---

### Task 3: Migrate / Clean Up Legacy Integration Tests

**Files:**
- Delete: `tests/integration/test_dungeon_level_player_spawn.gd`
- Delete: `tests/integration/test_dungeon_level_multifloor_integration.gd`
- Delete: `tests/integration/test_dungeon_level_determinism.gd`
- Delete: `tests/integration/test_dungeon_level_destruction_vfx_wiring.gd`
- Delete: `tests/integration/test_dungeon_level_destruction_interactor.gd`

**Interfaces:**
- Consumes: Standalone test coverage already established in `tests/lab/`, `tests/destruction/`, and `tests/room_templates/`.
- Produces: Clean `tests/integration/` without legacy scene coupling.

- [ ] **Step 1: Remove legacy test files that depend strictly on `dungeon_level.tscn`**

Use `git rm` to remove the 5 legacy integration tests.

- [ ] **Step 2: Commit test removals**

```bash
git add -u tests/integration/
git commit -m "chore(tests): remove legacy integration tests coupled to old dungeon_level scene"
```

---

### Task 4: Implement Permanent Legacy Reference Guardrail Test

**Files:**
- Create: `tests/lab/test_legacy_reference_guardrail.gd`

**Interfaces:**
- Consumes: Repository scan over `src/`, `scenes/`, `tests/`, `project.godot`.
- Produces: PASS if 0 references to `scenes/dungeon/dungeon_level` or `DungeonLevelController` exist in active code.

- [ ] **Step 1: Write `tests/lab/test_legacy_reference_guardrail.gd`**

```gdscript
extends SceneTree

const FORBIDDEN_TOKENS = [
	"res://scenes/dungeon/dungeon_level.tscn",
	"res://scenes/dungeon/dungeon_level_controller.gd",
	"DungeonLevelController"
]

const SCAN_DIRS = [
	"res://src",
	"res://scenes",
	"res://tests"
]
```

- [ ] **Step 2: Run guardrail test to verify current state**

Run: `Godot_v4.6.1-stable_win64.exe --headless -s res://tests/lab/test_legacy_reference_guardrail.gd`

- [ ] **Step 3: Commit guardrail test**

```bash
git add tests/lab/test_legacy_reference_guardrail.gd
git commit -m "test(lab): add permanent static guardrail against legacy dungeon_level reintroduction"
```

---

### Task 5: Execute Complete Test Gate (Point of No Return)

**Files:**
- Test: `tests/test_golden_fixtures.gd`
- Test: `tests/lab/test_lab_dependency_boundary.gd`
- Test: `tests/lab/test_rng_isolation.gd`
- Test: `tests/lab/test_dungeon_level_lab_integration.gd`
- Test: `tests/lab/test_seed_reactivity.gd`

- [ ] **Step 1: Run Golden Fixtures suite**
Verify 20/20 seeds pass with 0 drift.

- [ ] **Step 2: Run Dependency Boundary test**
Verify 0 reverse dependencies.

- [ ] **Step 3: Run RNG Isolation & Reactivity tests**
Verify 100% deterministic isolation.

- [ ] **Step 4: Run E2E Lab Integration test**
Verify all 5 modes pass.

---

### Task 6: Tag Restoration Point & Remove Legacy Files

**Files:**
- Delete: `scenes/dungeon/dungeon_level.tscn`
- Delete: `scenes/dungeon/dungeon_level_controller.gd`
- Delete: associated `.uid` files (if any)

- [ ] **Step 1: Create git restoration tag**

```bash
git tag pre-dungeon-level-removal
```

- [ ] **Step 2: Remove legacy files using `git rm`**

```bash
git rm scenes/dungeon/dungeon_level.tscn scenes/dungeon/dungeon_level_controller.gd
```

- [ ] **Step 3: Commit legacy file deletion in an isolated commit**

```bash
git commit -m "refactor(scene): remove legacy dungeon_level.tscn and dungeon_level_controller.gd"
```

---

### Task 7: Final Architecture & Guardrail Verification

- [ ] **Step 1: Run `test_legacy_reference_guardrail.gd`**
Verify 0 violations across the entire codebase.

- [ ] **Step 2: Run `test_golden_fixtures.gd`**
Verify 20/20 PASS.

- [ ] **Step 3: Run `test_dungeon_level_lab_integration.gd`**
Verify 100% PASS.
