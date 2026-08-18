# Plan de Consolidación Arquitectónica - FASE 7: Consolidar Topología

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidar la construcción topológica del grafo (`Delaunay -> MST -> Optional edges`) garantizando 100% de conectividad, `E_mst = V - 1`, complejidad ciclomática `E - V + 1 >= 1`, grado máximo de nodo `<= 4`, ausencia de auto-aristas o aristas duplicadas y orden determinista.

**Architecture:** 
1. **Contratos Topológicos de `RoomGraphBuilder`**:
   - Grafo Conexo: Siempre 1 solo componente conexo si `rooms.size() > 0`.
   - Árbol de Expansión Mínima: Exactamente `V - 1` aristas obligatorias (`is_required == true`).
   - Ciclos Opcionales: Garantizar al menos 1 loop (`cyclomatic >= 1`) con configuración normal (`loop_chance > 0.0`) cuando existan aristas candidatas disponibles.
   - Restricción de Grado: Grado máximo por nodo `<= 4` para evitar congestión física de puertas en una misma sala.
   - Orden Determinista: `conn.id` asignado secuencialmente en orden canónico `(room_a_id, room_b_id)`.
2. **Suite de Pruebas de Topología (`test_phase7_topology.gd`)**:
   - Verificación de invariantes en 100 semillas:
     - `is_connected == true`.
     - `connections.size() >= rooms.size() - 1`.
     - `cyclomatic_complexity = E - V + 1 >= 1`.
     - Sin aristas repetidas `(a, b)` ni auto-bucles `(a, a)`.
     - Grado por sala `<= 4`.

**Tech Stack:** Godot 4.6.1 GDScript, headless testing CLI.

**Spec:** [a-plan/fase-equilibrate.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fase-equilibrate.md)

## Global Constraints
- **Regla 1**: Completar y verificar la Fase 7 antes de avanzar a la Fase 8.
- **Regla 2**: Mantener la arquitectura existente (`DelaunayCandidateBuilder` + `MinimumSpanningTree` + `OptionalConnectionSelector`).
- **Regla 5**: Toda la suite de pruebas (`run_all_tests.gd`) y Golden Seeds deben mantenerse pasando al 100%.

---

### Task 7.1: Consolidación de `RoomGraphBuilder` y `OptionalConnectionSelector`

**Files:**
- Modify: `src/dungeon_generator/core/topology/optional_connection_selector.gd`
- Modify: `src/dungeon_generator/core/topology/room_graph_builder.gd`

**Interfaces:**
- Consumes: `Array[RoomData]`, `topology_seed: int`, `loop_chance: float`
- Produces: `TopologyResult` con grafo conexo, ciclomático `>= 1` y grado `<= 4`.

- [ ] **Step 1: Reforzar `OptionalConnectionSelector` para garantizar `cyclomatic >= 1` y grado `<= 4`**
- [ ] **Step 2: Verificar `RoomGraphBuilder` y cálculo de métricas de complejidad ciclomática**

---

### Task 7.2: Suite de Pruebas Topológicas (Phase 7 Gate)

**Files:**
- Create: `tests/test_phase7_topology.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: `RoomGraphBuilder`, `DungeonPipeline`
- Produces: Test de validación de invariantes topológicas en 100 semillas.

- [ ] **Step 1: Escribir `tests/test_phase7_topology.gd` validando 100 semillas**
- [ ] **Step 2: Ejecutar `test_phase7_topology.gd` y verificar 100% de éxito**
- [ ] **Step 3: Integrar en `tests/run_all_tests.gd` y ejecutar regresión completa**
- [ ] **Step 4: Commit de Fase 7**
