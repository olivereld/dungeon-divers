# Plan de Consolidación Arquitectónica - FASE 0: Auditoría y Congelación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Realizar la auditoría arquitectónica exhaustiva del generador de mazmorras existente y generar el documento canónico `docs/architecture/ARCHITECTURE_AUDIT.md` sin mutar el código fuente en ejecución, congelando los contratos de partida y dejando listo el paso para la Fase 1.

**Architecture:** Mapeo de dependencias, análisis estático y documental de todos los subsistemas existentes (Core, Algorithms, Solvers, Semantic, Presentation, Validation, Repair, UI/Debug) para registrar: Responsabilidad, Input, Output, Dependencias, Mutaciones, Fuente de Verdad, Tests Existentes y Problemas/Deuda Técnica.

**Tech Stack:** Godot 4.6.1 GDScript, headless testing CLI, Markdown docs.

**Spec:** [a-plan/fase-equilibrate.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fase-equilibrate.md)

## Global Constraints
- **Regla 1**: No saltar fases. Esta Fase 0 es el prerrequisito obligatorio antes de cualquier modificación en la Fase 1.
- **Regla 2**: No modificar código fuente de runtime durante la Fase 0 (solo documentación y análisis).
- **Regla 3**: Identificar una única fuente de verdad por responsabilidad (0 duplicaciones).
- **Regla 5**: Toda la suite actual de tests (`res://tests/run_all_tests.gd`) debe mantenerse pasando al 100%.

---

### Task 0.1: Auditoría de Datos Core y Estado Espacial

**Files:**
- Document: `docs/architecture/ARCHITECTURE_AUDIT.md`
- Inspect: `src/dungeon_generator/core/data/cell_grid.gd`
- Inspect: `src/dungeon_generator/core/data/room_data.gd`
- Inspect: `src/dungeon_generator/core/data/dungeon_result.gd`
- Inspect: `src/dungeon_generator/core/data/door_placement.gd`
- Inspect: `src/dungeon_generator/core/data/door_pair.gd`
- Inspect: `src/dungeon_generator/core/data/dungeon_door_manifest.gd`
- Inspect: `src/dungeon_generator/core/data/wall_opening_manifest.gd`

**Interfaces:**
- Consumes: Especificación de estructuras de datos en `src/dungeon_generator/core/data/`
- Produces: Sección 1 de `docs/architecture/ARCHITECTURE_AUDIT.md` (Core Data Structures)

- [ ] **Step 1: Inspeccionar y auditar contratos de datos de `CellGrid`, `RoomData` y `DungeonResult`**
- [ ] **Step 2: Inspeccionar representaciones de puertas (`DoorPlacement`, `DoorPair`, `DungeonDoorManifest`, `WallOpeningManifest`)**
- [ ] **Step 3: Redactar sección Core Data en `docs/architecture/ARCHITECTURE_AUDIT.md`**
- [ ] **Step 4: Verificar coherencia de ownership y fuentes de verdad**
- [ ] **Step 5: Commit de Task 0.1**

---

### Task 0.2: Auditoría del Pipeline y Algoritmos Topológicos

**Files:**
- Document: `docs/architecture/ARCHITECTURE_AUDIT.md`
- Inspect: `src/dungeon_generator/core/dungeon_pipeline.gd`
- Inspect: `src/dungeon_generator/core/graph/dungeon_graph.gd`
- Inspect: `src/dungeon_generator/core/algorithms/delaunay_triangulator.gd`
- Inspect: `src/dungeon_generator/core/algorithms/mst_solver.gd`
- Inspect: `src/dungeon_generator/core/algorithms/room_shape_generator.gd`
- Inspect: `src/dungeon_generator/core/algorithms/orthogonal_corridor_planner.gd`
- Inspect: `src/dungeon_generator/core/algorithms/astar_carver.gd`

**Interfaces:**
- Consumes: Algoritmos en `src/dungeon_generator/core/algorithms/` y `src/dungeon_generator/core/graph/`
- Produces: Sección 2 de `docs/architecture/ARCHITECTURE_AUDIT.md` (Pipeline & Topology Generation)

