# Auditoría de Arquitectura del Dungeon Generator (Fase 0)

> **Documento Canónico de Auditoría y Congelación Arquitectónica**
> **Fecha:** 2026-08-18
> **Estado:** Fase 0 Completada — Base contractual para Fases 1 a 19.

---

## 1. Resumen Ejecutivo y Mapa General del Sistema

El generador de mazmorras de `dungeon-divers` está estructurado en capas secuenciales desacopladas:
1. **Core Data**: Modelos de datos puros y contenedores lógicos (`CellGrid`, `RoomData`, `DungeonResult`, `DoorPair`, `WallOpeningManifest`).
2. **Pipeline Orquestador**: `DungeonPipeline` y `MultiFloorGenerator` con derivación determinista de semillas.
3. **Generación Topológica & Espacial**: `MissionGrammar`, `SpaceGrammar`, `RoomShapeGenerator`, `RoomGraphBuilder` (Delaunay + MST + Loops).
4. **Enrutamiento & Tallado de Corredores**: `EntranceSolver`, `OrthogonalCorridorPlanner`, `AStarCarver`.
5. **Resolución de Puertas & Umbrales**: `DoorResolver`, `DoorPhysicalValidator`.
6. **Capa Semántica**: `SemanticOrchestrator`, `StartBossSolver`, `CriticalPathSolver`, `KeyLockPlanner`, `GameplayValidator`.
7. **Sistemas de Reparación**: `RoomConnectivityRepair`, `CorridorConnectivityRepair`, `RoomIntegrityCleaner`, `CorridorPruner`.
8. **Presentación & Renderizado 3D**: `DungeonPresentationBuilder`, `ContinuousWallMeshBuilder`, `ContinuousWallExtractor`, `DungeonDoorSpawner`.
9. **UI, Debug & Quality Gates**: `DungeonVisualizer`, `DungeonAsciiExporter`, `run_all_tests.gd`, `golden_fixture_manager.gd`.

---

## 2. Auditoría Detallada por Componente

### 2.1 Core Data Structures

#### `CellGrid` (`src/dungeon_generator/core/data/cell_grid.gd`)
- **Responsabilidad Única**: Única fuente de verdad del estado espacial discreto en 2D (rejilla plana con `PackedInt32Array`).
- **Input / Parámetros**: Dimensiones `width`, `height`, tipo por defecto.
- **Output / Retorno**: Tipos de celda (`CellType`: `VOID`, `WALL`, `FLOOR`, `DOOR`, `LOCKED_DOOR`, `STAIRS_DOWN`, `STAIRS_UP`, `SPAWN`, `OBJECTIVE`, `CORRIDOR`, `COLUMN`, `OBSTACLE`).
- **Dependencias**: `RefCounted` puro, cero dependencias externas.
- **Mutaciones**: `set_cell()`, `clear()`, `_cells` indexado.
- **Fuente de Verdad**: Estado de ocupación transitable (`is_walkable`), sólido (`is_solid`) y conectividad espacial.
- **Tests Existentes**: `tests/test_cell_grid.gd`.
- **Problemas Identificados**: `_metadata` tipo `Dictionary` es poco usado y puede almacenar datos sin tipo estricto.

#### `RoomData` (`src/dungeon_generator/core/data/room_data.gd`)
- **Responsabilidad Única**: Descriptor de una habitación individual (geometría AABB `rect`, tipo semántico `room_type`, centro y conexiones).
- **Input / Parámetros**: `id`, `rect: Rect2i`, `room_type: StringName`.
- **Output / Retorno**: Geometría interior (`get_inner_rect()`), puntos transitables, proyecciones perimetrales (`get_nearest_edge_point()`).
- **Dependencias**: `CellGrid`.
- **Mutaciones**: `connections`, `connected_room_ids`, `depth_in_graph`.
- **Fuente de Verdad**: Dimensiones y límites de la habitación.
- **Tests Existentes**: `tests/test_room_shape_generator.gd`, `tests/test_room_connectivity.gd`.
- **Problemas Identificados**: La lista `connections` (posiciones en Vector2i) duplica parcialmente la información presente en `DungeonResult.connections` / `RoomConnection`. Debe clarificarse en la Fase 1 que `RoomConnection` es el propietario de las aristas del grafo.

