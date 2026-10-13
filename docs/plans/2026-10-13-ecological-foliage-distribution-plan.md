# Sistema de Distribución Ecológica de Foliage Multiescala — Plan de Implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar una arquitectura ecológica de distribución de foliage en 3 escalas (Micro/Medio/Macro), basada en parches bi-escala (Large + Fine noise), transiciones suaves de claros/bosque, escalas ponderadas e influencia de dosel (canopy factor), determinista por chunk y renderizada con MultiMeshInstance3D y shaders.

**Architecture:** 
- `FoliageProfile` y `FoliageSpecies` se enriquecen con zonas ecológicas (`EcologicalZone`), escalas por categoría (Micro, Medio, Macro), parámetros de parches bi-escala y factores de atenuación bajo dosel.
- `FoliageGenerator` calcula de forma determinista por chunk (`world_seed + chunk_pos + domain`) las máscaras de bosque/claros con gradiente suave (`1.0 -> 0.85 -> 0.70 -> 0.45 -> 0.20 -> 0.05 -> 0.0`), evalúa parches regionales y genera instancias con distribución ponderada de escala (`70%`, `25%`, `5%`) y variación según zona (planicie vs bosque).
- `FoliageMultiMeshBuilder` y `FoliageRenderer` materializan las instancias por especie en `MultiMeshInstance3D` en el Main Thread sin raycasts.

**Tech Stack:** Godot 4.6 (GDScript, FastNoiseLite, MultiMeshInstance3D, Spatial Shader).

**Spec:** Especificación de arquitectura y distribución de foliage provista por el usuario (Patches bi-escala, Foliage en 3 escalas, Variación ponderada, Clusters + Clearing mask, Transición ecológica, Atenuación de dosel arbóreo, Determinismo estricto por chunk).

## Global Constraints

1. **Zero raycasts:** Prohibido realizar consultas de físicas/raycasting por cada brizna o arbusto. Elevación, pendiente y humedad se derivan matemáticamente de `WorldCell` y el mapa procedural.
2. **Worker Thread Isolation:** El generador corre en worker thread y únicamente produce datos puros en `FoliageChunkData` (`Transform3D`, `Color`, `species_id`), sin tocar el `SceneTree`.
3. **Determinismo Estricto por Chunk:** Toda generación depende exclusivamente de `(world_x, world_z)` y `world_seed`. El mismo chunk generado en cualquier orden produce exactamente las mismas instancias.
4. **Respeto a Hidrología y Pendientes:** La vegetación terrestre nunca se genera sobre agua (`is_water`), lechos fluviales de exclusión ni acantilados de roca (`CLIFF`).
5. **No Biome Hardcoding:** Toda parametrización reside en `FoliageProfile`, `FoliageSpecies` y `BiomeDefinition`.

---

## Tareas de Implementación

### Tarea 1: Contratos de Ecología y Parámetros Multiescala (`FoliageProfile` y `FoliageSpecies`)

**Archivos:**
- Modificar: `src/world_generator/foliage/foliage_species.gd`
- Modificar: `src/world_generator/foliage/foliage_profile.gd`
- Test: `tests/test_foliage_ecology_contracts.gd`

**Interfaces:**
- `FoliageSpecies`:
  - `scale_category: int` (enum `ScaleCategory { MICRO = 0, MEDIUM = 1, MACRO = 2 }`)
  - `scale_weights: Dictionary` (mapping peso relativo de escala, por defecto `{"small": 0.70, "medium": 0.25, "large": 0.05}`)
  - `small_mult_range: Vector2` (por defecto `Vector2(0.75, 0.95)`)
  - `medium_mult_range: Vector2` (por defecto `Vector2(0.95, 1.15)`)
  - `large_mult_range: Vector2` (por defecto `Vector2(1.15, 1.35)`)
- `FoliageProfile`:
  - Enum `EcologicalZone { PLAINS = 0, FOREST_EDGE = 1, OPEN_FOREST = 2, DENSE_FOREST = 3, CLEARING = 4 }`
  - `large_noise_frequency: float = 0.02` (define grandes regiones/manchas)
  - `fine_noise_frequency: float = 0.12` (variación y micro-huecos dentro de las manchas)
  - `canopy_influence_radius: float = 2.0` (radio de influencia bajo el dosel arbóreo)
  - `canopy_attenuation_factor: float = 0.35` (multiplicador de densidad de césped bajo árboles)
  - `clearing_threshold: float = 0.35` (umbral para formación de claros limpios)
  - `zone_densities: Dictionary` (densidades relativas por zona: PLAINS, FOREST_EDGE, etc.)

