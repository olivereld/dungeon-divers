# Plan de Consolidación Arquitectónica - FASE 18: Regression Suite

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Congelar y registrar formalmente las 20 Golden Seeds maestras en el registro canónico [`docs/architecture/GOLDEN_SEEDS_REGISTRY.json`](file:///c:/Users/olivereld/Documents/dungeon-divers/docs/architecture/GOLDEN_SEEDS_REGISTRY.json) junto con sus invariantes estructurales completas (`checksum`, `room_count`, `edge_count`, `loop_count`, `floor_count`, `critical_path`, `boss_depth`), y construir la suite fija de regresión (`test_phase18_regression_suite.gd`).

**Architecture:** 
1. **Registro Canónico de Golden Seeds ([`docs/architecture/GOLDEN_SEEDS_REGISTRY.json`](file:///c:/Users/olivereld/Documents/dungeon-divers/docs/architecture/GOLDEN_SEEDS_REGISTRY.json))**:
   - 20 semillas canónicas: `[100001, ..., 100020]`.
   - Para cada semilla registra:
     - `seed`
     - `checksum` (SHA-256)
     - `room_count`
     - `edge_count`
     - `loop_count`
     - `floor_count`
     - `critical_path_length`
     - `boss_depth`
     - `fitness_score`
2. **Suite Canónica de Regresión (`tests/test_phase18_regression_suite.gd`)**:
   - Itera sobre las 20 Golden Seeds y valida contra el registro canónico:
     - Checksum exacto SHA-256.
     - Conteo exacto de salas y aristas.
     - Transitabilidad 100%.
     - Profundidad de Boss `>= 60%`.
     - Invariantes estructurales y de puertas.

**Tech Stack:** Godot 4.6.1 GDScript, headless testing CLI.

**Spec:** [a-plan/fase-equilibrate.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fase-equilibrate.md)

## Global Constraints
- **Regla 1**: Completar y verificar la Fase 18 antes de avanzar a la Fase 19.
- **Regla 2**: Congelar los invariantes de regresión para blindar el pipeline contra regresiones.
- **Regla 5**: Toda la suite de pruebas (`run_all_tests.gd`) y Golden Seeds deben mantenerse pasando al 100%.

---

### Task 18.1: Generación del Registro Canónico `GOLDEN_SEEDS_REGISTRY.json` y Actualización de `GoldenFixtureManager`

**Files:**
- Create: `docs/architecture/GOLDEN_SEEDS_REGISTRY.json`
- Modify: `src/dungeon_generator/debug/golden_fixture_manager.gd`

**Interfaces:**
- Consumes: `DungeonPipeline`, `DungeonConfig`
- Produces: `docs/architecture/GOLDEN_SEEDS_REGISTRY.json` con las métricas fijas de las 20 Golden Seeds.

- [ ] **Step 1: Generar el fixture canónico `GOLDEN_SEEDS_REGISTRY.json` para las 20 semillas maestras**
- [ ] **Step 2: Actualizar `GoldenFixtureManager` para validar `DungeonResult` frente al registro**

---

### Task 18.2: Suite de Pruebas de Regresión Canónica (Phase 18 Gate)

**Files:**
- Create: `tests/test_phase18_regression_suite.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: `DungeonPipeline`, `GoldenFixtureManager`
- Produces: Gate test de regresión fija sobre las 20 Golden Seeds.

- [ ] **Step 1: Escribir `tests/test_phase18_regression_suite.gd` validando los invariantes congelados**
- [ ] **Step 2: Ejecutar `test_phase18_regression_suite.gd` y verificar 100% de éxito**
- [ ] **Step 3: Integrar en `tests/run_all_tests.gd` y ejecutar regresión completa**
- [ ] **Step 4: Commit de Fase 18**