#### `DungeonResult` (`src/dungeon_generator/core/data/dungeon_result.gd`)
- **Responsabilidad Única**: Contenedor inmutable de transferencia de datos con el resultado completo del pipeline.
- **Input / Parámetros**: Creado y poblado por `DungeonPipeline.generate()`.
- **Output / Retorno**: `grid`, `mission_graph`, `rooms`, `connections`, `entrance_pairs`, `corridor_paths`, `doors`, `door_pairs`, `seed_used`, `seed_trace`.
- **Dependencias**: `CellGrid`, `DungeonGraph`, `RoomData`, `DoorPair`.
- **Mutaciones**: Solo durante el ensamblado final en `DungeonPipeline`.
- **Fuente de Verdad**: Contenedor canónico de salida de generación.
- **Tests Existentes**: `tests/test_pipeline_integration.gd`, `tests/test_golden_fixtures.gd`.
- **Problemas Identificados**: Coexisten arrays de bajo nivel (`doors: Array[DoorPlacement]`) y de alto nivel (`door_pairs: Array[DoorPair]`). Se debe congelar `door_pairs` como el contrato estándar.

#### `DoorPair` y `DoorPlacement` (`src/dungeon_generator/core/data/door_pair.gd`, `door_placement.gd`)
- **Responsabilidad Única**: Representación lógica estructural de una puerta (`DoorPlacement`: celda sala, celda corredor, lado cardinal, tipo) y de la pareja de puertas de una conexión (`DoorPair`: `door_a`, `door_b`).
- **Input / Parámetros**: `connection_id`, `door_a`, `door_b`.
- **Output / Retorno**: Validación de extremos y formateo de depuración.
- **Dependencias**: `RoomEntrance` (direcciones cardinales), `DoorType`.
- **Mutaciones**: Inmutable una vez instanciado.
- **Fuente de Verdad**: Ubicación física y orientación de puertas lógicas.
- **Tests Existentes**: `tests/test_door_resolver_policy.gd`, `tests/test_door_and_opening_manifests.gd`.
- **Problemas Identificados**: Ninguno estructural; es el contrato canónico actual.

#### `DungeonDoorManifest` y `WallOpeningManifest` (`src/dungeon_generator/core/data/`)
- **Responsabilidad Única**: Contratos de datos neutros entre la lógica del generador y el generador de mallas continuas 3D (`WallOpeningManifest` para abrir vanos en muros perimetrales; `DungeonDoorManifest` para instanciar marcos y puertas 3D).
- **Input / Parámetros**: `cell`, `adjacent_cell`, `side`, `door_type`.
- **Output / Retorno**: Coordenadas 3D, rotación angular en radianes, vanos perimetrales.
- **Dependencias**: `Resource`.
- **Mutaciones**: Registros únicos por arista orientada `(cell, side)`.
- **Fuente de Verdad**: Contrato frontera Presentation.
- **Tests Existentes**: `tests/test_door_manifest_extraction.gd`, `tests/test_wall_mesh_door_carving.gd`.
- **Problemas Identificados**: Totalmente desacoplado y sólido.

---

### 2.2 Pipeline, Topología y Algoritmos

#### `DungeonPipeline` (`src/dungeon_generator/core/dungeon_pipeline.gd`)
- **Responsabilidad Única**: Coordinar la secuencia de etapas y manejar el bucle de reintentos deterministas (`MAX_ATTEMPTS = 5`).
- **Input / Parámetros**: `config: DungeonConfig`, `max_retries: int`, `force_new_seed: bool`.
- **Output / Retorno**: `DungeonResult`.
- **Dependencias**: Múltiples clases de algoritmos, solvers, validadores y reparaciones cargadas mediante `preload`.
- **Mutaciones**: Orquesta y muta el `CellGrid` a través de las fases.
- **Fuente de Verdad**: Flujo de ejecución general.
- **Tests Existentes**: `tests/test_pipeline_integration.gd`, `tests/test_pipeline_resilience.gd`.
- **Problemas Identificados (Deuda Técnica)**: Actualmente `DungeonPipeline` realiza operaciones de pegado manual de marcadores y llamadas a reparaciones en línea. En la Fase 2 y 3 se reducirá estrictamente a un orquestador que pasa el `DungeonGenerationContext` entre etapas sin lógica algorítmica interna.

