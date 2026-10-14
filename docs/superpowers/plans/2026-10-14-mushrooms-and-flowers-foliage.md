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

- [ ] **Paso 1: Escribir el test que falla `tests/test_flower_and_mushroom_distribution.gd`**

```gdscript
extends SceneTree

const _GeneratorScript = preload("res://src/world_generator/foliage/foliage_generator.gd")
const _SpeciesScript = preload("res://src/world_generator/foliage/foliage_species.gd")
const _ProfileScript = preload("res://src/world_generator/foliage/foliage_profile.gd")

func _init() -> void:
	print("Running test_flower_and_mushroom_distribution...")
	var prof := _ProfileScript.new()
	assert(prof.zone_densities[_ProfileScript.EcologicalZone.DENSE_FOREST].has("mushroom"), "DENSE_FOREST must have mushroom weight")
	assert(prof.zone_densities[_ProfileScript.EcologicalZone.CLEARING].has("flower"), "CLEARING must have flower weight")
	assert(prof.zone_densities[_ProfileScript.EcologicalZone.DENSE_FOREST]["mushroom"] > prof.zone_densities[_ProfileScript.EcologicalZone.PLAINS]["mushroom"], "Mushrooms must have higher density in forest than plains")
	assert(prof.zone_densities[_ProfileScript.EcologicalZone.CLEARING]["flower"] > prof.zone_densities[_ProfileScript.EcologicalZone.DENSE_FOREST]["flower"], "Flowers must have higher density in clearings than dense forest")

	# Test ecological species weighting helper
	var gen := _GeneratorScript.new()
	var sp_grass := _SpeciesScript.new(&"grass", "Grass")
	sp_grass.foliage_type = _SpeciesScript.FoliageType.GRASS

	var sp_flower := _SpeciesScript.new(&"flower", "Flower")
	sp_flower.foliage_type = _SpeciesScript.FoliageType.FLOWER
	sp_flower.canopy_preference = -1.0

	var sp_mush := _SpeciesScript.new(&"mushroom", "Mushroom")
	sp_mush.foliage_type = _SpeciesScript.FoliageType.MUSHROOM
	sp_mush.canopy_preference = 1.0

	# In clearing (sunny), flower effective weight should be high, mushroom low
	var w_flower_clearing = gen.compute_species_effective_weight(sp_flower, prof, _ProfileScript.EcologicalZone.CLEARING, 0.05)
	var w_mush_clearing = gen.compute_species_effective_weight(sp_mush, prof, _ProfileScript.EcologicalZone.CLEARING, 0.05)
	assert(w_flower_clearing > w_mush_clearing, "Flowers must dominate clearings over mushrooms")

	# In dense forest (shady), mushroom effective weight should be high, flower low
	var w_flower_dense = gen.compute_species_effective_weight(sp_flower, prof, _ProfileScript.EcologicalZone.DENSE_FOREST, 0.85)
	var w_mush_dense = gen.compute_species_effective_weight(sp_mush, prof, _ProfileScript.EcologicalZone.DENSE_FOREST, 0.85)
	assert(w_mush_dense > w_flower_dense, "Mushrooms must dominate dense forest over flowers")

	print("[PASS] test_flower_and_mushroom_distribution")
	quit(0)
```

- [ ] **Paso 2: Ejecutar test para verificar que falla**

Ejecutar:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_flower_and_mushroom_distribution.gd
```
Esperado: FALLA (`compute_species_effective_weight` no existe).

- [ ] **Paso 3: Implementar `compute_species_effective_weight` y actualizar `foliage_profile.gd` y `foliage_generator.gd`**

En `src/world_generator/foliage/foliage_profile.gd`:
Actualizar `zone_densities` con las claves `"flower"` y `"mushroom"` en las 5 zonas ecológicas.

En `src/world_generator/foliage/foliage_generator.gd`:
Añadir método auxiliar:
```gdscript
func compute_species_effective_weight(species: FoliageSpecies, profile: FoliageProfile, zone_id: int, forest_density: float) -> float:
	if species == null or profile == null:
		return 0.0
	var base_w: float = maxf(species.density_weight, 0.01)
	var zone_dict: Dictionary = profile.zone_densities.get(zone_id, {})

	match species.foliage_type:
		_FoliageSpeciesScript.FoliageType.MUSHROOM:
			var zone_mult: float = float(zone_dict.get("mushroom", 0.50))
			var shade_factor: float = clampf(0.20 + forest_density * 1.60, 0.15, 2.0)
			return base_w * zone_mult * shade_factor
		_FoliageSpeciesScript.FoliageType.FLOWER:
			var zone_mult: float = float(zone_dict.get("flower", 0.80))
			var sun_factor: float = clampf(1.30 - forest_density * 1.10, 0.10, 1.5)
			return base_w * zone_mult * sun_factor
		_: # GRASS
			var zone_mult: float = float(zone_dict.get("grass", 1.0))
			return base_w * zone_mult
```
Y en `generate_foliage`, utilizar `compute_species_effective_weight` al construir la ruleta de selección de especie para cada celda, y verificar `chosen_species.tint_with_grass_color` antes de mezclar con el color de hierba del terreno.

- [ ] **Paso 4: Ejecutar test para verificar que pasa**

Ejecutar:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_flower_and_mushroom_distribution.gd
```
Esperado: PASS con código de salida 0.

