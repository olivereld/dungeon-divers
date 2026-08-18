# Plan de Consolidación Arquitectónica - FASE 17: Debug y Observabilidad

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir e integrar el subsistema canónico de observabilidad y diagnóstico forense (`DungeonDiagnosticExporter`), permitiendo diagnosticar, inspeccionar capas lógicas (`rooms`, `MST`, `loops`, `critical_path`, `doors`, `distance_field`, `seed_trace`) y reproducir de forma 100% exacta cualquier mazmorra exitosa o fallida a partir únicamente de `seed + config`.

**Architecture:** 
1. **Exportador Canónico de Diagnóstico ([`src/dungeon_generator/debug/dungeon_diagnostic_exporter.gd`](file:///c:/Users/olivereld/Documents/dungeon-divers/src/dungeon_generator/debug/dungeon_diagnostic_exporter.gd))**:
   - `export_diagnostic_report(result: DungeonResult, config: DungeonConfig = null) -> Dictionary`:
     - Genera un reporte JSON estructurado con:
       - **Identificación**: `seed`, `attempt`, `checksum`, `floor`, `generation_time_ms`.
       - **Trazabilidad de Semillas**: `seed_trace` completo (`stage_seeds`, `repair_chain`, `stage_timings_ms`).
       - **Topología & Misión**: Salas, aristas MST, loops, camino crítico, boss depth.
       - **Espacio & Puertas**: Umbrales, pares de puertas, estrategias de ruteo de corredores.
       - **Overlays ASCII**: Mapa de ocupación, mapa de roles semánticos y mapa de flujo de distancias.
       - **Comando de Reproducción**: Código ejecutable para regenerar la mazmorra con exactitud bit a bit.
2. **Invariante de Reproducibilidad**:
   - Dado cualquier reporte de diagnóstico, regenerar con la misma `seed` y `config` produce un `checksum` idéntico.
3. **Suite de Pruebas de Observabilidad (`test_phase17_debug_observability.gd`)**:
   - Valida la integridad del reporte de diagnóstico en 50 semillas.
   - Valida que cualquier mazmorra sea reproducible y diagnosticable al 100%.

**Tech Stack:** Godot 4.6.1 GDScript, headless testing CLI.

**Spec:** [a-plan/fase-equilibrate.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fase-equilibrate.md)

## Global Constraints
- **Regla 1**: Completar y verificar la Fase 17 antes de avanzar a la Fase 18.
- **Regla 2**: Diagnóstico desacoplado sin mutar algoritmos ni estructuras lógicas.
- **Regla 5**: Toda la suite de pruebas (`run_all_tests.gd`) y Golden Seeds deben mantenerse pasando al 100%.

---

### Task 17.1: Implementación de `DungeonDiagnosticExporter`

**Files:**
- Create: `src/dungeon_generator/debug/dungeon_diagnostic_exporter.gd`

**Interfaces:**
- Consumes: `DungeonResult`, `DungeonConfig`
- Produces: Reporte estructurado JSON + ASCII + Reproducibilidad exacta.

- [ ] **Step 1: Crear `DungeonDiagnosticExporter` con exportación JSON, ASCII y telemetría de capas**

---

### Task 17.2: Suite de Pruebas de Observabilidad y Reproducibilidad (Phase 17 Gate)

**Files:**
- Create: `tests/test_phase17_debug_observability.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: `DungeonPipeline`, `DungeonDiagnosticExporter`
- Produces: Gate test de diagnóstico y reproducibilidad forense.

- [ ] **Step 1: Escribir `tests/test_phase17_debug_observability.gd` probando 50 semillas**
- [ ] **Step 2: Ejecutar `test_phase17_debug_observability.gd` y verificar 100% de éxito**
- [ ] **Step 3: Integrar en `tests/run_all_tests.gd` y ejecutar regresión completa**
- [ ] **Step 4: Commit de Fase 17**
