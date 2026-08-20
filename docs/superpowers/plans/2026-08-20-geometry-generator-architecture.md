# Geometry Generator (Evolución de Wall Mesh Generator) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformar y desacoplar `src/wall_mesh_generator` en un sistema modular de generación geométrica 3D (`src/geometry_generator`) que separe extracción topológica de aristas (WallBoundaryGraph), generación de mallas continuas por clusters (GeneratedMesh), constructores de colisión independientes (CollisionBuilder) y decoradores superficiales (BrickDecorator/MaterialResolver).

**Architecture:** El sistema consume datos espaciales (como `CellGrid` y `WallOpeningManifest`), extrae un grafo explícito de aristas de frontera agrupado en componentes conexas (`WallBoundaryGraph`), extruye geometría continua limpia en unidades independientes (`GeneratedMesh`), genera representaciones físicas optimizadas (`CollisionBuilder`) y aplica decoración/materiales de forma desacoplada (`MaterialResolver`), exponiendo una fachada unificada `DungeonGeometryGenerator` con adaptadores de retrocompatibilidad.

**Tech Stack:** Godot 4.x, GDScript 2.0 (RefCounted, ArrayMesh, SurfaceTool, CollisionShape3D, BoxShape3D, ConcavePolygonShape3D, FastNoiseLite).

**Spec:** Especificación de arquitectura y refactorización detallada en el requerimiento del usuario y en `docs/architecture/ARCHITECTURE_AUDIT.md`.

## Global Constraints

- **Zero Breaking Changes:** El sistema existente (`DungeonPresentationBuilder`, `PlaceholderFactory`) debe seguir funcionando durante y después de la transición mediante facades/adapters.
- **No Test Execution by Agent:** El agente nunca debe ejecutar comandos ni pruebas directamente en terminal; debe indicar el comando exacto para que el usuario lo ejecute.
- **Separación Estricta de Capas:** 
  1. Extracción topológica (Topología/Grafos) no conoce mallas ni materiales.
  2. Generadores de geometría producen `ArrayMesh` puro sin texturas hardcodeadas ni colisiones embebidas.
  3. Constructores de colisión deciden formas físicas (BoxShape3D, Compound, Concave) independientemente del render.
  4. Decoradores y Materiales son plugins/pasos opcionales que no alteran la topología base.

---

## File Structure & Map

```
src/geometry_generator/
├── config/
│   ├── geometry_config.gd          # Configuración base de generación
│   ├── wall_geometry_config.gd     # Dimensiones estructurales de muro, zócalos y cornisas
│   ├── collision_config.gd         # Políticas de colisión (BOX, COMPOUND, CONCAVE)
│   └── decoration_config.gd        # Parámetros de ladrillos, relieve, ruido y densidad
├── data/
│   ├── geometry_request.gd         # DTO de solicitud de generación
│   ├── geometry_result.gd          # DTO de salida con clusters y diagnósticos
│   ├── generated_mesh.gd           # Contenedor de ArrayMesh, CollisionShapes y Bounds por cluster
│   ├── wall_boundary_graph.gd      # Grafo de aristas dirigidas y vértices de frontera
│   └── wall_component.gd           # Componente conexa con loops cerrados y cadenas abiertas
├── extraction/
│   ├── boundary_extractor.gd       # Extracción CellGrid -> WallBoundaryGraph
│   └── component_extractor.gd      # Descomposición de WallBoundaryGraph en WallComponents
├── geometry/
│   ├── wall_geometry_builder.gd    # Extrusión de mallas continuas con miter joints por cluster
│   └── corner_geometry_builder.gd  # Geometría especializada para esquinas y encuentros
├── collision/
│   └── wall_collision_builder.gd   # Generador de BoxShapes/CompoundShapes a partir de componentes
├── decoration/
│   ├── brick_decorator.gd          # Decoración de ladrillos en relieve con FastNoiseLite
│   └── material_resolver.gd        # Asignación de materiales y shaders a slots de malla
└── facade/
    └── dungeon_geometry_generator.gd # Fachada central de alto nivel
```

---

## Tasks

### Task 0: Definición de Contratos de Datos y Configuración (Fase M0)

**Files:**
- Create: `src/geometry_generator/data/generated_mesh.gd`
- Create: `src/geometry_generator/data/wall_boundary_graph.gd`
- Create: `src/geometry_generator/data/wall_component.gd`
- Create: `src/geometry_generator/data/geometry_request.gd`
- Create: `src/geometry_generator/data/geometry_result.gd`
- Create: `src/geometry_generator/config/wall_geometry_config.gd`
- Create: `src/geometry_generator/config/collision_config.gd`
- Create: `src/geometry_generator/config/decoration_config.gd`
- Test: `tests/test_geometry_contracts.gd`

