# Physical Height Jump Rules & Navigation Visualizer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unificar la detección de transiciones verticales y saltos (`JUMP_UP`, `DROP`, `STEP_UP`, `STEP_DOWN`) utilizando la diferencia de altura física (`delta_height`) además del `elevation_level`, conectando `analyze_transition()`, `MovementRules` y `WorldNavigationVisualizer` para que cualquier desnivel físico (e.g. +1 bloque aunque comparta `elevation_level`) se visualice en azul y requiera salto con la barra espaciadora.

**Architecture:** 
1. `WorldNavigationGrid` y `MovementGrid`: `analyze_transition(from_cell, to_cell)` se convierte en la autoridad espacial compartida que calcula formalmente tanto `delta_level` como `delta_height` (`to_height - from_height`) e `is_same_height`.
2. `MovementProfile`: expone límites métricos explícitos (`max_jump_height = 6.0`, `max_walk_step_height = 0.0`, `max_walk_step_down_height = 0.0`, `max_drop_height = 8.0`) con retrocompatibilidad automática hacia `max_walk_step_up` y `max_jump_up`.
3. `MovementRules`: evalúa ascensos y descensos considerando si hay desnivel físico (`absf(delta_height) > 0.05`) o lógico (`delta_level != 0`), rechazando con `REASON_JUMP_REQUIRED` si no se presiona salto.
4. `WorldNavigationVisualizer`: elimina la duplicación interna de cálculo y consume directamente `grid.analyze_transition()`, coloreando en azul las celdas que poseen transiciones saltables (`can_jump_up` o `can_jump_down`) tanto por diferencia física como de nivel.

**Tech Stack:** Godot 4.6 GDScript, RefCounted, Node3D, StandardMaterial3D.

**Spec:**
- `analyze_transition()` produce: `delta_height = to_height - from_height`, `is_same_height = absf(delta_height) <= 0.05`.
- `MovementProfile`:
  - `@export var max_jump_height: float = 6.0`
  - `@export var max_walk_step_height: float = 0.0`
  - `@export var max_walk_step_down_height: float = 0.0`
  - `@export var max_drop_height: float = 8.0`
- `MovementRules`: Si $\Delta_{\text{height}} > 0.05 \lor \Delta_{\text{level}} > 0$:
  - Si $\Delta \le \text{walk\_up} \land \neg \text{is\_jump} \to \text{STEP\_UP}$.
  - Si $\Delta \le \text{jump\_up} \land \neg \text{is\_jump} \to \text{REASON\_JUMP\_REQUIRED}$.
  - Si $\Delta \le \text{jump\_up} \land \text{is\_jump} \to \text{JUMP\_UP}$.
  - Si $\Delta > \text{jump\_up} \to \text{REASON\_ELEVATION\_TOO\_HIGH}$.
- `WorldNavigationVisualizer`: Evalúa vecinos consumiendo `grid.analyze_transition()`; colorea en azul (`can_jump_up` / `can_jump_down`) cualquier celda con desnivel saltable físico o lógico.

## Global Constraints

- Preservar compatibilidad total con tests existentes donde `height == base + level * step` y donde solo se configura `max_walk_step_up` / `max_jump_up`.
- Mantener la suite de tests en 100% PASS en Godot headless (`test_movement_unit.gd`, `test_movement_integration.gd`, `test_jumpable_elevation_rules.gd`).

---

### Task 1: Enriquecer `analyze_transition()` con `delta_height` e `is_same_height`

**Files:**
- Modify: `src/world_generator/navigation/world_navigation_grid.gd:104-128`
- Modify: `src/gameplay/movement/movement_grid.gd:223-250`
- Test: `tests/test_jumpable_elevation_rules.gd`

**Interfaces:**
- Produces en el Dictionary retornado por `analyze_transition()`:
  - `"delta_height": float` ($= \text{to\_height} - \text{from\_height}$)
  - `"is_same_height": bool` ($= \text{absf}(\text{delta\_height}) \le 0.05$)

- [x] **Step 1: Modificar `src/world_generator/navigation/world_navigation_grid.gd`**

Actualizar el diccionario base y la asignación en `analyze_transition`:

```gdscript
func analyze_transition(from_cell: Vector2i, to_cell: Vector2i) -> Dictionary:
	var res := {
		"valid": false,
		"from_level": 0,
		"to_level": 0,
		"delta_level": 0,
		"from_height": 0.0,
		"to_height": 0.0,
		"delta_height": 0.0,
		"from_walkable": false,
		"to_walkable": false,
		"is_same_level": true,
		"is_same_height": true
	}
	if not has_cell(from_cell) or not has_cell(to_cell):
		return res
	res.valid = true
	res.from_level = get_elevation_level(from_cell)
	res.to_level = get_elevation_level(to_cell)
	res.delta_level = res.to_level - res.from_level
	res.from_height = get_height(from_cell)
	res.to_height = get_height(to_cell)
	res.delta_height = res.to_height - res.from_height
	res.from_walkable = is_walkable(from_cell)
	res.to_walkable = is_walkable(to_cell)
	res.is_same_level = (res.delta_level == 0)
	res.is_same_height = (absf(res.delta_height) <= 0.05)
	return res
```

- [x] **Step 2: Modificar `src/gameplay/movement/movement_grid.gd`**

Aplicar idénticos campos a la implementación local de fallback en `MovementGrid.analyze_transition()`.

- [x] **Step 3: Verificar con Godot headless**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_jumpable_elevation_rules.gd`
Expected: Carga y ejecución sin errores.

---

### Task 2: Incorporar Parámetros de Altura Física en `MovementProfile`

**Files:**
- Modify: `src/gameplay/movement/movement_profile.gd:40-90`
- Test: `tests/test_jumpable_elevation_rules.gd`

**Interfaces:**
- Produces:
  - `@export var max_walk_step_height: float = 0.0`
  - `@export var max_jump_height: float = 6.0`
  - `@export var max_walk_step_down_height: float = 0.0`
  - `@export var max_drop_height: float = 8.0`
  - Helpers de retrocompatibilidad:
    - `get_effective_walk_step_up_height() -> float`
    - `get_effective_jump_up_height() -> float`
    - `get_effective_walk_step_down_height() -> float`
    - `get_effective_drop_height() -> float`

- [x] **Step 1: Agregar las propiedades y helpers en `src/gameplay/movement/movement_profile.gd`**

```gdscript
## Desnivel físico métrico máximo transitable automáticamente caminando sin saltar hacia arriba.
## Por defecto 0.0: no se camina ningún desnivel físico hacia arriba sin saltar.
@export var max_walk_step_height: float = 0.0

## Máxima altura física métrica permitida mediante salto ascendente (JUMP_UP, hasta 6m / 3 bloques de 2m).
@export var max_jump_height: float = 6.0

## Desnivel físico métrico máximo transitable automáticamente caminando sin saltar hacia abajo.
## Por defecto 0.0: cualquier borde físico requiere salto manual.
@export var max_walk_step_down_height: float = 0.0

## Máxima altura física métrica permitida para un descenso controlado (DROP, hasta 8m / 4 bloques de 2m).
@export var max_drop_height: float = 8.0

## Retorna la altura física efectiva transitable caminando hacia arriba, respetando max_walk_step_up si max_walk_step_height no fue configurado explícitamente.
func get_effective_walk_step_up_height() -> float:
	if max_walk_step_height > 0.0:
		return max_walk_step_height
	if max_walk_step_up > 0:
		return float(max_walk_step_up) * 2.0
	return 0.0

## Retorna la altura física máxima efectiva para JUMP_UP.
func get_effective_jump_up_height() -> float:
	if max_jump_height > 0.0:
		return max_jump_height
	return float(max_jump_up) * 2.0

## Retorna la altura física efectiva transitable caminando hacia abajo.
func get_effective_walk_step_down_height() -> float:
	if max_walk_step_down_height > 0.0:
		return max_walk_step_down_height
	if max_walk_step_down > 0:
		return float(max_walk_step_down) * 2.0
	return 0.0

## Retorna la altura física máxima efectiva para DROP.
func get_effective_drop_height() -> float:
	if max_drop_height > 0.0:
		return max_drop_height
	return float(max_drop_distance) * 2.0
