# Navigation Transition & Jump System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Conectar formalmente la autoridad espacial de navegación con las reglas de movimiento y el input del jugador, clasificando explícitamente las transiciones entre celdas ($A \to B$) en `WALK`, `STEP_UP`, `JUMP_UP`, `DROP` y `FALL`, desacoplando la caminata suave del salto manual mediante umbrales específicos (`max_walk_step_up` vs `max_jump_up`).

**Architecture:** La cuadrícula espacial (`WorldNavigationGrid`) expone las propiedades físicas y topológicas de cada celda ($A \to B$). `MovementProfile` define las capacidades del actor (`max_walk_step_up`, `max_jump_up`, `max_walk_step_down`, `max_drop_distance`). `MovementRules` valida la transición recibiendo `MovementRequest(direction, is_jump)` y asigna formalmente el tipo de transición. `MovementComponent` ejecuta la animación y el arco parabólico de 0.48s simétrico.

**Tech Stack:** Godot 4.6 GDScript, Node3D / CharacterBody3D, Packed Arrays, State Machine AnimationTree.

**Spec:** Análisis y especificación de arquitectura de transición espacial:
- `delta == 0` $\to$ `WALK`
- `0 < delta <= max_walk_step_up` $\to$ `STEP_UP` (caminable automático)
- `delta <= max_jump_up` $\to$ `JUMP_UP` (requiere `is_jump = true` / Space, de lo contrario `REASON_JUMP_REQUIRED`)
- `delta > max_jump_up` $\to$ `REASON_ELEVATION_TOO_HIGH`
- `0 < abs_delta <= max_walk_step_down` $\to$ `STEP_DOWN` (descenso suave automático)
- `abs_delta <= max_drop_distance` $\to$ `DROP` (requiere `is_jump = true` / Space, de lo contrario `REASON_JUMP_REQUIRED`)
- `abs_delta <= max_fall_height` y `can_fall` $\to$ `FALL`
- `abs_delta > max_drop_distance` sin caída $\to$ `REASON_DROP_TOO_HIGH`

## Global Constraints

- Preservar la compatibilidad con tests unitarios existentes en `src/gameplay/movement/tests/`.
- Mantener compatibilidad con los aliases existentes de `MovementProfile` (`max_step_up`, `max_step_down`, `require_jump_for_elevation`).
- Mantener `cells_per_second` y curvas de interpolación continuas.
- Sin llamadas blocking en física; cálculos puramente discretos e interpolaciones en `process_movement`.

---

### Task 1: Refactorizar `MovementProfile` con Separación Conceptual de Caminata y Salto

**Files:**
- Modify: `src/gameplay/movement/movement_profile.gd:35-85`
- Test: `tests/test_jumpable_elevation_rules.gd`

**Interfaces:**
- Produces:
  - `@export var max_walk_step_up: int = 0` (desnivel ascendente que se puede caminar sin saltar)
  - `@export var max_jump_up: int = 3` (desnivel ascendente máximo franqueable saltando)
  - `@export var max_walk_step_down: int = 0` (desnivel descendente que se puede bajar sin saltar)
  - `@export var max_drop_distance: int = 4` (desnivel descendente máximo con salto controlado)
  - Getters/setters de compatibilidad para `max_step_up` y `max_step_down`.

- [x] **Step 1: Modificar `MovementProfile` con las nuevas propiedades y aliases retrocompatibles**

```gdscript
# En src/gameplay/movement/movement_profile.gd:

## Desnivel de elevación ascendente transitable automáticamente caminando sin saltar.
## Si es 0, cualquier elevación requiere salto manual.
@export var max_walk_step_up: int = 0

## Máximo desnivel de elevación ascendente permitido mediante salto (JUMP_UP, hasta 3 bloques).
@export var max_jump_up: int = 3

## Desnivel de elevación descendente transitable automáticamente caminando sin saltar.
## Si es 0, cualquier borde o risco requiere salto manual.
@export var max_walk_step_down: int = 0

## Máximo desnivel de elevación descendente permitido para un salto en descenso controlado (DROP).
@export var max_drop_distance: int = 4

## Alias de retrocompatibilidad para max_jump_up.
var max_step_up: int:
	get:
		return max_jump_up
	set(val):
		max_jump_up = val

## Alias de retrocompatibilidad para max_walk_step_down.
var max_step_down: int:
	get:
		return max_walk_step_down
	set(val):
		max_walk_step_down = val
```