- [x] **Paso 1: Escribir el test que falla `tests/test_foliage_ecology_contracts.gd`**

```gdscript
extends SceneTree

const _SpeciesScript = preload("res://src/world_generator/foliage/foliage_species.gd")
const _ProfileScript = preload("res://src/world_generator/foliage/foliage_profile.gd")

func _init() -> void:
	print("Running test_foliage_ecology_contracts...")
	
	# Test FoliageSpecies ScaleCategory
	var sp := _SpeciesScript.new(&"grass_micro", "Micro Grass")
	assert(sp.scale_category == _SpeciesScript.ScaleCategory.MICRO, "Default category must be MICRO")
	assert(sp.scale_weights.has("small") and sp.scale_weights.has("medium") and sp.scale_weights.has("large"), "Must have weighted scale buckets")
	
	# Test FoliageProfile Ecology parameters
	var prof := _ProfileScript.new()
	assert(prof.large_noise_frequency > 0.0, "Must have large_noise_frequency")
	assert(prof.fine_noise_frequency > prof.large_noise_frequency, "Fine noise frequency must be higher than large noise")
	assert(prof.canopy_attenuation_factor >= 0.0 and prof.canopy_attenuation_factor <= 1.0, "Canopy attenuation must be in [0, 1]")
	assert(prof.zone_densities.has(_ProfileScript.EcologicalZone.PLAINS), "Must have PLAINS zone density")
	assert(prof.zone_densities.has(_ProfileScript.EcologicalZone.DENSE_FOREST), "Must have DENSE_FOREST zone density")
	
	print("[PASS] test_foliage_ecology_contracts")
	quit(0)
```

- [x] **Paso 2: Ejecutar test para verificar que falla**

Ejecutar:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_foliage_ecology_contracts.gd
```
Esperado: FALLA (campos/enums no definidos aún).

- [x] **Paso 3: Implementar extensiones en `foliage_species.gd` y `foliage_profile.gd`**

En `src/world_generator/foliage/foliage_species.gd`:
Añadir enum `ScaleCategory { MICRO = 0, MEDIUM = 1, MACRO = 2 }`, `@export var scale_category: ScaleCategory = ScaleCategory.MICRO`, `@export var scale_weights: Dictionary = {"small": 0.70, "medium": 0.25, "large": 0.05}`, y los rangos de multiplicadores `small_mult_range`, `medium_mult_range`, `large_mult_range`.

En `src/world_generator/foliage/foliage_profile.gd`:
Añadir enum `EcologicalZone { PLAINS = 0, FOREST_EDGE = 1, OPEN_FOREST = 2, DENSE_FOREST = 3, CLEARING = 4 }`, variables exportadas de ruido bi-escala (`large_noise_frequency`, `fine_noise_frequency`), parámetros de dosel (`canopy_influence_radius`, `canopy_attenuation_factor`), y diccionario `zone_densities`.

- [x] **Paso 4: Ejecutar test para verificar que pasa**

Ejecutar:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_foliage_ecology_contracts.gd
```
Esperado: PASS con código de salida 0.

- [x] **Paso 5: Commit de la Tarea 1**

```powershell
git add src/world_generator/foliage/foliage_species.gd src/world_generator/foliage/foliage_profile.gd tests/test_foliage_ecology_contracts.gd
git commit -m "feat(foliage): add ecological zones and multi-scale contracts"
```

---

### Tarea 2: Muestreo de Parches Bi-Escala y Clasificación de Zonas Ecológicas

**Archivos:**
- Modificar: `src/world_generator/foliage/foliage_generator.gd`
- Test: `tests/test_foliage_patch_sampling.gd`

