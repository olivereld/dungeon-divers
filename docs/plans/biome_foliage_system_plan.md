# Sistema de Foliage Procedural Ligado a Biomas — Plan de Implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar un sistema de foliage procedural estilizado (hierba, césped, plantas pequeñas) ligado a `BiomeDefinition`, determinista, generado por chunks en worker threads y renderizado mediante `MultiMeshInstance3D` con vertex shader de viento y soporte para las texturas del proyecto (`assets/texture/foliage/grass`).

**Architecture:**
- `BiomeDefinition` aloja un `FoliageProfile` desacoplado con array de `FoliageSpecies`.
- `FoliageGenerator` genera datos puros (`FoliageChunkData`) en worker thread a partir de celdas, hidrología y coordenadas mundiales, sin raycasts.
- `FoliageMultiMeshBuilder` y `FoliageRenderer` materializan las instancias en el Main Thread mediante `MultiMeshInstance3D` con geometría crossed-quads.
- `foliage_wind.gdshader` anima el viento en GPU según la posición mundial de cada vértice y su altura (`UV.y`).

**Tech Stack:** Godot 4.6 (GDScript + Spatial Shader + MultiMeshInstance3D + ArrayMesh procedural).

---

## Restricciones Globales (Global Constraints)

1. **Zero raycasts:** Prohibido realizar consultas de físicas/raycasting por cada brizna de hierba. La elevación y pendiente se derivan matemáticamente de `WorldCell` y el terreno triangulado existente.
2. **Worker Thread Isolation:** Prohibido instanciar nodos del SceneTree o mallas en el worker thread. El generador solo produce datos de arrays planos (`Vector3`, `Transform3D`, `Color`).
3. **No Biome Hardcoding:** El generador de foliage y los renderers no deben contener sentencias del tipo `if biome == TAIGA`. Toda la parametrización proviene exclusivamente de `FoliageProfile` y `FoliageSpecies`.
4. **Hydrology Authority:** El follaje terrestre nunca debe generarse sobre agua o dentro de lechos fluviales; debe consultar la autoridad de `HydrologyResult`.
5. **Determinismo Mundial:** Las instancias deben depender de la posición mundial global `(world_x, world_z)` y la semilla `world_seed`, garantizando continuidad perfecta entre costuras de chunks vecinos.

---

## Tareas de Implementación

### Tarea 1: Contratos de Datos y Perfiles de Foliage (`FoliageProfile`, `FoliageSpecies`, `FoliageChunkData`)

**Archivos:**
- Crear: `src/world_generator/foliage/foliage_species.gd`
- Crear: `src/world_generator/foliage/foliage_profile.gd`
- Crear: `src/world_generator/foliage/foliage_chunk_data.gd`
- Modificar: `src/world_generator/biomes/biome_definition.gd`
- Test: `src/world_generator/tests/test_foliage_contracts.gd`

**Interfaces:**
- `FoliageSpecies`: Recurso exportado que define:
  - `id: StringName`
  - `display_name: String`
  - `texture_path: String` (ej: `"res://assets/texture/foliage/grass/large_grass_01.jpg"`)
  - `density_weight: float = 1.0`
  - `scale_min: Vector3 = Vector3(0.8, 0.8, 0.8)`
  - `scale_max: Vector3 = Vector3(1.2, 1.3, 1.2)`
  - `max_slope: float = 25.0`
  - `color_bottom: Color`
  - `color_top: Color`
  - `quad_cross_count: int = 2` (2 o 3 quads cruzados)
- `FoliageProfile`: Recurso exportado que define:
  - `base_density: float = 1.0` (factor multiplicador por celda)
  - `species: Array[FoliageSpecies] = []`
  - `min_height: float = 0.0`
  - `max_height: float = 1.0`
  - `water_clearance: float = 1.0`
  - `max_slope: float = 28.0`
  - `noise_frequency: float = 0.08` (ruido para claros/parches)
- `FoliageChunkData`: Estructura ligera de datos que almacena:
  - `chunk_coord: Vector2i`
  - `instances_by_species: Dictionary` (mapping `species_id -> Array[Transform3D]`)
  - `colors_by_species: Dictionary` (mapping `species_id -> PackedColorArray`)
- `BiomeDefinition`:
  - Campo añadido: `@export var foliage_profile: Resource = null`

- [x] **Paso 1.1: Escribir el test de contrato `test_foliage_contracts.gd` que valida la creación y serialización de `FoliageSpecies`, `FoliageProfile` y `BiomeDefinition.foliage_profile`.**
- [x] **Paso 1.2: Implementar `FoliageSpecies` en `src/world_generator/foliage/foliage_species.gd`.**
- [x] **Paso 1.3: Implementar `FoliageProfile` en `src/world_generator/foliage/foliage_profile.gd`.**
- [x] **Paso 1.4: Implementar `FoliageChunkData` en `src/world_generator/foliage/foliage_chunk_data.gd`.**
- [x] **Paso 1.5: Actualizar `BiomeDefinition` para recibir y almacenar `foliage_profile`.**
- [x] **Paso 1.6: Ejecutar `test_foliage_contracts.gd` y verificar que pasa al 100%.**

