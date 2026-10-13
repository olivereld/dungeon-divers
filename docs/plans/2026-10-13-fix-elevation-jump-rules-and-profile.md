# Fix Elevation Jump Rules & Profile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Corregir los valores por defecto de `MovementProfile` (`max_walk_step_up = 0`, `max_jump_up = 3`, `max_walk_step_down = 0`) y solucionar el bug en `MovementRules` donde un desnivel $\le \text{jump\_up}$ se degradaba erróneamente a `STEP_UP` en vez de rechazar con `REASON_JUMP_REQUIRED` cuando `is_jump == false`.

**Architecture:** 
1. `MovementProfile` define como regla base que los desniveles verticales no son caminables automáticamente (`max_walk_step_up = 0`, `max_walk_step_down = 0`), requiriendo salto hasta 3 bloques hacia arriba y 4 hacia abajo.
2. `MovementRules` valida estrictamente la rama `delta_level > 0`: si `delta_level > walk_up` y `delta_level <= jump_up`, rechaza con `REASON_JUMP_REQUIRED` si `is_jump == false`, impidiendo colisiones caminando contra paredes de 1 nivel.
3. `WorldNavigationVisualizer` evalúa y resalta con precisión las transiciones de borde entre celdas contiguas.

**Tech Stack:** Godot 4.6 GDScript, RefCounted, Node3D, StandardMaterial3D.

**Spec:**
- `MovementProfile.max_walk_step_up = 0`
- `MovementProfile.max_jump_up = 3`
- `MovementProfile.max_walk_step_down = 0`
- `MovementProfile.max_drop_distance = 4`
- Si $\Delta > 0 \land \Delta \le \text{jump\_up} \land \neg \text{is\_jump} \to \text{REASON\_JUMP\_REQUIRED}$ (sin degradar a `STEP_UP`).
- Si $\Delta < 0 \land |\Delta| \le \text{max\_drop} \land \neg \text{is\_jump} \to \text{REASON\_JUMP\_REQUIRED}$ (sin caer o bajar automáticamente).

## Global Constraints

- Preservar compatibilidad en tests de NPC/escalones donde se requiera probar explícitamente `STEP_UP` configurando `profile.max_walk_step_up = 1` localmente en dicho sub-test.
- Todas las suites de prueba (`test_movement_unit.gd`, `test_movement_integration.gd`, `test_jumpable_elevation_rules.gd`) deben pasar en Godot headless.

---

### Task 1: Corregir Valores por Defecto en `MovementProfile`

**Files:**
- Modify: `src/gameplay/movement/movement_profile.gd:35-50`
- Test: `tests/test_jumpable_elevation_rules.gd`

**Interfaces:**
- Produces:
  - `@export var max_walk_step_up: int = 0`
  - `@export var max_jump_up: int = 3`
  - `@export var max_walk_step_down: int = 0`
  - `@export var max_drop_distance: int = 4`

- [x] **Step 1: Modificar `src/gameplay/movement/movement_profile.gd` con los valores corregidos**

```gdscript
# En src/gameplay/movement/movement_profile.gd:

## Desnivel de elevación ascendente transitable automáticamente caminando sin saltar.
## Por defecto 0: cualquier elevación vertical requiere salto manual.
@export var max_walk_step_up: int = 0

## Máximo desnivel de elevación ascendente permitido mediante salto (JUMP_UP, hasta 3 bloques).
@export var max_jump_up: int = 3

## Desnivel de elevación descendente transitable automáticamente caminando sin saltar.
## Por defecto 0: cualquier borde o risco requiere salto manual.
@export var max_walk_step_down: int = 0

## Si es true, el movimiento normal por input no cambia de nivel automáticamente en los bordes.
@export var require_jump_for_elevation: bool = false
```

- [x] **Step 2: Verificar la carga del script en Godot headless**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_jumpable_elevation_rules.gd`
Expected: Carga sin errores de sintaxis.

---

### Task 2: Corregir el Bug de Validación en `MovementRules`

**Files:**
- Modify: `src/gameplay/movement/movement_rules.gd:65-115`
- Test: `tests/test_jumpable_elevation_rules.gd`

**Interfaces:**
- Consumes:
  - `profile.max_walk_step_up`, `profile.max_jump_up`, `profile.max_walk_step_down`, `profile.max_drop_distance`
  - `is_jump`
- Produces:
  - Rechazo estricto `REASON_JUMP_REQUIRED` cuando `is_jump == false` tanto en subidas como en bajadas de risco.

- [x] **Step 1: Escribir el caso de prueba para el bug en `tests/test_jumpable_elevation_rules.gd`**

Verificar que con `walk_up = 0` y `jump_up = 3`, intentar caminar hacia $\Delta = +1$ sin `is_jump` devuelva invariablemente `REASON_JUMP_REQUIRED` y NO sea aceptado como `STEP_UP`.

```gdscript
var rules := _RulesScript.new()
var prof := _ProfileScript.new()
prof.max_walk_step_up = 0
prof.max_jump_up = 3