**Interfaces:**
- Consumes: `FoliageProfile.EcologicalZone`, `FoliageProfile.large_noise_frequency`, `FoliageProfile.fine_noise_frequency`, `WorldCell.forest_density`, `WorldCell.clearing_density`
- Produces: `func evaluate_ecological_zone(cell: WorldCell, large_noise_val: float) -> int`, `func evaluate_patch_coverage(pos: Vector2i, large_noise: FastNoiseLite, fine_noise: FastNoiseLite, profile: FoliageProfile) -> float`

- [x] **Paso 1: Escribir el test que falla `tests/test_foliage_patch_sampling.gd`**

```gdscript
extends SceneTree

const _GeneratorScript = preload("res://src/world_generator/foliage/foliage_generator.gd")
const _ProfileScript = preload("res://src/world_generator/foliage/foliage_profile.gd")
const _CellScript = preload("res://src/world_generator/data/world_cell.gd")

func _init() -> void:
	print("Running test_foliage_patch_sampling...")
	var gen := _GeneratorScript.new()
	var prof := _ProfileScript.new()
	
	# Test Plains Cell (low forest density, high clearing)
	var plains_cell := _CellScript.new(Vector2i(10, 10))
	plains_cell.forest_density = 0.02
	plains_cell.clearing_density = 0.8
	var zone_plains: int = gen.evaluate_ecological_zone(plains_cell, 0.5)
	assert(zone_plains == _ProfileScript.EcologicalZone.PLAINS or zone_plains == _ProfileScript.EcologicalZone.CLEARING, "Must evaluate to plains/clearing")
	
	# Test Dense Forest Cell (high forest density, low clearing)
	var forest_cell := _CellScript.new(Vector2i(20, 20))
	forest_cell.forest_density = 0.85
	forest_cell.clearing_density = 0.05
	var zone_forest: int = gen.evaluate_ecological_zone(forest_cell, 0.5)
	assert(zone_forest == _ProfileScript.EcologicalZone.DENSE_FOREST, "Must evaluate to dense forest")
	
	# Test Patch Coverage smoothly combines large and fine noise
	var cov1: float = gen.evaluate_patch_coverage_at(Vector2i(5, 5), 12345, prof)
	var cov2: float = gen.evaluate_patch_coverage_at(Vector2i(5, 5), 12345, prof)
	assert(is_equal_approx(cov1, cov2), "Patch coverage must be strictly deterministic")
	assert(cov1 >= 0.0 and cov1 <= 1.0, "Patch coverage must be normalized [0, 1]")
	
	print("[PASS] test_foliage_patch_sampling")
	quit(0)
```

- [x] **Paso 2: Ejecutar test para verificar que falla**

Ejecutar:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_foliage_patch_sampling.gd
```
Esperado: FALLA (métodos `evaluate_ecological_zone` y `evaluate_patch_coverage_at` inexistentes).

- [x] **Paso 3: Implementar en `foliage_generator.gd`**

Añadir funciones:
```gdscript
func evaluate_ecological_zone(cell: WorldCell, large_noise_val: float) -> int:
	if cell.clearing_density > 0.65 or cell.forest_density < 0.08:
		return _FoliageProfileScript.EcologicalZone.PLAINS if cell.forest_density < 0.05 else _FoliageProfileScript.EcologicalZone.CLEARING
	elif cell.forest_density > 0.60 and cell.clearing_density < 0.20:
		return _FoliageProfileScript.EcologicalZone.DENSE_FOREST
	elif cell.forest_density > 0.30:
		return _FoliageProfileScript.EcologicalZone.OPEN_FOREST
	else:
		return _FoliageProfileScript.EcologicalZone.FOREST_EDGE

func evaluate_patch_coverage_at(pos: Vector2i, master_seed: int, profile: FoliageProfile) -> float:
	var l_noise := FastNoiseLite.new()
	l_noise.seed = master_seed ^ 0x3F5A
	l_noise.frequency = profile.large_noise_frequency
	var f_noise := FastNoiseLite.new()
	f_noise.seed = master_seed ^ 0x9B1C
	f_noise.frequency = profile.fine_noise_frequency
	
	var val_l: float = (l_noise.get_noise_2d(float(pos.x), float(pos.y)) + 1.0) * 0.5
	var val_f: float = (f_noise.get_noise_2d(float(pos.x), float(pos.y)) + 1.0) * 0.5
	# Combina grandes regiones con variación interna detallada
	return clampf(val_l * 0.65 + val_f * 0.35, 0.0, 1.0)
