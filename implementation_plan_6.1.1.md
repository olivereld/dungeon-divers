# Fase 6.1.1 — Reparación Inteligente de Conectividad (Connectivity Repair)

Resumen
-------
Este documento actualiza la Fase 6 del pipeline de generación para introducir una fase intermedia 6.1.1: "Intelligent Connectivity Repair". La idea central:

- Reparar fragmentación interna de habitaciones inmediatamente después de construir las celdas de las habitaciones (post-Cellular/BSP/Hybrid) y antes de construir topología, tallar corredores, o resolver puertas.
- Separar responsabilidades de reparación en componentes concretos (RoomConnectivityRepair, CorridorConnectivityRepair, DoorConnectivityRepair) y delegar la decisión a un coordinator ligero.
- Mantener el seed base (p. ej. 12345) como la identidad del dungeon; todas las decisiones internas (reparaciones, variaciones) usan seeds derivados deterministas.
- Usar retry (derivación de seed) solo como último recurso después de intentar reparaciones locales y escaladas semánticas.
- No mezclar los cambios de UI (pantalla negra) con la lógica PCG: arreglar manejo de fallos por separado garantizando que la última dungeon válida se conserva.

Criterios de diseño
-------------------
1. Reparaciones locales y semánticas:
   - RoomConnectivityRepair: reparar únicamente dentro de room.rect y celdas pertenecientes a esa habitación.
   - CorridorConnectivityRepair: reparar trazados de corredores, ajustar carve parameters localmente.
   - DoorConnectivityRepair: fase posterior, no se usa en la reparación inicial de habitaciones.

2. Orden estrictamente secuencial:
   - Construir habitaciones
   - Validar conectividad interna por habitación
   - Reparar habitación (si es necesario)
   - Revalidar habitación
   - Continuar con topología y carving
   - Validación global (FloodFill)
   - Si falla global → diagnosticar (corredor/puerta/topología) → intentar reparación semántica → revalidar → retry derivado si irreparable

3. Determinismo:
   - base_seed permanece como identidad.
   - Derivación determinista para cada decisión: derive_seed(base_seed, attempt, "repair-room-%d" % room_id)
   - Registrar la cadena de seeds usadas en el resultado final para trazabilidad.

4. Seguridad semántica:
   - Ninguna reparación local puede abrir paredes exteriores ni conectar habitaciones distintas.
   - Las reparaciones se limitan por bounding box y por una máscara de celdas asignadas a la habitación.

5. UX y manejo de errores:
   - Separar la corrección de pantalla negra del pipeline: conservar last_valid_result en la UI.
   - Emitir generation_failed con estructura (seed, attempts, reason, affected_rooms, diagnostics).

Componentes propuestos
----------------------
- src/dungeon_generator/core/repair/room_connectivity_repair.gd
  - Funciones:
    - repair_room_internal_connectivity(grid: CellGrid, room: RoomData, diag: Dictionary, repair_seed: int, max_attempts: int = 2) -> Dictionary
      - Intenta una o más técnicas deterministas y limitadas para unir regiones dentro de room.rect.
      - Retorna { success: bool, repairs_applied: Array, details: Dictionary }
  - Técnicas (aplicadas en orden):
    1. Flood-fill de la habitación y detección de la región principal (mayor área o que contiene centro/start/goal según semántica).
    2. Para cada isla, calcular la celda más cercana en la región principal restringida a room.rect.
    3. Trazar camino mínimo limitado dentro de room.rect (A* sobre máscara de la habitación, coste alto para romper paredes) y aplicar carving solo sobre ese camino.
    4. Si el trazado no es posible porque la isla está separada por un muro que no se puede tocar, marcar como irreparable localmente y devolver detalles.

- src/dungeon_generator/core/repair/corridor_connectivity_repair.gd
  - Funciones para reintentar carving entre par de rooms usando parámetros más permisivos pero localizados, sin destruir habitaciones.

- src/dungeon_generator/core/repair/connectivity_coordinator.gd
  - Decide qué reparación invocar. En esta fase su rol es mínimo: preferir reparaciones por habitación inmediatamente tras la construcción.

Modificaciones en dungeon_pipeline.gd (resumen técnico)
------------------------------------------------------
Reemplazar los "continue" tempranos por un flujo de diagnosis → attempt-repair → revalidate:

1) Después de _build_rooms(grid, rooms, config, rng_variation):
   - Ejecutar validación por habitación:
     for r in rooms:
         r_val = _StructuralValidatorScript.validate_room_internal_connectivity(grid, r)
         if not r_val["is_valid"]:
             diag = r_val
             repair_seed = _DungeonSeedFactoryScript.derive_seed(base_seed, attempt, "repair-room-%d" % r.id)
             var rep_res = RoomConnectivityRepair.repair_room_internal_connectivity(grid, r, diag, repair_seed)
             if rep_res.success:
                 # volver a validar esta habitación
                 new_val = _StructuralValidatorScript.validate_room_internal_connectivity(grid, r)
                 if not new_val["is_valid"]:
                     # si aún inválida: marcar para retry derivado (salir de generación actual)
                     push_warning("Room %d irreparable locally after repair attempts." % r.id)
                     goto try_next_attempt
             else:
                 # irreparable local → try_next_attempt
                 push_warning("Room %d marked irreparable: %s" % [r.id, rep_res.details])
                 goto try_next_attempt

