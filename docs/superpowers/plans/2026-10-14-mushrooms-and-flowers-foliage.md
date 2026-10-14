# Hongos y Flores en el Sistema de Foliage — Plan de Implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrar hongos y flores al sistema de foliage procedural existente utilizando las nuevas texturas de quads cruzados, generando texturas y colores de gradiente botánicos optimizados, modulando su distribución según hábitat ecológico (sombra bajo dosel para hongos, claros y praderas soleadas para flores) y manteniendo compatibilidad total con MultiMeshInstance3D y shaders de viento.

**Architecture:** 
- `FoliageSpecies` se extiende con `FoliageType` (`GRASS`, `FLOWER`, `MUSHROOM`), control de influencia de textura gradiente (`gradient_influence`), preferencia de dosel (`canopy_preference`) y control de tinte de terreno (`tint_with_grass_color`).
- Se genera una suite de texturas de gradiente botánicas de alta resolución en `assets/texture/foliage/flowers/` y `assets/texture/foliage/mushrooms/` (Amanita, Boletus, Chanterelle, Lavanda, Amapola, Margarita) junto con paletas duales `color_bottom`/`color_top`.
- `foliage_wind.gdshader` y `FoliageMaterial` se actualizan para admitir `gradient_influence` configurable por especie (manteniendo 0.20 para césped y hasta 0.85-1.0 para hongos y flores).
- `FoliageGenerator` modula pesos deterministas por tipo biológico: los hongos se concentran bajo el dosel arbóreo (`DENSE_FOREST`, `OPEN_FOREST`) y suelo húmedo, mientras que las flores colonizan claros (`CLEARING`), bordes (`FOREST_EDGE`) y planicies abiertas (`PLAINS`).
- `BiomeRegistry` y los perfiles de bioma (`taiga`, `temperate_forest`, `tundra`, `jungle`, `alpine`) se equipan con sus especies correspondientes de flores y hongos.

**Tech Stack:** Godot 4.6 (GDScript, FastNoiseLite, MultiMeshInstance3D, Spatial Shader, Image PNG export).

**Spec:** Requerimiento del usuario para incorporar las texturas existentes en `assets/texture/foliage/flowers` y `assets/texture/foliage/mushrooms` al foliage, con generación de gradientes de color y texturas de gradiente adecuadas.

## Global Constraints

1. **Zero raycasts:** Prohibido realizar consultas de físicas/raycasting por cada flor u hongo. Elevación, pendiente y humedad se derivan matemáticamente de `WorldCell` y el mapa procedural.
2. **Worker Thread Isolation:** El generador corre en worker thread y únicamente produce datos puros en `FoliageChunkData` (`Transform3D`, `Color`, `species_id`), sin tocar el `SceneTree`.
3. **Determinismo Estricto por Chunk:** Toda generación depende exclusivamente de `(world_x, world_z)` y `world_seed`. El mismo chunk generado en cualquier orden produce exactamente las mismas instancias.
4. **Respeto a Hidrología y Pendientes:** Hongos y flores nunca se generan sobre agua (`is_water`), lechos de exclusión ni acantilados de roca (`CLIFF`).
5. **No Biome Hardcoding:** Toda parametrización reside en `FoliageProfile`, `FoliageSpecies` y `BiomeDefinition`.
6. **Preservación Visual del Césped:** Los cambios en shader y generador deben preservar al 100% la calibración visual actual del césped existente.

---

## Tareas de Implementación

### Tarea 1: Generación de Texturas de Gradiente Botánicas para Hongos y Flores

**Archivos:**
- Crear: `scripts/generate_foliage_gradients.gd`
- Crear: `assets/texture/foliage/flowers/flower_gradient_lavender.png`
- Crear: `assets/texture/foliage/flowers/flower_gradient_poppy.png`
- Crear: `assets/texture/foliage/flowers/flower_gradient_daisy.png`
- Crear: `assets/texture/foliage/mushrooms/mushroom_gradient_amanita.png`
- Crear: `assets/texture/foliage/mushrooms/mushroom_gradient_boletus.png`
- Crear: `assets/texture/foliage/mushrooms/mushroom_gradient_chanterelle.png`
- Test: `tests/test_foliage_gradient_assets.gd`