**Interfaces:**
- Consumes: `CellGrid`, `WallOpeningManifest`
- Produces: `GeneratedMesh`, `WallBoundaryGraph`, `WallComponent`, `WallGeometryConfig`, `CollisionConfig`, `DecorationConfig`

- [x] **Step 1: Escribir la prueba unitaria de validación de contratos**
- [x] **Step 2: Implementar las clases de datos y configuraciones**
- [ ] **Step 3: Notificar al usuario para ejecutar la prueba de contratos**
Comando a indicar al usuario:
`godot --headless -s res://tests/test_geometry_contracts.gd`

---

### Task 1: Extracción Topológica Robusta (Fase M1 - Boundary & Component Extractor)

**Files:**
- Create: `src/geometry_generator/extraction/boundary_extractor.gd`
- Create: `src/geometry_generator/extraction/component_extractor.gd`
- Test: `tests/test_wall_boundary_extraction.gd`

**Interfaces:**
- Consumes: `CellGrid`, `WallOpeningManifest`
- Produces: `WallBoundaryGraph`, `Array[WallComponent]`

- [x] **Step 1: Escribir la prueba de extracción de fronteras y componentes conexas**
- [x] **Step 2: Implementar BoundaryExtractor y ComponentExtractor**
- [ ] **Step 3: Notificar al usuario para ejecutar la prueba de extracción**
Comando a indicar al usuario:
`godot --headless -s res://tests/test_wall_boundary_extraction.gd`

---

### Task 2: Extrusión de Geometría Continua por Clusters (Fase M2 - WallGeometryBuilder)

**Files:**
- Create: `src/geometry_generator/geometry/wall_geometry_builder.gd`
- Test: `tests/test_wall_geometry_builder.gd`

**Interfaces:**
- Consumes: `WallComponent`, `WallGeometryConfig`
- Produces: `GeneratedMesh` (con `ArrayMesh` de mallas continuas con miter joints a 45°, sin materiales ni ladrillos acoplados)

- [x] **Step 1: Escribir la prueba de extrusión geométrica pura**
- [x] **Step 2: Implementar WallGeometryBuilder**
- [ ] **Step 3: Notificar al usuario para ejecutar la prueba de geometría**
Comando a indicar al usuario:
`godot --headless -s res://tests/test_wall_geometry_builder.gd`

---

### Task 3: Generador de Colisiones Desacoplado (Fase M3 - WallCollisionBuilder)

**Files:**
- Create: `src/geometry_generator/config/collision_config.gd`
- Create: `src/geometry_generator/collision/wall_collision_builder.gd`
- Test: `tests/test_wall_collision_builder.gd`

**Interfaces:**
- Consumes: `WallComponent`, `WallGeometryConfig`, `CollisionConfig`
- Produces: `Array[Shape3D]`, `Array[Transform3D]` dentro de `GeneratedMesh`

- [ ] **Step 1: Escribir la prueba de generación de colisiones**

Crear `tests/test_wall_collision_builder.gd`:
- Valida que para segmentos rectos se generan `BoxShape3D` optimizados.
- Valida que para polígonos complejos o política `COMPOUND_BOX` se generan colisionadores que cubren el perímetro sin gaps.
- Valida que los `bounds` de colisión coinciden estrechamente con los `bounds` de la malla.

```gdscript
extends SceneTree

const WallComponent = preload("res://src/geometry_generator/data/wall_component.gd")
const WallGeometryConfig = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const CollisionConfig = preload("res://src/geometry_generator/config/collision_config.gd")
const WallCollisionBuilder = preload("res://src/geometry_generator/collision/wall_collision_builder.gd")
const GeneratedMesh = preload("res://src/geometry_generator/data/generated_mesh.gd")

func _init() -> void:
	print("--- Running test_wall_collision_builder ---")
	var comp := WallComponent.new(0)
	comp.loops.append([
		Vector2i(2, 2),
		Vector2i(6, 2),
		Vector2i(6, 6),
		Vector2i(2, 6)
	])

	var config := WallGeometryConfig.new()
	var col_cfg := CollisionConfig.new()
	col_cfg.mode = CollisionConfig.CollisionMode.COMPOUND_BOX

	var col_builder := WallCollisionBuilder.new()
	var g_mesh := GeneratedMesh.new()
	col_builder.build_collision_for_component(comp, config, col_cfg, g_mesh)

	assert(g_mesh.collision_shapes.size() == 4, "Debe generar 4 BoxShapes para las 4 paredes")
	for shape in g_mesh.collision_shapes:
		assert(shape is BoxShape3D)

	print("[PASS] test_wall_collision_builder passed!")
	quit(0)
```

