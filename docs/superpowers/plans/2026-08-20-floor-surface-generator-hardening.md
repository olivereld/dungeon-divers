# Floor Surface & Tile Generator Architecture (Fases M1-M8) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidar y refinar la arquitectura del subsistema de suelos procedurales en un flujo en capas limpio y extensible (M1 a M8), introduciendo descriptores de patrón de baldosas (`FloorTilePattern` / `TileDescriptor`), soporte de colisiones múltiples (`NONE`, `BOX`, `CONCAVE_TRIMESH`), separación estricta de generación de datos puros vs materialización geométrica, y un `DungeonFloorSpawner` desacoplado que evite convertir a `DungeonPresentationBuilder` en un God Object.

**Architecture:**
El pipeline de suelos se estructura en 3 capas desacopladas:
1. **Capa Lógica / Datos Puros (M1-M3):**
   - `FloorSurfaceExtractor`: Extrae regiones continuas y metadatos de habitaciones y corredores a partir de `CellGrid` / `DungeonSemanticResult`.
   - `FloorTilePattern`: Genera un catálogo de `TileDescriptor` con transformaciones locales, jitter, variantes de material (Stone, Cobblestone, Brick, Marble, Ruined) y cotas.
   - `FloorSurfaceResult`: DTO inmutable que contiene los clusters de descriptores y metadatos sin instanciar nodos 3D.
2. **Capa Geométrica y Física (M4-M5):**
   - `FloorSurfaceMeshBuilder`: Transforma descriptores de baldosas en `ArrayMesh` por cluster con superficies PBR optimizadas.
   - `FloorCollisionBuilder`: Construye las formas físicas (`BOX`, `COMPOUND_BOX`, `CONCAVE_TRIMESH`) según la configuración del biome.
3. **Capa de Presentación / Spawning (M6-M8):**
   - `DungeonFloorSpawner`: Spawner especializado (análogo a `DungeonDoorSpawner` y `DungeonEntitySpawner`) que materializa `MeshInstance3D` y `StaticBody3D` en `StagingRoot`.
   - `DungeonPresentationBuilder`: Coordinador de 2 líneas que delega la materialización sin acumular lógica de baldosas.

**Tech Stack:** Godot 4.x, GDScript 2.0 (`RefCounted`, `Resource`, `Node3D`, `MeshInstance3D`, `StaticBody3D`, `CollisionShape3D`, `BoxShape3D`, `ConcavePolygonShape3D`, `ArrayMesh`, `SurfaceTool`, `AABB`).

**Spec:** Auditoría técnica de arquitectura para `floor-tiled-generator` y roadmap de fases M1-M8.

---

## Global Constraints

- **No God Object in Presentation:** `DungeonPresentationBuilder` solo orquesta (`_floor_generator.generate(...)` y `_floor_spawner.spawn_floor(...)`).
- **Data vs Presentation Boundary:** M1, M2 y M3 producen datos puros (`FloorSurfaceResult`, `TileDescriptor`); no crean `Node3D`.
- **Zero Core Mutations:** `CellGrid`, `RoomData`, `DungeonSemanticResult` permanecen 100% inmutables y de solo lectura.
- **Support for Varied Patterns & Collision Modes:** Soporte para múltiples estilos de piedra/patrón y modos de colisión (`NONE`, `BOX`, `COMPOUND_BOX`, `CONCAVE_TRIMESH`).
- **Atomic Swap Guarantee:** Compatibilidad total con el staging desacoplado y swap atómico de `DungeonPresentationBuilder`.

---

## File Structure & Map

