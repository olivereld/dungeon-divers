# Plan de Consolidación Arquitectónica - FASE 1: Congelar Contratos de Datos

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Congelar y unificar los contratos de datos del generador de mazmorras, eliminando redundancias y ambigüedades de propiedad entre `RoomData`, `RoomConnection`, `CellGrid`, `DoorPair` y `DungeonResult`, y crear la suite de tests de invariantes estructurales.

**Architecture:** 
1. Limpiar `RoomData` para que sea exclusivamente `identidad + geometría + semántica básica` (eliminar arrays redundantes no canónicos `connections` y `connected_room_ids` / `_build_room_connections`).
2. Documentar y fijar la titularidad canónica de cada dato:
   - `RoomGraph` / `RoomConnection`: Única fuente de verdad de adyacencias topológicas.
   - `CellGrid`: Única fuente de verdad de ocupación espacial 2D.
   - `EntrancePair`: Puntos perimetrales candidatos de tallado (intermedio).
   - `DoorPair`: Representación canónica final de puertas de una conexión.
   - `DungeonResult`: Contenedor inmutable de resultado final.
   - `DungeonSemanticResult`: Propietario de la semántica de misión/progresión (start, boss, critical path, keys/locks, depth).
3. Implementar `tests/test_phase1_structural_invariants.gd` para validar automáticamente todas las invariantes de datos y ownership.

**Tech Stack:** Godot 4.6.1 GDScript, headless testing CLI.

**Spec:** [a-plan/fase-equilibrate.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fase-equilibrate.md)

## Global Constraints
- **Regla 1**: Completar, verificar y pasar todos los tests de la Fase 1 antes de avanzar a la Fase 2.
- **Regla 2**: No reescribir por comodidad ni duplicar sistemas.
- **Regla 3**: Una única fuente canónica de verdad por dato.
- **Regla 5**: Toda la suite existente de pruebas (`run_all_tests.gd`) debe mantenerse pasando al 100%.

---

### Task 1.1: Limpieza y Congelación de `RoomData` y Conexiones Topológicas

**Files:**
- Modify: `src/dungeon_generator/core/data/room_data.gd`
- Modify: `src/dungeon_generator/core/grammars/space_grammar.gd`
- Modify: `src/dungeon_generator/core/algorithms/astar_carver.gd`
- Modify: `src/dungeon_generator/core/repair/corridor_connectivity_repair.gd`
- Modify: `src/dungeon_generator/core/dungeon_pipeline.gd`

**Interfaces:**
- Consumes: `RoomData`, `RoomConnection`
- Produces: `RoomData` limpio con ownership estricto (`id`, `rect`, `room_type`, `mission_node_id`, `is_required`, `depth_in_graph`).

- [ ] **Step 1: Escribir test de invariantes estructurales para `RoomData` en `tests/test_phase1_structural_invariants.gd`**
- [ ] **Step 2: Eliminar `connections` y `connected_room_ids` de `RoomData`, y el método muerto `_build_room_connections` en `DungeonPipeline`**
- [ ] **Step 3: Actualizar `space_grammar.gd`, `astar_carver.gd` y `corridor_connectivity_repair.gd` para no depender de `connected_room_ids`**
- [ ] **Step 4: Ejecutar tests y verificar que pasan**
- [ ] **Step 5: Commit de Task 1.1**

---

### Task 1.2: Formalización del Mapa Canónico de Ownership y Contratos de Datos

**Files:**
- Create/Document: `docs/architecture/DATA_CONTRACTS.md`
- Test: `tests/test_phase1_structural_invariants.gd`

**Interfaces:**
- Consumes: `CellGrid`, `RoomData`, `RoomConnection`, `DoorPair`, `DungeonResult`, `DungeonSemanticResult`
- Produces: Contrato formal documentado respondiendo "¿Dónde vive cada pieza de información y quién puede modificarla?".

- [ ] **Step 1: Redactar `docs/architecture/DATA_CONTRACTS.md` con las respuestas definitivas de ownership**
- [ ] **Step 2: Agregar a `test_phase1_structural_invariants.gd` pruebas para `CellGrid`, `DoorPair`, `DungeonResult` y `DungeonSemanticResult`**
- [ ] **Step 3: Ejecutar `run_all_tests.gd` y `test_phase1_structural_invariants.gd`**
- [ ] **Step 4: Commit de Task 1.2**