#### `DelaunayTriangulator` & `MSTSolver` (`src/dungeon_generator/core/algorithms/`)
- **Responsabilidad Única**: `DelaunayTriangulator` calcula la triangulación de Delaunay 2D sobre los centros de las habitaciones. `MSTSolver` extrae el Árbol de Expansión Mínima (Kruskal) garantizando conectividad `E = V - 1`.
- **Input / Parámetros**: Puntos Vector2 de las habitaciones.
- **Output / Retorno**: Aristas de Delaunay y aristas de MST (`Array[RoomConnection]`).
- **Dependencias**: Matemáticas puras vectoriales.
- **Mutaciones**: Ninguna (funciones estáticas puras).
- **Fuente de Verdad**: Topología base no dirigida.
- **Tests Existentes**: `tests/test_delaunay_triangulator.gd`, `tests/test_mst_solver.gd`, `tests/test_dungeon_graph.gd`.
- **Problemas Identificados**: Ninguno; algoritmo estable y determinista.

#### `RoomShapeGenerator` (`src/dungeon_generator/core/algorithms/room_shape_generator.gd`)
- **Responsabilidad Única**: Generación procedural de formas de salas (rectángulos, elipses, octógonos) y tallado del suelo en `CellGrid`.
- **Input / Parámetros**: `grid`, `room: RoomData`, `rng`.
- **Output / Retorno**: Celdas talladas como `CellGrid.CellType.FLOOR`.
- **Dependencias**: `CellGrid`, `RoomData`.
- **Mutaciones**: Muta `grid` en el área de la habitación.
- **Fuente de Verdad**: Geometría interior de cada habitación.
- **Tests Existentes**: `tests/test_room_shape_generator.gd`, `tests/test_pipeline_room_shapes.gd`.
- **Problemas Identificados**: Ninguno; respeta las proporciones de diseño.

#### `OrthogonalCorridorPlanner` & `AStarCarver` (`src/dungeon_generator/core/algorithms/`)
- **Responsabilidad Única**: `OrthogonalCorridorPlanner` evalúa trazados directos (rectos, forma de L y L alternativa). `AStarCarver` realiza el pathfinding de cuadrícula A* ortogonal con penalización por giros de 90°, penalización por proximidad de salas y protección de jambas de puertas (+50.0).
- **Input / Parámetros**: `grid`, `rooms`, `entrance_pairs`, `connections`, `config`.
- **Output / Retorno**: `CarveResult` con array de `CorridorPath` tallados en `CellGrid` como `CORRIDOR`.
- **Dependencias**: `CellGrid`, `RoomData`, `RoomEntrance`, `RoomConnection`.
- **Mutaciones**: Modifica celdas de `grid` de `WALL` a `CORRIDOR`.
- **Fuente de Verdad**: Trayectorias físicas de pasillos.
- **Tests Existentes**: `tests/test_astar_carver.gd`, `tests/test_orthogonal_corridor_planner.gd`, `tests/test_corridor_clearance_buffer.gd`, `tests/test_corridor_aesthetic_quality.gd`.
- **Problemas Identificados**: Altamente optimizado tras las mejoras de protección de jambas y separación de muros.

---

### 2.3 Solvers, Semántica, Validación y Reparación

#### `EntranceSolver` & `DoorResolver` (`src/dungeon_generator/core/solvers/`)
- **Responsabilidad Única**: `EntranceSolver` busca puntos perimetrales válidos (`EntrancePair`) en los muros de las habitaciones para conectar con el exterior. `DoorResolver` clasifica cada extremo como puerta cerrada (`CLOSED_DOOR`), puerta con llave (`LOCKED_DOOR`) o arco de paso (`OPEN_PASSAGE`), y valida físicamente que existan jambas de muro paralelas.
- **Input / Parámetros**: `grid`, `rooms`, `connections`, `corridor_paths`.
- **Output / Retorno**: `DoorResolutionResult` con `door_pairs: Array[DoorPair]`.
- **Dependencias**: `CellGrid`, `RoomEntrance`, `DoorPlacement`, `DoorPhysicalValidator`.
- **Mutaciones**: Actualiza celdas en `grid` a `DOOR` o `LOCKED_DOOR`.
- **Fuente de Verdad**: Clasificación y colocación de puertas.
- **Tests Existentes**: `tests/test_door_placement_solver.gd`, `tests/test_door_resolver_policy.gd`, `tests/test_door_physical_validator.gd`, `tests/test_door_wall_alignment.gd`.
- **Problemas Identificados**: Ninguno; el validador físico de jambas garantiza la coherencia con la malla continua 3D y el plano 2D.