```text
src/floor_tile_generator/
├── config/
│   ├── floor_tile_config.gd         # Configuración con enum PatternType (STONE, COBBLE, BRICK, MARBLE) y CollisionMode
│   └── floor_material_profile.gd    # Configuración de materiales y presets visuales
├── data/
│   ├── tile_descriptor.gd           # DTO de baldosa individual (rect, height, bevel, tone, pattern_id, transform)
│   ├── floor_surface_cluster.gd     # DTO de cluster de región con lista de TileDescriptors y ArrayMesh
│   └── floor_surface_result.gd      # DTO contenedor de salida de la generación pura
├── extraction/
│   └── floor_surface_extractor.gd   # M1/M2: Extracción pura de superficies y agrupamiento por salas/pasillos
├── patterns/
│   └── floor_tile_pattern.gd        # M3: Generador de patrones y descriptores de losas
├── geometry/
│   └── floor_surface_mesh_builder.gd# M4: Construcción de ArrayMesh desde TileDescriptors
├── collision/
│   └── floor_collision_builder.gd   # M5: Construcción de colisiones (BOX, COMPOUND_BOX, CONCAVE_TRIMESH)
└── facade/
    └── dungeon_floor_generator.gd   # Fachada de datos puros que coordina M1-M5

src/dungeon_generator/presentation/
├── dungeon_floor_spawner.gd         # M6: Spawner especializado de nodos 3D para la presentación
└── dungeon_presentation_builder.gd  # Integración limpia de 2 líneas

tests/
├── test_floor_tile_patterns.gd              # M3: Validar teselado y generación de TileDescriptors
├── test_floor_surface_mesh_builder.gd       # M4: Validar generación de mallas PBR desde descriptores
├── test_floor_collision_modes.gd            # M5: Validar BOX, COMPOUND_BOX y CONCAVE_TRIMESH
├── test_floor_generator_determinism.gd      # M7: Validar determinismo con semillas y presets
└── test_dungeon_floor_spawner_e2e.gd        # M8: Validar integración E2E en Presentation y Atomic Swap
```

---

## Tasks

### Task 1: DTOs y Patrones de Baldosas (`TileDescriptor`, `FloorTilePattern`, `FloorTileConfig`) (M1-M3)

**Files:**
- Create: `src/floor_tile_generator/data/tile_descriptor.gd`
- Create: `src/floor_tile_generator/data/floor_surface_cluster.gd`
- Create: `src/floor_tile_generator/data/floor_surface_result.gd`
- Create: `src/floor_tile_generator/patterns/floor_tile_pattern.gd`
- Modify: `src/floor_tile_generator/config/floor_tile_config.gd`
- Test: `tests/test_floor_tile_patterns.gd`

**Interfaces:**
- Consumes: Tipos base de Godot (`Resource`, `RefCounted`, `Rect2`, `Vector2i`, `Transform3D`)
- Produces: `TileDescriptor` (posición, escala, cota, bisel, variación tonal, variante de material), `FloorTilePattern` con generadores para `STYLIZED_STONE`, `COBBLESTONE`, `BRICK`, `SMOOTH_SLAB`, y `FloorSurfaceResult`.

- [x] **Step 1: Escribir la prueba unitaria de patrones y descriptores (`tests/test_floor_tile_patterns.gd`)**
- [x] **Step 2: Implementar `TileDescriptor` (`src/floor_tile_generator/data/tile_descriptor.gd`)**
- [x] **Step 3: Implementar `FloorSurfaceCluster` y `FloorSurfaceResult` (`src/floor_tile_generator/data/`)**
- [x] **Step 4: Implementar `FloorTilePattern` (`src/floor_tile_generator/patterns/floor_tile_pattern.gd`) con múltiples estilos procedurales**
- [x] **Step 5: Actualizar `FloorTileConfig` con enum `PatternType`**
- [x] **Step 6: Indicar comando para verificar que la prueba pasa:**
  `godot --headless -s res://tests/test_floor_tile_patterns.gd`

---

### Task 2: Constructor de Mallas a partir de Descriptores (`FloorSurfaceMeshBuilder`) (M4)

**Files:**
- Create: `src/floor_tile_generator/geometry/floor_surface_mesh_builder.gd`
- Test: `tests/test_floor_surface_mesh_builder.gd`

**Interfaces:**
- Consumes: `FloorSurfaceCluster` conteniendo lista de `TileDescriptor`, `FloorTileConfig`, `seed: int`
- Produces: `ArrayMesh` de dos superficies PBR (`FloorSlabs` y `FloorMortar`) calculando biseles 3D, normales suavizadas, UVs y colores de vértice.