- [x] **Step 2: Ejecutar los tests de movimiento existentes para verificar no-regresión**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script src/gameplay/movement/tests/test_movement_unit.gd`
Expected: `ALL MOVEMENT UNIT TESTS PASSED!`

---

### Task 2: Incorporar Análisis de Transición entre Celdas en `WorldNavigationGrid`

**Files:**
- Modify: `src/world_generator/navigation/world_navigation_grid.gd:85-125`
- Test: `tests/test_jumpable_elevation_rules.gd`

**Interfaces:**
- Produces:
  - `func analyze_transition(from_cell: Vector2i, to_cell: Vector2i) -> Dictionary`
    Retorna un diccionario con:
    - `valid: bool` (ambas celdas existen y están cargadas)
    - `from_level: int`, `to_level: int`, `delta_level: int`
    - `from_height: float`, `to_height: float`
    - `from_walkable: bool`, `to_walkable: bool`
    - `is_same_level: bool`

- [x] **Step 1: Implementar `analyze_transition` en `WorldNavigationGrid`**

```gdscript
# En src/world_generator/navigation/world_navigation_grid.gd:

func analyze_transition(from_cell: Vector2i, to_cell: Vector2i) -> Dictionary:
	var res := {
		"valid": false,
		"from_level": 0,
		"to_level": 0,
		"delta_level": 0,
		"from_height": 0.0,
		"to_height": 0.0,
		"from_walkable": false,
		"to_walkable": false,
		"is_same_level": true
	}
	if not has_cell(from_cell) or not has_cell(to_cell):
		return res
	res.valid = true
	res.from_level = get_elevation_level(from_cell)
	res.to_level = get_elevation_level(to_cell)
	res.delta_level = res.to_level - res.from_level
	res.from_height = get_height(from_cell)
	res.to_height = get_height(to_cell)
	res.from_walkable = is_walkable(from_cell)
	res.to_walkable = is_walkable(to_cell)
	res.is_same_level = (res.delta_level == 0)
	return res
