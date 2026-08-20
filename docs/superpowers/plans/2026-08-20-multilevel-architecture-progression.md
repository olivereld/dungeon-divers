# Multilevel Architecture, Vertical Progression & Stair Planning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformar el generador multinivel en una arquitectura modular completa bajo `src/dungeon_generator/core/multilevel/`, resolviendo la progresión semántica vertical global (Start -> Pisos Intermedios -> Boss), el cálculo inteligente y no destructivo de anclajes de escaleras (`FloorConnectionPlanner` / `StairPlanner`), y la validación formal de navegabilidad entre pisos (`MultiFloorValidator`), eliminando la mutación destructiva de `CellGrid` y limpiando tests obsoletos.

**Architecture:** Se separa la generación individual de piso (`DungeonPipeline` + `SemanticOrchestrator`) de la orquestación multinivel (`MultiFloorOrchestrator`). Un `VerticalProgressionSolver` distribuye los objetivos y roles semánticos a través de los pisos (ej. Floor 0: Spawn/Entrada; Floor N-1: Boss/Meta). El `FloorConnectionPlanner` evalúa celdas candidatas mediante puntuación ponderada (profundidad, distancia de puertas, clearance) y registra `StairData` sin mutar destructivamente el `CellGrid`. Finalmente, `MultiFloorValidator` comprueba la conectividad y alcanzabilidad vertical E2E.

**Tech Stack:** Godot 4.x, GDScript 2.0 (RefCounted, Resource, CellGrid, DungeonGraph, DungeonFloorData, DungeonMultiFloorResult, FloorConnection, StairData).

**Spec:** Auditoría técnica de multinivel (`docs/architecture/ARCHITECTURE_AUDIT.md`).

## Global Constraints

- **No Test Execution by Agent:** El agente nunca debe ejecutar comandos ni pruebas directamente en terminal; debe indicar el comando exacto para que el usuario lo ejecute.
- **Zero Destructive Mutations:** `CellGrid` y `DungeonResult` generados por el pipeline deben permanecer inmutables; las escaleras se registran mediante `StairData` y metadata de piso.
- **Deterministic Seed Hierarchy:** Cada piso y conexión vertical utiliza derivación criptográfica/hashing determinista (`v1:master:floor:X`, `v1:master:stairs:X`).

---

## File Structure & Map

```
src/dungeon_generator/core/
├── multilevel/
│   ├── multi_floor_orchestrator.gd        # Orquestador desacoplado de composición multinivel
│   ├── vertical_progression_solver.gd     # Asignación y resolución de progresión vertical
│   ├── floor_connection_planner.gd        # Scoring y selección no destructiva de escaleras
│   └── multi_floor_validator.gd           # Validador estructural y navegacional multinivel
├── multi_floor_generator.gd               # Fachada de compatibilidad delegando al nuevo orquestador
└── stair_planner.gd                       # Adaptador legacy delegando a floor_connection_planner.gd

tests/
├── test_boss_spawn_identity.gd            # [DELETE] Archivo vacío 0 bytes
├── test_multifloor_vertical_progression.gd# [NEW] Test de progresión vertical global
├── test_stair_candidate_scoring.gd        # [NEW] Test de scoring y colocación no destructiva
├── test_multifloor_validator.gd           # [MODIFY/REPLACE] Validación estructural y de navegabilidad E2E
├── test_fase_10_vertical_integration.gd   # [MODIFY] Regresión de integración vertical 3D
└── test_presentation_atomic_swap.gd       # [REGRESSION] Swap atómico y preservación
```

---

## Tasks

### Task 1: Limpieza de Pruebas Obsoletas e Invariantes

**Files:**
- Delete: `tests/test_boss_spawn_identity.gd`

- [x] **Step 1: Eliminar el archivo de test vacío `tests/test_boss_spawn_identity.gd`**

---

### Task 2: Submódulo `core/multilevel` y Algoritmo de Escaleras No Destructivo

**Files:**
- Create: `src/dungeon_generator/core/multilevel/vertical_progression_solver.gd`
- Create: `src/dungeon_generator/core/multilevel/floor_connection_planner.gd`
- Create: `src/dungeon_generator/core/multilevel/multi_floor_validator.gd`
- Create: `src/dungeon_generator/core/multilevel/multi_floor_orchestrator.gd`
- Modify: `src/dungeon_generator/core/multi_floor_generator.gd`
- Modify: `src/dungeon_generator/core/stair_planner.gd`
- Test: `tests/test_stair_candidate_scoring.gd`
- Test: `tests/test_multifloor_vertical_progression.gd`

**Interfaces:**
- `VerticalProgressionSolver`: Recibe `total_floors` y `DungeonConfig`, resuelve qué pisos alojan `START`, `PASSAGE_DOWN/UP`, `KEYS/LOCKS` y `BOSS/GOAL`.
- `FloorConnectionPlanner`: Busca candidatos en `DungeonFloorData`, puntúa por distancia a puertas, profundidad, radio libre, y genera `FloorConnection` sin alterar celdas base.
- `MultiFloorValidator`: Valida $N$ pisos, $N-1$ conexiones verticales bidireccionales y alcanzabilidad de inicio a fin.
- `MultiFloorOrchestrator`: Coordina el pipeline completo determinista.

- [x] **Step 1: Implementar `VerticalProgressionSolver`**
- [x] **Step 2: Implementar `FloorConnectionPlanner` con scoring multicriterio**
- [x] **Step 3: Implementar `MultiFloorValidator` con comprobación estructural y de navegación**
- [x] **Step 4: Implementar `MultiFloorOrchestrator` e integrar `MultiFloorGenerator` y `StairPlanner`**
- [x] **Step 5: Escribir pruebas unitarias de scoring de escaleras y progresión vertical**

---

### Task 3: Integración E2E y Validación Vertical

**Files:**
- Modify: `tests/test_fase_10_vertical_integration.gd`
- Modify: `tests/test_multifloor_generation.gd`

- [x] **Step 1: Actualizar suites de prueba vertical multinivel para consumir la nueva arquitectura**
- [ ] **Step 2: Notificar al usuario para ejecutar la suite completa de pruebas**
Comandos a indicar al usuario:
1. `godot --headless -s res://tests/test_stair_candidate_scoring.gd`
2. `godot --headless -s res://tests/test_multifloor_vertical_progression.gd`
3. `godot --headless -s res://tests/test_multifloor_generation.gd`
4. `godot --headless -s res://tests/test_fase_10_vertical_integration.gd`
5. `godot --headless -s res://tests/test_presentation_atomic_swap.gd`
