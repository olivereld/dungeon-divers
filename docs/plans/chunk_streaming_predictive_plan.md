# Plan de Implementación — Eliminar Freeze durante Streaming de Chunks

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminar completamente los micro-freezes y caídas bruscas de FPS (`60 -> 7 -> 60`) al cruzar límites de chunks mediante generación hidrológica 100% asíncrona en workers, activación visual incremental por etapas con presupuesto de tiempo real inter-etapa en Main Thread, y correcta separación de radios (VISIBLE, PRELOAD, CACHE).

**Architecture:**
1. **Hidrología Desacoplada y Asíncrona:** Eliminar toda llamada síncrona a `_ensure_macro_hydrology` del Main Thread. El `ChunkGenerationScheduler` o un worker genera regiones hidrológicas antes de que los chunks dependientes entren en `ChunkState.GENERATING`. Los chunks esperan en `WAITING_HYDROLOGY` de forma no bloqueante.
2. **Activación Incremental por Etapas (Frame Budget Real):** Romper la activación monolítica del chunk (`_build_chunk_view`) en etapas discretas:
   `TERRAIN_MESH` $\to$ `COLLISION` $\to$ `WATER` $\to$ `POI` $\to$ `VEGETATION` $\to$ `VISIBLE`.
   El presupuesto (`activation_budget_ms = 2.0`, `max_chunk_activations_per_frame = 1`) se valida **entre etapas**, deteniendo la ejecución y continuando en el siguiente frame si se agota el presupuesto. Además, la creación física pesada (`create_trimesh_shape()`) se limita estrictamente a máximo 1 por frame.
3. **Manejo Estricto de Radios:**
   - `VISIBLE` (radio 2): Chunks con nodos instanciados y visibles en el SceneTree.
   - `PRELOAD` (radio 5): Chunks generados y mantenidos en `READY` (`ChunkData` en memoria), sin instanciar nodos ni saturar el SceneTree.
   - `CACHE` (radio 8): Chunks que salieron del radio visible cuyos nodos fueron liberados (`queue_free()`), pero conservan su `ChunkData` para reutilización inmediata sin regenerar.

**Tech Stack:** Godot 4.6.1 (GDScript), Threads, Mutex, Semaphore, ArrayMesh, Trimesh Collision.

**Spec:** Documento de requerimientos *Plan Técnico — Eliminar Freeze durante Streaming de Chunks*.

## Global Constraints
- Ninguna generación de hidrología (`generate_regional_hydrology`) o chunk (`WorldPipeline.generate_chunk`) puede ocurrir en el Main Thread durante el gameplay.
- Presupuesto de activación en Main Thread: `activation_budget_ms = 2.0`, con verificación continua entre etapas.
- Máximo 1 `create_trimesh_shape()` por frame.
- Cero llamadas a `flush_pending()` en el flujo normal de juego (solo permitido en tests/shutdown).
- Mantener compatibilidad 100% con el pipeline existente de mazmorras y POIs.
- Un único test de integración en `src/world_generator/tests/test_chunk_streaming_integration.gd`.

---

## File Structure & Responsibilities

