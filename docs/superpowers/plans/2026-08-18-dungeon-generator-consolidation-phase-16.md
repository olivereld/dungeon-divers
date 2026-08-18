# Plan de Consolidación Arquitectónica - FASE 16: Presentation / Rendering

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidar el subsistema de renderizado 3D completamente desacoplado del generador lógico, garantizando que consuma `DungeonResult` de forma read-only (0 mutaciones sobre `CellGrid`, `RoomData`, `RoomGraph` o semántica), utilice `MultiMeshInstance3D`/`GridMap` y mallas de pared continuas, e implemente iluminación focal optimizada (máximo 12 `OmniLight3D` sin sombras proyectadas).

**Architecture:** 
1. **Desacoplamiento Estricto (Read-Only Consumer)**:
   - El generador produce `DungeonResult` inmutable.
   - El renderer (`DungeonPresentationBuilder`) consume `DungeonResult` y genera un árbol de nodos 3D en un `StagingRoot` desacoplado, seguido de un `Atomic Swap`.
   - **Invariante Crítico**: Cero modificaciones de `CellGrid`, `RoomData`, `RoomGraph`, o `DungeonResult.checksum`.
2. **Geometría y Mallas de Pared**:
   - `ContinuousWallMeshBuilder`: Malla continua sin fisuras ni spikes.
   - `FloorGridMap` / `MultiMeshInstance3D`: Agrupación por tipo de tile sin instancias individuales por tile.
   - `DungeonDoorSpawner`: Spawning físico alineado a los contratos `DoorPair`.
3. **Iluminación Focal Optimizada**:
   - Spawner de luces (`OmniLight3D`) con límite estricto `<= 12` luces ubicadas en salas clave (Spawn, Boss, Objetivos, Shrines).
   - `omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID` con `shadow_enabled = false` (rendimiento máximo).
4. **Suite de Pruebas de Renderizado (`test_phase16_presentation_rendering.gd`)**:
   - Valida el contrato Read-Only (checksum pre y post render idéntico).
   - Valida el límite de luces (`<= 12`), sin sombras.
   - Valida la ausencia de nodos por tile individuales (`0 MeshInstance3D` sueltos por tile).
   - Valida la estabilidad y compatibilidad a lo largo de 50 semillas.

**Tech Stack:** Godot 4.6.1 GDScript, headless testing CLI, 3D Node system.

**Spec:** [a-plan/fase-equilibrate.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fase-equilibrate.md)

## Global Constraints
- **Regla 1**: Completar y verificar la Fase 16 antes de avanzar a la Fase 17.
- **Regla 2**: Desacoplamiento estricto: el renderizador jamás muta estructuras lógicas.
- **Regla 5**: Toda la suite de pruebas (`run_all_tests.gd`) y Golden Seeds deben mantenerse pasando al 100%.

---

### Task 16.1: Soporte Canónico de `DungeonResult` e Iluminación Focal en `DungeonPresentationBuilder`

**Files:**
- Modify: `src/dungeon_generator/presentation/dungeon_presentation_builder.gd`

**Interfaces:**
- Consumes: `DungeonResult`, `BiomeProfile`, `DungeonConfig`
- Produces: `DungeonPresentationResult` con Staging, Muros Continuos, Entidades y Luces optimizadas (`<= 12`).

- [ ] **Step 1: Añadir `build_from_dungeon_result()` en `DungeonPresentationBuilder`**
- [ ] **Step 2: Implementar spawning de iluminación focal acotada (`<= 12 OmniLight3D` sin sombras)**

---

### Task 16.2: Suite de Pruebas de Renderizado (Phase 16 Gate)

**Files:**
- Create: `tests/test_phase16_presentation_rendering.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: `DungeonPipeline`, `DungeonPresentationBuilder`, `BiomeProfile`
- Produces: Gate test de desacoplamiento, luces y mallas en 50 semillas.

- [ ] **Step 1: Escribir `tests/test_phase16_presentation_rendering.gd` probando invariantes de renderizado**
- [ ] **Step 2: Ejecutar `test_phase16_presentation_rendering.gd` y verificar 100% de éxito**
- [ ] **Step 3: Integrar en `tests/run_all_tests.gd` y ejecutar regresión completa**
- [ ] **Step 4: Commit de Fase 16**