```

- [x] **Step 2: Verificar carga en Godot headless**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_jumpable_elevation_rules.gd`
Expected: Carga sin advertencias ni errores.

---

### Task 3: Unificar la Validación de Elevación en `MovementRules` usando `delta_height` y `delta_level`

**Files:**
- Modify: `src/gameplay/movement/movement_rules.gd:60-125`
- Test: `tests/test_jumpable_elevation_rules.gd`

**Interfaces:**
- Consumes:
  - `grid.analyze_transition(from_cell, to_cell)` (o fallback a `get_elevation_level` / `get_height`)
  - `profile.get_effective_walk_step_up_height()`, `profile.get_effective_jump_up_height()`, etc.
  - `is_jump`
- Produces:
  - Detección precisa de ascensos (`delta_height > 0.05` o `delta_level > 0`) y descensos (`delta_height < -0.05` o `delta_level < 0`).
  - Rechazo estricto `REASON_JUMP_REQUIRED` si no se pulsa salto y la diferencia física excede la caminata plana.

- [x] **Step 1: Refactorizar el bloque de elevación en `src/gameplay/movement/movement_rules.gd`**

```gdscript
	# 5. Elevación y tipo de transición (WALK vs STEP_UP vs JUMP_UP vs STEP_DOWN vs DROP vs FALL)
	var transition_type: int = _ResultScript.TransitionType.WALK
	if grid.has_method("analyze_transition") or grid.has_method("get_elevation_level"):
		var delta_level: int = 0
		var delta_h: float = 0.0

		if grid.has_method("analyze_transition"):
			var trans: Dictionary = grid.analyze_transition(from_cell, to_cell)
			delta_level = trans.get("delta_level", 0)
			delta_h = trans.get("delta_height", 0.0)
		else:
			var cur_lvl: int = grid.get_elevation_level(from_cell)
			var tgt_lvl: int = grid.get_elevation_level(to_cell)
			delta_level = tgt_lvl - cur_lvl
			if grid.has_method("get_height"):
				delta_h = grid.get_height(to_cell) - grid.get_height(from_cell)
			else:
				delta_h = float(delta_level) * 2.0

		var walk_up_lvl: int = profile.max_walk_step_up if profile != null else 0
		var walk_up_h: float = profile.get_effective_walk_step_up_height() if profile != null and profile.has_method("get_effective_walk_step_up_height") else (float(walk_up_lvl) * 2.0)

		var jump_up_lvl: int = profile.max_jump_up if profile != null else 3
		var jump_up_h: float = profile.get_effective_jump_up_height() if profile != null and profile.has_method("get_effective_jump_up_height") else (float(jump_up_lvl) * 2.0)

		var walk_down_lvl: int = profile.max_walk_step_down if profile != null else 0
		var walk_down_h: float = profile.get_effective_walk_step_down_height() if profile != null and profile.has_method("get_effective_walk_step_down_height") else (float(walk_down_lvl) * 2.0)

		var max_drop_lvl: int = profile.max_drop_distance if profile != null else 4
		var max_drop_h: float = profile.get_effective_drop_height() if profile != null and profile.has_method("get_effective_drop_height") else (float(max_drop_lvl) * 2.0)

		var require_jump: bool = profile.require_jump_for_elevation if profile != null else false

		var is_rise: bool = (delta_h > 0.05) or (delta_level > 0)
		var is_drop: bool = (delta_h < -0.05) or (delta_level < 0)

		if require_jump and (is_rise or is_drop) and not is_jump:
			return _ResultScript.reject(_ResultScript.REASON_JUMP_REQUIRED, from_cell, to_cell)

		if not is_rise and not is_drop:
			transition_type = _ResultScript.TransitionType.WALK
		elif is_rise:
			var can_walk_step: bool = (delta_level <= walk_up_lvl) and (delta_h <= walk_up_h + 0.01)
			if can_walk_step and not is_jump:
				transition_type = _ResultScript.TransitionType.STEP_UP
			elif delta_level <= jump_up_lvl and delta_h <= jump_up_h + 0.01:
				if not is_jump:
					return _ResultScript.reject(
						_ResultScript.REASON_JUMP_REQUIRED,
						from_cell,
						to_cell
					)
				transition_type = _ResultScript.TransitionType.JUMP_UP
			else:
				return _ResultScript.reject(
					_ResultScript.REASON_ELEVATION_TOO_HIGH,
					from_cell,
					to_cell
				)
		else: # is_drop
			var abs_delta_lvl: int = absi(delta_level)
			var abs_delta_h: float = absf(delta_h)

			var can_walk_step_down: bool = (abs_delta_lvl <= walk_down_lvl) and (abs_delta_h <= walk_down_h + 0.01)
			if can_walk_step_down and not is_jump:
				transition_type = _ResultScript.TransitionType.STEP_DOWN
			elif abs_delta_lvl <= max_drop_lvl and abs_delta_h <= max_drop_h + 0.01 and profile != null and profile.can_drop:
				if not is_jump:
					return _ResultScript.reject(
						_ResultScript.REASON_JUMP_REQUIRED,
						from_cell,
						to_cell
					)
				if grid.has_method("find_lower_support"):
					var support: Dictionary = grid.find_lower_support(to_cell, max_drop_lvl)
					if not support.get("found", false) or not support.get("walkable", false):
						return _ResultScript.reject(_ResultScript.REASON_NO_SURFACE_BELOW, from_cell, to_cell)
				transition_type = _ResultScript.TransitionType.DROP
			else:
				var can_fall: bool = profile.can_fall if profile != null else true
				if not can_fall:
					if profile != null and profile.can_drop and (abs_delta_lvl > max_drop_lvl or abs_delta_h > max_drop_h):
						return _ResultScript.reject(_ResultScript.REASON_DROP_TOO_HIGH, from_cell, to_cell)
					elif profile != null and profile.can_drop:
						return _ResultScript.reject(_ResultScript.REASON_DROP_NOT_ALLOWED, from_cell, to_cell)
					else:
						return _ResultScript.reject(_ResultScript.REASON_FALL_NOT_ALLOWED, from_cell, to_cell)

				var max_fall: int = profile.max_fall_height if profile != null else 6
				var max_fall_h: float = float(max_fall) * 2.0
				if abs_delta_lvl > max_fall or abs_delta_h > max_fall_h:
					if profile != null and profile.can_drop:
						return _ResultScript.reject(_ResultScript.REASON_DROP_TOO_HIGH, from_cell, to_cell)
					return _ResultScript.reject(_ResultScript.REASON_FALL_TOO_HIGH, from_cell, to_cell)

				if grid.has_method("find_lower_support"):
					var support: Dictionary = grid.find_lower_support(to_cell, max_fall)
					if not support.get("found", false) or not support.get("walkable", false):
						return _ResultScript.reject(_ResultScript.REASON_NO_SURFACE_BELOW, from_cell, to_cell)

				transition_type = _ResultScript.TransitionType.FALL
```

