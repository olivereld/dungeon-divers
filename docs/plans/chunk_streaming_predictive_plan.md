# Plan Técnico de Implementación: Streaming Asíncrono y Pre-generación Predictiva del Mundo

## 1. Resumen Ejecutivo y Objetivos

Transformar la generación del mundo procedural por chunks de un modelo síncrono/reactivo a un sistema de **streaming predictivo, desacoplado y asíncrono** guiado por las siguientes directrices arquitectónicas:

1. **Desacoplamiento Estricto:** Separación de lifecycle entre `ChunkData` (datos puros generados en workers CPU) y `ChunkView` (materialización de mallas y colisiones en Main Thread bajo presupuesto).
2. **Modelo de Tres Radios:** Diferenciar `visible_radius`, `preload_radius` y `cache_radius` dentro de `ChunkConfig`.
3. **Predicción Cinemática Barata:** `ChunkStreamingController` proyecta la posición futura del jugador según su vector de velocidad para priorizar chunks en la dirección de avance.
4. **Cola Priorizada con Cancelación e Inmunidad a Tokens Obsoletos:** `ChunkGenerationScheduler` reordena peticiones por urgencia relativa y descarta resultados con tokens caducados.
5. **Hidrología Regional Asíncrona:** Extracción de `_ensure_macro_hydrology` a `HydrologyRegionCache` con estados `UNREQUESTED`, `GENERATING`, `READY`.
6. **Planificador de Activación con Presupuesto de Frame:** `ChunkActivationScheduler` controla la instanciación de mallas, colisiones, agua, POIs y vegetación para no superar `activation_budget_ms` (por defecto 2.0 ms).
7. **Bootstrap Rápido:** Inicio de gameplay con activación exclusiva del área mínima jugable (sin bloqueos con `flush_pending`).
8. **Test de Integración Unificado:** `src/world_generator/tests/test_chunk_streaming_integration.gd` validando el ciclo completo extremo a extremo.

---

## 2. Mapa de Archivos e Interfaces

### Archivos Nuevos
| Archivo | Responsabilidad |
|---|---|
| `src/world_generator/chunks/chunk_state.gd` | Define el enum canónico `ChunkState` (`UNREQUESTED`, `QUEUED`, `GENERATING`, `READY`, `ACTIVATING`, `VISIBLE`, `CACHED`) y `ChunkRecord`. |
| `src/world_generator/chunks/chunk_streaming_controller.gd` | Evalúa posición y velocidad del jugador; calcula chunks visibles, preload y cache; aplica predicción direccional. |
| `src/world_generator/chunks/hydrology_region_cache.gd` | Gestión de hidrología macro compartida por regiones con soporte multi-hilo y deduplicación. |
| `src/world_generator/chunks/chunk_activation_scheduler.gd` | Cola priorizada de activación en Main Thread con límite de tiempo por frame (`activation_budget_ms`). |
| `src/world_generator/tests/test_chunk_streaming_integration.gd` | Test unificado de integración para el pipeline de streaming asíncrono. |

### Archivos Modificados
| Archivo | Cambios Principales |
|---|---|
| `src/world_generator/chunks/chunk_config.gd` | Incorporación de `visible_radius`, `preload_radius`, `cache_radius`, `prediction_distance_chunks`, `activation_budget_ms`, `max_chunk_activations_per_frame`. |
| `src/world_generator/chunks/chunk_generation_scheduler.gd` | Reemplazo de cola FIFO simple por cola priorizada con deduplicación, tokens de generación y cancelación explícita. |
| `src/world_generator/chunks/chunk_manager.gd` | Distinción entre `loaded_chunks` (visibles) y `cached_chunks` (en memoria sin view); integración con `HydrologyRegionCache`. |
| `src/world_generator/chunks/chunk_world.gd` | Delegación de orquestación a `ChunkStreamingController` y `ChunkActivationScheduler`; división de `_on_chunk_loaded` en sub-etapas ordenadas; bootstrap inicial ligero. |
| `src/world_generator/scenes/chunk_world_integration.gd` | Actualización de telemetría HUD con métricas del nuevo streaming (queue length, ready chunks, cached chunks, activation ms). |

---

## 3. Desglose de Fases de Implementación (TDD y Pasos Concretos)