```

- [x] **Paso 4: Ejecutar test para verificar que pasa**

Ejecutar:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_foliage_patch_sampling.gd
```
Esperado: PASS con código de salida 0.

- [x] **Paso 5: Commit de la Tarea 2**

```powershell
git add src/world_generator/foliage/foliage_generator.gd tests/test_foliage_patch_sampling.gd
git commit -m "feat(foliage): add bi-scale patch sampling and ecological zone evaluator"
```

---

### Tarea 3: Muestreo de Escala Ponderada y Atenuación por Dosel Arbóreo (Canopy Factor)

**Archivos:**
- Modificar: `src/world_generator/foliage/foliage_generator.gd`
- Test: `tests/test_foliage_canopy_and_scale.gd`

**Interfaces:**
- Consumes: `FoliageSpecies.scale_weights`, `FoliageProfile.canopy_attenuation_factor`, `WorldCell.canopy_zone`
- Produces: `func sample_weighted_scale(species: FoliageSpecies, rng: RandomNumberGenerator, zone_id: int) -> Vector3`, `func compute_canopy_attenuation(cell: WorldCell, nearby_trees_density: float, profile: FoliageProfile) -> float`

- [x] **Paso 1: Escribir el test que falla `tests/test_foliage_canopy_and_scale.gd`**

```gdscript
extends SceneTree

const _GeneratorScript = preload("res://src/world_generator/foliage/foliage_generator.gd")
const _SpeciesScript = preload("res://src/world_generator/foliage/foliage_species.gd")
const _ProfileScript = preload("res://src/world_generator/foliage/foliage_profile.gd")
const _CellScript = preload("res://src/world_generator/data/world_cell.gd")

func _init() -> void:
	print("Running test_foliage_canopy_and_scale...")
	var gen := _GeneratorScript.new()
	var sp := _SpeciesScript.new(&"grass", "Grass")
	var prof := _ProfileScript.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	
	# Test weighted scale distribution (majority small/medium, minority large)
	var small_count := 0
	var total_rolls := 1000
	for i in range(total_rolls):
		var sc: Vector3 = gen.sample_weighted_scale(sp, rng, _ProfileScript.EcologicalZone.PLAINS)
		if sc.y <= sp.scale_max.y * 0.96:
			small_count += 1
	var small_ratio: float = float(small_count) / float(total_rolls)
	assert(small_ratio > 0.50, "Most samples must be small/medium scale, ratio: %f" % small_ratio)
	
	# Test canopy attenuation factor
	var open_cell := _CellScript.new()
	open_cell.forest_density = 0.0
	var forest_cell := _CellScript.new()
	forest_cell.forest_density = 0.9
	
	var atten_open: float = gen.compute_canopy_attenuation(open_cell, 0.0, prof)
	var atten_forest: float = gen.compute_canopy_attenuation(forest_cell, 0.9, prof)
	assert(is_equal_approx(atten_open, 1.0), "Open ground must have 1.0 canopy factor")
	assert(atten_forest < 0.60, "Forest ground must have attenuated foliage density, got: %f" % atten_forest)
	
	print("[PASS] test_foliage_canopy_and_scale")
	quit(0)
```

- [x] **Paso 2: Ejecutar test para verificar que falla**

Ejecutar:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_foliage_canopy_and_scale.gd
```
Esperado: FALLA (métodos `sample_weighted_scale` y `compute_canopy_attenuation` inexistentes).

- [x] **Paso 3: Implementar en `foliage_generator.gd`**

Implementar `sample_weighted_scale()` usando la distribución ponderada `70% small`, `25% medium`, `5% large`, aplicando además un multiplicador según la zona (planicie: `0.7-1.3` más irregular y alta; bosque: `0.55-1.05` más compacta y baja).
Implementar `compute_canopy_attenuation()` que calcula el factor multiplicador de densidad reduciendo la cantidad de césped bajo copas de árboles para dar visibilidad natural alrededor de los troncos.

- [x] **Paso 4: Ejecutar test para verificar que pasa**

Ejecutar:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_foliage_canopy_and_scale.gd
```
Esperado: PASS con código de salida 0.

