# Plan de Consolidación Arquitectónica - FASE 11: Consolidar Doors

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidar `DoorResolver` asegurando correspondencia biunívoca entre `RoomConnection`, `EntrancePair` y `DoorPair`, garantizando que ninguna puerta quede flotante, fuera de límites o sobrepuesta, y que `DoorResolver` opere como resolvedor puro sin modificar la topología del grafo.

**Architecture:** 
1. **Contratos Canónicos de Puertas (`DoorResolver` + `DoorPair` + `DoorPlacement`)**:
   - `DoorResolver.resolve_doors()`:
     - Detecta las celdas de umbral para cada `EntrancePair` y `CorridorPath`.
     - Valida contención perimetral, jambas de soporte y transitabilidad.
     - Asigna tipo lógico (`STANDARD`, `LOCKED`, `BOSS`, `ARCHWAY`) respetando la configuración.
     - Emite `DoorPair` por cada conexión resuelta.
     - **Regla Estricta**: No altera el grafo topológico ni crea conexiones nuevas.
2. **Suite de Pruebas de Puertas (`test_phase11_doors.gd`)**:
   - Validación en 100 semillas de:
     - 100% de puertas dentro de los límites del `CellGrid`.
     - 100% de puertas sobre celdas transitables (`is_walkable == true`).
     - Correspondencia biunívoca `RoomConnection <-> DoorPair`.
     - 0 solapamientos indebidos o puertas flotantes.

**Tech Stack:** Godot 4.6.1 GDScript, headless testing CLI.

**Spec:** [a-plan/fase-equilibrate.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fase-equilibrate.md)

## Global Constraints
- **Regla 1**: Completar y verificar la Fase 11 antes de avanzar a la Fase 12.
- **Regla 2**: `DoorResolver` nunca debe mutar el grafo topológico.
- **Regla 5**: Toda la suite de pruebas (`run_all_tests.gd`) y Golden Seeds deben mantenerse pasando al 100%.

---

### Task 11.1: Consolidación de `DoorResolver` y `DungeonDoorStage`

**Files:**
- Modify: `src/dungeon_generator/core/solvers/door_resolver.gd`
- Modify: `src/dungeon_generator/core/stages/dungeon_door_stage.gd`

**Interfaces:**
- Consumes: `CellGrid`, `Array[RoomData]`, `Array[EntrancePair]`, `Array[CorridorPath]`, `Array[RoomConnection]`, `DungeonConfig`
- Produces: `DoorResolutionResult` con array de `DoorPair` y `doors` rasterizadas.

- [ ] **Step 1: Verificar validación de límites, transitabilidad y correspondencia biunívoca en `DoorResolver`**
- [ ] **Step 2: Verificar flujo atómico en `DungeonDoorStage`**

---

### Task 11.2: Suite de Pruebas de Puertas (Phase 11 Gate)

**Files:**
- Create: `tests/test_phase11_doors.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: `DungeonPipeline`, `DoorResolver`
- Produces: Test de validación de puertas en 100 semillas.

- [ ] **Step 1: Escribir `tests/test_phase11_doors.gd` probando 100 semillas**
- [ ] **Step 2: Ejecutar `test_phase11_doors.gd` y verificar 100% de éxito**
- [ ] **Step 3: Integrar en `tests/run_all_tests.gd` y ejecutar regresión completa**
- [ ] **Step 4: Commit de Fase 11**