var res_walk := rules.validate_transition(Vector2i(5, 5), Vector2i(6, 5), grid, prof, null, null, false)
assert(res_walk.accepted == false, "Walk towards +1 with walk_up=0 must be rejected")
assert(res_walk.reason == _RulesScript._ResultScript.REASON_JUMP_REQUIRED, "Reason must be REASON_JUMP_REQUIRED")
```

- [x] **Step 2: Corregir el bloque en `src/gameplay/movement/movement_rules.gd`**

```gdscript
		if delta_level == 0:
			transition_type = _ResultScript.TransitionType.WALK
		elif delta_level > 0:
			if delta_level <= walk_up and not is_jump:
				transition_type = _ResultScript.TransitionType.STEP_UP
			elif delta_level <= jump_up:
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
		else: # delta_level < 0
			var abs_delta: int = absi(delta_level)
			if abs_delta <= walk_down and not is_jump:
				transition_type = _ResultScript.TransitionType.STEP_DOWN
			elif abs_delta <= max_drop and profile != null and profile.can_drop:
				if not is_jump:
					return _ResultScript.reject(
						_ResultScript.REASON_JUMP_REQUIRED,
						from_cell,
						to_cell
					)
				if grid.has_method("find_lower_support"):
					var support: Dictionary = grid.find_lower_support(to_cell, max_drop)
					if not support.get("found", false) or not support.get("walkable", false):
						return _ResultScript.reject(_ResultScript.REASON_NO_SURFACE_BELOW, from_cell, to_cell)
				transition_type = _ResultScript.TransitionType.DROP
			else:
				var can_fall: bool = profile.can_fall if profile != null else true
				if not can_fall:
					if profile != null and profile.can_drop and abs_delta > max_drop:
						return _ResultScript.reject(_ResultScript.REASON_DROP_TOO_HIGH, from_cell, to_cell)
					elif profile != null and profile.can_drop:
						return _ResultScript.reject(_ResultScript.REASON_DROP_NOT_ALLOWED, from_cell, to_cell)
					else:
						return _ResultScript.reject(_ResultScript.REASON_FALL_NOT_ALLOWED, from_cell, to_cell)

				var max_fall: int = profile.max_fall_height if profile != null else 6
				if abs_delta > max_fall:
					if profile != null and profile.can_drop:
						return _ResultScript.reject(_ResultScript.REASON_DROP_TOO_HIGH, from_cell, to_cell)
					return _ResultScript.reject(_ResultScript.REASON_FALL_TOO_HIGH, from_cell, to_cell)

				if grid.has_method("find_lower_support"):
					var support: Dictionary = grid.find_lower_support(to_cell, max_fall)
					if not support.get("found", false) or not support.get("walkable", false):
						return _ResultScript.reject(_ResultScript.REASON_NO_SURFACE_BELOW, from_cell, to_cell)

				transition_type = _ResultScript.TransitionType.FALL
```

- [x] **Step 3: Ejecutar `tests/test_jumpable_elevation_rules.gd` para verificar el pase del test**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_jumpable_elevation_rules.gd`
Expected: `ALL JUMPABLE ELEVATION TESTS PASSED!`

---

### Task 3: Diagnosticar y Mejorar la Visualización en `WorldNavigationVisualizer`

**Files:**
- Modify: `src/world_generator/navigation/world_navigation_visualizer.gd:160-260`
- Test: Inspección con script scratch y visualizer

**Interfaces:**
- Consumes:
  - `p_profile.max_jump_up`, `p_profile.max_drop_distance`, `p_profile.max_walk_step_up`
- Produces:
  - Evaluación exacta de si una celda es un borde saltable (`can_jump_up`, `can_jump_down`), asegurando que cualquier celda contigua a un desnivel de 1 a 3 bloques se coloree en azul eléctrico/cian sin quedarse en verde plano.

- [x] **Step 1: Revisar `_evaluate_jumpable_edges` en `WorldNavigationVisualizer`**

Garantizar que:
1. `max_up = p_profile.max_jump_up if p_profile != null else max_jump_up_height` (3 bloques).
2. `max_drop = p_profile.max_drop_distance if p_profile != null else max_jump_down_height` (4 bloques).
3. Todo delta $> 0$ donde $\text{delta} \le \text{max\_up}$ active `res.can_jump_up = true` (coloreando la celda inferior en azul).
4. Todo delta $< 0$ donde $|\text{delta}| \le \text{max\_drop}$ active `res.can_jump_down = true` (coloreando la celda superior en azul).

- [x] **Step 2: Verificar con `scratch/check_jump_vis.gd` o script de prueba rápida**

Ejecutar inspección de celdas adyacentes para confirmar que la celda al pie del risco tiene `can_jump_up = true` y color azul.

---

### Task 4: Sincronizar Tests de la Suite y Validar Proyecto Completo

**Files:**
- Modify: `src/gameplay/movement/tests/test_movement_unit.gd:126-135`
- Modify: `src/gameplay/movement/tests/test_movement_integration.gd:158-165`
- Test: Toda la suite de tests

**Interfaces:**
- Garantiza que los tests unitarios donde se prueban intencionalmente escalones caminables de NPCs configuren explícitamente `profile.max_walk_step_up = 1` y `profile.max_jump_up = 1` para ese test en particular, o verifiquen `REASON_JUMP_REQUIRED`.

- [x] **Step 1: Ajustar `test_movement_unit.gd` para pruebas de escalón suave**

En las líneas donde `test_movement_unit.gd` prueba la caminata en escalón suave (+1 nivel como `STEP_UP`), asignar explícitamente `profile.max_walk_step_up = 1` antes de la llamada, documentando que con el default de 0 requeriría salto.

- [x] **Step 2: Ajustar `test_movement_integration.gd` línea 160**

En `test_movement_integration.gd`, asegurar que el NPC que prueba subir +2 niveles verifique el motivo de rechazo esperado acorde a su perfil.

- [x] **Step 3: Ejecutar la batería completa de pruebas**

Run:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script src/gameplay/movement/tests/test_movement_unit.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script src/gameplay/movement/tests/test_movement_integration.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_jumpable_elevation_rules.gd
```
Expected: Todas las pruebas reportan `ALL TESTS PASSED!`.