```

- [x] **Step 2: Verificar la integración de `analyze_transition` en `MovementGrid` como envoltorio polimórfico**

Garantizar que `MovementGrid` delegue a `nav.analyze_transition` cuando esté presente, o provea fallback directo sobre sus celdas.

---

### Task 3: Actualizar `MovementRules.validate_transition` con Clasificación Formal de Salto

**Files:**
- Modify: `src/gameplay/movement/movement_rules.gd:55-125`
- Test: `tests/test_jumpable_elevation_rules.gd`

**Interfaces:**
- Consumes:
  - `MovementProfile.max_walk_step_up`, `MovementProfile.max_jump_up`, `MovementProfile.max_walk_step_down`, `MovementProfile.max_drop_distance`
  - `MovementRequest.is_jump`
- Produces:
  - `validate_transition(...) -> MovementResult` clasificando rigurosamente:
    - $\Delta = 0 \to \text{WALK}$
    - $\Delta > 0 \land \Delta \le \text{max\_walk\_step\_up} \land \neg \text{is\_jump} \to \text{STEP\_UP}$
    - $\Delta > 0 \land \Delta \le \text{max\_jump\_up} \land \text{is\_jump} \to \text{JUMP\_UP}$
    - $\Delta > 0 \land \Delta \le \text{max\_jump\_up} \land \neg \text{is\_jump} \to \text{REASON\_JUMP\_REQUIRED}$
    - $\Delta > 0 \land \Delta > \text{max\_jump\_up} \to \text{REASON\_ELEVATION\_TOO\_HIGH}$
    - $\Delta < 0 \land |\Delta| \le \text{max\_walk\_step\_down} \land \neg \text{is\_jump} \to \text{STEP\_DOWN}$
    - $\Delta < 0 \land |\Delta| \le \text{max\_drop\_distance} \land \text{is\_jump} \to \text{DROP}$
    - $\Delta < 0 \land \neg \text{is\_jump} \to \text{REASON\_JUMP\_REQUIRED}$ (si supera walk_step_down)

- [x] **Step 1: Escribir test en `tests/test_jumpable_elevation_rules.gd` para la nueva clasificación**

Probar los 5 casos de transición vertical:
1. $\Delta = 0$ caminando $\to$ `WALK`.
2. $\Delta = +1$ sin salto con `max_walk_step_up = 0` $\to$ Rechazado `REASON_JUMP_REQUIRED`.
3. $\Delta = +1$ con `is_jump = true` y `max_jump_up = 3` $\to$ Aceptado `JUMP_UP`.
4. $\Delta = -1$ sin salto con `max_walk_step_down = 0` $\to$ Rechazado `REASON_JUMP_REQUIRED`.
5. $\Delta = -1$ con `is_jump = true` y `max_drop_distance = 4` $\to$ Aceptado `DROP`.

- [x] **Step 2: Implementar la lógica en `MovementRules.validate_transition`**

```gdscript
# En src/gameplay/movement/movement_rules.gd:

		# 5. Desnivel de elevación discreto y clasificación formal de transición
		var transition_type: int = _ResultScript.TransitionType.WALK
		if water_mode != _ProfileScript.WaterMode.FLY:
			var cur_level: int = grid.get_elevation_level(from_cell)
			var target_level: int = grid.get_elevation_level(to_cell)
			var delta_level: int = target_level - cur_level

			var walk_up: int = profile.max_walk_step_up if profile != null else 0
			var jump_up: int = profile.max_jump_up if profile != null else 1
			var walk_down: int = profile.max_walk_step_down if profile != null else 0
			var max_drop: int = profile.max_drop_distance if profile != null else 4

			if delta_level == 0:
				transition_type = _ResultScript.TransitionType.WALK
			elif delta_level > 0:
				if delta_level <= walk_up and not is_jump:
					transition_type = _ResultScript.TransitionType.STEP_UP
				elif delta_level <= jump_up:
					if not is_jump:
						return _ResultScript.reject(_ResultScript.REASON_JUMP_REQUIRED, from_cell, to_cell)
					transition_type = _ResultScript.TransitionType.JUMP_UP
				else:
					return _ResultScript.reject(_ResultScript.REASON_ELEVATION_TOO_HIGH, from_cell, to_cell)
			else: # delta_level < 0
				var abs_delta: int = absi(delta_level)
				if abs_delta <= walk_down and not is_jump:
					transition_type = _ResultScript.TransitionType.STEP_DOWN
				elif abs_delta <= max_drop and profile != null and profile.can_drop:
					if not is_jump:
						return _ResultScript.reject(_ResultScript.REASON_JUMP_REQUIRED, from_cell, to_cell)
					if grid.has_method("find_lower_support"):
						var support: Dictionary = grid.find_lower_support(to_cell, max_drop)
						if not support.get("found", false) or not support.get("walkable", false):
							return _ResultScript.reject(_ResultScript.REASON_NO_SURFACE_BELOW, from_cell, to_cell)
					transition_type = _ResultScript.TransitionType.DROP
				else:
					# Caída (FALL) solo si está permitida y excede el control del salto
					var can_fall: bool = profile.can_fall if profile != null else true
					var max_fall: int = profile.max_fall_height if profile != null else 6
					if not can_fall:
						return _ResultScript.reject(_ResultScript.REASON_DROP_TOO_HIGH, from_cell, to_cell)
					if abs_delta > max_fall:
						return _ResultScript.reject(_ResultScript.REASON_FALL_TOO_HIGH, from_cell, to_cell)
					transition_type = _ResultScript.TransitionType.FALL
