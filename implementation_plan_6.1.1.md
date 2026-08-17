# Fase 6.1.1 — Reparación Inteligente de Conectividad (Connectivity Repair)

Resumen
-------
Este documento actualiza la Fase 6 del pipeline de generación para introducir una fase intermedia 6.1.1: "Intelligent Connectivity Repair". La idea central:

- Reparar fragmentación interna de habitaciones inmediatamente después de construir las celdas de las habitaciones (post-Cellular/BSP/Hybrid) y antes de construir topología, tallar corredores o resolver puertas.
- Separar responsabilidades de reparación en componentes concretos (RoomConnectivityRepair, CorridorConnectivityRepair, DoorConnectivityRepair) y delegar la coordinación a un coordinator ligero.
- Mantener el seed base (p. ej. 12345) como la identidad lógica del dungeon; todas las decisiones internas (reparaciones, variaciones) usan seeds derivados deterministas y se registran como enteros.
- Usar retry (derivación de seed) solo como último recurso después de intentar reparaciones locales y escaladas semánticas.
- No mezclar los cambios de UI (pantalla negra) con la lógica PCG: arreglar manejo de fallos por separado garantizando que la última dungeon válida se conserva.

Correcciones clave aplicadas en esta versión
-------------------------------------------
1. Control de flujo explícito para marcar un intento como fallido. Ya no hay `goto` ni `continue` dentro del loop de `room_failures`. Se utiliza un flag `attempt_failed` y `break` para salir y `continue` en el bucle externo de attempts.

2. Reubicación de CorridorConnectivityRepair antes de DoorResolver. El orden es ahora: Topology → AStarCarver → Validación de corredores → CorridorRepair → Revalidar → DoorResolver → FloodFill global.

3. Reparaciones atómicas: cada reparación hace snapshot del estado relevante del `CellGrid` (o usa un journal de cambios) y, si la reparación falla, revierte exactamente al estado anterior. Esto evita mutaciones parciales que invaliden fases posteriores.

4. Criterio determinista y explícito para seleccionar la "región principal" dentro de una habitación:
   1) Región que contiene `room.start` si existe (start spawn marker).
   2) Si no existe, región que contiene `room.center` si es transitable.
   3) Si no, región de mayor tamaño (mayor número de celdas).
   4) Si hay empate, elegir la región con la menor coordenada lexicográfica (y,x).

5. Formato y trazabilidad de seeds: se almacenan enteros reales derivados y una estructura clara en el resultado:

```json
{
  "base_seed": 12345,
  "attempt": 2,
  "attempt_seed": 84729103,
  "repair_seed_chain": [
    {"stage": "repair-room", "room_id": 3, "seed": 18273642},
    {"stage": "repair-room", "room_id": 5, "seed": 91827364}
  ]
}
```

Criterios de diseño (actualizado)
---------------------------------
1. Reparaciones locales y semánticas:
   - RoomConnectivityRepair: reparar únicamente dentro de `room.rect` y celdas pertenecientes a esa habitación; operaciones limitadas y atomizadas.
   - CorridorConnectivityRepair: reintentos de carving entre pares de habitaciones, ejecutado antes de DoorResolver.
   - DoorConnectivityRepair: fase separada y posterior; no se ejecuta durante la reparación inicial de habitaciones.

2. Orden estrictamente secuencial (ahora definitivo):
   - Construir habitaciones
   - Validar conectividad interna por habitación
   - Reparar habitación (si es necesario, atómico)
   - Revalidar habitación
   - Construir topología (Delaunay/MST)
   - AStarCarver (corredores)
   - Validación de corredores
   - CorridorConnectivityRepair (si procede, atómico)
   - Revalidar
   - DoorResolver
   - Validación global (FloodFill)
   - Si falla global → diagnosticar (corredor/puerta/topología) → intentar reparación semántica → revalidar → retry derivado si irreparable

3. Determinismo y trazabilidad:
   - `base_seed` permanece como identidad lógica.
   - Cada decisión derivadora utiliza `derive_seed(base_seed, attempt, "<stage>-<id>")` y produce un entero almacenado en `repair_seed_chain`.
   - `attempt_seed` es la seed concreta usada para las fases del attempt (topology/layout/corridor etc.).

4. Seguridad semántica:
   - Ninguna reparación local puede abrir paredes exteriores ni conectar habitaciones distintas.
   - Las reparaciones se limitan por bounding box y por una máscara de celdas asignadas a la habitación.

