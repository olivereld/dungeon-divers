# Plan de Corrección — Corridors + Room Ownership + Semantics

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminar de raíz los defectos donde los corredores atraviesan salas intermedias ajenas (`corridor -> room -> corridor`) y donde la semántica produce múltiples salas Boss (ej. en seed `352896113`), implementando el contrato estricto de **Room Ownership**, delimitación formal de **Doorway**, enrutamiento y ensanchamiento restringidos, y autoridad semántica única de Boss (`count(boss) == 1`).

**Architecture:**
1. **Contrato Espacial y Room Ownership (`CellGrid` + `DungeonGenerationContext`)**:
   - `CellGrid` mantiene un `_room_owners: PackedInt32Array` asignando a cada celda el ID de la sala propietaria (`-1` para muros/pasillos/void).
   - El router ortogonal y A* restringen su dominio: para una conexión `A -> B`, solo se permiten celdas libres/pasillo, doorway de A y doorway de B. Toda celda perteneciente a una sala `C` queda estrictamente prohibida (`Room C = forbidden corridor territory`).
2. **Delimitación de Doorway y `EntranceSolver`**:
   - Los puntos de entrada generados por `EntranceSolver` deben situarse exclusivamente en el perímetro/doorway de la sala. El centerline de los corredores conecta doorway con doorway sin penetrar en el interior de salas intermedias.
3. **Widening Seguro y Validación Pre-Commit**:
   - El ensanchamiento de corredores (`width > 1`) no puede invadir salas ajenas. Si invade, se reduce el ancho o se busca ruta alternativa.
   - Validación pre-commit estricta: `rooms_touched ⊆ {A, B}`.
4. **Semántica Única de Boss y Validación Dura**:
   - `GrammarRules` y `MissionGrammar` impiden la aplicación duplicada de nodos `BOSS`.
   - `DungeonQualityGate` y `GameplayValidator` hacen cumplir el hard constraint: `count(BOSS) == 1`, `boss != entrance`, `boss != goal`.

**Tech Stack:** Godot 4.6.1 GDScript, headless testing CLI.

**Spec:** [a-plan/fase_corredores.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fase_corredores.md)

## Global Constraints
- **Regla 1**: Ejecutar en el orden estricto de 15 fases definido en la especificación sin saltarse ningún paso.
- **Regla 2**: NO implementar nuevos sistemas de reparación; eliminar el defecto en el origen (routing, widening y semántica).
- **Regla 3**: Cero invasión de salas intermedias (`0 corridor-through-room`).
- **Regla 4**: Exactamente un Boss por mazmorra (`count(BOSS) == 1`).
- **Regla 5**: Toda la suite de pruebas (`run_all_tests.gd`) y las Golden Seeds deben mantenerse pasando al 100%.

---

### Task 1: Congelar Seeds de Regresión y Diagnóstico (Fase 1)

**Files:**
- Create: `tests/test_corridor_regression_seeds.gd`

**Interfaces:**
- Consumes: `DungeonPipeline`, `DungeonConfig`
- Produces: Suite de captura y diagnóstico de las seeds problemáticas: `3196820195`, `148285204`, `352896113` (7 y 10 salas).

- [ ] **Step 1: Crear `tests/test_corridor_regression_seeds.gd` registrando los casos de fallo baseline**
- [ ] **Step 2: Ejecutar el test para capturar el estado actual antes de las modificaciones**

---

### Task 2: Corregir el Contrato Espacial y Room Ownership (Fase 2)

**Files:**
- Modify: `src/dungeon_generator/core/data/cell_grid.gd`
- Modify: `src/dungeon_generator/core/stages/dungeon_room_stage.gd`

**Interfaces:**
- Consumes: `CellGrid`, `RoomData`
- Produces: `grid.get_room_owner(pos) -> int`, `grid.set_room_owner(pos, room_id)`, registro de propiedad en cada celda de sala.

- [ ] **Step 1: Añadir `_room_owners: PackedInt32Array` y métodos `get_room_owner()` / `set_room_owner()` en `CellGrid`**
- [ ] **Step 2: Actualizar `DungeonRoomStage._build_room_floors` para poblar el `room_owner` de cada celda de sala**
- [ ] **Step 3: Ejecutar `test_cell_grid.gd` para verificar integridad del modelo**

---

### Task 3: Delimitación de Doorway y Corrección de `EntranceSolver` (Fase 3 & Fase 4)

**Files:**
- Modify: `src/dungeon_generator/core/solvers/entrance_solver.gd`
- Modify: `src/dungeon_generator/core/data/door_pair.gd`

**Interfaces:**
- Consumes: `RoomData`, `RoomConnection`, `CellGrid`
- Produces: `EntrancePair` con `start` y `goal` estrictamente en los bordes/doorways de las salas A y B.

- [ ] **Step 1: Verificar y forzar que `EntranceSolver` nunca entregue centros de sala ni caras internas no perimetrales**
- [ ] **Step 2: Validar que `entrance_a ∈ boundary(A)` y `entrance_b ∈ boundary(B)`**
- [ ] **Step 3: Ejecutar `test_phase4_entrance_solver.gd` y `test_door_placement_solver.gd`**

