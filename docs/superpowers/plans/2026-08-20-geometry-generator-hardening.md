# Geometry Generator Hardening & Collision Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Endurecer matemáticamente el cálculo de ingletes (miters) y topología poligonal en `WallGeometryBuilder`, normalizar la semántica de colisiones (`NONE`, `PER_SEGMENT_BOX`, `COMPOUND_BOX`, `CONCAVE_TRIMESH`), corregir el bug de inicialización de configuración en `generate_and_attach_wall_nodes()`, y blindar el contrato público `DungeonGeometryGenerator` -> `GeometryResult`.

**Architecture:** El módulo refina el algoritmo de cálculo de vectores miter para garantizar inmunidad a ángulos agudos/obtusos, esquinas cóncavas/convexas y segmentos degenerados sin producir NaNs ni triángulos invertidos. La capa de colisión se sincroniza de forma determinista con los parámetros geométricos del muro, y la fachada `DungeonGeometryGenerator` normaliza todas las configuraciones por defecto antes de orquestar la materialización física y visual.

**Tech Stack:** Godot 4.x, GDScript 2.0 (RefCounted, ArrayMesh, SurfaceTool, BoxShape3D, ConcavePolygonShape3D, StaticBody3D, CollisionShape3D).

**Spec:** Auditoría de geometría procedural (`docs/architecture/ARCHITECTURE_AUDIT.md`) y requerimientos del usuario.

## Global Constraints

- **No Test Execution by Agent:** El agente nunca debe ejecutar comandos ni pruebas directamente en terminal; debe indicar el comando exacto para que el usuario lo ejecute.
- **Zero Inconsistencies:** No permitir NaNs, divisiones por cero, triángulos degenerados (área cero) ni normales nulas en mallas 3D.
- **Inmunidad a Configuración Nula:** Todos los métodos públicos de fachada deben normalizar `null` a configuraciones válidas por defecto antes de procesar o evaluar condiciones hijas.

---

## File Structure & Map

```
src/geometry_generator/
├── config/
│   ├── collision_config.gd          # Actualizar enum: NONE, PER_SEGMENT_BOX, COMPOUND_BOX, CONCAVE_TRIMESH
│   └── wall_geometry_config.gd      # Verificación y clamping de miter limits
├── data/
│   ├── generated_mesh.gd            # Contenedor estricto con validación de AABB y transformaciones
│   └── geometry_result.gd           # Contrato explícito de salida con diagnósticos
├── geometry/
│   └── wall_geometry_builder.gd     # Cálculo robusto de miters para cóncavos/convexos/colineales
├── collision/
│   └── wall_collision_builder.gd    # Implementación diferenciada de PER_SEGMENT_BOX vs COMPOUND_BOX vs TRIMESH
└── facade/
    └── dungeon_geometry_generator.gd # Normalización de configs y orquestación garantizada

tests/
├── test_wall_geometry_hardening.gd  # Suite agresiva de casos topológicos (rectángulo, L, U, T, concavidades, colineales)
├── test_wall_collision_hardening.gd # Suite de validación de envolturas de colisión física
└── test_geometry_facade_contract.gd # Suite de contrato público y llamada con parámetros nulos
```

---

## Tasks

### Task 1: Endurecimiento Geométrico de Miters y Topología (Fase M1 & M2)

**Files:**
- Modify: `src/geometry_generator/geometry/wall_geometry_builder.gd`
- Test: `tests/test_wall_geometry_hardening.gd`

**Interfaces:**
- Consumes: `WallComponent`, `WallGeometryConfig`
- Produces: `GeneratedMesh` (ArrayMesh 100% libre de NaNs, normales degeneradas o vértices duplicados erróneos)

- [x] **Step 1: Escribir la suite agresiva de pruebas geométricas**
- [x] **Step 2: Implementar algoritmo robusto de cálculo de miters en `WallGeometryBuilder`**
- [ ] **Step 3: Notificar al usuario para ejecutar la prueba de endurecimiento geométrico**
Comando a indicar al usuario:
`godot --headless -s res://tests/test_wall_geometry_hardening.gd`

---

### Task 2: Normalización de Colisiones y Corrección de Fachada (Fase M3, M4 & M5)

**Files:**
- Modify: `src/geometry_generator/config/collision_config.gd`
- Modify: `src/geometry_generator/collision/wall_collision_builder.gd`
- Modify: `src/geometry_generator/facade/dungeon_geometry_generator.gd`
- Test: `tests/test_wall_collision_hardening.gd`
- Test: `tests/test_geometry_facade_contract.gd`

**Interfaces:**
- Consumes: `CellGrid`, `WallOpeningManifest`, `WallGeometryConfig`, `CollisionConfig`
- Produces: `GeometryResult`, nodos 3D garantizados en `generate_and_attach_wall_nodes()` incluso con argumentos nulos

- [x] **Step 1: Escribir la prueba de colisiones y contrato de fachada**
- [x] **Step 2: Actualizar `CollisionConfig`, `WallCollisionBuilder` y `DungeonGeometryGenerator`**
- [ ] **Step 3: Notificar al usuario para ejecutar las pruebas de validación**
Comandos a indicar al usuario:
1. `godot --headless -s res://tests/test_wall_geometry_hardening.gd`
2. `godot --headless -s res://tests/test_wall_collision_hardening.gd`
3. `godot --headless -s res://tests/test_geometry_facade_contract.gd`
4. `godot --headless -s res://tests/test_geometry_generator_integration.gd`
5. `godot --headless -s res://tests/test_presentation_atomic_swap.gd`