- [x] **Paso 5: Commit de la Tarea 3**

```powershell
git add src/world_generator/foliage/foliage_generator.gd tests/test_foliage_canopy_and_scale.gd
git commit -m "feat(foliage): implement weighted scale sampling and tree canopy attenuation"
```

---

### Tarea 4: Configuración Ecológica para Biomas Taiga y Bosque Otoñal

**Archivos:**
- Modificar: `src/world_generator/profiles/taiga_world_profile.gd`
- Modificar: `src/world_generator/profiles/autumn_forest_world_profile.gd`
- Test: `tests/test_taiga_foliage_distribution.gd`

**Interfaces:**
- Consumes: `FoliageProfile`, `FoliageSpecies`, `ScaleCategory`
- Produces: Perfil de follaje ecológico calibrado con 3 especies jerárquicas:
  - Micro: `grass_common` / `grass_short` (10–35 cm)
  - Medio: `grass_tall` / `shrub_fern` (40 cm – 1.2 m)
  - Macro: `shrub_wild` / arbustos bajos

- [x] **Paso 1: Escribir el test que falla `tests/test_taiga_foliage_distribution.gd`**

```gdscript
extends SceneTree

const _TaigaProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _AutumnProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _SpeciesScript = preload("res://src/world_generator/foliage/foliage_species.gd")

func _init() -> void:
	print("Running test_taiga_foliage_distribution...")
	var taiga := _TaigaProfileScript.new()
	var autumn := _AutumnProfileScript.new()
	
	# Validate Taiga foliage setup
	var t_fol = taiga.foliage_profile if "foliage_profile" in taiga else null
	assert(t_fol != null, "Taiga must provide a foliage_profile")
	assert(t_fol.species.size() >= 2, "Taiga must have at least 2 distinct foliage species (Micro + Medium)")
	
	# Validate Autumn Forest foliage setup
	var a_fol = autumn.foliage_profile if "foliage_profile" in autumn else null
	assert(a_fol != null, "Autumn Forest must provide a foliage_profile")
	assert(a_fol.species.size() >= 2, "Autumn Forest must have at least 2 distinct foliage species")
	
	var has_micro := false
	var has_medium := false
	for sp in t_fol.species:
		if sp.scale_category == _SpeciesScript.ScaleCategory.MICRO:
			has_micro = true
		elif sp.scale_category == _SpeciesScript.ScaleCategory.MEDIUM:
			has_medium = true
	assert(has_micro and has_medium, "Taiga must contain both MICRO and MEDIUM foliage species")
	
	print("[PASS] test_taiga_foliage_distribution")
	quit(0)
```

- [x] **Paso 2: Ejecutar test para verificar que falla**

Ejecutar:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_taiga_foliage_distribution.gd
```
Esperado: FALLA si los perfiles no instancian las especies multiescala.

- [x] **Paso 3: Configurar perfiles en `taiga_world_profile.gd` y `autumn_forest_world_profile.gd`**

Configurar la lista de especies con sus categorías `MICRO` (césped base corto y abundante) y `MEDIUM` (hierba alta y matas medianas), definiendo los rangos de escala física reales:
- Micro: `Vector3(0.5, 0.4, 0.5)` a `Vector3(0.85, 0.75, 0.85)`
- Medio: `Vector3(0.9, 0.9, 0.9)` a `Vector3(1.3, 1.4, 1.3)`
Y configurando `zone_densities` con las proporciones ecológicas validadas en la spec.

- [x] **Paso 4: Ejecutar test para verificar que pasa**

Ejecutar:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_taiga_foliage_distribution.gd
```
Esperado: PASS con código de salida 0.

- [x] **Paso 5: Commit de la Tarea 4**

```powershell
git add src/world_generator/profiles/taiga_world_profile.gd src/world_generator/profiles/autumn_forest_world_profile.gd tests/test_taiga_foliage_distribution.gd
git commit -m "feat(foliage): calibrate multi-scale ecological profiles for Taiga and Autumn Forest"
```

---

### Tarea 5: Generación Determinista por Chunk y Validación End-to-End

**Archivos:**
- Modificar: `src/world_generator/foliage/foliage_generator.gd`
- Test: `tests/test_foliage_chunk_streaming_deterministic.gd`