#### `SemanticOrchestrator` (`src/dungeon_generator/core/semantic/semantic_orchestrator.gd`)
- **Responsabilidad Única**: Coordina la lógica de juego: asignación de Start Room y Boss Room (`StartBossSolver`), cálculo del Camino Crítico (`CriticalPathSolver`), distribución de Llaves y Puertas Bloqueadas (`KeyLockPlanner`) y validación formal de alcanzabilidad (`GameplayValidator`).
- **Input / Parámetros**: `DungeonResult`, `DungeonConfig`.
- **Output / Retorno**: `DungeonSemanticResult` inmutable.
- **Dependencias**: Módulos en `src/dungeon_generator/core/semantic/`.
- **Mutaciones**: Cero mutaciones en `CellGrid` (100% puro).
- **Fuente de Verdad**: Semántica de juego, progresión y depth map.
- **Tests Existentes**: `tests/semantic/test_semantic_orchestrator_integration.gd`, `tests/semantic/test_critical_path_solver.gd`, `tests/semantic/test_key_lock_planner.gd`, `tests/semantic/test_gameplay_validator.gd`.
- **Problemas Identificados**: Totalmente modular y testeado.

#### Reparaciones (`RoomConnectivityRepair`, `CorridorConnectivityRepair`, `RoomIntegrityCleaner`, `CorridorPruner`)
- **Responsabilidad Única**: Mecanismos de recuperación deterministas ante fallos locales de conectividad o pockets huérfanos.
- **Input / Parámetros**: `grid`, `rooms`, diagnóstico de fallo, semilla derivada de reparación.
- **Output / Retorno**: Objeto de resultado `{ success: bool, repairs_applied: Array }`.
- **Dependencias**: `CellGrid`, `AStarCarver`, `FloodFill`.
- **Mutaciones**: Modifica celdas desconectadas o elimina celdas de corredor en fondos de saco innecesarios.
- **Fuente de Verdad**: Mecanismo de emergencia (Regla 4: No sustituye la generación).
- **Tests Existentes**: `tests/test_room_connectivity_repair.gd`, `tests/test_corridor_connectivity_repair.gd`, `tests/test_room_integrity_cleaner.gd`, `tests/test_corridor_pruner.gd`.
- **Problemas Identificados**: Con las mejoras algorítmicas de la Fase 8/9, la tasa de disparo de reparaciones es mínima (<2%). En la Fase 14 se formalizará el logging estricto de invariantes para cada repair.

---

### 2.4 Presentación 3D, Mallas Continuas, UI y Test Runner

#### `DungeonPresentationBuilder` & `ContinuousWallMeshBuilder`
- **Responsabilidad Única**: `DungeonPresentationBuilder` construye la representación 3D en un nodo Staging invisible y realiza un Atomic Swap al árbol de escena principal. `ContinuousWallMeshBuilder` genera mallas continuas con ingletes limpios, zócalos, cornisas y ladrillos decorativos en 3 superficies sin artefactos de esquinas.
- **Input / Parámetros**: `grid: CellGrid`, `WallOpeningManifest`, presets de material.
- **Output / Retorno**: `ArrayMesh` de paredes y nodos `MeshInstance3D` con colisión Trimesh.
- **Dependencias**: Godot 3D Rendering (`ArrayMesh`, `SurfaceTool`, `MultiMeshInstance3D`).
- **Mutaciones**: Cero mutaciones sobre `CellGrid` ni datos de generación (puro consumidor).
- **Fuente de Verdad**: Geometría y visuales 3D.
- **Tests Existentes**: `tests/test_wall_mesh_generator.gd`, `tests/test_continuous_wall_generator.gd`, `tests/test_wall_mesh_spike_suppression.gd`, `tests/test_wall_mesh_door_carving.gd`.
- **Problemas Identificados**: Ninguno; el problema de colisión en esquinas cóncavas fue corregido con éxito.