2) Sólo si todas las habitaciones tienen conectividad 1 región → continuar con topology, entrance_solver, corridor carving, door resolver.

3) Tras mover por todas las fases y ejecutar FloodFill:
   - Si FloodFill falla, ejecutar diagnóstico global: diag_global = _flood_fill.get_connectivity_diagnostics(grid, rooms)
   - Identificar si las regiones aisladas pertenecen claramente a:
     - habitaciones (ya deberían estar resueltas, rare)
     - corredores (usar corridor id / path maps)
     - puertas/entrances (entrance pairs mismatched)
   - Invocar CorridorConnectivityRepair si corresponde; invocar Door repair solo en fase de puertas si se ha determinado.
   - Revalidar y sólo si irreparable → continue (nuevo attempt basado en base_seed + (attempt+1))

Pseudocódigo integrado (extracto para patch)
---------------------------------------------
  # tras _build_rooms(...)
  var room_failures := []
  for r in rooms:
      var r_val = _StructuralValidatorScript.validate_room_internal_connectivity(grid, r)
      if not r_val["is_valid"]:
          room_failures.append({"room": r, "diag": r_val})

  if room_failures.size() > 0:
      for rf in room_failures:
          var repair_seed = _DungeonSeedFactoryScript.derive_seed(base_seed, attempt, "repair-room-%d" % rf.room.id)
          var rep := RoomConnectivityRepair.repair_room_internal_connectivity(grid, rf.room, rf.diag, repair_seed, config.max_room_repair_attempts)
          if not rep.success:
              push_warning("Attempt %d: Room %d irreparable locally after repairs. Marking attempt as failed." % [attempt, rf.room.id])
              continue # goto try next attempt in outer loop
          # revalidate single room
          var after_val = _StructuralValidatorScript.validate_room_internal_connectivity(grid, rf.room)
          if not after_val["is_valid"]:
              push_warning("Attempt %d: Room %d still invalid after local repairs." % [attempt, rf.room.id])
              continue # try next attempt

Firme separación UI / pipeline
-------------------------------
- Mantener last_valid_result en el gestor de dungeon (DungeonManager). generate() se ejecuta en pipeline sin destruir el result vigente hasta recibir generation_completed(result).
- generation_failed debe emitir una estructura:
  {
    "seed": base_seed,
    "attempts": attempt+1,
    "reason": "ROOM_CONNECTIVITY",
    "affected_rooms": [3,5,6],
    "diagnostics": diag
  }
- La UI mostrará modal con esos datos y botón [Reintentar] que vuelve a llamar generate(config, max_retries, force_new_seed=false).

Pruebas (tests/)
----------------
Objetivo estricto para la semilla 12345:
- Test que fije config.use_fixed_seed=true, config.seed=12345 y capture el layout inmediato tras _build_rooms (snapshot de CellGrid), validar que las regiones detectadas coinciden con un archivo de fixtures (p. ej. tests/fixtures/seed_12345_initial_regions.json).
- Ejecutar RoomConnectivityRepair con los mismos inputs y repair_seed derivado y comparar CellGrid final con un snapshot esperado (tests/fixtures/seed_12345_after_repair.grid).
- Ejecutar pipeline completo con generación determinista (mismo orden de RNG derive_seed) y comprobar que:
  - seed_used == base_seed
  - fixtures de final CellGrid coinciden
  - chain_of_repair_seeds == [ "repair-room-3:xxxx", ... ]

Checklist PR
------------
- [ ] Añadir archivos de reparación en src/dungeon_generator/core/repair/
- [ ] Modificar dungeon_pipeline.gd: hooks de diagnosis y llamadas a room repair justo después de _build_rooms
- [ ] No tocar reparación de puertas en esta fase; parchear sólo habitaciones + corredor escalado si es necesario más tarde.
- [ ] Añadir tests unitarios e integración: validators, repair modules, pipeline
- [ ] Añadir logging estructurado: seed, derived seeds, repairs applied
- [ ] Documentar los cambios en implementation_plan-v3.md (o añadir este fichero nuevo)

Estimación de esfuerzo
----------------------
- Corregir warning ternario, UI: 0.5–1 día
- Implementar RoomConnectivityRepair + hooks en pipeline + tests básicos: 1.5–3 días
- Implementar CorridorConnectivityRepair escalable y tests: 1–2 días
- Tests integrados de seed determinista y CI: 1 día
Total: 4–7 días.

Siguientes pasos (que puedo hacer ahora)
---------------------------------------
- Generar un patch (diff) para dungeon_pipeline.gd que añada los hooks de diagnosis y llamadas a RoomConnectivityRepair.
- Crear el stub file src/dungeon_generator/core/repair/room_connectivity_repair.gd con implementación determinista y limitaciones por room.rect.
- Añadir tests iniciales y fixtures para seed 12345.

¿Quieres que cree ya el archivo markdown en el repositorio (implementation_plan_6.1.1.md) con este contenido y/o que genere los stubs/patches mencionados listos para PR?