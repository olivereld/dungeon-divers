# Presentation Builder & GeometryResult Clusters Integration (Fase M6) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Conectar directamente `DungeonPresentationBuilder` con `DungeonGeometryGenerator` para consumir `GeometryResult` y sus clusters independientes de `GeneratedMesh`, permitiendo que la presentación 3D gestione mallas y colisiones modulares por componente conexa sin depender del adaptador unificado monolítico, manteniendo 100% de retrocompatibilidad y atomic swap intacto.

**Architecture:** `DungeonPresentationBuilder` reemplaza la llamada interna legacy a `ContinuousWallMeshBuilder` por la fachada `DungeonGeometryGenerator`. El builder invoca `generate_wall_clusters()`, recibe `GeometryResult`, e instancia los clusters de muros en el staging tree (`ContinuousWalls`) con sus correspondientes `MeshInstance3D` y `StaticBody3D` físicos optimizados, preservando el contrato de swap atómico y rollback ante fallos.

**Tech Stack:** Godot 4.x, GDScript 2.0 (RefCounted, Node3D, MeshInstance3D, StaticBody3D, CollisionShape3D, ArrayMesh, AABB).

**Spec:** Auditoría técnica y hoja de ruta M6/M7 para consolidación de infraestructura geométrica.

## Global Constraints

- **No Test Execution by Agent:** El agente nunca debe ejecutar comandos ni pruebas directamente en terminal; debe indicar el comando exacto para que el usuario lo ejecute.
- **Zero Breaking Changes:** Todas las suites existentes (`test_fase_9_horizontal_integration.gd`, `test_fase_10_vertical_integration.gd`, `test_continuous_wall_generator.gd`, `test_presentation_atomic_swap.gd`) deben seguir pasando al 100%.
- **Atomic Swap & Rollback Guarantee:** El staging desacoplado, la destrucción limpia de nodos en rollback y la promoción atómica en commit deben mantenerse invariables.

---

## File Structure & Map

```
src/dungeon_generator/presentation/
└── dungeon_presentation_builder.gd    # Integrar DungeonGeometryGenerator consumiendo GeometryResult

tests/
├── test_presentation_geometry_clusters.gd # Nueva suite que valida clusters independientes en presentación
├── test_continuous_wall_generator.gd      # Regresión continua
├── test_fase_9_horizontal_integration.gd  # Regresión horizontal
└── test_presentation_atomic_swap.gd       # Regresión swap atómico y Boss
```

---

## Tasks

### Task 1: Integración de DungeonGeometryGenerator en DungeonPresentationBuilder (Fase M6)

**Files:**
- Modify: `src/dungeon_generator/presentation/dungeon_presentation_builder.gd:50-105`
- Modify: `src/dungeon_generator/presentation/dungeon_presentation_builder.gd:200-230`
- Modify: `src/dungeon_generator/presentation/dungeon_presentation_builder.gd:330-360`
- Test: `tests/test_presentation_geometry_clusters.gd`

**Interfaces:**
- Consumes: `DungeonSemanticResult`, `DungeonConfig`, `BiomeProfile`, `DungeonGeometryGenerator`, `GeometryResult`, `GeneratedMesh`
- Produces: `DungeonPresentationResult` con jerarquía de muros basada en clusters independientes y colisiones físicas asociadas.

- [x] **Step 1: Escribir la prueba unitaria de validación de clusters en la presentación**
- [x] **Step 2: Actualizar `DungeonPresentationBuilder` para consumir `DungeonGeometryGenerator`**
- [ ] **Step 3: Notificar al usuario para ejecutar la suite completa de integración y regresión**
Comandos a indicar al usuario:
1. `godot --headless -s res://tests/test_presentation_geometry_clusters.gd`
2. `godot --headless -s res://tests/test_continuous_wall_generator.gd`
3. `godot --headless -s res://tests/test_fase_9_horizontal_integration.gd`
4. `godot --headless -s res://tests/test_presentation_atomic_swap.gd`