**Interfaces:**
- Consumes: `WorldResult`, `Rect2i` del chunk, `FoliageGenerator.generate_foliage`
- Produces: `FoliageChunkData` idéntico bit a bit al re-generar el mismo chunk independientemente del orden de streaming.

- [x] **Paso 1: Escribir el test que falla `tests/test_foliage_chunk_streaming_deterministic.gd`**

```gdscript
extends SceneTree

const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")
const _AutumnProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _GeneratorScript = preload("res://src/world_generator/foliage/foliage_generator.gd")

func _init() -> void:
	print("Running test_foliage_chunk_streaming_deterministic...")
	var seed_val := 98765
	var profile = _AutumnProfileScript.new()
	var config = _ChunkConfigScript.new(16, 1, 3)
	var hydro = _WorldPipelineScript.generate_regional_hydrology(seed_val, profile)
	
	var cw = _ChunkWorldScript.new()
	cw.initialize(seed_val, profile, config, hydro, 3)
	cw.load_initial_area(Vector2i(2, -3), 1)
	
	var gen := _GeneratorScript.new()
	var chunk_bounds := Rect2i(32, -48, 16, 16)
	
	# Generate chunk A run 1
	var data1 = gen.generate_foliage(cw.chunk_manager.chunks.get(Vector2i(2, -3)), seed_val, chunk_bounds, profile)
	# Generate chunk A run 2
	var data2 = gen.generate_foliage(cw.chunk_manager.chunks.get(Vector2i(2, -3)), seed_val, chunk_bounds, profile)
	
	assert(data1 != null and data2 != null, "Foliage chunk data must not be null")
	assert(data1.get_total_instance_count() == data2.get_total_instance_count(), "Instance count must be identical across runs")
	assert(data1.get_total_instance_count() > 0, "Chunk with land must generate foliage instances")
	
	# Verify transforms match perfectly
	for sp_id in data1.instances_by_species.keys():
		var list1: Array = data1.instances_by_species[sp_id]
		var list2: Array = data2.instances_by_species[sp_id]
		assert(list1.size() == list2.size(), "Species instance count mismatch for %s" % str(sp_id))
		for i in range(list1.size()):
			assert(list1[i].origin.is_equal_approx(list2[i].origin), "Instance position mismatch")
			assert(list1[i].basis.is_equal_approx(list2[i].basis), "Instance rotation/scale mismatch")
	
	print("[PASS] test_foliage_chunk_streaming_deterministic (Total instances: %d)" % data1.get_total_instance_count())
	quit(0)
```

- [x] **Paso 2: Ejecutar test para verificar que falla o valida la paridad**

Ejecutar:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_foliage_chunk_streaming_deterministic.gd
```

- [x] **Paso 3: Integrar la evaluación en `FoliageGenerator.generate_foliage()`**

Unificar el bucle de generación en `FoliageGenerator`:
1. Muestrear cobertura con parches bi-escala (`evaluate_patch_coverage_at`).
2. Resolver la zona ecológica de la celda (`evaluate_ecological_zone`).
3. Calcular factor de atenuación por dosel arbóreo (`compute_canopy_attenuation`).
4. Seleccionar especie por ruleta de peso ponderando categoría (`MICRO`, `MEDIUM`, `MACRO`).
5. Generar escala ponderada (`sample_weighted_scale`).
6. Registrar en `foliage_data.add_instance()`.

- [x] **Paso 4: Ejecutar test para verificar que pasa al 100%**

Ejecutar:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_foliage_chunk_streaming_deterministic.gd
```
Esperado: PASS con código de salida 0.

- [x] **Paso 5: Commit de la Tarea 5**

```powershell
git add src/world_generator/foliage/foliage_generator.gd tests/test_foliage_chunk_streaming_deterministic.gd
git commit -m "feat(foliage): finalize deterministic multi-scale ecological foliage pipeline"
```

---

## Verificación Final

Ejecutar la suite completa de pruebas:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_foliage_ecology_contracts.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_foliage_patch_sampling.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_foliage_canopy_and_scale.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_taiga_foliage_distribution.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_foliage_chunk_streaming_deterministic.gd
```
Todas las pruebas deben salir con código 0 y reporte `[PASS]`.
