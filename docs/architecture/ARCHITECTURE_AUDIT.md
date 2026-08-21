# Auditoría y Registro Arquitectónico del Dungeon Generator & Presentation

> **Documento Canónico de Arquitectura, Contratos y Estado del Sistema**
> **Fecha de Actualización:** 2026-08-20
> **Estado:** Fases 1 a 16 Completadas — Módulos Core, Geometría Continua, Suelos Estocásticos, Iluminación Procedural y Cámara Isométrica con Oclusión Fina.

---

## 1. Resumen Ejecutivo y Mapa General del Sistema

El proyecto `dungeon-divers` está construido bajo una estricta separación de responsabilidades y capas unidireccionales:

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                            1. CORE LOGICAL DATA                             │
│  CellGrid (2D) ──► RoomData ──► DungeonResult ──► DungeonSemanticResult     │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
┌──────────────────────────────────────▼──────────────────────────────────────┐
│                    2. PIPELINE, TOPOLOGÍA & SEMÁNTICA                       │
│  Delaunay/MST ──► AStarCarver ──► DoorResolver ──► SemanticOrchestrator     │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
┌──────────────────────────────────────▼──────────────────────────────────────┐
│                   3. GENERADORES GEOMÉTRICOS Y PRESENTACIÓN                 │
│  • ContinuousWallMeshBuilder (Mallas de Muro, Zócalos, Cornisas, Bricks)    │
│  • FloorSurfaceMeshBuilder   (Suelos Estocásticos, Biseles, Ruido de Altura)│
│  • DungeonLightingGenerator  (Planners de Luz, Antorchas en Paredes, Flicker)│
│  • DungeonPresentationBuilder (Staging Desacoplado & Atomic Swap)           │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
┌──────────────────────────────────────▼──────────────────────────────────────┐
│                    4. MÓDULO DE CÁMARA ISOMÉTRICA & VIEW                    │
│  IsometricCameraRig ──► OcclusionDetector ──► Resolver ──► WallFadeController│
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Auditoría Detallada por Componente y Módulo

### 2.1 Core Data & Topología Lógica

#### `CellGrid` (`src/dungeon_generator/core/data/cell_grid.gd`)
- **Responsabilidad**: Única fuente de verdad del estado espacial discreto en 2D (rejilla plana indexada con `PackedInt32Array`).
- **Inmutabilidad en Presentación**: Cero mutaciones fuera del pipeline generativo.
- **Tipos de Celda**: `VOID`, `WALL`, `FLOOR`, `DOOR`, `LOCKED_DOOR`, `STAIRS_DOWN`, `STAIRS_UP`, `SPAWN`, `OBJECTIVE`, `CORRIDOR`, `COLUMN`, `OBSTACLE`.

#### `SemanticOrchestrator` (`src/dungeon_generator/core/semantic/semantic_orchestrator.gd`)
- **Responsabilidad**: Determina la progresión de gameplay sin mutar el mapa físico: Start/Boss, Camino Crítico (`CriticalPathSolver`), asignación de llaves/cerraduras (`KeyLockPlanner`) y validación formal de alcanzabilidad (`GameplayValidator`).

---

### 2.2 Generación Procedural de Superficies y Geometría 3D

#### `ContinuousWallMeshBuilder` (`src/wall_mesh_generator/core/continuous_wall_mesh_builder.gd`)
- **Responsabilidad**: Genera mallas 3D continuas con ingletes automáticos, vanos perimetrales (`WallOpeningManifest`), zócalos inferiores, cornisas superiores y ladrillos decorativos en relieve.
- **Etiquetado Semántico**: Registra los muros y sus cuerpos de colisión en el grupo `camera_occluder` (`const CAMERA_OCCLUDER_GROUP = &"camera_occluder"`).