| File | Status | Responsibility |
| --- | --- | --- |
| `src/world_generator/chunks/chunk_state.gd` | Modify | Añadir estado `WAITING_HYDROLOGY` y campos de etapas de activación a `ChunkRecord`. |
| `src/world_generator/chunks/hydrology_region_cache.gd` | Modify | Permitir reservas asíncronas no bloqueantes y consultas atómicas de estado de regiones (`is_region_ready`, etc.). |
| `src/world_generator/chunks/chunk_generation_scheduler.gd` | Modify | Manejar generación asíncrona de macro-regiones hidrológicas en workers, resolviendo dependencias de chunks `WAITING_HYDROLOGY`. |
| `src/world_generator/chunks/chunk_manager.gd` | Modify | Eliminar `_ensure_macro_hydrology` del flujo síncrono. Manejar separación de `PRELOAD` (mantener `READY` sin emitir a vista) y `CACHE` (reutilizar `ChunkData` sin regenerar). |
| `src/world_generator/chunks/chunk_activation_scheduler.gd` | Modify | Implementar máquina de estados de activación incremental inter-frame (`TERRAIN_MESH` $\to$ `COLLISION` $\to$ `WATER` $\to$ `POI` $\to$ `VEGETATION`), chequeo de budget entre etapas y límite de 1 trimesh/frame. |
| `src/world_generator/chunks/chunk_world.gd` | Modify | Coordinar `VISIBLE`, `PRELOAD` y `CACHE`. Desasociar nodos visuales al salir de `VISIBLE` y retener datos en caché. Telemetría de frame y tiempos por etapa. |
| `src/world_generator/scenes/chunk_world_integration.gd` | Modify | Actualizar telemetría visual del HUD (`ready_chunks`, `activation_total_ms`, desglose de etapas, FPS sin freeze). |
| `src/world_generator/tests/test_chunk_streaming_integration.gd` | Modify | Test integral unificado: request $\to$ hydrology async $\to$ generation async $\to$ READY $\to$ activation incremental $\to$ VISIBLE $\to$ cache $\to$ reuse. |

---

### Task 1: Estados de Ciclo de Vida y Soporte para Hidrología Asíncrona

**Files:**
- Modify: `src/world_generator/chunks/chunk_state.gd:1-41`
- Modify: `src/world_generator/chunks/hydrology_region_cache.gd:1-92`

**Interfaces:**
- Consumes: `WorldPipeline.generate_regional_hydrology`
- Produces: `ChunkLifecycle.ChunkState.WAITING_HYDROLOGY`, `HydrologyRegionCache.is_region_ready(macro_coord)`, `HydrologyRegionCache.request_region_async(macro_coord)`

- [ ] **Step 1: Actualizar `chunk_state.gd` con `WAITING_HYDROLOGY` y etapas de activación incremental**
  Agregar al enum `ChunkState`:
  ```gdscript
  enum ChunkState {
      UNREQUESTED = 0,
      WAITING_HYDROLOGY = 1,
      QUEUED = 2,
      GENERATING = 3,
      READY = 4,
      ACTIVATING = 5,
      VISIBLE = 6,
      CACHED = 7
  }
  ```
  Y añadir constantes de etapas de activación (`ActivationStage`: `NONE`, `TERRAIN_MESH`, `COLLISION`, `WATER`, `POI`, `VEGETATION`, `COMPLETE`).

- [ ] **Step 2: Extender `hydrology_region_cache.gd` para consulta no bloqueante y generación thread-safe**
  Asegurar que `ensure_bounds` o `get_or_generate_region` no bloqueen el hilo llamante si se solicita desde Main Thread, permitiendo verificar si las regiones requeridas ya están listas:
  - `has_region(macro_coord: Vector2i) -> bool`
  - `is_region_ready(macro_coord: Vector2i) -> bool`
  - `get_required_macro_coords(bounds: Rect2i, macro_w: int, macro_h: int) -> Array[Vector2i]`
  - `generate_region_worker(macro_coord: Vector2i, macro_w: int, macro_h: int) -> HydrologyResult` (para ser llamada exclusivamente en workers).

- [ ] **Step 3: Ejecutar suite de pruebas actual para validar compatibilidad básica**
  Comando:
  ```powershell
  Start-Process -FilePath 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe' -ArgumentList '--headless', '--path', '.', '-s', 'res://src/world_generator/tests/test_chunk_streaming_integration.gd' -NoNewWindow -Wait
  ```

---

### Task 2: Generación Asíncrona de Hidrología en `ChunkGenerationScheduler` y Desacople en `ChunkManager`

**Files:**
- Modify: `src/world_generator/chunks/chunk_generation_scheduler.gd:1-227`
- Modify: `src/world_generator/chunks/chunk_manager.gd:126-335`