```

- [x] **Step 3: Ejecutar `test_movement_unit.gd` y `test_movement_integration.gd`**

Run: `& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script src/gameplay/movement/tests/test_movement_unit.gd`
Expected: `ALL MOVEMENT UNIT TESTS PASSED!`

---

### Task 4: Entrada Explícita `Space + Dirección` y Configuración en `PlayerTest`

**Files:**
- Modify: `src/character_test/player_test.gd:340-360, 520-560`
- Test: `tests/test_jumpable_elevation_rules.gd`

**Interfaces:**
- Consumes:
  - `Input.is_key_pressed(KEY_SPACE)`, `Input.is_action_pressed("ui_accept")`
  - `grid_dir` proyectado en 8 direcciones
- Produces:
  - Generación de `MovementRequest.new(grid_dir, &"player", true)` cuando Space está activo y se apunta a un desnivel válido.

- [x] **Step 1: Ajustar el perfil del jugador en `_setup_movement_component`**

```gdscript
# En src/character_test/player_test.gd:

	movement_component.profile.can_drop = true
	movement_component.profile.max_walk_step_up = 0     # Requiere saltar explícitamente para cualquier desnivel
	movement_component.profile.max_jump_up = 3          # Salta hasta 3 bloques hacia arriba
	movement_component.profile.max_walk_step_down = 0   # Requiere saltar para bajar riscos
	movement_component.profile.max_drop_distance = 4    # Desciende hasta 4 bloques
	movement_component.profile.drop_arc_height = 0.35
	movement_component.profile.drop_windup_time = 0.35
	movement_component.profile.drop_flight_time = 0.48
	movement_component.profile.jump_up_flight_time = 0.48
```

- [x] **Step 2: Mejorar el control de `Space + WASD` en `_physics_process`**

Si el jugador está presionando una dirección con WASD y pulsa Space (o mantiene Space mientras camina hacia un borde):
1. Capturar la dirección elegida (`preferred_dir`).
2. Invocar `movement_component.request_jump(preferred_dir)` de forma prioritaria sobre la caminata simple.
3. Si la solicitud de salto es aceptada, no emitir la solicitud de caminata en ese frame.

- [x] **Step 3: Probar manualmente con `test_jump_at_8_18.gd` o script de inspección**

Verificar que correr hacia un risco no avance automáticamente, y que presionar Space en el borde ejecute inmediatamente `JUMP_UP` o `DROP` hacia la dirección seleccionada.

---

### Task 5: Actualizar `WorldNavigationVisualizer` y Verificación Final de la Suite de Pruebas

**Files:**
- Modify: `src/world_generator/navigation/world_navigation_visualizer.gd:220-250`
- Test: Todos los tests de movimiento

**Interfaces:**
- Consumes:
  - `profile.max_jump_up`, `profile.max_drop_distance`
- Produces:
  - Malla semitransparente con detección de bordes azul alineada al perfil activo.

- [x] **Step 1: Adaptar `_evaluate_jumpable_edges` a las nuevas propiedades de `MovementProfile`**

```gdscript
# En src/world_generator/navigation/world_navigation_visualizer.gd:

	var cur_level: int = grid.get_elevation_level(cell)
	var max_up: int = p_profile.max_jump_up if p_profile != null else max_jump_up_height
	var max_down: int = p_profile.max_walk_step_down if p_profile != null else 1
	var can_drop: bool = p_profile.can_drop if p_profile != null else true
	var max_drop: int = p_profile.max_drop_distance if p_profile != null else max_jump_down_height
```

- [x] **Step 2: Ejecutar toda la batería de tests automatizados**

Run:
```powershell
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script src/gameplay/movement/tests/test_movement_unit.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script src/gameplay/movement/tests/test_movement_integration.gd
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless --script tests/test_jumpable_elevation_rules.gd
```
Expected: Todas las pruebas reportan `ALL TESTS PASSED!`.