- [ ] **Paso 5: Commit de la Tarea 3**

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

- [ ] **Paso 1: Escribir el test que falla `tests/test_biome_flowers_and_mushrooms.gd`**

```gdscript
extends SceneTree

const _BiomeRegistryScript = preload("res://src/world_generator/biomes/biome_registry.gd")
const _SpeciesScript = preload("res://src/world_generator/foliage/foliage_species.gd")

func _init() -> void:
	print("Running test_biome_flowers_and_mushrooms...")
	var reg = _BiomeRegistryScript.get_default()
	
	# Taiga
	var taiga = reg.get_definition(&"taiga")
	assert(taiga != null and taiga.foliage_profile != null, "Taiga foliage profile must exist")
	var has_amanita := false
	var has_flower := false
	for sp in taiga.foliage_profile.species:
		if sp.foliage_type == _SpeciesScript.FoliageType.MUSHROOM:
			has_amanita = true
		if sp.foliage_type == _SpeciesScript.FoliageType.FLOWER:
			has_flower = true
	assert(has_amanita, "Taiga must include mushroom species")
	assert(has_flower, "Taiga must include flower species")

	# Temperate Forest
	var forest = reg.get_definition(&"temperate_forest")
	var forest_mush := false
	var forest_flower := false
	for sp in forest.foliage_profile.species:
		if sp.foliage_type == _SpeciesScript.FoliageType.MUSHROOM:
			forest_mush = true
		if sp.foliage_type == _SpeciesScript.FoliageType.FLOWER:
			forest_flower = true
	assert(forest_mush and forest_flower, "Temperate forest must include both mushrooms and flowers")

	print("[PASS] test_biome_flowers_and_mushrooms")
	quit(0)
```

- [ ] **Paso 2: Ejecutar test para verificar que falla**

Ejecutar:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_biome_flowers_and_mushrooms.gd
```
Esperado: FALLA (las especies no están registradas en los biomas).

- [ ] **Paso 3: Configurar especies en `biome_registry.gd`**

En `src/world_generator/biomes/biome_registry.gd`:
Crear las instancias de `FoliageSpecies` para hongos y flores en:
- `_create_taiga_foliage()`
- `_create_forest_foliage()`
- `_create_tundra_foliage()`
- `_create_jungle_foliage()`
- `_create_alpine_foliage()`
Configurando:
- `foliage_type`
- `texture_path`
- `gradient_texture_path`
- `color_bottom` y `color_top` calibrados
- `wind_strength` suave/rígido (0.02 para hongos, 0.14 para flores)
- `tint_with_grass_color = false`

- [ ] **Paso 4: Ejecutar test para verificar que pasa**

Ejecutar:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_biome_flowers_and_mushrooms.gd
```
Esperado: PASS con código de salida 0.

- [ ] **Paso 5: Ejecutar la suite completa de tests de biomas y generador para verificar no-regresión**

Ejecutar:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script src/world_generator/tests/test_biome_foliage_profiles.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script src/world_generator/tests/test_foliage_generator.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_foliage_canopy_and_scale.gd
```
Esperado: Todos los tests pasan.

- [ ] **Paso 6: Commit de la Tarea 4**

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

- [ ] **Paso 1: Escribir `tests/test_chunk_foliage_multimesh_render.gd`**

```gdscript
extends SceneTree

const _GeneratorScript = preload("res://src/world_generator/foliage/foliage_generator.gd")
const _RendererScript = preload("res://src/world_generator/foliage/rendering/foliage_renderer.gd")
const _BiomeRegistryScript = preload("res://src/world_generator/biomes/biome_registry.gd")
const _ProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _StagePipelineScript = preload("res://src/world_generator/world_stage_pipeline.gd")

func _init() -> void:
	print("Running test_chunk_foliage_multimesh_render...")
	var prof := _ProfileScript.new()
	var pipeline := _StagePipelineScript.new()
	var result = pipeline.generate_world(12345, prof)
	assert(result != null, "WorldResult must not be null")

	var gen := _GeneratorScript.new()
	var bounds := Rect2i(0, 0, 32, 32)
	var chunk_data = gen.generate_foliage(result, 12345, bounds, prof)
	assert(chunk_data != null, "Foliage chunk data must not be null")

	var node = _RendererScript.build_chunk_foliage_node(chunk_data)
	assert(node != null, "Chunk foliage node must not be null")
	assert(node.get_child_count() >= 3, "Node must have multiple species MultiMeshInstance3Ds (got %d)" % node.get_child_count())

	var species_found := {}
	for child in node.get_children():
		if child is MultiMeshInstance3D:
			species_found[child.name] = child.multimesh.instance_count
			print(" -> Child: %s, Instances: %d" % [child.name, child.multimesh.instance_count])

	assert(chunk_data.get_total_instance_count() > 0, "Must have generated instances")
	print("[PASS] test_chunk_foliage_multimesh_render")
	quit(0)
```

- [ ] **Paso 2: Ejecutar test**

Ejecutar:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_chunk_foliage_multimesh_render.gd
```
Esperado: PASS con código de salida 0.

- [ ] **Paso 3: Commit de la Tarea 5**

```powershell
git add tests/test_chunk_foliage_multimesh_render.gd
git commit -m "test(foliage): add end-to-end multi-species chunk render validation"
```
