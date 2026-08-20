# Floor Tile Generator Module (Procedural Presentation Floor Geometry) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar el módulo desacoplado `src/floor_tile_generator/` para generar geometría procedural de baldosas de piedra estilizadas en clusters por regiones conectadas consumiendo exclusivamente `CellGrid` en modo lectura, integrándolo limpiamente en `DungeonPresentationBuilder` antes de las paredes sin mutar el Core lógico ni romper el atomic swap.

**Architecture:** 
El módulo sigue un flujo de tubería geométrica análogo a `geometry_generator`:
1. `FloorRegionExtractor`: Detecta regiones conexas de celdas transitables (`is_walkable`) mediante flood-fill determinista.
2. `FloorTileMeshBuilder`: Genera la geometría 3D detallada (losas entrelazadas con biseles a 45°, micro-variaciones de cota y colores de vértice para PBR, y base de mortero) para cada conjunto de celdas.
3. `FloorCollisionBuilder`: Genera formas de colisión físicas simplificadas y eficientes (placas de caja por cluster/región, evitando `CONCAVE_TRIMESH` por baldosa).
4. `FloorTileClusterBuilder`: Ensambla `ArrayMesh`, colisiones y metadatos en objetos `GeneratedFloorCluster`.
5. `DungeonFloorTileGenerator` (Fachada): Orquesta la extracción y materialización devolviendo un `FloorTileResult` desacoplado.
6. `DungeonPresentationBuilder`: Materializa los nodos visuales y físicos `FloorCluster` en el `StagingRoot` antes de generar las paredes, manteniendo coexistencia con `FloorGridMap` y swap atómico 100% seguro.

**Tech Stack:** Godot 4.x, GDScript 2.0 (`RefCounted`, `Node3D`, `MeshInstance3D`, `StaticBody3D`, `CollisionShape3D`, `BoxShape3D`, `ArrayMesh`, `SurfaceTool`, `AABB`).

**Spec:** Especificación de arquitectura y diseño para generación de suelo modular (`src/floor_tile_generator/`) en la rama `floor-tiled-generator`.

---

## Global Constraints

- **Zero Core Mutations:** `CellGrid`, `RoomData`, `DungeonConfig` y el modelo lógico de la mazmorra no deben ser mutados en ninguna circunstancia.
- **Pure Functional Facade:** La entrada primaria de generación es `CellGrid` + `FloorTileConfig` + `seed`.
- **Clustered Meshes (No 1000 Node3D):** No crear un `MeshInstance3D` ni un `StaticBody3D` por baldosa; generar clusters optimizados por región continua.
- **Physical Collision Decoupling:** La geometría visual es detallada e irregular; la colisión física es plana/caja simplificada para garantizar desplazamiento suave del jugador.
- **No Agent Execution of Godot Tests:** El agente no ejecutará directamente comandos de terminal de Godot si el entorno no lo soporta; generará y formateará los comandos exactos para el usuario.
- **Backward Compatibility:** Todas las suites existentes (`test_fase_9_horizontal_integration.gd`, `test_fase_10_vertical_integration.gd`, `test_presentation_atomic_swap.gd`, `test_continuous_wall_generator.gd`) deben mantenerse al 100% de aprobación.

---

## File Structure & Responsibilities

```text
src/floor_tile_generator/
├── config/
│   └── floor_tile_config.gd         # Configuración exportable (tile_size, margin, bevel, jitter, collision_mode, preset)
├── data/
│   ├── floor_tile_result.gd         # DTO con lista de GeneratedFloorCluster, estadísticas y diagnósticos
│   └── generated_floor_cluster.gd   # Representación de un cluster (ArrayMesh, CollisionShapes, Transform3D, AABB, región)
├── extraction/
│   └── floor_region_extractor.gd    # Extractor de componentes conexas transitables desde CellGrid
├── geometry/
│   ├── floor_tile_mesh_builder.gd   # Generador de geometría SurfaceTool (losas biseladas + mortero continuo)
│   └── floor_tile_cluster_builder.gd# Ensamblador de GeneratedFloorCluster por región
├── collision/
│   └── floor_collision_builder.gd   # Generador de cajas de colisión física por región
└── facade/
    └── dungeon_floor_tile_generator.gd # Fachada central de alto nivel (generate_floor_clusters, generate_and_attach_floor_nodes)

src/dungeon_generator/presentation/
└── dungeon_presentation_builder.gd  # Integración de la capa de suelo generada en StagingRoot

tests/
├── test_floor_tile_contracts.gd              # Validar creación y serialización de configs y DTOs
├── test_floor_region_extractor.gd            # Validar flood fill, habitaciones desconectadas, corredores, salas L/U
├── test_floor_tile_mesh_builder.gd           # Validar topología de malla, 2 superficies (Slabs/Mortar), UVs y normales
├── test_floor_tile_cluster_builder.gd        # Validar empaquetado de cluster, bounding box y collision shapes
├── test_floor_tile_generator_facade.gd       # Validar determinismo con seeds y generación end-to-end
└── test_floor_tile_presentation_integration.gd # Validar integración en DungeonPresentationBuilder y Atomic Swap
```