- [x] **Step 1: Escribir la prueba unitaria de construcción de mallas desde descriptores (`tests/test_floor_surface_mesh_builder.gd`)**
- [x] **Step 2: Implementar `FloorSurfaceMeshBuilder` procesando la lista de `TileDescriptor` de cada cluster**
- [x] **Step 3: Indicar comando para verificar que la prueba pasa:**
  `godot --headless -s res://tests/test_floor_surface_mesh_builder.gd`

---

### Task 3: Constructor de Colisiones Multimodo (`FloorCollisionBuilder`) (M5)

**Files:**
- Modify: `src/floor_tile_generator/collision/floor_collision_builder.gd`
- Test: `tests/test_floor_collision_modes.gd`

**Interfaces:**
- Consumes: `FloorSurfaceCluster`, `ArrayMesh`, `FloorTileConfig`
- Produces: Generación de formas físicas de colisión según modo: `NONE` (0 shapes), `BOX` (1 bounding box), `COMPOUND_BOX` (tiras contiguas RLE), `CONCAVE_TRIMESH` (`ConcavePolygonShape3D` derivado de los triángulos de la malla).

- [x] **Step 1: Escribir la prueba unitaria de modos de colisión (`tests/test_floor_collision_modes.gd`)**
- [x] **Step 2: Actualizar `FloorCollisionBuilder` para implementar `BOX`, `COMPOUND_BOX` y `CONCAVE_TRIMESH`**
- [x] **Step 3: Indicar comando para verificar que la prueba pasa:**
  `godot --headless -s res://tests/test_floor_collision_modes.gd`

---

### Task 4: Fachada de Datos Puros (`DungeonFloorGenerator`) (M1, M2, M7)

**Files:**
- Create: `src/floor_tile_generator/facade/dungeon_floor_generator.gd`
- Test: `tests/test_floor_generator_determinism.gd`

**Interfaces:**
- Consumes: `grid: CellGrid`, `config: FloorTileConfig`, `seed: int`, `room_data / corridors` (opcionales)
- Produces: `FloorSurfaceResult` inmutable conteniendo todos los clusters, mallas y colisiones calculadas (0 nodos 3D creados).

- [x] **Step 1: Escribir la prueba unitaria de determinismo y generación pura (`tests/test_floor_generator_determinism.gd`)**
- [x] **Step 2: Implementar `DungeonFloorGenerator` orquestando Extracción -> Patrones -> Malla -> Colisión**
- [x] **Step 3: Indicar comando para verificar que la prueba pasa:**
  `godot --headless -s res://tests/test_floor_generator_determinism.gd`

---

### Task 5: Spawner Desacoplado de Presentación (`DungeonFloorSpawner`) (M6, M8)

**Files:**
- Create: `src/dungeon_generator/presentation/dungeon_floor_spawner.gd`
- Modify: `src/dungeon_generator/presentation/dungeon_presentation_builder.gd`
- Test: `tests/test_dungeon_floor_spawner_e2e.gd`
- Test: `tests/test_fase_9_horizontal_integration.gd`
- Test: `tests/test_presentation_atomic_swap.gd`

**Interfaces:**
- Consumes: `FloorSurfaceResult`, `staging_root: Node3D`, `BiomeProfile`
- Produces: Instanciación limpia de `MeshInstance3D` y `StaticBody3D` bajo el nodo contenedor `FloorTiles` en staging.

- [x] **Step 1: Escribir la prueba unitaria E2E de spawning en presentación (`tests/test_dungeon_floor_spawner_e2e.gd`)**
- [x] **Step 2: Implementar `DungeonFloorSpawner` en `src/dungeon_generator/presentation/` (análogo a `DungeonDoorSpawner` y `DungeonEntitySpawner`)**
- [x] **Step 3: Refactorizar `DungeonPresentationBuilder` para delegar la materialización en `DungeonFloorSpawner` en 2 líneas**
- [x] **Step 4: Indicar comandos para validar la suite completa de integración y regresión:**
  1. `godot --headless -s res://tests/test_dungeon_floor_spawner_e2e.gd`
  2. `godot --headless -s res://tests/test_fase_9_horizontal_integration.gd`
  3. `godot --headless -s res://tests/test_presentation_atomic_swap.gd`
