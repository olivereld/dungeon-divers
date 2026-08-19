# Plan de Consolidación Arquitectónica - FASE 9: Consolidar Routing y Corridors

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidar el sistema de routing ortogonal jerárquico (`Straight -> L-Simple -> Alternative-L -> A* Fallback`) asegurando que el 100% de las conexiones produzcan corredores transitables válidos con `<= 2` codos promedio por conexión, respetando anchos diferenciados (`critical_path = 3`, `standard = 2`, `treasure_spur = 1`).

**Architecture:** 
1. **Jerarquía Canónica de Routing (`OrthogonalCorridorPlanner` + `AStarCarver`)**:
   - Nivel 1: Línea recta (0 giros).
   - Nivel 2: L simple (1 giro: H->V).
   - Nivel 3: L alternativa (1 giro: V->H).
   - Nivel 4: Z / U route ortogonal (2 giros).
   - Nivel 5: Direction-Aware A* con penalización de giros.
2. **Anchos Diferenciados**:
   - Corredores del camino crítico (`is_critical_path`): `width = 3` (o `width = 2`).
   - Corredores estándar: `width = 2`.
   - Espolones de tesoro (`is_treasure_spur`): `width = 1` permitido.
3. **Suite de Pruebas de Corredores (`test_phase9_corridors.gd`)**:
   - Validación en 100 semillas de:
     - 100% de conexiones resueltas con corredores válidos.
     - Extremos `start` y `goal` conectados a los suelos de sus respectivas salas.
     - Promedio de giros por corredor `<= 2.0`.
     - Tasa de fallback a reparaciones de emergencia `<= 5%`.

**Tech Stack:** Godot 4.6.1 GDScript, headless testing CLI.

**Spec:** [a-plan/fase-equilibrate.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fase-equilibrate.md)

## Global Constraints
- **Regla 1**: Completar y verificar la Fase 9 antes de avanzar a la Fase 10.
- **Regla 2**: Mantener la separación de fases: routing geométrico puro antes de la rasterización y puertas.
- **Regla 5**: Toda la suite de pruebas (`run_all_tests.gd`) y Golden Seeds deben mantenerse pasando al 100%.

---

### Task 9.1: Consolidación de `AStarCarver` y `OrthogonalCorridorPlanner`

**Files:**
- Modify: `src/dungeon_generator/core/algorithms/astar_carver.gd`
- Modify: `src/dungeon_generator/core/algorithms/orthogonal_corridor_planner.gd`

**Interfaces:**
- Consumes: `CellGrid`, `Array[RoomData]`, `Array[EntrancePair]`, `Array[RoomConnection]`, `DungeonConfig`
- Produces: `CorridorCarveResult` con métricas estéticas de giros y transitabilidad.

- [ ] **Step 1: Reforzar la jerarquía de routing (Straight -> L-Simple -> Alt-L -> Z/U -> A*)**
- [ ] **Step 2: Asegurar anchos diferenciados y conectividad estricta de ambos extremos**

---

### Task 9.2: Suite de Pruebas de Corredores y Métricas de Calidad (Phase 9 Gate)

**Files:**
- Create: `tests/test_phase9_corridors.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: `DungeonPipeline`, `AStarCarver`
- Produces: Test de validación de corredores en 100 semillas.

- [ ] **Step 1: Escribir `tests/test_phase9_corridors.gd` probando 100 semillas**
- [ ] **Step 2: Ejecutar `test_phase9_corridors.gd` y verificar 100% de éxito**
- [ ] **Step 3: Integrar en `tests/run_all_tests.gd` y ejecutar regresión completa**
- [ ] **Step 4: Commit de Fase 9**