---

### Task 4: Corregir `OrthogonalCorridorPlanner` con Restricción de Room Ownership (Fase 5)

**Files:**
- Modify: `src/dungeon_generator/core/algorithms/orthogonal_corridor_planner.gd`

**Interfaces:**
- Consumes: `CellGrid`, `room_a_id`, `room_b_id`
- Produces: Rutas ortogonales (`Straight`, `L`, `Z/U`) que rechazan estrictamente cualquier celda con `room_owner != -1` y `room_owner != room_a` y `room_owner != room_b`.

- [ ] **Step 1: Modificar `is_cell_valid_for_corridor` en `OrthogonalCorridorPlanner` para validar `grid.get_room_owner(cell)`**
- [ ] **Step 2: Prohibir expresamente trazar corredores sobre el suelo de salas intermedias C**
- [ ] **Step 3: Ejecutar `test_orthogonal_corridor_planner.gd`**

---

### Task 5: Corregir `AStarCarver` con Dominio Prohibido para Salas Ajenas (Fase 6 & Fase 9)

**Files:**
- Modify: `src/dungeon_generator/core/algorithms/astar_carver.gd`

**Interfaces:**
- Consumes: `CellGrid`, `CorridorRequest`, `room_map`
- Produces: Búsqueda A* donde las salas intermedias C son **territorio estrictamente prohibido** (peso INF / nodo desconectado, no costo 1000). Reutilización permitida para celdas `CORRIDOR` existentes, pero prohibida para `ROOM_FLOOR` ajeno.

- [ ] **Step 1: Modificar `_find_direction_aware_path` y `_build_base_astar_graph` en `AStarCarver` para descartar celdas pertenecientes a salas ajenas**
- [ ] **Step 2: Permitir reutilización de celdas existentes de tipo `CORRIDOR` sin permitir atravesar `FLOOR` de salas ajenas**
- [ ] **Step 3: Ejecutar `test_astar_carver.gd`**

---

### Task 6: Corregir Widening y Validación Pre-Commit (Fase 7 & Fase 8)

**Files:**
- Modify: `src/dungeon_generator/core/algorithms/astar_carver.gd`

**Interfaces:**
- Consumes: `candidate_carved_cells`, `req.room_a_id`, `req.room_b_id`
- Produces: Ensanchamiento seguro que retrocede a `width = 1` o falla si invade salas ajenas; validación pre-commit `rooms_touched ⊆ {A, B}`.

- [ ] **Step 1: En `_compute_widened_corridor_cells`, filtrar celdas ensanchadas para que nunca toquen salas ajenas**
- [ ] **Step 2: Implementar validación pre-commit de `rooms_touched`: si el corredor toca una tercera sala C, abortar el tallado de esa ruta**
- [ ] **Step 3: Ejecutar `test_corridor_clearance_buffer.gd` y `test_phase9_corridors.gd`**

---

### Task 7: Corregir Semántica de Boss Único y Validación en Quality Gate (Fase 11 & Fase 12)

**Files:**
- Modify: `src/dungeon_generator/core/grammars/grammar_rules.gd`
- Modify: `src/dungeon_generator/core/grammars/mission_grammar.gd`
- Modify: `src/dungeon_generator/core/semantic/start_boss_solver.gd`
- Modify: `src/dungeon_generator/core/validation/dungeon_quality_gate.gd`

**Interfaces:**
- Consumes: `DungeonGraph`, `MissionNode`, `DungeonConfig`
- Produces: Garantía de exactamente un único Boss (`count(BOSS) == 1`), `boss != start`, `boss_depth >= 60% max_depth`.

- [ ] **Step 1: Modificar `MissionGrammar` para evitar aplicar la regla `boss_finisher` más de una vez por mazmorra**
- [ ] **Step 2: En `StartBossSolver` y `DungeonQualityGate`, agregar hard assertion `exactly_one_boss`**
- [ ] **Step 3: Ejecutar `test_phase8_semantics.gd`**

---

### Task 8: Suite Integral de Tests y Validación de Regresión de Corredores (Fases 10, 13, 14, 15)

**Files:**
- Create: `tests/test_corridor_ownership_and_semantics.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: Toda la suite de generación
- Produces: Validación de los 7 tests de corredores y confirmación de 0 penetraciones en salas y 1 solo Boss en las seeds críticas `3196820195`, `148285204`, `352896113`.

- [ ] **Step 1: Crear `tests/test_corridor_ownership_and_semantics.gd` cubriendo los 7 tests de la Fase 13**
- [ ] **Step 2: Ejecutar `tests/test_corridor_ownership_and_semantics.gd` y verificar 100% PASS**
- [ ] **Step 3: Ejecutar la suite global de CI `tests/run_all_tests.gd` y verificar 100% PASS**
- [ ] **Step 4: Commit final de las correcciones de corredores y semántica**
