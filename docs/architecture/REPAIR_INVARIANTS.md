# Contratos Formales e Invariantes de Reparación (Fase 14)

Este documento establece los contratos canónicos que rigen a todos los mecanismos de reparación del generador procedimental. La reparación es un **mecanismo excepcional y de última línea**, nunca una etapa estándar para enmascarar fallos de diseño del algoritmo generador.

---

## 1. Reglas Globales de Reparación

1. **Aislamiento Semántico y Topológico**:
   Ninguna acción de reparación puede modificar:
   - `Room Semantics` (roles de inicio, boss, puzzle, tesoro).
   - `MissionGraph` (dependencias lógicas y cerraduras).
   - `Critical Path` (camino canónico de avance).
   - `Entrance / Doorway Placements`.
   - `RoomGraph Topology` (aristas de conexión entre salas).

2. **Atomicidad y Rollback**:
   Toda modificación del `CellGrid` realizada por un reparador debe ejecutarse a través de un `CellGridJournal`. Si la reparación no produce un resultado 100% válido, debe ejecutarse un `rollback` inmediato sin dejar celdas residuales ni efectos secundarios.

3. **Tasa de Activación Excepcional**:
   La tasa de activación de cualquier mecanismo de reparación en generación normal debe ser **`<= 2.0%`**. Si un reparador se activa frecuentemente, debe detenerse la generación, perfilarse la causa raíz y corregirse el algoritmo generativo correspondiente.

---

## 2. Contratos Canónicos por Mecanismo

### A. `RoomConnectivityRepair`

* **Input Invariant**: Habitación con geometría compleja o columnas/obstáculos que generan dos o más regiones transitables desconectadas (`regions.size() > 1`).
* **Failure Condition**: Fragmentación interna que aísla un subconjunto de celdas de suelo dentro de la misma sala.
* **Repair Action**:
  1. Identificar la región principal más grande y central.
  2. Calcular la trayectoria ortogonal mínima entre cada isla secundaria y la región principal contenida estrictamente dentro de `room.rect`.
  3. Registrar cambios en `CellGridJournal`.
* **Output Invariant**: La habitación posee exactamente **una única región transitable conexa** (`regions.size() == 1`), 100% contenida en `room.rect`.

---

### B. `CorridorConnectivityRepair`

* **Input Invariant**: Corredor donde el ensanchado o la geometría adyacente causó una discontinuidad transitable detectada por `FloodFill`.
* **Failure Condition**: Falta de continuidad transitable entre el umbral de entrada A y el umbral de entrada B de una conexión obligatoria.
* **Repair Action**:
  1. Trazado ortogonal de emergencia A* restringido al búfer del corredor y registrado en Journal.
  2. Verificación estricta de no invasión de salas ajenas.
* **Output Invariant**: Camino 100% transitable y continuo entre ambos umbrales sin violar `grid_bounds`.

---

### C. `RoomIntegrityCleaner`

* **Input Invariant**: Habitación rasterizada con celdas de suelo no contiguas o esquinas desconectadas en su perímetro.
* **Failure Condition**: Celdas huérfanas o transiciones de 1 celda en diagonal sin soporte ortogonal.
* **Repair Action**: Poda determinista convirtiendo celdas huérfanas en `WALL` respetando las celdas interiores.
* **Output Invariant**: Perímetro geométricamente limpio y conexo.
