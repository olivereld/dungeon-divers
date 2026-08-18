# Plan de Consolidación Arquitectónica - FASE 8: Consolidar Semántica

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidar la asignación semántica (`Graph -> Entrance -> Boss -> Critical Path -> Treasure -> Shrines -> Elite -> Combat`) asegurando que `boss_depth >= 60% max_depth`, tesoros en hojas fuera de ruta (máx 4), 1-2 shrines a profundidad media, y 1-2 élites en la ruta crítica antes de decorar o renderizar.

**Architecture:** 
1. **Contratos Semánticos (`SemanticOrchestrator` + `ObjectiveAssigner`)**:
   - `ObjectiveType`: Añadir `SHRINE` y `ELITE`.
   - `StartBossSolver`: Garantizar que `boss_depth >= 0.60 * max_depth`.
   - `ObjectiveAssigner`:
     - **SPAWN** en `start_room_id` (grado 1).
     - **BOSS** en `boss_room_id` (mayor área y profundidad máxima).
     - **TREASURE**: Hojas off-path (máx 4).
     - **SHRINE**: 1-2 salas mid-depth preferentemente off-path.
     - **ELITE**: 1-2 salas intermedias en el `critical_path`.
   - `GameplayValidator`: Comprueba formalmente resolubilidad, camino crítico y presencia de objetivos antes de la etapa de renderizado 3D.
2. **Suite de Pruebas Semánticas (`test_phase8_semantics.gd`)**:
   - Verificación en 100 semillas de:
     - `boss_depth >= 0.60 * max_depth`.
     - `start_room_id != boss_room_id`.
     - Critical path conectado y no vacío.
     - Presencia de Spawn, Boss y al menos 1 Treasure / Shrine / Elite.
     - Imposibilidad de soft-locks.

**Tech Stack:** Godot 4.6.1 GDScript, headless testing CLI.

**Spec:** [a-plan/fase-equilibrate.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fase-equilibrate.md)

## Global Constraints
- **Regla 1**: Completar y verificar la Fase 8 antes de avanzar a la Fase 9.
- **Regla 2**: Mantener la pureza lógica de `DungeonSemanticResult` (cero mutación del `CellGrid`, 100% testeable en headless).
- **Regla 5**: Toda la suite de pruebas (`run_all_tests.gd`) y Golden Seeds deben mantenerse pasando al 100%.

---

### Task 8.1: Consolidación de `ObjectiveData`, `StartBossSolver` y `ObjectiveAssigner`

**Files:**
- Modify: `src/dungeon_generator/core/semantic/data/objective_data.gd`
- Modify: `src/dungeon_generator/core/semantic/start_boss_solver.gd`
- Modify: `src/dungeon_generator/core/semantic/objective_assigner.gd`
- Modify: `src/dungeon_generator/core/semantic/gameplay_validator.gd`

**Interfaces:**
- Consumes: `DungeonResult`, `DungeonConfig`
- Produces: `DungeonSemanticResult` completo y validado.

- [ ] **Step 1: Expandir `ObjectiveData` con `SHRINE` y `ELITE`**
- [ ] **Step 2: Calibrar `StartBossSolver` para asegurar `boss_depth >= 60% max_depth`**
- [ ] **Step 3: Implementar asignación de Shrines, Elites y Tesoros off-path en `ObjectiveAssigner`**
- [ ] **Step 4: Actualizar `GameplayValidator` para verificar las nuevas reglas semánticas**

---

### Task 8.2: Suite de Pruebas Semánticas (Phase 8 Gate)

**Files:**
- Create: `tests/test_phase8_semantics.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: `SemanticOrchestrator`, `DungeonPipeline`
- Produces: Test de validación de 100 semillas consecutivas.

- [ ] **Step 1: Escribir `tests/test_phase8_semantics.gd` probando 100 semillas**
- [ ] **Step 2: Ejecutar `test_phase8_semantics.gd` y verificar 100% de éxito**
- [ ] **Step 3: Integrar en `tests/run_all_tests.gd` y ejecutar regresión completa**
- [ ] **Step 4: Commit de Fase 8**