- [ ] **Step 1: Analizar responsabilidades y dependencias de `DungeonPipeline`**
- [ ] **Step 2: Analizar `DelaunayTriangulator`, `MST` y selección de loops**
- [ ] **Step 3: Analizar `RoomShapeGenerator` y separación espacial**
- [ ] **Step 4: Analizar `OrthogonalCorridorPlanner` y `AStarCarver`**
- [ ] **Step 5: Redactar sección Pipeline & Topology en `docs/architecture/ARCHITECTURE_AUDIT.md`**
- [ ] **Step 6: Commit de Task 0.2**

---

### Task 0.3: Auditoría de Solvers, Semántica, Validación y Reparación

**Files:**
- Document: `docs/architecture/ARCHITECTURE_AUDIT.md`
- Inspect: `src/dungeon_generator/core/solvers/entrance_solver.gd`
- Inspect: `src/dungeon_generator/core/solvers/door_resolver.gd`
- Inspect: `src/dungeon_generator/core/semantic/semantic_orchestrator.gd`
- Inspect: `src/dungeon_generator/core/validation/`
- Inspect: `src/dungeon_generator/core/repair/`

**Interfaces:**
- Consumes: Solvers, semántica, validadores y reparadores del generador
- Produces: Sección 3 de `docs/architecture/ARCHITECTURE_AUDIT.md` (Solvers, Semantics, Validation & Repair)

- [ ] **Step 1: Analizar `EntranceSolver` y `DoorResolver`**
- [ ] **Step 2: Analizar `SemanticOrchestrator`, `CriticalPathSolver`, `StartBossSolver`, `KeyLockPlanner`**
- [ ] **Step 3: Analizar validadores físicos y de gameplay (`DoorPhysicalValidator`, `GameplayValidator`, `FloodFill`)**
- [ ] **Step 4: Analizar sistemas de reparación (`CorridorConnectivityRepair`, `RoomConnectivityRepair`, `RoomIntegrityCleaner`)**
- [ ] **Step 5: Redactar sección Solvers, Validation & Repair en `docs/architecture/ARCHITECTURE_AUDIT.md`**
- [ ] **Step 6: Commit de Task 0.3**

---

### Task 0.4: Auditoría de Presentación 3D, Mallas Continuas, UI y Test Runner

**Files:**
- Document: `docs/architecture/ARCHITECTURE_AUDIT.md`
- Inspect: `src/dungeon_generator/presentation/dungeon_presentation_builder.gd`
- Inspect: `src/wall_mesh_generator/core/continuous_wall_mesh_builder.gd`
- Inspect: `src/wall_mesh_generator/core/continuous_wall_extractor.gd`
- Inspect: `src/dungeon_generator/debug/dungeon_visualizer.gd`
- Inspect: `src/dungeon_generator/debug/dungeon_ascii_exporter.gd`
- Inspect: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: Módulos de presentación, generador de mallas de muros, visualizador 2D y suite de tests
- Produces: Sección 4 de `docs/architecture/ARCHITECTURE_AUDIT.md` (Presentation, UI, Quality Gates)

- [ ] **Step 1: Analizar flujo de presentación 3D desacoplado (Staging -> Atomic Swap) en `DungeonPresentationBuilder`**
- [ ] **Step 2: Analizar generador procedural de muros continuos (`ContinuousWallMeshBuilder`, `ContinuousWallExtractor`)**
- [ ] **Step 3: Analizar visualizador 2D interactivo (`DungeonVisualizer`) y exportador ASCII (`DungeonAsciiExporter`)**
- [ ] **Step 4: Mapear la suite de pruebas consolidada (`run_all_tests.gd`)**
- [ ] **Step 5: Completar documento final `docs/architecture/ARCHITECTURE_AUDIT.md`**
- [ ] **Step 6: Ejecutar regresión completa con `run_all_tests.gd`**
- [ ] **Step 7: Commit final de Fase 0**
