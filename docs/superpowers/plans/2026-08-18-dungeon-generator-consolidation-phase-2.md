# Plan de Consolidación Arquitectónica - FASE 2: Crear el Contexto de Generación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar la estructura `DungeonGenerationContext` como contenedor puro de estado lógico de una generación, desacoplando a `DungeonPipeline` del transporte manual de decenas de variables locales.

**Architecture:** 
`DungeonGenerationContext` almacena exclusivamente estado lógico estructurado por categorías:
- **Config & Seeds**: `config`, `base_seed`, `attempt`, `attempt_seed`, `stage_seeds`, `repair_seed_chain`.
- **Topología & Espacio**: `mission_graph`, `rooms`, `connections`, `entrance_pairs`, `grid`, `corridor_paths`, `door_pairs`.
- **Semántica & Progresión**: `start_room_id`, `boss_room_id`, `critical_path_rooms`, `critical_path_connections`, `depth_map`, `key_placements`, `locked_doors`.
- **Distance Field**: `distance_field` canónico (calculado una sola vez).
- **Métricas & Diagnósticos**: `stage_timings_ms`, `validation_result`, `fitness_score`, `metrics`, `diagnostics`.
- **Métodos auxiliares puros**: `to_dungeon_result()`, `record_timing()`, `record_repair()`, `mark_attempt_failed()`.

**Tech Stack:** Godot 4.6.1 GDScript, headless test runner.

**Spec:** [a-plan/fase-equilibrate.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fase-equilibrate.md)

## Global Constraints
- **Regla 1**: No saltar fases. Completar y testear la Fase 2 antes de la Fase 3.
- **Regla 2**: No transformar el contexto en un God Object (cero algoritmos dentro del contexto, solo estado puro).
- **Regla 3**: Mantener la compatibilidad total con la generación actual.
- **Regla 5**: Toda la suite existente de pruebas (`run_all_tests.gd`) debe mantenerse pasando al 100%.

---

### Task 2.1: Implementación de `DungeonGenerationContext` y Test Unitario

**Files:**
- Create: `src/dungeon_generator/core/data/dungeon_generation_context.gd`
- Create: `tests/test_phase2_generation_context.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: `DungeonConfig`, `CellGrid`, `RoomData`, `RoomConnection`, `DoorPair`, `DungeonResult`
- Produces: `DungeonGenerationContext` con métodos puros de exportación y tracking.

- [ ] **Step 1: Escribir el test unitario `tests/test_phase2_generation_context.gd`**
- [ ] **Step 2: Ejecutar el test para verificar que falla antes de implementar**
- [ ] **Step 3: Implementar `src/dungeon_generator/core/data/dungeon_generation_context.gd`**
- [ ] **Step 4: Ejecutar `test_phase2_generation_context.gd` y verificar que pasa al 100%**
- [ ] **Step 5: Integrar el test en `tests/run_all_tests.gd` y ejecutar regresión completa**
- [ ] **Step 6: Commit de Fase 2**