- [x] **Step 2: Ejecutar los tests actuales para asegurar cero regresiones**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_jumpable_elevation_rules.gd`
Expected: `ALL JUMPABLE ELEVATION TESTS PASSED!`

---

### Task 4: Unificar `WorldNavigationVisualizer` usando `analyze_transition()` y Altura Física

**Files:**
- Modify: `src/world_generator/navigation/world_navigation_visualizer.gd:214-260`
- Test: `tests/test_jumpable_elevation_rules.gd`

**Interfaces:**
- Consumes:
  - `grid.analyze_transition(cell, n_cell)`
  - `p_profile.get_effective_jump_up_height()`, `p_profile.get_effective_drop_height()`
- Produces:
  - `can_jump_up = true` y `can_jump_down = true` determinados por la misma autoridad de transición, detectando diferencias físicas de altura aun cuando `delta_level == 0`.

- [x] **Step 1: Refactorizar `_evaluate_jumpable_edges()` en `src/world_generator/navigation/world_navigation_visualizer.gd`**

```gdscript
## Evalúa si una celda transitable tiene vecinos con desniveles válidos para saltar hacia abajo o subir.
func _evaluate_jumpable_edges(cell: Vector2i, p_profile: MovementProfile) -> Dictionary:
	var res := {"can_jump_down": false, "can_jump_up": false}
	if grid == null:
		return res

	var max_up_lvl: int = p_profile.max_jump_up if p_profile != null else max_jump_up_height
	var max_up_h: float = p_profile.get_effective_jump_up_height() if p_profile != null and p_profile.has_method("get_effective_jump_up_height") else float(max_up_lvl) * 2.0

	var can_drop: bool = p_profile.can_drop if p_profile != null else true
	var max_drop_lvl: int = p_profile.max_drop_distance if p_profile != null else max_jump_down_height
	var max_drop_h: float = p_profile.get_effective_drop_height() if p_profile != null and p_profile.has_method("get_effective_drop_height") else float(max_drop_lvl) * 2.0

	for dir in _NEIGHBOR_DIRS:
		var n_cell := cell + dir

		var trans: Dictionary = {}
		if grid.has_method("analyze_transition"):
			trans = grid.analyze_transition(cell, n_cell)
			if not trans.get("valid", false) or not trans.get("to_walkable", false):
				continue
		else:
			if grid.has_method("has_cell") and not grid.has_cell(n_cell):
				continue
			if grid.has_method("is_walkable") and not grid.is_walkable(n_cell):
				continue
			var cur_lvl: int = grid.get_elevation_level(cell) if grid.has_method("get_elevation_level") else 0
			var tgt_lvl: int = grid.get_elevation_level(n_cell) if grid.has_method("get_elevation_level") else 0
			var cur_h: float = grid.get_height(cell) if grid.has_method("get_height") else 0.0
			var tgt_h: float = grid.get_height(n_cell) if grid.has_method("get_height") else 0.0
			trans = {
				"delta_level": tgt_lvl - cur_lvl,
				"delta_height": tgt_h - cur_h
			}

		if grid.has_method("is_water") and grid.is_water(n_cell):
			var water_mode: int = p_profile.water_mode if p_profile != null else _ProfileScript.WaterMode.LAND
			if water_mode == _ProfileScript.WaterMode.LAND:
				continue

		var delta_lvl: int = trans.get("delta_level", 0)
		var delta_h: float = trans.get("delta_height", 0.0)

		# 1. Bajar (delta negativo físico o de nivel)
		if delta_h < -0.05 or delta_lvl < 0:
			var abs_h: float = absf(delta_h)
			var abs_lvl: int = absi(delta_lvl)
			if can_drop and abs_h <= max_drop_h + 0.01 and abs_lvl <= max_drop_lvl:
				res.can_jump_down = true

		# 2. Subir (delta positivo físico o de nivel)
		elif delta_h > 0.05 or delta_lvl > 0:
			if delta_h <= max_up_h + 0.01 and delta_lvl <= max_up_lvl:
				res.can_jump_up = true

		if res.can_jump_down and res.can_jump_up:
			break

	return res