**Interfaces:**
- Consumes: `HydrologyRegionCache`, `WorldPipeline`
- Produces: Eliminación total de `_ensure_macro_hydrology` del flujo de Main Thread en `_enqueue_chunk_generation()`. Solicitud asíncrona de hidrología delegada a los workers.

- [ ] **Step 1: Eliminar `_ensure_macro_hydrology(coord)` de `_enqueue_chunk_generation()` en `chunk_manager.gd`**
  Garantizar que `_enqueue_chunk_generation` solo asigne token y encole la solicitud al scheduler sin calcular hidrología en Main Thread.

- [ ] **Step 2: Actualizar `ChunkGenerationScheduler` para resolver hidrología en segundo plano**
  En `ChunkGenerationScheduler`:
  - Permitir encolar tareas de generación de hidrología regional con alta prioridad o procesar dependencias de hidrología en el worker antes de invocar `generate_chunk`.
  - Cuando el worker toma un `ChunkRequest`, si requiere hidrología regional y esta no está lista en `hydrology_cache`, el worker la genera en su propio hilo secundario y la guarda en `hydrology_cache` antes de procesar el chunk.

- [ ] **Step 3: Probar que la generación en workers no congela el hilo principal**
  Verificar que `test_chunk_streaming_integration.gd` continúe pasando de forma asíncrona.

---

### Task 3: Activación Incremental Inter-Frame con Presupuesto Real (`ChunkActivationScheduler`)

**Files:**
- Modify: `src/world_generator/chunks/chunk_activation_scheduler.gd:1-204`

**Interfaces:**
- Consumes: `ChunkData`, `TerrainMeshBuilder`, `WorldRenderer`
- Produces: Activación fragmentada por micro-etapas (`TERRAIN_MESH` $\to$ `COLLISION` $\to$ `WATER` $\to$ `POI` $\to$ `VEGETATION`), `last_frame_collision_count`, desglose de telemetría de tiempos por etapa.

- [ ] **Step 1: Definir clase `ActivationTask` para persistir el progreso de construcción de un chunk**
  ```gdscript
  class ActivationTask:
      var coord: Vector2i
      var chunk_data: ChunkData
      var priority: float
      var token: int
      var stage: int = Stage.TERRAIN_MESH
      var chunk_view: Node3D = null
      var terrain_mesh: ArrayMesh = null
      # Tiempos de telemetría acumulados
      var time_terrain_ms: float = 0.0
      var time_collision_ms: float = 0.0
      var time_water_ms: float = 0.0
      var time_poi_ms: float = 0.0
      var time_vegetation_ms: float = 0.0
  ```

- [ ] **Step 2: Implementar ejecución incremental con chequeo de presupuesto entre etapas**
  En `process_activations`:
  - Si el presupuesto (`budget_ms`, ej. 2.0 ms) se supera al terminar una etapa, guardar el estado en `task.stage`, detener el procesamiento y continuar en el siguiente frame.
  - Limitar la etapa de `COLLISION` (`create_trimesh_shape()`) a máximo 1 operación pesada por frame.
  - Emitir `chunk_activated` solo cuando se completen todas las etapas (`Stage.COMPLETE`).

- [ ] **Step 3: Agregar telemetría granular de activación**
  Registrar métricas públicas en `ChunkActivationScheduler`:
  - `telemetry_terrain_ms`
  - `telemetry_collision_ms`
  - `telemetry_water_ms`
  - `telemetry_vegetation_ms`
  - `telemetry_total_activation_ms`

---

### Task 4: Separación Estricta de Radios (VISIBLE, PRELOAD, CACHE) y Manejo de Ciclo de Vida

**Files:**
- Modify: `src/world_generator/chunks/chunk_manager.gd`
- Modify: `src/world_generator/chunks/chunk_world.gd`

