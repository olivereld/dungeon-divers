# Plan de Consolidación Arquitectónica - FASE 14: Redefinir Repair

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redefinir y formalizar todos los mecanismos de reparación como acciones excepcionales, transaccionales y estrictamente documentadas bajo el contrato canónico (`Input Invariant -> Failure Condition -> Repair Action -> Output Invariant`), verificando que su tasa de activación en generación normal no supere el 2%.

**Architecture:** 
1. **Contratos Canónicos de Reparación ([`docs/architecture/REPAIR_INVARIANTS.md`](file:///c:/Users/olivereld/Documents/dungeon-divers/docs/architecture/REPAIR_INVARIANTS.md))**:
   - `RoomConnectivityRepair`:
     - *Input Invariant*: Habitación generada con múltiples islas desconectadas (`regions.size() > 1`).
     - *Failure*: Desconexión interna transitable.
     - *Repair Action*: Conexión de islas a la región principal determinista mediante `CellGridJournal` y rollback automático.
     - *Output Invariant*: Exactamente 1 región transitable conexa (`regions.size() == 1`).
   - `CorridorConnectivityRepair`:
     - *Input Invariant*: Corredor desconectado tras tallado (`FloodFill` detecta aislamiento).
     - *Failure*: Interrupción por ensanchado o geometría adyacente.
     - *Repair Action*: Trazado ortogonal de emergencia con Journal.
     - *Output Invariant*: Transitabilidad completa y continua entre ambos umbrales.
   - `RoomIntegrityCleaner`:
     - *Input Invariant*: Puntos transitables flotantes en perímetros o esquinas no contiguas.
     - *Failure*: Celdas de suelo huérfanas en los bordes de sala.
     - *Repair Action*: Poda determinista de celdas no contiguas.
     - *Output Invariant*: Perímetro limpio y coherente.
2. **Restricciones Inmutables**:
   - Ningún repair puede mutar: `room semantics`, `mission graph`, `critical path`, `boss`, `entrance`, `topology`.
3. **Suite de Pruebas de Reparación (`test_phase14_repair_contracts.gd`)**:
   - Validación de contratos de invariantes y tasa de activación `<= 2%` en 100 semillas.

**Tech Stack:** Godot 4.6.1 GDScript, headless testing CLI.

**Spec:** [a-plan/fase-equilibrate.md](file:///c:/Users/olivereld/Documents/dungeon-divers/a-plan/fase-equilibrate.md)

## Global Constraints
- **Regla 1**: Completar y verificar la Fase 14 antes de avanzar a la Fase 15.
- **Regla 2**: Reparación como mecanismo excepcional; nunca enmascarar fallos de diseño del generador.
- **Regla 5**: Toda la suite de pruebas (`run_all_tests.gd`) y Golden Seeds deben mantenerse pasando al 100%.

---

### Task 14.1: Documentación Canónica de Contratos de Reparación e Invariantes

**Files:**
- Create: `docs/architecture/REPAIR_INVARIANTS.md`
- Modify: `src/dungeon_generator/core/repair/room_connectivity_repair.gd`
- Modify: `src/dungeon_generator/core/repair/corridor_connectivity_repair.gd`

**Interfaces:**
- Consumes: `CellGrid`, `RoomData`, `CellGridJournal`
- Produces: Reparaciones transaccionales y reversibles con contratos documentados.

- [ ] **Step 1: Crear `docs/architecture/REPAIR_INVARIANTS.md` con los 3 contratos formales**
- [ ] **Step 2: Verificar docstrings y aislamiento de efectos secundarios en los reparadores**

---

### Task 14.2: Suite de Pruebas de Contratos de Reparación (Phase 14 Gate)

**Files:**
- Create: `tests/test_phase14_repair_contracts.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: `DungeonPipeline`, `RoomConnectivityRepair`, `CorridorConnectivityRepair`
- Produces: Test de validación de contratos y tasa de activación en 100 semillas.

- [ ] **Step 1: Escribir `tests/test_phase14_repair_contracts.gd` probando 100 semillas**
- [ ] **Step 2: Ejecutar `test_phase14_repair_contracts.gd` y verificar 100% de éxito**
- [ ] **Step 3: Integrar en `tests/run_all_tests.gd` y ejecutar regresión completa**
- [ ] **Step 4: Commit de Fase 14**