---

## Tasks

### Task 1: Contratos de Datos y Configuración (`FloorTileConfig`, `FloorTileResult`, `GeneratedFloorCluster`)

**Files:**
- Create: `src/floor_tile_generator/config/floor_tile_config.gd`
- Create: `src/floor_tile_generator/data/generated_floor_cluster.gd`
- Create: `src/floor_tile_generator/data/floor_tile_result.gd`
- Test: `tests/test_floor_tile_contracts.gd`

**Interfaces:**
- Consumes: Tipos base de Godot (`Resource`, `RefCounted`, `ArrayMesh`, `Shape3D`, `Transform3D`, `AABB`)
- Produces: `FloorTileConfig` con enum `CollisionMode`, `GeneratedFloorCluster` con métodos `to_mesh_instance()` y `create_collision_body()`, `FloorTileResult` con colecciones de clusters y diagnósticos.

- [x] **Step 1: Escribir la prueba unitaria de contratos de datos (`tests/test_floor_tile_contracts.gd`)**
- [x] **Step 2: Implementar `FloorTileConfig` (`src/floor_tile_generator/config/floor_tile_config.gd`)**
- [x] **Step 3: Implementar `GeneratedFloorCluster` (`src/floor_tile_generator/data/generated_floor_cluster.gd`)**
- [x] **Step 4: Implementar `FloorTileResult` (`src/floor_tile_generator/data/floor_tile_result.gd`)**
- [x] **Step 5: Indicar comando para verificar que la prueba pasa:**
  `godot --headless -s res://tests/test_floor_tile_contracts.gd`

---

### Task 2: Extractor de Regiones Conexas (`FloorRegionExtractor`)

**Files:**
- Create: `src/floor_tile_generator/extraction/floor_region_extractor.gd`
- Test: `tests/test_floor_region_extractor.gd`

**Interfaces:**
- Consumes: `CellGrid` (`is_walkable`, `width`, `height`, `get_cell`)
- Produces: `Array[Array[Vector2i]]` (lista de regiones conexas de celdas de suelo transitables)

- [x] **Step 1: Escribir la prueba unitaria de extracción de regiones (`tests/test_floor_region_extractor.gd`)**
  - Probar grid vacío, grid con sala única rectangular, grid con sala en L, grid con dos salas separadas por pared, grid con sala conectada por corredor.
- [x] **Step 2: Implementar `FloorRegionExtractor` con flood-fill determinista de 4 vecinos transitables**
- [x] **Step 3: Indicar comando para verificar que la prueba pasa:**
  `godot --headless -s res://tests/test_floor_region_extractor.gd`

---

### Task 3: Constructor de Malla Geométrica de Baldosas (`FloorTileMeshBuilder`)

**Files:**
- Create: `src/floor_tile_generator/geometry/floor_tile_mesh_builder.gd`
- Test: `tests/test_floor_tile_mesh_builder.gd`

**Interfaces:**
- Consumes: `Array[Vector2i]` (celdas de la región), `FloorTileConfig`, `seed: int`
- Produces: `ArrayMesh` con 2 superficies ("FloorSlabs" y "FloorMortar"), normales válidas, colores de vértice deterministas y UVs.

- [x] **Step 1: Escribir la prueba unitaria del constructor de malla (`tests/test_floor_tile_mesh_builder.gd`)**
  - Validar generación de mallas sin degenerate triangles, AABB coherente con el área de celdas, existencia de ambas superficies de material, y determinismo con la misma semilla.
- [x] **Step 2: Implementar `FloorTileMeshBuilder` construyendo losas entrelazadas biseladas y base continua de mortero por región**
- [x] **Step 3: Indicar comando para verificar que la prueba pasa:**
  `godot --headless -s res://tests/test_floor_tile_mesh_builder.gd`

---

### Task 4: Constructor de Colisiones Físicas y de Clusters (`FloorCollisionBuilder` & `FloorTileClusterBuilder`)