```

- [x] **Step 2: Ejecutar test de visualizador**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_jumpable_elevation_rules.gd`
Expected: `ALL JUMPABLE ELEVATION TESTS PASSED!`

---

### Task 5: Crear Casos de Prueba para Desniveles Físicos con Mismo Nivel Topológico

**Files:**
- Modify: `tests/test_jumpable_elevation_rules.gd`
- Test: `tests/test_jumpable_elevation_rules.gd`

**Interfaces:**
- Verifica el caso específico de la captura del usuario:
  - Dos celdas con `elevation_level = 2` idéntico.
  - Pero con diferencia física: `cell_a.height = 2.0` vs `cell_b.height = 3.0` ($\Delta_{\text{height}} = +1.0$ bloque).
  - Comprobar que:
    1. `analyze_transition()` retorna `delta_level == 0`, `delta_height == 1.0`, `is_same_height == false`.
    2. Caminar de A a B sin salto es RECHAZADO con `REASON_JUMP_REQUIRED`.
    3. Saltar de A a B con `is_jump = true` es ACEPTADO como `JUMP_UP`.
    4. El visualizador marca `cell_a` con `can_jump_up = true` (azul).
    5. El visualizador marca `cell_b` con `can_jump_down = true` (azul).

- [x] **Step 1: Añadir función `_test_physical_height_same_level()` en `tests/test_jumpable_elevation_rules.gd`**

