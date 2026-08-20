# Stochastic Floor Tile Patterns & Spatial Variance (Fases V1-V3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminar completamente la repetición del patrón de piedras de suelo mediante un sistema estocástico híbrido en 3 capas (V1 a V3): 8 familias de layouts estructurales base (`STYLIZED_STONE`), transformaciones ortogonales (rotación 0°/90°/180°/270° y reflejos H/V), modulación macro con campo de ruido continuo (`FloorNoiseField`), jitter seguro acotado, y eliminación total de código duplicado en el builder.

**Architecture:**
```text
                       Dungeon / World Seed
                                │
                                ▼
                       FloorNoiseField (V2)
                 (FastNoiseLite / Macro Gradients)
                                │
                   ┌────────────┴────────────┐
                   ▼                         ▼
          Noise Value (<0.3, 0.6, >0.8)   Spatial Hash
          (Stone Size & Crack Bias)       (Layout & Rotation)
                   │                         │
                   └────────────┬────────────┘
                                ▼
                     FloorTilePattern (V1)
                   (8 Layouts × 4 Rotations × 2 Flips = 64 Variantes)
                                │
                                ▼
                     TileDescriptor Stream
                   (SizeClass, Rotation, Jitter, Shards)
                                │
                                ▼
                  FloorSurfaceMeshBuilder
                   (ArrayMesh PBR Slabs + Mortar)
```

**Tech Stack:** Godot 4.x, GDScript 2.0 (`FastNoiseLite`, `RefCounted`, `Rect2`, `PackedVector2Array`, `Transform3D`, `ArrayMesh`, `SurfaceTool`).

---

## Global Constraints

- **100% Surface Coverage:** Ninguna variante de layout o rotación puede dejar huecos vacíos en las esquinas o bordes de la celda `[0, tile_size] × [0, tile_size]`.
- **Zero Inter-Tile Gaps & Overlaps:** El jitter está acotado por `margin` para garantizar `margin_min <= gap <= margin_max` sin invadir piedras vecinas.
- **Single Source of Truth:** `FloorTilePattern` es el único responsable de la disposición espacial de losas; `FloorTileMeshBuilder` solo construye geometría.
- **Strict Seed Determinism:** Misma semilla + mismas coordenadas = idéntico resultado; celdas contiguas con la misma semilla lucen visiblemente distintas y no repetitivas.

---

## File Structure & Map

```text
src/floor_tile_generator/
├── config/
│   └── floor_tile_config.gd         # Añadir parámetros de ruido (noise_scale, noise_frequency, jitter_strength)
├── data/
│   └── tile_descriptor.gd           # Añadir enum SizeClass (SMALL, MEDIUM, LARGE, SHARD)
├── patterns/
│   ├── stone_layout_catalog.gd      # V1: 8 Familias de layouts modulares estilizados (100% cobertura garantizada)
│   ├── floor_noise_field.gd         # V2: Modulador de ruido de baja frecuencia espacial para sesgo de tamaño y desgaste
│   └── floor_tile_pattern.gd        # V1/V2: Orquestador que combina catálogo, rotaciones/flips y modulador de ruido
├── geometry/
│   └── floor_surface_mesh_builder.gd# Limpieza: solo consume TileDescriptors
└── facade/
    └── dungeon_floor_generator.gd   # Conexión pura con FloorNoiseField y semilla global

tests/
├── test_stone_layout_catalog.gd     # V1: Validar cobertura al 100%, 0 solapamientos en las 64 variantes combinatorias
├── test_floor_noise_field.gd        # V2: Validar modulación espacial suave y coherencia macro
├── test_stochastic_tile_patterns.gd # V1/V2: Validar variedad visual en celdas contiguas y determinismo estricto
└── test_dungeon_floor_spawner_e2e.gd# V3: Regresión E2E completa en el pipeline
```

---

## Tasks

### Task 1: Catálogo de Layouts Estructurales y Transformaciones Ortogonales (V1)

**Files:**
- Create: `src/floor_tile_generator/patterns/stone_layout_catalog.gd`
- Modify: `src/floor_tile_generator/data/tile_descriptor.gd`
- Test: `tests/test_stone_layout_catalog.gd`

**Interfaces:**
- Consumes: `Rect2`, `Vector2`, `tile_size: float`, `margin: float`
- Produces: 8 layouts estructurales probados (Central Megalith, Herringbone Masonry, Asymmetric 3-Row, Quad Grid, Split Corner, Cross Weave, Stepped Flags, Dense Pavers), y métodos de transformación ortogonal `rotate_layout_90(layout, times)` y `flip_layout(layout, flip_x, flip_y)` garantizando cobertura exacta `[0, 2.0] × [0, 2.0]`.