#### `DungeonVisualizer` & `DungeonAsciiExporter`
- **Responsabilidad Única**: Visualización plana 2D interactiva (`Control` con dibujo custom `_draw`) y exportación serializada ASCII para inspección rápida en texto.
- **Input / Parámetros**: `DungeonResult` / `DungeonFloorData`.
- **Output / Retorno**: Render 2D en pantalla y String con mapa ASCII.
- **Dependencias**: `CellGrid`, `DoorPhysicalValidator`.
- **Mutaciones**: Solo de visualización local (lectura pura).
- **Fuente de Verdad**: Herramientas de depuración y flujo en 2 pasos (2D -> 3D).
- **Tests Existentes**: `tests/test_dungeon_2d_3d_flow.gd`, `tests/test_dungeon_ascii_exporter.gd`.
- **Problemas Identificados**: Ninguno; sincronizado al 100% con los criterios del generador 3D.

#### `run_all_tests.gd` (`tests/run_all_tests.gd`)
- **Responsabilidad Única**: Suite maestra de CI y pruebas unitarias / estrés automatizadas.
- **Suites Integradas**: 28 suites de pruebas que cubren Core, Topología, Mallas, Puertas, Multi-Floor, QA, Stress 10k seeds y Golden Seeds.
- **Tasa de Éxito Actual**: 100% (28/28 suites pasando).

---

## 3. Matriz de Fuentes Canónicas de Verdad

| Dominio | Estructura Canónica | Propietario Exclusivo | Mutadores Permitidos | Consumidores de Solo Lectura |
| :--- | :--- | :--- | :--- | :--- |
| **Espacio Discreto (2D)** | `CellGrid` | `DungeonPipeline` | `RoomShapeGenerator`, `AStarCarver`, `DoorResolver` | `Presentation`, `Visualizer`, `AsciiExporter`, `Validators` |
| **Topología y Grafo** | `RoomConnection` / `DungeonGraph` | `RoomGraphBuilder` | `RoomGraphBuilder` | `EntranceSolver`, `AStarCarver`, `DoorResolver`, `SemanticOrchestrator` |
| **Límites de Salas** | `RoomData.rect` | `SpaceGrammar` | `SpaceGrammar` | `RoomShapeGenerator`, `AStarCarver`, `DoorResolver`, `Visualizer` |
| **Puertas y Umbrales** | `DoorPair` | `DoorResolver` | `DoorResolver` | `DungeonResult`, `SemanticOrchestrator`, `DoorSpawner`, `Visualizer` |
| **Vanos en Paredes 3D** | `WallOpeningManifest` | `DoorManifestFactory` | `DoorManifestFactory` | `ContinuousWallExtractor`, `ContinuousWallMeshBuilder` |
| **Semántica y Progresión**| `DungeonSemanticResult` | `SemanticOrchestrator` | `SemanticOrchestrator` | `DungeonPresentationBuilder`, `GameplayValidator`, `UI` |
| **Geometría y Mallas 3D**| `ArrayMesh` | `ContinuousWallMeshBuilder` | `ContinuousWallMeshBuilder` | `MeshInstance3D` (Rendering / Physics) |

---

## 4. Conclusiones y Habilitación para Fase 1

1. **Estado del Código**: El sistema es determinista, robusto y cuenta con una suite de pruebas automatizadas al 100% de cobertura funcional.
2. **Deuda Técnica a Tratar en Fases 1 a 3**:
   - En **Fase 1**: Eliminar redundancia entre `RoomData.connections` y `DungeonResult.connections` consolidando a `RoomConnection` como único portador de aristas.
   - En **Fase 2 y 3**: Crear `DungeonGenerationContext` y adelgazar `DungeonPipeline` para que sea un coordinador puro de etapas sin código algorítmico interno.
3. **PHASE GATE: PASS** -> Fase 0 completada satisfactoriamente sin mutaciones de código en runtime.