```gdscript
func _test_physical_height_same_level() -> void:
	print(" -> Testing physical height difference with same elevation_level...")
	var grid := _NavGridScript.new(1.0, 16, Vector3.ZERO)
	var profile := _ProfileScript.new()
	profile.max_walk_step_up = 0
	profile.max_jump_up = 3
	profile.max_walk_step_down = 0
	profile.max_drop_distance = 4
	profile.can_drop = true

	var cells := {}
	# Celda inferior: (1, 1), level = 2, height = 2.0
	var c_low := _WorldCellScript.new(Vector2i(1, 1))
	c_low.elevation_level = 2
	c_low.height = 2.0
	c_low.is_walkable = true
	cells[Vector2i(1, 1)] = c_low

	# Celda superior: (2, 1), level = 2 (mismo nivel!), height = 3.0 (+1.0 bloque físico)
	var c_high := _WorldCellScript.new(Vector2i(2, 1))
	c_high.elevation_level = 2
	c_high.height = 3.0
	c_high.is_walkable = true
	cells[Vector2i(2, 1)] = c_high

	var chunk := _NavChunkScript.from_cells(Vector2i.ZERO, Rect2i(0, 0, 16, 16), cells)
	grid.register_chunk(chunk)

	# 1. analyze_transition
	var trans := grid.analyze_transition(Vector2i(1, 1), Vector2i(2, 1))
	assert(trans.delta_level == 0, "delta_level must be 0")
	assert(absf(trans.delta_height - 1.0) < 0.001, "delta_height must be 1.0")
	assert(trans.is_same_height == false, "is_same_height must be false")

	# 2. MovementRules
	var rules := _RulesScript.new()
	var res_walk := rules.validate_transition(Vector2i(1, 1), Vector2i(2, 1), grid, profile, null, null, false)
	assert(not res_walk.accepted, "Walk against +1.0m height wall without jump must be rejected")
	assert(res_walk.reason == _RulesScript._ResultScript.REASON_JUMP_REQUIRED, "Reason must be REASON_JUMP_REQUIRED")

	var res_jump := rules.validate_transition(Vector2i(1, 1), Vector2i(2, 1), grid, profile, null, null, true)
	assert(res_jump.accepted, "Jump against +1.0m height wall must be accepted")
	assert(res_jump.transition_type == _RulesScript._ResultScript.TransitionType.JUMP_UP, "Transition must be JUMP_UP")

	# 3. Visualizer
	var vis := _VisualizerScript.new()
	vis.grid = grid
	var info_low := vis._evaluate_jumpable_edges(Vector2i(1, 1), profile)
	assert(info_low.can_jump_up == true, "c_low must detect can_jump_up = true for +1.0m physical step")

	var info_high := vis._evaluate_jumpable_edges(Vector2i(2, 1), profile)
	assert(info_high.can_jump_down == true, "c_high must detect can_jump_down = true for -1.0m physical step")

	print("    [PASS] Physical height difference with same elevation_level correctly validated and visualized as jumpable")
```

- [x] **Step 2: Llamar `_test_physical_height_same_level()` en `_init()` de `test_jumpable_elevation_rules.gd`**

- [x] **Step 3: Ejecutar `test_jumpable_elevation_rules.gd`**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_jumpable_elevation_rules.gd`
Expected: `ALL JUMPABLE ELEVATION TESTS PASSED!`

---

### Task 6: Ejecutar la Batería Completa de Pruebas y Validación General

**Files:**
- Test: `tests/test_jumpable_elevation_rules.gd`
- Test: `src/gameplay/movement/tests/test_movement_unit.gd`
- Test: `src/gameplay/movement/tests/test_movement_integration.gd`

- [x] **Step 1: Ejecutar la suite completa de tests**

Run:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_jumpable_elevation_rules.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script src/gameplay/movement/tests/test_movement_unit.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script src/gameplay/movement/tests/test_movement_integration.gd
```
Expected: Todas las baterías de pruebas pasan con éxito (`ALL TESTS PASSED!`).
