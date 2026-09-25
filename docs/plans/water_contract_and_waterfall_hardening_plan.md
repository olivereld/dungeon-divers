# Plan de Implementación — Blindaje del Contrato Marino, Continuidad y Corrección de Cascadas

> **Orden de Ejecución:** Seguimiento estricto de los 6 Bloques especificados por el usuario.
> **Regla de oro:** Cero cambios a shaders, shoreline resolver, o mallas base. Si un test falla, se corrige la causa concreta y aislada sin reescrituras especulativas.

---

### Bloque 1: Blindar el Contrato del Fondo Marino (Data Model + Validación en HydrologyStage)
- **Objetivo:**
  Garantizar explícitamente en el pipeline y en el contrato de datos:
  - `water_cells[pos]["water_height"] = H_water`
  - `water_cells[pos]["bed_height"] = H_bed`
  - `water_cells[pos]["depth"] = H_water - H_bed`
  - `cell.height == H_bed`
  - Validación post-etapa en `HydrologyStage`: para cada celda en `hydro.water_cells`, verificar que `cell.height == bed_height` y `bed_height <= water_height`.
- **Archivos:**
  - `src/world_generator/stages/hydrology_stage.gd`: Añadir validación de contrato `_validate_water_bed_contract(cells, hydro)`.
  - `src/world_generator/tests/test_water_height_contract.gd`: Asegurar que ya comprueba explícitamente `cell.height == bed_height` para cada water cell.

---

### Bloque 2: Validación del Fondo Marino Renderizado
- **Objetivo:**
  Para cada `water_cell`:
  - `TerrainMesh Y == bed_height`
  - `bed_height <= water_height`
  Verificar que el fondo renderizado por `TerrainMeshBuilder` sea exactamente el fondo hidráulico (`cell.height == bed_height`).
- **Archivos:**
  - Crear o extender `src/world_generator/tests/test_water_seabed_render_contract.gd` para validar que los vértices del terreno donde hay agua coinciden exactamente con `bed_height`.

---

### Bloque 3: Validación de Continuidad del Agua (Water Continuity Test)
- **Objetivo:**
  Para cada pareja cardinal de `water_cells` adyacentes $(A, B)$:
  - Ambos tienen `water_height` finito.
  - Ambos tienen `bed_height` finito.
  - Ambos tienen `depth >= 0`.
  - Coordenadas de vértices limítrofes coinciden o conectan sin saltos geométricos inesperados (sin gaps verticales abiertos).
- **Archivos:**
  - Crear test `src/world_generator/tests/test_water_continuity.gd`.

---

### Bloque 4: Validación de Costuras entre Chunks (Chunk Seam Test)
- **Objetivo:**
  Generar dos chunks adyacentes ($A$ y $B$) y verificar en su frontera común:
  - `water_height A == water_height B` (tolerancia epsilon)
  - `bed_height A == bed_height B`
  - `terrain height A == terrain height B`
  Garantizar que no aparezcan escalones o gaps entre chunks adyacentes.
- **Archivos:**
  - Crear test `src/world_generator/tests/test_chunk_water_seam.gd`.

---

### Bloque 5: Corrección Aislada de Cascadas
- **Objetivo:**
  En `water_mesh_builder.gd`, un `water_cell` no debe crear cascadas hacia cualquier vecino con menor cota indiscriminadamente.
  Una cascada solo se genera cuando:
  - $A$ es `water_cell`
  - $B$ es vecino cardinal
  - $B$ es `water_cell` y $B.water\_height < A.water\_height - threshold$
  - $B$ es realmente un destino hidráulico válido (p. ej., alineado con la dirección de flujo hidráulico de la celda `flow_dir` o conectado hidráulicamente).
  - **No tocar:** alturas de agua, carving, lagos, ríos, shader. Solo el predicado de decisión de emitir el quad de waterfall.
- **Archivos:**
  - `src/world_generator/presentation/water/water_mesh_builder.gd`: Refinar la condición de generación de waterfalls.
  - `src/world_generator/tests/test_waterfall_mesh_generation.gd`: Ejecutar y verificar.

---

### Bloque 6: Pruebas Visuales y de Regresión
- **Objetivo:**
  Ejecutar el conjunto de tests y verificar renderizado sin regresiones.
