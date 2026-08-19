# Plan de Consolidación Arquitectónica - FASE 5: Consolidar Room Generation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidar la generación de habitaciones (`SpaceGrammar` + `RoomShapeGenerator`) para garantizar proporciones arquitectónicas canónicas (Small 45%, Medium 40%, Large 15%, mínimo 2 Large), formas estables (Rectangle 60%, Octagon 18%, Pillared/Cruciform 22%), y una tasa de salas inválidas de 0% en 100+ semillas.

**Architecture:** 
1. **Distribución Canónica de Tamaños en `SpaceGrammar`**:
   - Small (5x5 a 7x7): 45%
   - Medium (8x8 a 10x10): 40%
   - Large (11x11 a 14x14): 15%
   - Garantía determinista: Al menos 2 salas de categoría Large (ej. Boss + sala principal de combate/tesoro).
2. **Distribución Canónica de Formas en `RoomShapeGenerator` / `DungeonRoomStage`**:
   - `OPEN_HALL` (Rectangle): 60%
   - `OCTAGONAL_CHAMBER` (Octagon): 18%
   - `PILLARED_HALL` y `CRUCIFORM_SANCTUARY` (Columnas y Cruz): 22%
3. **Invariantes de Validación Estructural**:
   - Dimensiones mínimas `>= 5x5`.
   - Área transitable mínima `>= 16` celdas y ratio de transitabilidad `>= 70%`.
   - Centro 100% transitable.
   - Floor 100% contiguo internamente sin necesidad de `RoomConnectivityRepair` en generación normal.
4. **Gate de Validación**:
   - Test de 100+ semillas deterministas verificando las proporciones y 0% de fallos estructurales en salas.

**Tech Stack:** Godot 4.6.1 GDScript, headless testing CLI.

**Spec:** [a-plan/fase-equilibrate.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fase-equilibrate.md)

## Global Constraints
- **Regla 1**: Completar, verificar y pasar todos los tests de la Fase 5 antes de avanzar a la Fase 6.
- **Regla 2**: Mantener compatibilidad determinista y no alterar las interfaces públicas.
- **Regla 5**: Toda la suite existente de pruebas (`run_all_tests.gd`) debe mantenerse pasando al 100%.

---

### Task 5.1: Consolidación de `SpaceGrammar` y `DungeonRoomStage`

**Files:**
- Modify: `src/dungeon_generator/core/grammars/space_grammar.gd`
- Modify: `src/dungeon_generator/core/stages/dungeon_room_stage.gd`
- Modify: `src/dungeon_generator/core/algorithms/room_shape_generator.gd`

**Interfaces:**
- Consumes: `mission_graph`, `DungeonConfig`, `DungeonGenerationContext`
- Produces: `Array[RoomData]` con distribución canónica de tamaños y formas.

- [ ] **Step 1: Implementar distribución Small/Medium/Large con mínimo 2 Large en `SpaceGrammar`**
- [ ] **Step 2: Calibrar la selección de formas en `DungeonRoomStage` (60% Rect, 18% Octagon, 22% Pillared/Cruciform)**
- [ ] **Step 3: Reforzar `RoomShapeGenerator` para asegurar habitabilidad >= 70%**

---

### Task 5.2: Suite de Pruebas de Calidad de Habitaciones (100+ Seeds Gate)

**Files:**
- Create: `tests/test_phase5_room_generation.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: `DungeonPipeline`, `DungeonConfig`
- Produces: Test de validación de 100 semillas consecutivas comprobando métricas de tamaño, formas y 0% fallos.

- [ ] **Step 1: Escribir `tests/test_phase5_room_generation.gd` con análisis estadístico en 100+ semillas**
- [ ] **Step 2: Ejecutar `test_phase5_room_generation.gd` y verificar 0 fallos de sala**
- [ ] **Step 3: Integrar en `tests/run_all_tests.gd` y ejecutar regresión completa**
- [ ] **Step 4: Commit de Fase 5**