---

### Tarea 2: Mallas Procedurales de Hierba Cruzada (Crossed-Quads)

**Archivos:**
- Crear: `src/world_generator/foliage/rendering/foliage_mesh_factory.gd`
- Test: `src/world_generator/tests/test_foliage_mesh.gd`

**Detalles Técnicos:**
- Genera un `ArrayMesh` programáticamente con 2, 3 o 4 quads cruzados en el eje Y.
- Cada vértice incluye:
  - `POSITION`: Centrado horizontalmente en `(0, y, 0)` desde el origen base $Y=0$ hasta la altura del quad.
  - `UV`: Coordenadas $[0, 1]$ mapeando la textura de hierba.
  - `UV2`: Coordenadas donde `UV2.y = UV.y` almacena la máscara de viento (0 en la raíz, 1 en la punta).
  - `NORMAL`: Normales orientadas hacia arriba estilizadas (`vec3(0.0, 1.0, 0.0)` con suave sesgo radial) para iluminación toon uniforme.

- [x] **Paso 2.1: Crear test `test_foliage_mesh.gd` comprobando que las mallas generadas tienen los vértices, UVs y normales correctos.**
- [x] **Paso 2.2: Implementar `FoliageMeshFactory` con soporte de 2 quads en X (90°) y 3 quads estrellados (60°).**
- [x] **Paso 2.3: Validar que `test_foliage_mesh.gd` pasa correctamente.**

---

### Tarea 3: Shader de Foliage y Viento (`foliage_wind.gdshader`)

**Archivos:**
- Crear: `src/world_renderer/shaders/foliage_wind.gdshader`
- Crear: `src/world_generator/foliage/rendering/foliage_material.gd`

**Características del Shader:**
- Modo espacial: `cull_disabled`, `depth_draw_opaque`, `diffuse_toon`.
- **Texturas & Alpha:** `uniform sampler2D texture_albedo : source_color`, compatible con `alpha_scissor_threshold` (e.g. 0.35) o lum-cutoff para texturas JPEG.
- **Gradiente Vertical:** Interpolación de color entre `color_bottom` (raíz oscura integrada con el suelo) y `color_top` (puntas iluminadas).
- **Viento Procedural por Vértice:**
  - Vértice base ($Y=0$) estático sin desplazamiento.
  - Desplazamiento horizontal gobernado por:
    $\Delta P = \text{wind\_dir} \cdot \sin(\text{TIME} \cdot \text{speed} + \text{world\_pos.xz} \cdot \text{freq}) \cdot (\text{UV.y})^2 \cdot \text{strength}$.
  - Soporte de ráfagas suaves con variación de fase única por instancia / posición mundial.

- [x] **Paso 3.1: Escribir `foliage_wind.gdshader` con lógica de viento, alpha scissor e iluminación Half-Lambert.**
- [x] **Paso 3.2: Implementar la factoría de material en `src/world_generator/foliage/rendering/foliage_material.gd` que cachea y parametriza materiales por especie.**

---

### Tarea 4: Generador Procedural en Worker (`FoliageGenerator`)

**Archivos:**
- Crear: `src/world_generator/foliage/foliage_generator.gd`
- Test: `src/world_generator/tests/test_foliage_generator.gd`

**Algoritmo de Generación:**
1. Itera las celdas dentro de `core_bounds` del chunk (o mundo).
2. Lee `cell.biome_id` y obtiene `biome_def = biome_registry.get_definition(cell.biome_id)`.
3. Si el bioma no tiene `foliage_profile` o `foliage_profile.species.is_empty()`, omite.
4. Aplica filtros geométricos rápidos:
   - Exclusión de agua: consulta `hydrology.is_water(cell_pos)` o `cell.is_water`.
   - Exclusión de pendiente excesiva: `local_slope > profile.max_slope` o acantilados.
   - Exclusión de rocas / zonas no caminables si corresponde.
5. Ruido espacial continuo: FastNoiseLite en `(world_x, world_z)` para crear parches naturales (zonas densas vs claros abiertos).
6. Para cada sub-brizna (0..N instancias por celda):
   - Deriva una sub-semilla determinista: `hash(world_seed, x, y, instance_idx)`.
   - Selecciona especie según pesos de `FoliageSpecies.density_weight`.
   - Aplica jitter sub-celda y muestrea la altura $Y$ del terreno triangulado.
   - Calcula rotación Y aleatoria y variación de escala.
   - Agrega la transformación y color de instancia a `FoliageChunkData`.