**Interfaces:**
- Genera imágenes 512x512 RGBA8 con gradientes verticales anatómicos ($V$ de 0 en ápice/sombrero a 1 en base/raíz) y sutil variación horizontal $U$ (hues y tonos variados por coordenadas de mundo en shader).
- `flower_gradient_lavender.png`: Tallo verde oliva en base $\to$ transición cálida $\to$ pétalos violeta/lila con centro dorado.
- `flower_gradient_poppy.png`: Tallo verde bosque $\to$ corola naranja cálido / rojo amapola silvestre.
- `flower_gradient_daisy.png`: Tallo verde tierno $\to$ corola marfil / blanco crema con cálido disco central amarillo.
- `mushroom_gradient_amanita.png`: Base de micelio grisáceo/loam $\to$ tallo blanco crema/marfil $\to$ anillo $\to$ sombrero rojo escarlata boreal.
- `mushroom_gradient_boletus.png`: Base terrosa $\to$ tallo beige pálido $\to$ sombrero marrón castaño / porcini umbrío.
- `mushroom_gradient_chanterelle.png`: Base crema ocre $\to$ tallo albaricoque $\to$ sombrero amarillo dorado intenso.

- [x] **Paso 1: Escribir el test que falla `tests/test_foliage_gradient_assets.gd`**
...
- [x] **Paso 2: Ejecutar test para verificar que falla**
...
- [x] **Paso 3: Escribir y ejecutar el script generador de gradientes `scripts/generate_foliage_gradients.gd`**
...
- [x] **Paso 4: Ejecutar test para verificar que pasa**
...
- [x] **Paso 5: Commit de la Tarea 1**

```powershell
git add scripts/generate_foliage_gradients.gd tests/test_foliage_gradient_assets.gd assets/texture/foliage/flowers/*.png assets/texture/foliage/mushrooms/*.png
git commit -m "feat(foliage): generate botanical gradient textures for flowers and mushrooms"
```

---

### Tarea 2: Extensiones de `FoliageSpecies`, `FoliageMaterial` y `foliage_wind.gdshader`

**Archivos:**
- Modificar: `src/world_generator/foliage/foliage_species.gd`
- Modificar: `src/world_renderer/shaders/foliage_wind.gdshader`
- Modificar: `src/world_generator/foliage/rendering/foliage_material.gd`
- Test: `tests/test_foliage_species_types.gd`

**Interfaces:**
- `FoliageSpecies`:
  - `enum FoliageType { GRASS = 0, FLOWER = 1, MUSHROOM = 2 }`
  - `@export var foliage_type: FoliageType = FoliageType.GRASS`
  - `@export var tint_with_grass_color: bool = true` (para flores y hongos será `false`)
  - `@export var gradient_influence: float = -1.0` (cuando es `>= 0.0`, controla la mezcla con `gradient_texture` en el shader)
  - `@export var canopy_preference: float = 0.0` (`+1.0` para hongos que aman la sombra, `-1.0` para flores amantes de claros soleados, `0.0` para césped)
- `foliage_wind.gdshader`:
  - Añade uniform: `uniform float gradient_influence : hint_range(0.0, 1.0) = 0.20;`
  - Modifica la línea 102:
    `gradient_col = mix(base_gradient, tex_grad, gradient_influence);`
- `FoliageMaterial.gd`:
  - Si `species.gradient_influence >= 0.0`, asignar al shader:
    `mat.set_shader_parameter("gradient_influence", species.gradient_influence)`
  - Si es menor a 0.0 pero tiene `gradient_texture_path` no vacío, fijar `0.85` para hongos/flores y `0.20` para césped.

