# Plan de Consolidación Arquitectónica - FASE 12: Decoración y Reservas

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separar completamente la estructura del dungeon de la decoración mediante una máscara de reserva espacial canónica (`DungeonReservedMask`) que impida cualquier solapamiento indebido entre puertas, corredores transitables, columnas, antorchas, escombros, cofres, santuarios y puntos de spawn.

**Architecture:** 
1. **Máscara Única de Reserva Espacial (`DungeonReservedMask`)**:
   - `src/dungeon_generator/core/data/dungeon_reserved_mask.gd`:
     - Almacena celdas reservadas y el motivo (`DOORWAY`, `CORRIDOR_CLEARANCE`, `SPAWN`, `BOSS_SET_PIECE`, `CHEST`, `SHRINE`, `TORCH`, `PILLAR`, `DEBRIS`).
     - Funciones atómicas `reserve(pos, reason)`, `is_reserved(pos)`, `reserve_clearance(pos)`.
2. **Secuencia Canónica de Reserva y Colocación en `DungeonMarkerStage`**:
   - Orden estricto:
     `doors -> door_clearance -> pillars -> torches -> debris -> chests -> shrines -> boss set-piece -> spawns`.
   - Ningún marcador ni elemento decorativo puede colocarse sobre una celda ya reservada.
3. **Suite de Pruebas de Reservas y Cero Solapamientos (`test_phase12_decorations_reservations.gd`)**:
   - Validación en 100 semillas de:
     - Cero solapamientos entre elementos decorativos y umbrales de puerta.
     - Cero elementos decorativos bloqueando corredores transitables.
     - 100% de consultas a la máscara de reserva respetadas.

**Tech Stack:** Godot 4.6.1 GDScript, headless testing CLI.

**Spec:** [a-plan/fase-equilibrate.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fase-equilibrate.md)

## Global Constraints
- **Regla 1**: Completar y verificar la Fase 12 antes de avanzar a la Fase 13.
- **Regla 2**: `DungeonReservedMask` es la ÚNICA fuente de verdad para reservas decorativas.
- **Regla 5**: Toda la suite de pruebas (`run_all_tests.gd`) y Golden Seeds deben mantenerse pasando al 100%.

---

### Task 12.1: Creación de `DungeonReservedMask` e Integración en `DungeonMarkerStage`

**Files:**
- Create: `src/dungeon_generator/core/data/dungeon_reserved_mask.gd`
- Modify: `src/dungeon_generator/core/stages/dungeon_marker_stage.gd`
- Modify: `src/dungeon_generator/core/data/dungeon_generation_context.gd`

**Interfaces:**
- Consumes: `DungeonGenerationContext`, `doors`, `corridor_paths`, `rooms`
- Produces: `DungeonReservedMask` validada y marcadores sin solapamientos.

- [ ] **Step 1: Crear `DungeonReservedMask` con API atómica de reservas y motivos**
- [ ] **Step 2: Añadir `reserved_mask` a `DungeonGenerationContext`**
- [ ] **Step 3: Actualizar `DungeonMarkerStage` para poblar y respetar `DungeonReservedMask`**

---

### Task 12.2: Suite de Pruebas de Decoración y Reservas (Phase 12 Gate)

**Files:**
- Create: `tests/test_phase12_decorations_reservations.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: `DungeonPipeline`, `DungeonReservedMask`
- Produces: Test de validación de reservas y 0 solapamientos en 100 semillas.

- [ ] **Step 1: Escribir `tests/test_phase12_decorations_reservations.gd` probando 100 semillas**
- [ ] **Step 2: Ejecutar `test_phase12_decorations_reservations.gd` y verificar 100% de éxito**
- [ ] **Step 3: Integrar en `tests/run_all_tests.gd` y ejecutar regresión completa**
- [ ] **Step 4: Commit de Fase 12**