- [x] **Paso 4.1: Escribir test `test_foliage_generator.gd` validando determinismo, ausencia de plantas en agua y distribución natural.**
- [x] **Paso 4.2: Implementar `FoliageGenerator.generate_chunk_foliage(...)`.**
- [x] **Paso 4.3: Ejecutar `test_foliage_generator.gd` y validar que el generador es completamente determinista y orden-independiente.**

---

### Tarea 5: MultiMesh Builder y Renderer (`FoliageRenderer`)

**Archivos:**
- Crear: `src/world_generator/foliage/rendering/foliage_multimesh_builder.gd`
- Crear: `src/world_generator/foliage/rendering/foliage_renderer.gd`
- Test: `src/world_generator/tests/test_foliage_renderer.gd`

**Funcionalidades:**
- Transforma `FoliageChunkData` en uno o varios `MultiMeshInstance3D` por chunk (agrupados por `FoliageSpecies`).
- Configura `MultiMesh.transform_format = TRANSFORM_3D` y `use_colors = true`.
- Asigna la malla crossed-quads correspondiente y el material con shader de viento.
- Expone `build_chunk_foliage_node(data: FoliageChunkData) -> Node3D`.

- [x] **Paso 5.1: Escribir test `test_foliage_renderer.gd` que valida la creación de nodos `MultiMeshInstance3D` y asignación de transforms.**
- [x] **Paso 5.2: Implementar `FoliageMultiMeshBuilder` y `FoliageRenderer`.**
- [x] **Paso 5.3: Validar que `test_foliage_renderer.gd` pasa correctamente.**

---

### Tarea 6: Configuración de Biomas en `BiomeRegistry`

**Archivos:**
- Modificar: `src/world_generator/biomes/biome_registry.gd`
- Modificar perfiles de bioma por defecto para asignar `FoliageProfile`:
  - `TAIGA`: Hierba boreal en turberas y claros con `large_grass_01` y `medium_grass_01`.
  - `TEMPERATE_FOREST`: Hierba templada verde rica y densa.
  - `TUNDRA`: Hierba rala de líquenes y pasto ártico con `single_grass_01`.
  - `DESERT`: Pasto seco escaso (`single_grass_01` en tono pajizo).
  - `JUNGLE`: Follaje denso y exuberante.
  - `ALPINE`: Pastos alpinos de altura en praderas montañosas.
- Test: `src/world_generator/tests/test_biome_foliage_profiles.gd`

- [x] **Paso 6.1: Crear test `test_biome_foliage_profiles.gd` verificando que todos los biomas registrados cuentan con un `FoliageProfile` válido y texturas vinculadas.**
- [x] **Paso 6.2: Definir las fábricas `_create_taiga_foliage()`, `_create_forest_foliage()`, etc., en `BiomeRegistry`.**
- [x] **Paso 6.3: Validar que el test pase al 100%.**

---

### Tarea 7: Integración en el Pipeline de Chunks y Lifecycle de Streaming

**Archivos:**
- Modificar: `src/world_generator/chunks/chunk_data.gd` (añadir propiedad `foliage: FoliageChunkData`)
- Modificar: `src/world_generator/facade/world_pipeline.gd` (ejecutar `FoliageGenerator` en worker)
- Modificar: `src/world_generator/chunks/chunk_world.gd` y `chunk_activation_scheduler.gd` (instanciar foliage en Main Thread)
- Modificar: `src/world_renderer/world_renderer.gd` (renderizar foliage en modo laboratorio)
- Test: `src/world_generator/tests/test_foliage_chunk_streaming.gd`

- [x] **Paso 7.1: Añadir `var foliage: RefCounted = null` a `WorldResult` (heredado por `ChunkData`).**
- [x] **Paso 7.2: Integrar la llamada a `FoliageGenerator` en `WorldPipeline.generate` y `WorldPipeline.generate_chunk`.**
- [x] **Paso 7.3: Conectar la instanciación de `FoliageRenderer` en `ChunkWorld._spawn_chunk_vegetation` y en `WorldRenderer.render_world`.**
- [x] **Paso 7.4: Escribir y ejecutar `test_foliage_chunk_streaming.gd` verificando que al cargar y descargar chunks, los nodos de foliage se liberan limpiamente de la memoria sin leaks.**

---

### Tarea 8: Verificación Final y Telemetría de Rendimiento

**Archivos:**
- Test: `src/world_generator/tests/test_foliage_performance.gd`
- Ejecutar suite completa del proyecto para garantizar cero regresiones.

- [x] **Paso 8.1: Ejecutar benchmark midiendo microsegundos de generación de foliage en worker y tiempo de activación de MultiMesh en Main Thread.**
- [x] **Paso 8.2: Ejecutar `test_world_all.gd`, `test_foliage_performance.gd` y las pruebas de biomas para confirmar 0 regresiones.**
