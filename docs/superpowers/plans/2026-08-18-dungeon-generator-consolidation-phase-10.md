# Plan de Consolidación Arquitectónica - FASE 10: Rasterización y CellGrid

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidar `CellGrid` como la única fuente de verdad espacial definitiva, implementar el calculador canónico de campo de distancias de una sola pasada (`DungeonDistanceField`), y verificar formalmente que el 100% de las celdas de suelo y pasillos sean alcanzables sin recalcular BFS redundantes.

**Architecture:** 
1. **Campo de Distancia Canónico (`DungeonDistanceField`)**:
   - `src/dungeon_generator/core/algorithms/dungeon_distance_field.gd`:
     - `compute_distance_field(grid: CellGrid, start_pos: Vector2i) -> Dictionary`: Realiza un único BFS desde el inicio por todas las celdas transitables (`is_walkable`).
     - Almacenado en `ctx.distance_field` para ser compartido sin recalcularlo para dificultad, pacing, visibilidad o validación.
     - `verify_100_percent_reachable(grid: CellGrid, start_pos: Vector2i) -> Dictionary`: Comprueba que toda celda transitable del `CellGrid` tiene distancia finita desde `start_pos`.
2. **Integración en `DungeonValidationStage`**:
   - Calcula y almacena `ctx.distance_field`.
   - Verifica que no existen islas transitables huérfanas o desconectadas.
3. **Suite de Pruebas de Rasterización (`test_phase10_rasterization_cellgrid.gd`)**:
   - Validación en 100 semillas de:
     - 100% de celdas transitables (`FLOOR`, `CORRIDOR`, `DOOR`, `SPAWN`, `OBJECTIVE`) alcanzables desde `start_pos`.
     - `distance_field` poblado y continuo.
     - Envolvente de muros correcta (sin celdas transitables expuestas a `VOID`).

**Tech Stack:** Godot 4.6.1 GDScript, headless testing CLI.

**Spec:** [a-plan/fase-equilibrate.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fase-equilibrate.md)

## Global Constraints
- **Regla 1**: Completar y verificar la Fase 10 antes de avanzar a la Fase 11.
- **Regla 2**: Un único BFS canónico para el distance field (no recalcular BFS independientes).
- **Regla 5**: Toda la suite de pruebas (`run_all_tests.gd`) y Golden Seeds deben mantenerse pasando al 100%.

---

### Task 10.1: Implementación de `DungeonDistanceField` e Integración en `DungeonValidationStage`

**Files:**
- Create: `src/dungeon_generator/core/algorithms/dungeon_distance_field.gd`
- Modify: `src/dungeon_generator/core/stages/dungeon_validation_stage.gd`

**Interfaces:**
- Consumes: `CellGrid`, `start_pos: Vector2i`
- Produces: `Dictionary` (Vector2i -> int) con las distancias mínimas y validación 100% reachable.

- [ ] **Step 1: Implementar `DungeonDistanceField` con BFS único y validador de alcanzabilidad**
- [ ] **Step 2: Integrar `DungeonDistanceField` en `DungeonValidationStage.execute()` y guardar en `ctx.distance_field`**

---

### Task 10.2: Suite de Pruebas de Rasterización y Alcanzabilidad (Phase 10 Gate)

**Files:**
- Create: `tests/test_phase10_rasterization_cellgrid.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: `DungeonPipeline`, `DungeonDistanceField`
- Produces: Test de validación espacial de 100 semillas consecutivas.

- [ ] **Step 1: Escribir `tests/test_phase10_rasterization_cellgrid.gd` probando 100 semillas**
- [ ] **Step 2: Ejecutar `test_phase10_rasterization_cellgrid.gd` y verificar 100% de éxito**
- [ ] **Step 3: Integrar en `tests/run_all_tests.gd` y ejecutar regresión completa**
- [ ] **Step 4: Commit de Fase 10**
