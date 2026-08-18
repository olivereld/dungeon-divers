# Plan de Consolidación Arquitectónica - FASE 3: Reducir DungeonPipeline a Orquestador

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformar `DungeonPipeline` en un coordinador puro de alto nivel que delega cada responsabilidad a etapas modulares desacopladas (`src/dungeon_generator/core/stages/`) comunicadas mediante `DungeonGenerationContext`.

**Architecture:** 
Crear el paquete de etapas modulares en `src/dungeon_generator/core/stages/`:
1. `DungeonMissionStage`: Generación de gramática de misiones y validación de resolubilidad.
2. `DungeonRoomStage`: Layout espacial (`SpaceGrammar`), tallado de formas de sala (`RoomShapeGenerator`) y validación/reparación de conectividad interna.
3. `DungeonTopologyStage`: Construcción de grafo (`RoomGraphBuilder`: Delaunay + MST + Loops).
4. `DungeonEntranceStage`: Resolución de puntos de umbral (`EntranceSolver`).
5. `DungeonCorridorStage`: Tallado ortogonal (`AStarCarver`), reparación (`CorridorConnectivityRepair`), integridad (`RoomIntegrityCleaner`) y podado (`CorridorPruner`).
6. `DungeonDoorStage`: Clasificación y validación de puertas con jambas (`DoorResolver`).
7. `DungeonMarkerStage`: Colocación de marcadores de spawn, objetivo y llaves.
8. `DungeonValidationStage`: Comprobación de conectividad 100% (`FloodFill`) y evaluación de calidad (`FitnessEvaluator`).

`DungeonPipeline` se simplifica a un bucle de orquestación limpio:
```gdscript
for attempt in range(max_retries):
    var ctx := DungeonGenerationContext.new(config, base_seed, attempt)
    if not _mission_stage.execute(ctx): continue
    if not _room_stage.execute(ctx): continue
    if not _topology_stage.execute(ctx): continue
    if not _entrance_stage.execute(ctx): continue
    if not _corridor_stage.execute(ctx): continue
    if not _door_stage.execute(ctx): continue
    _marker_stage.execute(ctx)
    if not _validation_stage.execute(ctx): continue
    return ctx.to_dungeon_result()
```

**Tech Stack:** Godot 4.6.1 GDScript, headless testing CLI.

**Spec:** [a-plan/fase-equilibrate.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fase-equilibrate.md)

## Global Constraints
- **Regla 1**: Completar y verificar la Fase 3 al 100% antes de avanzar a la Fase 4.
- **Regla 2**: Extender y encapsular la lógica existente sin crear algoritmos paralelos ni alterar el comportamiento determinista de las semillas.
- **Regla 5**: Toda la suite existente de pruebas (`run_all_tests.gd`) y la suite de Golden Seeds deben mantenerse pasando al 100%.

---

### Task 3.1: Creación de Etapas Modulares (`src/dungeon_generator/core/stages/`)

**Files:**
- Create: `src/dungeon_generator/core/stages/dungeon_mission_stage.gd`
- Create: `src/dungeon_generator/core/stages/dungeon_room_stage.gd`
- Create: `src/dungeon_generator/core/stages/dungeon_topology_stage.gd`
- Create: `src/dungeon_generator/core/stages/dungeon_entrance_stage.gd`
- Create: `src/dungeon_generator/core/stages/dungeon_corridor_stage.gd`
- Create: `src/dungeon_generator/core/stages/dungeon_door_stage.gd`
- Create: `src/dungeon_generator/core/stages/dungeon_marker_stage.gd`
- Create: `src/dungeon_generator/core/stages/dungeon_validation_stage.gd`

**Interfaces:**
- Consumes: `DungeonGenerationContext`, algoritmos existentes en `core/`
- Produces: Contrato estándar `func execute(ctx: DungeonGenerationContext) -> bool` por etapa.

- [ ] **Step 1: Implementar `DungeonMissionStage`, `DungeonRoomStage`, `DungeonTopologyStage`, `DungeonEntranceStage`**
- [ ] **Step 2: Implementar `DungeonCorridorStage`, `DungeonDoorStage`, `DungeonMarkerStage`, `DungeonValidationStage`**

---

### Task 3.2: Refactorización de `DungeonPipeline` a Orquestador Puro

**Files:**
- Modify: `src/dungeon_generator/core/dungeon_pipeline.gd`
- Create: `tests/test_phase3_pipeline_orchestrator.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: Las etapas modulares de Task 3.1 y `DungeonGenerationContext`
- Produces: `DungeonPipeline` limpio como orquestador de alto nivel con cero lógica algorítmica interna.

- [ ] **Step 1: Escribir test unitario de orquestación `tests/test_phase3_pipeline_orchestrator.gd`**
- [ ] **Step 2: Refactorizar `DungeonPipeline.generate()` para coordinar las etapas modulares**
- [ ] **Step 3: Ejecutar `test_phase3_pipeline_orchestrator.gd` y `test_golden_seeds_reforced.gd`**
- [ ] **Step 4: Integrar en `tests/run_all_tests.gd` y verificar 100% de éxito en CI**
- [ ] **Step 5: Commit de Fase 3**