- [x] **Step 1: Escribir la prueba unitaria del catálogo (`tests/test_stone_layout_catalog.gd`)**
- [x] **Step 2: Añadir `SizeClass` (SMALL, MEDIUM, LARGE, SHARD) a `TileDescriptor`**
- [x] **Step 3: Implementar `StoneLayoutCatalog` con los 8 layouts base y operaciones ortogonales (64 variantes totales)**
- [x] **Step 4: Indicar comando para verificar que la prueba pasa:**
  `godot --headless -s res://tests/test_stone_layout_catalog.gd`

---

### Task 2: Modulador de Ruido Espacial de Baja Frecuencia (`FloorNoiseField`) (V2)

**Files:**
- Create: `src/floor_tile_generator/patterns/floor_noise_field.gd`
- Modify: `src/floor_tile_generator/config/floor_tile_config.gd`
- Test: `tests/test_floor_noise_field.gd`

**Interfaces:**
- Consumes: `world_pos: Vector2`, `seed: int`, `frequency: float`
- Produces: Muestreo de ruido continuo `sample_noise(world_x, world_y) -> float [-1.0, 1.0]`, funciones auxiliares `get_preferred_size_class()`, `get_wear_bias()`, `get_tone_offset()`.

- [x] **Step 1: Escribir la prueba unitaria de modulación de ruido (`tests/test_floor_noise_field.gd`)**
- [x] **Step 2: Actualizar `FloorTileConfig` con parámetros de ruido (`noise_scale`, `noise_frequency`, `wear_threshold`)**
- [x] **Step 3: Implementar `FloorNoiseField` usando `FastNoiseLite` encapsulado**
- [x] **Step 4: Indicar comando para verificar que la prueba pasa:**
  `godot --headless -s res://tests/test_floor_noise_field.gd`

---

### Task 3: Integración de Variación Estocástica en `FloorTilePattern` (V1-V2)

**Files:**
- Modify: `src/floor_tile_generator/patterns/floor_tile_pattern.gd`
- Modify: `src/floor_tile_generator/facade/dungeon_floor_generator.gd`
- Test: `tests/test_stochastic_tile_patterns.gd`

**Interfaces:**
- Consumes: `cell_pos: Vector2i`, `config: FloorTileConfig`, `seed: int`, `noise_field: FloorNoiseField`
- Produces: Generación no repetitiva de `TileDescriptor` para cada celda combinando selección de layout por noise + hash, rotaciones deterministas y jitter seguro.

- [x] **Step 1: Escribir la prueba de diversidad visual entre celdas contiguas (`tests/test_stochastic_tile_patterns.gd`)**
- [x] **Step 2: Refactorizar `FloorTilePattern` para consumir `StoneLayoutCatalog` y `FloorNoiseField`**
- [x] **Step 3: Actualizar `DungeonFloorGenerator` para inicializar y pasar el `FloorNoiseField` con la semilla global**
- [x] **Step 4: Indicar comando para verificar que la prueba pasa:**
  `godot --headless -s res://tests/test_stochastic_tile_patterns.gd`

---

### Task 4: Actualización del Visor 3D y Suites de Regresión E2E (V3)

**Files:**
- Modify: `src/floor_tile_generator/scenes/floor_tile_viewer.gd`
- Modify: `tests/test_floor_generator_determinism.gd`
- Test: `tests/test_dungeon_floor_spawner_e2e.gd`
- Test: `tests/test_presentation_atomic_swap.gd`

**Interfaces:**
- Consumes: Toda la suite de presentación y generación
- Produces: Validación completa E2E con variedad visual inmediata en el visor 3D y 0 regresiones en el pipeline.

- [x] **Step 1: Actualizar `test_floor_generator_determinism.gd` para validar determinismo sin asumir número fijo de 19 piedras**
- [x] **Step 2: Actualizar `floor_tile_viewer.gd` para permitir alternar ruido y variantes en tiempo real**
- [x] **Step 3: Indicar comandos para validar la suite completa de pruebas:**
  1. `godot --headless -s res://tests/test_stone_layout_catalog.gd`
  2. `godot --headless -s res://tests/test_floor_noise_field.gd`
  3. `godot --headless -s res://tests/test_stochastic_tile_patterns.gd`
  4. `godot --headless -s res://tests/test_floor_generator_determinism.gd`
  5. `godot --headless -s res://tests/test_dungeon_floor_spawner_e2e.gd`