### Fase A: Modelo de Lifecycle (`ChunkState` y `ChunkRecord`)
- **Objetivo:** Formalizar los estados del ciclo de vida del chunk y separar `ChunkData != ChunkView`.
- **Archivos:**
  - Crear `src/world_generator/chunks/chunk_state.gd`
- **Detalle de Implementación:**
  - Definir enum `ChunkState`:
    ```gdscript
    enum ChunkState {
        UNREQUESTED,
        QUEUED,
        GENERATING,
        READY,
        ACTIVATING,
        VISIBLE,
        CACHED
    }
    ```
  - Crear clase `ChunkRecord` con campos: `coord: Vector2i`, `state: int`, `token: int`, `data: ChunkData`, `view: Node3D`, `priority: float`, `last_accessed_msec: int`.

---

### Fase B: Configuración Ampliada y `ChunkStreamingController`
- **Objetivo:** Manejar los 3 radios (`visible`, `preload`, `cache`) y predecir la dirección de avance del jugador.
- **Archivos:**
  - Modificar `src/world_generator/chunks/chunk_config.gd`
  - Crear `src/world_generator/chunks/chunk_streaming_controller.gd`
- **Detalle de Implementación:**
  - Añadir a `ChunkConfig`:
    - `var visible_radius: int = 2`
    - `var preload_radius: int = 5`
    - `var cache_radius: int = 8`
    - `var prediction_distance_chunks: float = 2.0`
    - `var activation_budget_ms: float = 2.0`
    - `var max_chunk_activations_per_frame: int = 1`
  - En `ChunkStreamingController`:
    - Función `update_player(player_pos: Vector3, player_velocity: Vector3, cell_size: float, chunk_size: int) -> Dictionary`.
    - Calcular `current_chunk` y `predicted_chunk = current_chunk + round(velocity.normalized() * prediction_distance_chunks)`.
    - Determinar conjuntos de chunks: `visible_set`, `preload_set`, `cache_set`.
    - Calcular prioridad escalar para cada chunk considerando distancia al jugador y ángulo respecto a la velocidad.

---

### Fase C: Scheduler de Generación con Cola de Prioridad y Tokens
- **Objetivo:** Reemplazar el `ChunkGenerationScheduler` FIFO por una cola ordenada por prioridad con cancelación y control estricto de tokens.
- **Archivos:**
  - Modificar `src/world_generator/chunks/chunk_generation_scheduler.gd`
- **Detalle de Implementación:**
  - Cada `ChunkRequest` almacena `priority: float`.
  - Método `request_chunk(coord, seed_val, profile, config, shared_hydro, token, priority: float)`.
  - Método `update_priority(coord: Vector2i, new_priority: float)`.
  - En el worker loop, extraer la solicitud con mayor prioridad (`sort_custom` o inserción ordenada bajo mutex).
  - Invalidador de tokens `invalidate_token(coord, new_token)` y descarte automático si el token de request no coincide con el token activo.

---

### Fase D: Cache de Hidrología Regional Asíncrona
- **Objetivo:** Desacoplar `_ensure_macro_hydrology` del flujo de generación individual de cada chunk.
- **Archivos:**
  - Crear `src/world_generator/chunks/hydrology_region_cache.gd`
  - Modificar `src/world_generator/chunks/chunk_manager.gd`
- **Detalle de Implementación:**
  - Estados por región: `UNREQUESTED`, `GENERATING`, `READY`.
  - Generación de macro-regiones en worker threads o compartidas entre chunks de la misma región.
  - Almacén de regiones con bloqueo concurrente para evitar que múltiples chunks simultáneos disparen la misma región hidrológica.

---

### Fase E: Scheduler de Activación en Main Thread con Presupuesto
- **Objetivo:** Escalonar la materialización 3D (malla, colisión, agua, vegetación, POIs) en el Main Thread respetando un frame budget.
- **Archivos:**
  - Crear `src/world_generator/chunks/chunk_activation_scheduler.gd`
  - Modificar `src/world_generator/chunks/chunk_world.gd`