5. UX y manejo de errores (sin mezclar con PCG):
   - Conservar `last_valid_result` en el gestor de dungeon (DungeonManager) hasta que llegue `generation_completed`.
   - `generation_failed` emite estructura detallada (base_seed, attempt, attempt_seed, reason, affected_rooms, diagnostics, repair_seed_chain).

Componentes propuestos (archivos y responsabilidades)
----------------------------------------------------
- src/dungeon_generator/core/repair/room_connectivity_repair.gd
  - Función principal:
    - repair_room_internal_connectivity(grid: CellGrid, room: RoomData, diag: Dictionary, repair_seed: int, max_attempts: int = 2) -> Dictionary
      - Realiza snapshot/journal del área afectada.
      - Técnicas aplicadas determinísticamente (véase abajo).
      - Si success == false, revierte los cambios exactos y retorna detalles.
      - Retorno: { success: bool, repairs_applied: Array, details: Dictionary, seed_used: int }

  - Técnicas deterministas (orden):
    1. Identificar la región principal usando el criterio determinista definido arriba.
    2. Para cada isla dentro del `room.rect`:
        - calcular celda objetivo más cercana en la región principal (distancia euclidiana o manhattan; determinista)
        - planificar un camino limitado dentro de la máscara de la habitación (A* restringido a `room.rect` y a celdas marcadas como pertenecientes a la habitación; permitir romper muros con coste alto)
        - aplicar carving únicamente sobre el camino planificado
    3. Revalidar localmente. Si falla, revertir y probar la siguiente técnica o marcar irreparable.

- src/dungeon_generator/core/repair/corridor_connectivity_repair.gd
  - Reintentar carving de paths entre entradas/puertas esperadas usando `attempt_seed` y `repair_seed` derivados; debe ser atómico.

- src/dungeon_generator/core/repair/connectivity_coordinator.gd
  - Simple coordinator que decide invocar Room o Corridor repair según la fase y el diagnóstico.

Modificaciones en dungeon_pipeline.gd (control de flujo y atómico)
-----------------------------------------------------------------

Resumen de control de flujo correcto (extracto seguro GDScript 4):

- Tras `_build_rooms(...)`:

```gdscript
var room_failures := []
for r in rooms:
    var r_val = _StructuralValidatorScript.validate_room_internal_connectivity(grid, r)
    if not r_val["is_valid"]:
        room_failures.append({"room": r, "diag": r_val})

if room_failures.size() > 0:
    var attempt_failed := false
    for rf in room_failures:
        var repair_seed = _DungeonSeedFactoryScript.derive_seed(base_seed, attempt, "repair-room-%d" % rf.room.id)
        var rep := RoomConnectivityRepair.repair_room_internal_connectivity(grid, rf.room, rf.diag, repair_seed, config.max_room_repair_attempts)
        if not rep.success:
            push_warning("Attempt %d: Room %d irreparable locally after repairs. Marking attempt as failed." % [attempt, rf.room.id])
            attempt_failed = true
            break
        # revalidate single room
        var after_val = _StructuralValidatorScript.validate_room_internal_connectivity(grid, rf.room)
        if not after_val["is_valid"]:
            push_warning("Attempt %d: Room %d still invalid after local repairs." % [attempt, rf.room.id])
            attempt_failed = true
            break

    if attempt_failed:
        continue # salta al siguiente attempt del for attempts
# si no falló, continuar con topology/ carving...
```

- Importante: `repair` debe devolver `success` sólo si la modificación fue persistida con coherencia; en caso contrario debe revertir cualquier cambio previo.

CorridorRepair antes de DoorResolver (extracto de flujo):

```text
build_rooms -> validate rooms -> room repairs -> build topology -> carve corridors -> validate corridors -> corridor repairs (if any) -> revalidate -> door resolver -> flood fill global
```

Rollback / atomicidad
---------------------
- Opciones de implementación:
  1. Clonar el `CellGrid` parcial (sub-rectángulo) antes de la reparación y restaurarlo si falla. Adecuado si `CellGrid` soporta clonación eficiente o para rectángulos pequeños.
  2. Usar un journal: registrar lista de celdas modificadas y sus valores previos; si falla, iterar el journal y restaurar.
  3. Transacciones en capas: si `CellGrid` implementa capas, aplicar cambios en una capa temporal y mergear sólo si éxito.