- [x] **Paso 1: Escribir el test que falla `tests/test_foliage_species_types.gd`**
...
- [x] **Paso 2: Ejecutar test para verificar que falla**
...
- [x] **Paso 3: Implementar cambios en `foliage_species.gd`, `foliage_wind.gdshader` y `foliage_material.gd`**
...
- [x] **Paso 4: Ejecutar test para verificar que pasa**
...
- [x] **Paso 5: Commit de la Tarea 2**

```powershell
git add src/world_generator/foliage/foliage_species.gd src/world_renderer/shaders/foliage_wind.gdshader src/world_generator/foliage/rendering/foliage_material.gd tests/test_foliage_species_types.gd
git commit -m "feat(foliage): add foliage types and configurable gradient influence"
```

---

### Tarea 3: Distribución Ecológica Específica en `FoliageProfile` y `FoliageGenerator`

**Archivos:**
- Modificar: `src/world_generator/foliage/foliage_profile.gd`
- Modificar: `src/world_generator/foliage/foliage_generator.gd`
- Test: `tests/test_flower_and_mushroom_distribution.gd`

**Interfaces:**
- `FoliageProfile.zone_densities`:
  - `PLAINS`: `{"grass": 1.0, "flower": 0.85, "mushroom": 0.02, "shrub": 0.10, "tree": 0.02}`
  - `FOREST_EDGE`: `{"grass": 0.80, "flower": 0.90, "mushroom": 0.45, "shrub": 0.25, "tree": 0.20}`
  - `OPEN_FOREST`: `{"grass": 0.60, "flower": 0.35, "mushroom": 0.85, "shrub": 0.35, "tree": 0.40}`
  - `DENSE_FOREST`: `{"grass": 0.35, "flower": 0.10, "mushroom": 1.50, "shrub": 0.45, "tree": 0.70}`
  - `CLEARING`: `{"grass": 0.90, "flower": 1.30, "mushroom": 0.20, "shrub": 0.15, "tree": 0.05}`
- `FoliageGenerator`:
  - En la selección y ponderación de especies de cada celda:
    - Calcula el factor ecológico por especie según su `foliage_type` y `canopy_preference`.
    - Para `MUSHROOM`: el peso se multiplica por el factor de sombra (`1.0 + cell.forest_density * 1.5`) y por la densidad de zona `"mushroom"`.
    - Para `FLOWER`: el peso se multiplica por el factor de sol (`1.0 - cell.forest_density * 0.7`) y por la densidad de zona `"flower"`.
    - Para `GRASS`: conserva la fórmula ecológica actual intacta.
  - Al generar el color de instancia:
    - Si `sp.tint_with_grass_color` es verdadero, aplica el lerp sutil con `profile.terrain_grass_color`.
    - Si es falso (flores y hongos), aplica una variación luminosa/cromática neutra (`tint_val = rng.randf_range(0.96, 1.04)`), preservando los colores puros del sombrero y los pétalos.

- [x] **Paso 1: Escribir el test que falla `tests/test_flower_and_mushroom_distribution.gd`**
...
- [x] **Paso 2: Ejecutar test para verificar que falla**
...
- [x] **Paso 3: Implementar `compute_species_effective_weight` y actualizar `foliage_profile.gd` y `foliage_generator.gd`**
...
- [x] **Paso 4: Ejecutar test para verificar que pasa**
...
- [x] **Paso 5: Commit de la Tarea 3**

```powershell
git add src/world_generator/foliage/foliage_profile.gd src/world_generator/foliage/foliage_generator.gd tests/test_flower_and_mushroom_distribution.gd
git commit -m "feat(foliage): add ecological habitat weighting for flowers and mushrooms"
```

---

### Tarea 4: Configuración de Especies en `BiomeRegistry` y Perfiles de Mundo