**Files:**
- Create: `src/floor_tile_generator/collision/floor_collision_builder.gd`
- Create: `src/floor_tile_generator/geometry/floor_tile_cluster_builder.gd`
- Test: `tests/test_floor_tile_cluster_builder.gd`

**Interfaces:**
- Consumes: Celdas de región `Array[Vector2i]`, `ArrayMesh`, `FloorTileConfig`
- Produces: `GeneratedFloorCluster` conteniendo `ArrayMesh`, `BoxShape3D` optimizadas para colisión física, transforms y AABB.

- [x] **Step 1: Escribir la prueba unitaria del builder de colisión y cluster (`tests/test_floor_tile_cluster_builder.gd`)**
  - Validar que genera `BoxShape3D` con la cobertura correcta para la región y que `create_collision_body()` devuelve un `StaticBody3D` con las formas físicas configuradas.
- [x] **Step 2: Implementar `FloorCollisionBuilder` generando cajas físicas simplificadas por rectángulos continuos de la región**
- [x] **Step 3: Implementar `FloorTileClusterBuilder` orquestando la malla y la colisión en `GeneratedFloorCluster`**
- [x] **Step 4: Indicar comando para verificar que la prueba pasa:**
  `godot --headless -s res://tests/test_floor_tile_cluster_builder.gd`

---

### Task 5: Fachada Central Unificada (`DungeonFloorTileGenerator`)

**Files:**
- Create: `src/floor_tile_generator/facade/dungeon_floor_tile_generator.gd`
- Test: `tests/test_floor_tile_generator_facade.gd`

**Interfaces:**
- Consumes: `grid: CellGrid`, `config: FloorTileConfig`, `seed: int`
- Produces: `FloorTileResult` con lista de `GeneratedFloorCluster` y método `generate_and_attach_floor_nodes(grid, parent_node, config, seed) -> Array[MeshInstance3D]`

- [x] **Step 1: Escribir la prueba unitaria de la fachada (`tests/test_floor_tile_generator_facade.gd`)**
  - Probar `generate_floor_clusters()`, validar determinismo idéntico en ejecuciones con misma semilla, validar manejo seguro de null inputs y diagnósticos.
- [x] **Step 2: Implementar `DungeonFloorTileGenerator` orquestando Extractor -> MeshBuilder -> CollisionBuilder -> ClusterBuilder**
- [x] **Step 3: Indicar comando para verificar que la prueba pasa:**
  `godot --headless -s res://tests/test_floor_tile_generator_facade.gd`

---

### Task 6: Integración en `DungeonPresentationBuilder` y Verificación Horizontal

**Files:**
- Modify: `src/dungeon_generator/presentation/dungeon_presentation_builder.gd` (incorporar generación de `FloorClusters` en `build_presentation`, `build_multi_floor_presentation` y `build_from_dungeon_result`)
- Create: `tests/test_floor_tile_presentation_integration.gd`
- Test: `tests/test_fase_9_horizontal_integration.gd`
- Test: `tests/test_fase_10_vertical_integration.gd`
- Test: `tests/test_presentation_atomic_swap.gd`

**Interfaces:**
- Consumes: `semantic_result.grid` / `dungeon_result.grid`, `BiomeProfile`, `DungeonConfig`
- Produces: Nodo `FloorTiles` en el árbol de staging conteniendo los `MeshInstance3D` y colisiones físicas antes de las paredes.

- [x] **Step 1: Escribir la prueba unitaria de integración de presentación (`tests/test_floor_tile_presentation_integration.gd`)**
  - Verificar presencia de nodos de suelo generados en `DungeonPresentation`, orden de instanciación respecto a paredes y colisiones funcionales.
- [x] **Step 2: Actualizar `DungeonPresentationBuilder` para instanciar el suelo procedural mediante `DungeonFloorTileGenerator`**
- [x] **Step 3: Indicar comandos para validar la suite completa de integración y regresión:**
  1. `godot --headless -s res://tests/test_floor_tile_presentation_integration.gd`
  2. `godot --headless -s res://tests/test_fase_9_horizontal_integration.gd`
  3. `godot --headless -s res://tests/test_fase_10_vertical_integration.gd`
  4. `godot --headless -s res://tests/test_presentation_atomic_swap.gd`
  2. `godot --headless -s res://tests/test_fase_9_horizontal_integration.gd`
  3. `godot --headless -s res://tests/test_fase_10_vertical_integration.gd`
  4. `godot --headless -s res://tests/test_presentation_atomic_swap.gd`