#### `FloorSurfaceMeshBuilder` & `DungeonFloorSpawner` (`src/floor_tile_generator/`)
- **Responsabilidad**: Generación estocástica de baldosas de suelo (`FloorTileConfig` con patrones `GRID`, `HERRINGBONE`, `RUNNING_BOND`, `CHECKERBOARD`, `HEXAGONAL`).
- **Características**: Modulación de altura por ruido perlin/simplex, biseles en esquinas y soporte para modo de colisión optimizado (`COMPOUND_BOX` o `TRIMESH`).

---

### 2.3 Iluminación Procedural 3D & Entorno Atmosférico

#### `DungeonLightingGenerator` & `DungeonLightSpawner` (`src/dungeon_lighting/`)
- **Responsabilidad**: Planificación e instanciación determinista de fuentes de luz cálidas y atmosféricas.
- **Componentes**:
  - `WallLightCandidateFinder`: Detecta celdas de muro orientadas hacia áreas transitables para adosar antorchas.
  - `RoomLightPlanner` y `CorridorLightPlanner`: Distribución espacial controlada de antorchas según presupuesto y densidad.
  - `TorchLightController`: Control de parpadeo orgánico (*flicker*) mediante ruido continuo independiente por cada antorcha.
  - `LightingProfile` & UI en vivo: Edición en tiempo real de color, energía, atenuación, sombras, niebla volumétrica y luz ambiental desde `DungeonVisualizer`.

---

### 2.4 Módulo de Cámara Isométrica y Sistema de Oclusión Fina

#### `IsometricCameraRig` (`src/presentation/camera/isometric_camera_rig.gd`)
- **Responsabilidad**: Módulo de cámara independiente, desacoplado y reutilizable para cualquier escena o entidad de juego.
- **Orientación Isométrica Estricta**:
  - `ISOMETRIC_YAW = 45.0°`
  - `ISOMETRIC_PITCH = 35.2643897°` (Ángulo isométrico verdadero)
  - `ISOMETRIC_ROLL = 0.0°`
  - Proyección: `Camera3D.PROJECTION_ORTHOGONAL`
  - **Invariante**: La rotación de la cámara es inmune a giros, animaciones o traslaciones del objetivo (`PlayerTest`).
- **Seguimiento Cinemático (Smooth Follow)**:
  - Controlador proporcional amortiguado con `follow_speed`, `acceleration`, `deceleration` y `dead_zone`.
  - Método instantáneo `teleport_to_target()` para spawns o cambios de nivel.
- **Zoom Ortogonal Exponencial**:
  - Rango continuo entre `zoom_min` y `zoom_max` con suavizado independiente del framerate (`1.0 - exp(-zoom_smoothing * delta)`).

#### `CameraOcclusionDetector` (`src/presentation/camera/camera_occlusion_detector.gd`)
- **Responsabilidad**: Detección multi-rayo (cabeza/torso, centro, pies/base) entre la lente ortogonal y el objetivo.
- **Emisión Delta por Flanco**:
  - Emite `occlusion_started(added_walls)` solo para los nuevos muros que entran en la línea de visión.
  - Emite `occlusion_ended(removed_walls)` solo para los muros liberados.

#### `OccluderResolver` (`src/presentation/camera/occluder_resolver.gd`)
- **Responsabilidad**: Mapea colliders físicos brutos (`StaticBody3D` / `CollisionShape3D`) hacia el nodo visual propietario de la geometría (`MeshInstance3D` o `GeometryInstance3D`) perteneciente al grupo `camera_occluder`.

#### `WallFadeController` (`src/presentation/camera/wall_fade_controller.gd`)
- **Responsabilidad**: Administra la transparencia individual de cada muro ocluyente mediante `GeometryInstance3D.transparency`.
- **Desvanecimiento Suave**:
  - Fade Out hacia `occluded_transparency = 0.75` al bloquear la visión.
  - Fade In hacia `transparency = 0.0` (opaco) al despejar la visión.
  - Sin uso de tweens repetitivos: interpolación continua mediante decaimiento exponencial.

---

## 3. Matriz de Fuentes Canónicas de Verdad