**Archivos:**
- Modificar: `src/world_generator/biomes/biome_registry.gd`
- Modificar: `src/world_generator/profiles/taiga_world_profile.gd`
- Test: `tests/test_biome_flowers_and_mushrooms.gd`

**Interfaces:**
- Especies añadidas a los biomas:
  - **Taiga**:
    - `mushroom_single_amanita` (`res://assets/texture/foliage/mushrooms/mushroom_single_1.jpg`, `res://assets/texture/foliage/mushrooms/mushroom_gradient_amanita.png`, `wind_strength: 0.02`, `ScaleCategory.MICRO`, `scale: (0.45, 0.45, 0.45)` a `(0.75, 0.75, 0.75)`)
    - `mushroom_cluster_chanterelle` (`res://assets/texture/foliage/mushrooms/mushroom_budge_1.jpg`, `res://assets/texture/foliage/mushrooms/mushroom_gradient_chanterelle.png`, `wind_strength: 0.02`, `ScaleCategory.MICRO`)
    - `flower_cluster_lavender` (`res://assets/texture/foliage/flowers/flowers_group_1.jpg`, `res://assets/texture/foliage/flowers/flower_gradient_lavender.png`, `wind_strength: 0.14`, `ScaleCategory.MICRO`)
  - **Temperate Forest**:
    - `mushroom_cluster_boletus` (`mushroom_budge_2.jpg`, `mushroom_gradient_boletus.png`)
    - `mushroom_single_boletus` (`mushroom_single_2.jpg`, `mushroom_gradient_boletus.png`)
    - `flower_single_wild` (`flowers_single_1.jpg`, `flower_gradient_lavender.png`)
    - `flower_cluster_poppy` (`flowers_group_2.jpg`, `flower_gradient_poppy.png`)
  - **Tundra**:
    - `flower_single_daisy` (`flowers_single_1.jpg`, `flower_gradient_daisy.png`)
  - **Jungle**:
    - `mushroom_cluster_jungle` (`mushroom_budge_2.jpg`, `mushroom_gradient_chanterelle.png`)
    - `flower_cluster_tropical` (`flowers_group_2.jpg`, `flower_gradient_poppy.png`)
  - **Alpine**:
    - `flower_single_alpine` (`flowers_single_1.jpg`, `flower_gradient_daisy.png`)

- [x] **Paso 1: Escribir el test que falla `tests/test_biome_flowers_and_mushrooms.gd`**
...
- [x] **Paso 2: Ejecutar test para verificar que falla**
...
- [x] **Paso 3: Configurar especies en `biome_registry.gd`**
...
- [x] **Paso 4: Ejecutar test para verificar que pasa**
...
- [x] **Paso 5: Ejecutar la suite completa de tests de biomas y generador para verificar no-regresión**
...
- [x] **Paso 6: Commit de la Tarea 4**

```powershell
git add src/world_generator/biomes/biome_registry.gd tests/test_biome_flowers_and_mushrooms.gd
git commit -m "feat(foliage): register mushrooms and flowers across all biomes"
```

---

### Tarea 5: Validación de Renderizado MultiMesh de Chunk y Cierre

**Archivos:**
- Crear: `tests/test_chunk_foliage_multimesh_render.gd`

**Interfaces:**
- Verifica que al generar un chunk con césped, flores y hongos:
  - Se generan nodos `MultiMeshInstance3D` individuales para cada especie.
  - Cada `MultiMeshInstance3D` tiene `use_colors = true` y material con el shader correcto.
  - El recuento de instancias de hongos es mayor en áreas de dosel boscoso.
  - El recuento de flores es mayor en claros.

- [x] **Paso 1: Escribir `tests/test_chunk_foliage_multimesh_render.gd`**
...
- [x] **Paso 2: Ejecutar test**
...
- [x] **Paso 3: Commit de la Tarea 5**

```powershell
git add tests/test_chunk_foliage_multimesh_render.gd
git commit -m "test(foliage): add end-to-end multi-species chunk render validation"
```
