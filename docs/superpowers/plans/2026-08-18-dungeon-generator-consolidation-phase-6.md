# Plan de Consolidación Arquitectónica - FASE 6: Consolidar Separación Espacial

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidar la separación espacial de habitaciones con un algoritmo AABB determinista (padding mínimo de 2 celdas, límite de 300 iteraciones, orden estricto `room_id ascending` y poda determinista en caso de desbordamiento).

**Architecture:** 
1. **Separación AABB Determinista (`RoomSpatialSeparator`)**:
   - `src/dungeon_generator/core/topology/room_spatial_separator.gd`:
     - Función `separate_rooms(rooms: Array[RoomData], bounds: Rect2i, rng: RandomNumberGenerator, min_padding: int = 2, max_iterations: int = 300) -> Array[RoomData]`.
     - Procesa salas siempre en orden `room_id ascending`.
     - Resuelve colisiones empujando o reubicando en espiral radial determinista.
     - Poda determinista de salas opcionales (`is_required == false`) si se agotan los 300 intentos antes de provocar solapamiento.
     - Validador estricto `validate_separation(rooms: Array[RoomData], bounds: Rect2i, min_padding: int = 2) -> Dictionary`.
2. **Integración en `SpaceGrammar`**:
   - `SpaceGrammar.generate()` delega la verificación y separación a `RoomSpatialSeparator`.
3. **Gate de Validación**:
   - 100 semillas verificando que 100% de los pares de habitaciones tienen `padding >= 2`, 0 solapamientos y todas las salas quedan dentro de los límites de la cuadrícula.

**Tech Stack:** Godot 4.6.1 GDScript, headless testing CLI.

**Spec:** [a-plan/fase-equilibrate.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fase-equilibrate.md)

## Global Constraints
- **Regla 1**: Completar y verificar la Fase 6 antes de avanzar a la Fase 7.
- **Regla 2**: Separación estrictamente determinista en orden `room_id ascending`.
- **Regla 5**: Toda la suite de pruebas (`run_all_tests.gd`) y Golden Seeds deben mantenerse pasando al 100%.

---

### Task 6.1: Implementación de `RoomSpatialSeparator` e Integración en `SpaceGrammar`

**Files:**
- Create: `src/dungeon_generator/core/topology/room_spatial_separator.gd`
- Modify: `src/dungeon_generator/core/grammars/space_grammar.gd`

**Interfaces:**
- Consumes: `Array[RoomData]`, `Rect2i`, `RandomNumberGenerator`
- Produces: `Array[RoomData]` sin solapamientos, con padding `>= 2` y contenido en `bounds`.

- [ ] **Step 1: Implementar `RoomSpatialSeparator` con algoritmo determinista y validador de separación**
- [ ] **Step 2: Conectar `RoomSpatialSeparator` en `SpaceGrammar.generate()`**

---

### Task 6.2: Suite de Pruebas de Separación Espacial (Phase 6 Gate)

**Files:**
- Create: `tests/test_phase6_spatial_separation.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: `DungeonPipeline`, `RoomSpatialSeparator`
- Produces: Test de validación espacial de 100 semillas consecutivas.

- [ ] **Step 1: Escribir `tests/test_phase6_spatial_separation.gd` probando 100 semillas**
- [ ] **Step 2: Ejecutar `test_phase6_spatial_separation.gd` y verificar 100% de éxito**
- [ ] **Step 3: Integrar en `tests/run_all_tests.gd` y ejecutar regresión completa**
- [ ] **Step 4: Commit de Fase 6**