| Dominio | Estructura Canónica | Propietario Exclusivo | Mutadores Permitidos | Consumidores de Solo Lectura |
| :--- | :--- | :--- | :--- | :--- |
| **Espacio Discreto (2D)** | `CellGrid` | `DungeonPipeline` | `RoomShapeGenerator`, `AStarCarver`, `DoorResolver` | `Presentation`, `Visualizer`, `Validators`, `Lighting` |
| **Topología y Grafo** | `RoomConnection` / `DungeonGraph` | `RoomGraphBuilder` | `RoomGraphBuilder` | `EntranceSolver`, `AStarCarver`, `SemanticOrchestrator` |
| **Puertas y Umbrales** | `DoorPair` | `DoorResolver` | `DoorResolver` | `DungeonResult`, `SemanticOrchestrator`, `DoorSpawner` |
| **Vanos en Paredes 3D** | `WallOpeningManifest` | `DoorManifestFactory` | `DoorManifestFactory` | `ContinuousWallMeshBuilder` |
| **Semántica de Juego** | `DungeonSemanticResult` | `SemanticOrchestrator` | `SemanticOrchestrator` | `DungeonPresentationBuilder`, `GameplayValidator` |
| **Geometría de Muros 3D** | `ArrayMesh` | `ContinuousWallMeshBuilder` | `ContinuousWallMeshBuilder` | `MeshInstance3D` (Grupo `camera_occluder`) |
| **Geometría de Suelo 3D** | `ArrayMesh` | `FloorSurfaceMeshBuilder` | `FloorSurfaceMeshBuilder` | `DungeonFloorSpawner` |
| **Iluminación Procedural**| `DungeonLightingResult`| `DungeonLightingGenerator` | `DungeonLightingGenerator` | `DungeonLightSpawner`, `TorchLightController` |
| **Observación & Cámara** | `IsometricCameraRig` | `IsometricCameraRig` | `IsometricCameraRig` | `Camera3D`, `WallFadeController`, `OcclusionDetector` |

---

## 4. Estado de la Suite de Pruebas Automatizadas

El sistema cuenta con una cobertura del 100% en modo headless estructurada en suites especializadas:

```text
SUITES DE TESTING (100% PASSING)
├── Core & Pipeline
│   ├── test_cell_grid.gd
│   ├── test_room_shape_generator.gd
│   ├── test_astar_carver.gd
│   ├── test_door_resolver_policy.gd
│   └── test_pipeline_integration.gd
├── Semantic & Gameplay
│   ├── test_semantic_orchestrator_integration.gd
│   ├── test_critical_path_solver.gd
│   └── test_key_lock_planner.gd
├── Geometry & Lighting
│   ├── test_lighting_contracts.gd
│   ├── test_wall_light_candidates.gd
│   ├── test_room_and_corridor_light_planners.gd
│   ├── test_lighting_determinism.gd
│   └── test_dungeon_lighting_spawner_e2e.gd
└── Camera & Occlusion Presentation
    ├── test_camera_contracts.gd
    ├── test_camera_smooth_follow.gd
    ├── test_camera_zoom.gd
    ├── test_camera_occlusion.gd
    ├── test_camera_integration_e2e.gd
    ├── test_camera_occluder_semantics.gd
    ├── test_camera_occluder_resolver.gd
    ├── test_wall_fade_controller.gd
    ├── test_camera_occlusion_physics.gd
    └── test_camera_isometric_rotation.gd
```

---

## 5. Conclusiones y Estado del Módulo de Presentación

1. **Desacoplamiento Total**: Ni la cámara ni la iluminación mutan ni dependen de la topología interna del generador. Consumen contratos puros (`Node3D`, `groups`, `GeometryInstance3D`).
2. **Invariantes Gráficas**: La orientación isométrica y la visibilidad del personaje están matemáticamente blindadas contra rotaciones o bloqueos de muros.
3. **Calidad de Presentación**: Transiciones suaves por decaimiento exponencial en zoom, seguimiento y desvanecimiento de paredes, eliminando tirones y popping visual.