**Interfaces:**
- Consumes: `ChunkLifecycle.ChunkState`, `ChunkActivationScheduler`
- Produces: `PRELOAD` genera y mantiene `READY` sin instanciar `ChunkView`. `VISIBLE` instantiates incrementalmente. Al salir de `VISIBLE`, libera `ChunkView` pero retiene `ChunkData` en `CACHE`.

- [ ] **Step 1: Ajustar `ChunkManager` para clasificar chunks requeridos por radio**
  Diferenciar entre chunks que deben pasar a `VISIBLE` (radio 2) vs chunks en `PRELOAD` (radio 5):
  - Chunks en `PRELOAD` se generan en workers y quedan en `loaded_chunks` / `READY`.
  - Solo los chunks dentro del radio `VISIBLE` son enviados al `ChunkActivationScheduler`.

- [ ] **Step 2: Gestión de Salida de Visibilidad y Caché en `ChunkWorld`**
  Cuando un chunk sale de `visible_radius`:
  - Si está dentro de `cache_radius` (radio 8): remover y liberar el nodo `ChunkView` (`queue_free()`), cancelar activaciones pendientes en scheduler, pero **conservar** el `ChunkData` en `ChunkManager` (marcado como `CACHED`).
  - Si el jugador regresa al chunk, transicionar inmediatamente de `CACHED` a la cola de activación sin pedir regeneración a los workers.
  - Solo si sale de `cache_radius` se descarga completamente (`unload_chunk`).

- [ ] **Step 3: Bootstrap inicial no bloqueante en `chunk_world.gd`**
  Modificar `bootstrap_minimum_area()`:
  - Generar y activar de forma inmediata únicamente el chunk central o radio 1 mínimo para el suelo inicial del jugador.
  - No llamar a `flush_pending()` en el loop de juego ni bloquear el frame. Encolar el resto en background.

---

### Task 5: Telemetría en HUD y Actualización del Test de Integración Unificado

**Files:**
- Modify: `src/world_generator/scenes/chunk_world_integration.gd`
- Modify: `src/world_generator/tests/test_chunk_streaming_integration.gd`

**Interfaces:**
- Consumes: Métricas de `ChunkActivationScheduler`, `ChunkManager`, `HydrologyRegionCache`
- Produces: Visualización completa de telemetría en HUD y test extremo a extremo validando que no hay bloqueos.

- [ ] **Step 1: Actualizar telemetría del HUD en `chunk_world_integration.gd`**
  Mostrar métricas requeridas:
  - `generation_queue`, `ready_chunks`, `activation_queue`, `visible_chunks`, `cached_chunks`.
  - Tiempos de activación detallados: `terrain_ms`, `collision_ms`, `water_ms`, `vegetation_ms`, `total_ms`.
  - Detección visual de picos de frame (> 16.6 ms).

- [ ] **Step 2: Actualizar `test_chunk_streaming_integration.gd` para validar el pipeline completo sin bloqueos**
  Comprobar en una única suite continua:
  1. `REQUEST`: petición asíncrona de chunk.
  2. `HYDROLOGY ASYNC`: generación de región hidrológica en background sin llamadas bloqueantes en Main Thread.
  3. `GENERATION ASYNC`: worker produce `ChunkData`.
  4. `READY`: chunk permanece en memoria sin crear nodos.
  5. `INCREMENTAL ACTIVATION`: activación por etapas respetando `budget_ms <= 2.0 ms` y límite de colisiones.
  6. `VISIBLE`: nodo instanciado en el SceneTree.
  7. `CACHE`: al alejarse, nodo eliminado de escena pero `ChunkData` preservado.
  8. `REUSE`: reingreso al radio visible activa directamente desde memoria sin reencolar en workers.

- [ ] **Step 3: Ejecutar pruebas automáticas y verificar aprobación 100%**
  Ejecutar el test de streaming y los tests de regresión de mazmorras en Godot Headless.
