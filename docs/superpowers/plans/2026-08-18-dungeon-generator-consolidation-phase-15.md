# Plan de Consolidación Arquitectónica - FASE 15: Performance Profiling

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Medir con precisión los tiempos de ejecución por etapa (`mission`, `rooms`, `separation`, `topology`, `entrances`, `corridors`, `doors`, `markers`, `validation`), validar que mazmorras de 60 salas se generen en `< 50 ms` (y mazmorras normales en `< 15 ms`), e implementar optimizaciones de memoria y algoritmos donde sea necesario.

**Architecture:** 
1. **Instrumentación de Tiempos por Etapa**:
   - `DungeonGenerationContext.stage_timings_ms`:
     - `mission_grammar` & `winnability`
     - `space_grammar` & `spatial_separation`
     - `topology_builder` (Delaunay + MST)
     - `entrance_solver`
     - `corridor_carving` (Orthogonal / A*)
     - `door_resolver`
     - `marker_stage` & `reserved_mask`
     - `quality_gate_validation` & `distance_field`
2. **Presupuestos de Rendimiento (Performance Budgets)**:
   - Mazmorra Estándar (~10-15 salas): `< 15 ms`
   - Mazmorra Mediana (40 salas): `< 35 ms`
   - Mazmorra Grande (60 salas): `< 50 ms`
3. **Suite de Benchmark y Profiling (`test_phase15_performance_profiling.gd`)**:
   - Ejecuta benchmarks en escenarios estándar, 40 salas y 60 salas.
   - Desglosa métricas promedio por etapa y valida que se cumpla el presupuesto global `< 50 ms` para 60 salas.

**Tech Stack:** Godot 4.6.1 GDScript, headless testing CLI.

**Spec:** [a-plan/fase-equilibrate.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fase-equilibrate.md)

## Global Constraints
- **Regla 1**: Completar y verificar la Fase 15 antes de avanzar a la Fase 16.
- **Regla 2**: Optimizar basándose en mediciones reales por etapa, sin optimizaciones prematuras innecesarias.
- **Regla 5**: Toda la suite de pruebas (`run_all_tests.gd`) y Golden Seeds deben mantenerse pasando al 100%.

---

### Task 15.1: Instrumentación Precisa de Tiempos por Etapa

**Files:**
- Modify: `src/dungeon_generator/core/dungeon_pipeline.gd`

**Interfaces:**
- Consumes: `DungeonGenerationContext`
- Produces: `stage_timings_ms` exhaustivo y transferido a `DungeonResult.metrics["timings"]`.

- [ ] **Step 1: Asegurar que todas las etapas registren su tiempo de ejecución en `ctx.record_timing()`**
- [ ] **Step 2: Consolidar `ctx.metrics["stage_timings_ms"]` en `DungeonResult`**

---

### Task 15.2: Suite de Benchmarks y Profiling (Phase 15 Gate)

**Files:**
- Create: `tests/test_phase15_performance_profiling.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: `DungeonPipeline`, `DungeonConfig`
- Produces: Benchmark de tiempos por etapa en mazmorras estándar, 40 salas y 60 salas.

- [ ] **Step 1: Escribir `tests/test_phase15_performance_profiling.gd` ejecutando benchmarks multiescala**
- [ ] **Step 2: Ejecutar `test_phase15_performance_profiling.gd` y verificar que 60 salas se generen en `< 50 ms`**
- [ ] **Step 3: Integrar en `tests/run_all_tests.gd` y ejecutar regresión completa**
- [ ] **Step 4: Commit de Fase 15**
