# Plan de Consolidación Arquitectónica - FASE 13: Validación Estructural (Quality Gate)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidar la validación como una verdadera **Quality Gate** dividida estrictamente entre **Hard Constraints** (rechazo inmediato del intento si falla cualquiera) y **Soft Quality Heuristics** (puntuación de fitness 0.0-100.0), garantizando que un dungeon con `hard_valid == false` jamás sea aceptado.

**Architecture:** 
1. **Quality Gate Canónica (`DungeonQualityGate`)**:
   - `src/dungeon_generator/core/validation/dungeon_quality_gate.gd`:
     - **Hard Constraints (Mandatorias)**:
       - `connected`: 100% de celdas transitables alcanzables.
       - `rooms_valid`: Sin solapamientos, dentro de límites, sin islas internas.
       - `graph_valid`: 1 componente conexo, sin auto-aristas ni duplicados, grado <= 4.
       - `doors_valid`: 100% en límites y sobre suelo transitable.
       - `boss_reachable`: `boss_depth >= 60% max_depth` y alcanzable desde start.
       - `semantics_valid`: Start != Boss, camino crítico continuo.
       - `placement_valid`: Sin solapamientos en `reserved_mask`.
     - **Soft Quality (Fitness Heuristics)**:
       - Branching factor, diversidad de formas, calidad de pasillos (pocas curvas), compacidad.
2. **Integración en `DungeonValidationStage`**:
   - Ejecuta `DungeonQualityGate.evaluate(ctx)`.
   - Si `hard_valid == false`: `ctx.mark_attempt_failed()` (intento rechazado).
   - Si `hard_valid == true`: Registra `ctx.fitness_score` y métricas de calidad.
3. **Suite de Pruebas de Quality Gate (`test_phase13_quality_gate.gd`)**:
   - Validación en 100 semillas de:
     - 100% de dungeons generados tienen `hard_valid == true`.
     - Cero tolerancias a hard failures.
     - Fitness score consistente y determinista.

**Tech Stack:** Godot 4.6.1 GDScript, headless testing CLI.

**Spec:** [a-plan/fase-equilibrate.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fase-equilibrate.md)

## Global Constraints
- **Regla 1**: Completar y verificar la Fase 13 antes de avanzar a la Fase 14.
- **Regla 2**: NUNCA convertir un hard failure en un fitness bajo; los hard failures rechazan el intento.
- **Regla 5**: Toda la suite de pruebas (`run_all_tests.gd`) y Golden Seeds deben mantenerse pasando al 100%.

---

### Task 13.1: Implementación de `DungeonQualityGate` e Integración en `DungeonValidationStage`

**Files:**
- Create: `src/dungeon_generator/core/validation/dungeon_quality_gate.gd`
- Modify: `src/dungeon_generator/core/stages/dungeon_validation_stage.gd`

**Interfaces:**
- Consumes: `DungeonGenerationContext`
- Produces: `QualityGateResult` con `hard_valid: bool`, `fitness_score: float` y diagnóstico formal.

- [ ] **Step 1: Crear `DungeonQualityGate` con verificación de Hard Constraints y Soft Quality**
- [ ] **Step 2: Integrar `DungeonQualityGate` en `DungeonValidationStage`**

---

### Task 13.2: Suite de Pruebas de Quality Gate (Phase 13 Gate)

**Files:**
- Create: `tests/test_phase13_quality_gate.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: `DungeonPipeline`, `DungeonQualityGate`
- Produces: Test de validación de 100 semillas consecutivas.

- [ ] **Step 1: Escribir `tests/test_phase13_quality_gate.gd` probando 100 semillas**
- [ ] **Step 2: Ejecutar `test_phase13_quality_gate.gd` y verificar 100% de éxito**
- [ ] **Step 3: Integrar en `tests/run_all_tests.gd` y ejecutar regresión completa**
- [ ] **Step 4: Commit de Fase 13**