- **Detalle de Implementación:**
  - Encolar `ChunkData` en estado `READY`.
  - Durante cada `_process` en `ChunkWorld`:
    - Medir tiempo transcurrido con `Time.get_ticks_usec()`.
    - Activar chunks ordenados por urgencia (1: visibles urgentes, 2: visibles, 3: predecidos).
    - Orden de construcción de cada chunk:
      1. `TerrainMesh`
      2. `TerrainCollision`
      3. `Water`
      4. `DungeonEntrancePOIView`
      5. `Vegetation`
    - Detener activación cuando `elapsed_ms >= activation_budget_ms` o se alcance `max_chunk_activations_per_frame`.

---

### Fase F: Cache de Datos y Política de Descarga
- **Objetivo:** Mantener `ChunkData` en caché al salir de `visible_radius` y liberar únicamente al exceder `cache_radius`.
- **Archivos:**
  - Modificar `src/world_generator/chunks/chunk_manager.gd`
- **Detalle de Implementación:**
  - Estructuras en `ChunkManager`:
    - `loaded_chunks: Dictionary` (visibles activos).
    - `cached_chunks: Dictionary` (chunks con datos generados en memoria, listos para activación inmediata sin recalcular).
  - Transición cuando un chunk sale de `visible_radius`:
    - `VISIBLE -> CACHED` (libera su `ChunkView` visual/colisión pero retiene el `ChunkData`).
  - Transición cuando sale de `cache_radius`:
    - `CACHED -> RELEASED` (libera completamente de memoria).
  - Reingreso: Si el jugador regresa antes de abandonar `cache_radius`, se reactiva inmediatamente sin re-generar en workers.

---

### Fase G: Bootstrap Inicial Liviano y Eliminación de `flush_pending` en Gameplay
- **Objetivo:** Iniciar la partida instantáneamente cargando únicamente la zona visible inmediata (radio 1-2) y delegar el resto al streaming en background.
- **Archivos:**
  - Modificar `src/world_generator/chunks/chunk_world.gd`
  - Modificar `src/world_generator/scenes/chunk_world_integration.gd`
- **Detalle de Implementación:**
  - Sustituir `load_initial_area` bloqueante por `bootstrap_minimum_area(center_coord)` que solo espera el chunk inicial y sus vecinos inmediatos directos.
  - El jugador puede moverse inmediatamente mientras los círculos de preload se calculan en background.
  - `flush_pending()` y `flush_async_queue()` se reservan exclusivamente para pruebas unitarias y shutdown.

---

### Fase H: Telemetría y Test Unificado de Integración
- **Objetivo:** Monitoreo visual de la cola y validación automatizada completa.
- **Archivos:**
  - Crear `src/world_generator/tests/test_chunk_streaming_integration.gd`
  - Modificar `src/world_generator/scenes/chunk_world_integration.gd` (HUD con métricas avanzadas)
- **Casos del Test de Integración:**
  1. **Determinismo:** El mismo chunk genera idéntico `ChunkData` antes y después de pasar por la cola priorizada.
  2. **Deduplicación:** No se encolan peticiones duplicadas para la misma coordenada.
  3. **Cancelación por Token:** Al cambiar rápidamente de posición, las peticiones obsoletas se descartan sin insertarse en el mundo.
  4. **Transición de Estados:** `UNREQUESTED -> QUEUED -> GENERATING -> READY -> ACTIVATING -> VISIBLE -> CACHED`.
  5. **Hit de Caché:** Chunks que salen del radio visible y regresan se activan desde `cached_chunks` sin pasar por el scheduler de generación.
  6. **Cumplimiento de Presupuesto:** Comprobar que el scheduler de activación no excede el frame budget asignado en Main Thread.

---

## 4. Criterios de Aceptación
- [ ] Ejecución de `test_chunk_streaming_integration.gd` con código de salida `0` y 100% de verificaciones aprobadas en Godot headless.
- [ ] Ningún stage procedural (`TerrainStage`, `HydrologyStage`, etc.) contiene lógica de streaming.
- [ ] Invariante $VISIBLE < PRELOAD < CACHE$ preservado en todo momento.
- [ ] Ausencia de congelamiento de pantalla al navegar a través de chunks en `chunk_world_integration.tscn`.
- [ ] El sistema de entradas a mazmorras y POIs continúa funcionando sin alteración.