- Requisito obligatorio: la reparación debe dejar el `CellGrid` exactamente igual que antes del inicio si `success == false`.

Determinismo en la elección de región principal (algoritmo explícito)
------------------------------------------------------------------
Para una habitación `room` y su lista de regiones internas `regions[]`:

1. Si `room.start` está definido y hay una región que contiene esa celda, elegirla como principal.
2. Else if `room.center` es transitable y pertenece a una región, elegir esa región.
3. Else elegir la región con mayor `size` (número de celdas).
4. Si hay empate en `size`, elegir la región cuyo `min_cell` (menor (y,x) lexicográfico) sea menor.

Esto elimina ambigüedad y asegura reproducibilidad.

Formato de trazabilidad de seeds (ejemplo)
-----------------------------------------
El `DungeonResult` debe incluir una sección `seed_trace` con la estructura:

```json
{
  "base_seed": 12345,
  "attempt": 0,
  "attempt_seed": 98765432,
  "repair_seed_chain": [
    {"stage": "repair-room", "room_id": 3, "seed": 18273642},
    {"stage": "repair-room", "room_id": 5, "seed": 91827364}
  ]
}
```

Tests (actualizado, objetivo estricto para seed 12345)
-----------------------------------------------------
- Unit: validators — casos con islas, caso límite.
- Unit: RoomConnectivityRepair — fixture con grid y room que produce 2+ regiones; ejecutar `repair_room_internal_connectivity` con `repair_seed` derivado y comprobar:
  - `success == true` (o false con rollback exacto comprobado)
  - las celdas modificadas coinciden con snapshot esperado en caso de éxito
  - si `success == false`, el grid final coincide exactamente con grid inicial
  - `seed` devuelto por el repair es el entero derivado esperado

- Integration: pipeline determinista:
  - config.use_fixed_seed=true, config.seed=12345
  - capturar snapshot del `CellGrid` tras `_build_rooms` y comparar con fixtures/seed_12345_initial_grid
  - ejecutar pipeline y comprobar `DungeonResult.seed_trace` coincide con fixture (base_seed, attempt, attempt_seed, repair_seed_chain con enteros exactos)
  - verificar que el CellGrid final coincide con fixture final

Checklist PR (actualizado)
-------------------------
- [ ] Añadir archivos de reparación en `src/dungeon_generator/core/repair/` (room_connectivity_repair.gd, corridor_connectivity_repair.gd, connectivity_coordinator.gd)
- [ ] Modificar `dungeon_pipeline.gd`: hooks de diagnosis y llamadas a RoomConnectivityRepair justo después de `_build_rooms` con control de flujo `attempt_failed`.
- [ ] Colocar CorridorConnectivityRepair entre carving y DoorResolver.
- [ ] Implementar snapshot/journal rollback y tests que verifiquen rollback.
- [ ] Añadir tests unitarios e integración: validators, repair modules, pipeline.
- [ ] Añadir logging estructurado: base_seed, attempt_seed, repair seeds enteros, repairs_applied.
- [ ] Documentar los cambios en `implementation_plan-v3.md` (o enlazar a este fichero nuevo).

Estimación de esfuerzo (actualizada)
------------------------------------
- Corregir warning ternario, UI: 0.5–1 día
- Implementar RoomConnectivityRepair (atómico) + hooks en pipeline + tests básicos: 2–4 días
- Implementar CorridorConnectivityRepair y reordenar flujo + tests: 1–2 días
- Tests integrados de seed determinista, fixtures y CI: 1 día
Total: 4.5–8 días.

Siguientes pasos (que puedo hacer ahora)
---------------------------------------
- Aplicar estos cambios al archivo `implementation_plan_6.1.1.md` (hecho).
- Generar un patch mínimo para `dungeon_pipeline.gd` que:
  - añada el control de flujo `attempt_failed` tras la fase de build_rooms,
  - invoque `RoomConnectivityRepair` y registre `repair_seed_chain`,
  - reordene corridore repair antes de DoorResolver.
- Crear el stub `src/dungeon_generator/core/repair/room_connectivity_repair.gd` con implementación determinista, snapshot/journal y tests básicos.

¿Quieres que cree ahora la rama `feature/6.1.1-connectivity-repair`, añada los stubs y el patch mínimo al `dungeon_pipeline.gd` y abra un PR para revisión?