# Plan de Consolidación Arquitectónica - FASE 4: Consolidar Determinismo y Seeds

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidar el modelo formal de derivación de semillas deterministas (`base_seed -> attempt_seed -> stage_seed`), implementar el calculador canónico de checksums (`DungeonChecksumCalculator`) y crear el test obligatorio de triple ejecución idéntica (`A == B == C`).

**Architecture:** 
1. **Modelo de Semillas Formalizado**:
   - `base_seed` (semilla raíz del piso / nivel).
   - `attempt_seed = derive_seed(base_seed, attempt, &"attempt")`.
   - `stage_seed = derive_seed(base_seed, attempt, stage_name)` para:
     `mission`, `layout`, `topology`, `semantics`, `corridor`, `doors`, `variation`, `decoration`, `validation`.
   - Reparaciones usan semillas derivadas determinísticamente (`repair_room_%d`, `repair_corridors`).
2. **Calculador Canónico de Checksum (`DungeonChecksumCalculator`)**:
   - Calcula un hash criptográfico determinista (SHA-256 o hash de 64 bits empaquetado) de todo el contenido estructural del `DungeonResult`:
     - Buffer espacial de celdas de `CellGrid`.
     - Habitaciones ordenadas por `room.id`.
     - Conexiones ordenadas por `conn.id`.
     - Puertas y umbrales ordenados por `conn.id`.
   - Almacenado en `DungeonResult.checksum`.
3. **Suite de Pruebas de Determinismo (`test_phase4_determinism.gd`)**:
   - Generación triple de 20 semillas arbitrarias: `checksum_A == checksum_B == checksum_C`.
   - Verificación de ausencia de RNG global, llamadas a tiempo o dependencias de orden no ordenado en diccionarios.

**Tech Stack:** Godot 4.6.1 GDScript, `HashingContext` (SHA-256), headless CLI test runner.

**Spec:** [a-plan/fase-equilibrate.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fase-equilibrate.md)

## Global Constraints
- **Regla 1**: Completar, verificar y pasar todos los tests de la Fase 4 antes de avanzar a la Fase 5.
- **Regla 2**: Prohibido usar `RandomNumberGenerator` sin seed, `randi()`, `Time.get_ticks_msec()` para lógica o iteración de diccionarios sin orden.
- **Regla 5**: Toda la suite existente de pruebas (`run_all_tests.gd`) debe mantenerse pasando al 100%.

---

### Task 4.1: Implementación de `DungeonChecksumCalculator` y Expansión de `DungeonSeedFactory`

**Files:**
- Create: `src/dungeon_generator/core/validation/dungeon_checksum_calculator.gd`
- Modify: `src/dungeon_generator/core/generation/dungeon_seed_factory.gd`
- Modify: `src/dungeon_generator/core/data/dungeon_result.gd`
- Modify: `src/dungeon_generator/core/data/dungeon_generation_context.gd`

**Interfaces:**
- Consumes: `DungeonResult`, `CellGrid`, `RoomData`, `RoomConnection`, `DoorPair`
- Produces: `DungeonChecksumCalculator.compute_checksum(result: DungeonResult) -> String`

- [ ] **Step 1: Expandir `DungeonSeedFactory` con offsets canónicos de todas las etapas**
- [ ] **Step 2: Implementar `DungeonChecksumCalculator` con hashing SHA-256 determinista**
- [ ] **Step 3: Agregar campo `checksum: String` a `DungeonResult` y poblarlo en `DungeonGenerationContext.to_dungeon_result()`**

---

### Task 4.2: Suite de Pruebas de Determinismo y Verificación de Invariantes

**Files:**
- Create: `tests/test_phase4_determinism.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: `DungeonPipeline`, `DungeonConfig`, `DungeonChecksumCalculator`
- Produces: Test obligatorio de triple corrida `A == B == C` en múltiples semillas y configuraciones.

- [ ] **Step 1: Implementar `tests/test_phase4_determinism.gd` probando 20 semillas con triple verificación de checksum**
- [ ] **Step 2: Ejecutar `test_phase4_determinism.gd` y verificar que pasa al 100%**
- [ ] **Step 3: Integrar en `tests/run_all_tests.gd` y ejecutar regresión completa**
- [ ] **Step 4: Commit de Fase 4**