- [ ] **Step 2: Implementar WallCollisionBuilder y CollisionConfig**

Implementar:
1. `CollisionConfig` con enum `CollisionMode { BOX, COMPOUND_BOX, CONCAVE_TRIMESH }`.
2. `WallCollisionBuilder`: Calcula centros y dimensiones de cada tramo de pared entre vértices consecutivos y genera `BoxShape3D` orientados con `Transform3D` alineado.

- [ ] **Step 3: Notificar al usuario para ejecutar la prueba de colisiones**
Comando a indicar al usuario:
`godot --headless -s res://tests/test_wall_collision_builder.gd`

---

### Task 4: Decoración Superficial y Material Resolver (Fase M4)

**Files:**
- Create: `src/geometry_generator/config/decoration_config.gd`
- Create: `src/geometry_generator/decoration/brick_decorator.gd`
- Create: `src/geometry_generator/decoration/material_resolver.gd`
- Test: `tests/test_surface_decoration.gd`

**Interfaces:**
- Consumes: `GeneratedMesh`, `WallComponent`, `DecorationConfig`
- Produces: Malla decorada opcional (superficie de ladrillos añadida) y materiales resueltos (`MaterialResolver`).

- [ ] **Step 1: Escribir la prueba de decoración superficial**

Crear `tests/test_surface_decoration.gd`:
- Valida que `BrickDecorator` añade la superficie de ladrillos sin alterar la geometría base del panel ni la colisión.
- Valida que `MaterialResolver` asigna materiales según el preset sin acoplarse al algoritmo generador.

- [ ] **Step 2: Implementar BrickDecorator y MaterialResolver**

Mover la lógica de dispersión de ladrillos con `FastNoiseLite` de `ContinuousWallMeshBuilder` a `BrickDecorator`, y la asignación de materiales Shader/Standard a `MaterialResolver`.

- [ ] **Step 3: Notificar al usuario para ejecutar la prueba de decoración**
Comando a indicar al usuario:
`godot --headless -s res://tests/test_surface_decoration.gd`

---

### Task 5: Fachada Central & Retrocompatibilidad con Presentation Builder (Fase M5)

**Files:**
- Create: `src/geometry_generator/facade/dungeon_geometry_generator.gd`
- Modify: `src/wall_mesh_generator/core/continuous_wall_mesh_builder.gd` (para actuar como adapter a la nueva arquitectura)
- Test: `tests/test_geometry_generator_integration.gd`
- Test: `tests/test_presentation_atomic_swap.gd`

**Interfaces:**
- Consumes: `CellGrid`, `WallOpeningManifest`, `WallGeometryConfig`, `DecorationConfig`, `CollisionConfig`
- Produces: `GeometryResult` (Array de `GeneratedMesh` por cluster / nodos 3D completos listos para staging)

- [ ] **Step 1: Escribir la prueba de integración de extremo a extremo**

Crear `tests/test_geometry_generator_integration.gd`:
- Genera dungeon completa con `DungeonPipeline`.
- Invoca `DungeonGeometryGenerator.generate_wall_clusters(grid, opening_manifest, ...)`.
- Comprueba que se reciben clusters independientes con `mesh`, `collision` y `bounds`.
- Comprueba que `ContinuousWallMeshBuilder` mantiene retrocompatibilidad exacta retornando el `ArrayMesh` unificado para `DungeonPresentationBuilder`.

- [ ] **Step 2: Implementar DungeonGeometryGenerator y actualizar ContinuousWallMeshBuilder como Adapter**

1. `dungeon_geometry_generator.gd`: Coordina `BoundaryExtractor` -> `ComponentExtractor` -> `WallGeometryBuilder` -> `WallCollisionBuilder` -> `BrickDecorator` -> `MaterialResolver`.
2. `continuous_wall_mesh_builder.gd`: Delega internamente a `DungeonGeometryGenerator`, unificando las mallas para no romper llamadas existentes de `DungeonPresentationBuilder` y `PlaceholderFactory`.

- [ ] **Step 3: Notificar al usuario para ejecutar las suites de integración y regresión**
Comandos a indicar al usuario:
1. `godot --headless -s res://tests/test_geometry_generator_integration.gd`
2. `godot --headless -s res://tests/test_continuous_wall_generator.gd`
3. `godot --headless -s res://tests/test_presentation_atomic_swap.gd`
