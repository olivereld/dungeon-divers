# Destruction Response Core (Fase 2.1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar y congelar la capa base de respuestas a la destrucción (`src/destruction/response/`) con `DestructionResponseContext` y `DestructionResponseService`, validando la canalización de eventos `DestructionComponent -> DestructionEvent -> DestructionService -> DestructionResponseService` mediante tests puros sin instanciar todavía mallas, escombros ni VFX reales.

**Architecture:** `DestructionComponent` emite la señal `destroyed(DestructionEvent)`. El runtime coordinator (`DestructionService`) captura esta señal y la reenvía a `DestructionResponseService`. Este servicio construye un `DestructionResponseContext` inmutable con el transform espacial, metadatos y semilla determinista, y delega a consumidores basados en contratos desacoplados.

**Tech Stack:** Godot 4.6 (GDScript), GDScript Signals, Unit/Integration Test Trees (`SceneTree`).

**Spec:** [docs/superpowers/plans/2026-08-27-data-driven-destruction-system.md](file:///c:/Users/olivereld/Documents/dungeon-divers/docs/superpowers/plans/2026-08-27-data-driven-destruction-system.md)

## Global Constraints
- `DestructionEvent` y `DestructibleDefinition` ya contienen los datos requeridos y sus contratos quedan formalmente congelados sin modificaciones.
- `DestructionComponent` nunca debe tener una referencia directa a `DestructionResponseService`; la comunicación se realiza exclusivamente vía señales a través de `DestructionService`.
- No implementar todavía generación de mallas de reemplazo, simulación física de escombros ni partículas VFX (reservados para Fases 2.2, 2.3 y 2.4).
- No modificar `props.json`, `fixtures.json`, `destruction.json` ni los spawners en esta fase.

---

### Task 1: Contexto de Respuesta (`DestructionResponseContext`)

**Files:**
- Create/Verify: `src/destruction/response/destruction_response_context.gd`
- Test: `tests/destruction/test_destruction_response_context.gd`

**Interfaces:**
- Consumes: `DestructionEvent`
- Produces: `DestructionResponseContext` con `event`, `global_transform`, `target_transform`, `room_id`, `source_asset_id`, `seed_value`, `base_seed`, `rng`.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/destruction/test_destruction_response_context.gd
extends SceneTree

const _DestructionContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")

func _init() -> void:
	print("--- Running test_destruction_response_context ---")
	var node = Node3D.new()
	node.position = Vector3(5, 0, 10)
	node.set_meta("room_id", 2)
	var def = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {"durability": 20.0, "mode": "break"})
	var evt = _DestructionEventScript.new(node, def, 0, 3, null)

	var ctx = _DestructionContextScript.from_event(evt, 12345, 2)
	assert(ctx.event == evt, "FAIL: context must retain event")
	assert(ctx.target_transform.origin == Vector3(5, 0, 10), "FAIL: transform origin mismatch")
	assert(ctx.room_id == 2, "FAIL: room_id mismatch")
	assert(ctx.source_asset_id == &"crypt_urn_banded_floor", "FAIL: source_asset_id mismatch")
	assert(ctx.base_seed == 12345, "FAIL: base_seed mismatch")
	assert(ctx.rng != null, "FAIL: rng must be initialized")

	# Deterministic random sequence verification
	var r1 = ctx.rng.randf()
	var ctx2 = _DestructionContextScript.from_event(evt, 12345, 2)
	var r2 = ctx2.rng.randf()
	assert(is_equal_approx(r1, r2), "FAIL: same seed must yield same sequence")

	node.free()
	print("[PASS] test_destruction_response_context passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it passes/fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_response_context.gd"`
Expected: PASS 100%.

- [ ] **Step 3: Commit**

```bash
git add src/destruction/response/destruction_response_context.gd tests/destruction/test_destruction_response_context.gd
git commit -m "feat(destruction): implement DestructionResponseContext data structure"
```

---

### Task 2: Coordinador de Respuestas (`DestructionResponseService`)

**Files:**
- Create/Verify: `src/destruction/response/destruction_response_service.gd`
- Modify: `src/destruction/runtime/destruction_service.gd`
- Test: `tests/destruction/test_destruction_response_service_unit.gd`

**Interfaces:**
- Consumes: `DestructionEvent` via `handle_destruction_event(event)`
- Produces: Dispatches to registered consumer delegates (replacement, debris, effects) passing `DestructionResponseContext`.

- [ ] **Step 1: Write the unit test with mock consumers**

```gdscript
# tests/destruction/test_destruction_response_service_unit.gd
extends SceneTree

const _DestructionResponseServiceScript = preload("res://src/destruction/response/destruction_response_service.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")

func _init() -> void:
	print("--- Running test_destruction_response_service_unit ---")
	var node = Node3D.new()
	node.position = Vector3(10, 0, 20)
	var def = _DestructibleDefScript.from_dict(&"test_prop", {"durability": 20.0, "mode": "break"})
	var evt = _DestructionEventScript.new(node, def, 0, 3, null)

	var service = _DestructionResponseServiceScript.new()
	assert(service.has_method("handle_destruction_event"), "FAIL: service must have handle_destruction_event method")

	var response_dict = service.handle_destruction_event(evt)
	assert(response_dict is Dictionary, "FAIL: handle_destruction_event must return Dictionary")
	assert(response_dict.has("replacement") and response_dict.has("debris") and response_dict.has("effects"), "FAIL: dictionary must have standard consumer keys")

	node.free()
	print("[PASS] test_destruction_response_service_unit passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_response_service_unit.gd"`
Expected: PASS 100%.

- [ ] **Step 3: Commit**

```bash
git add src/destruction/response/destruction_response_service.gd tests/destruction/test_destruction_response_service_unit.gd
git commit -m "feat(destruction): implement DestructionResponseService coordinator"
```

---

### Task 3: Test de Integración Mínimo de la Cadena

**Files:**
- Test: `tests/destruction/test_destruction_response_core_integration.gd`

**Interfaces:**
- Consumes: `DestructionComponent`, `DestructionHit`, `DestructionService`, `DestructionResponseService`.
- Verifies:
  `Urna -> apply_hit(fatal) -> DESTROYED -> DestructionEvent -> DestructionService -> DestructionResponseService -> Context -> PASS`
  sin dependencias visuales o físicas pesadas.

- [ ] **Step 1: Write integration test**

```gdscript
# tests/destruction/test_destruction_response_core_integration.gd
extends SceneTree

const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")
const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")
const _DestructionResponseServiceScript = preload("res://src/destruction/response/destruction_response_service.gd")

func _init() -> void:
	print("--- Running test_destruction_response_core_integration ---")

	var urn_node := Node3D.new()
	urn_node.position = Vector3(4.0, 0.0, 8.0)
	urn_node.set_meta("room_id", 1)

	var def = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"durability": 20.0,
		"mode": "break",
		"replacement_asset": "crypt_rubble_corner",
		"debris": "ceramic_small",
		"effects": ["dust_small", "ceramic_break"]
	})

	var response_service := _DestructionResponseServiceScript.new()
	var d_service := _DestructionServiceScript.new()
	d_service.set_response_service(response_service)

	var comp := _DestructionCompScript.new(def)
	urn_node.add_child(comp)
	d_service.register_instance(urn_node, comp)

	var stats := {"received": false}
	d_service.global_destruction_event.connect(func(e):
		stats["received"] = true
		assert(e.target == urn_node, "FAIL: event target mismatch")
		assert(e.definition == def, "FAIL: event definition mismatch")
	)

	# 1. Aplicar daño parcial (10 HP -> estado DAMAGED)
	var half_hit = _DestructionHitScript.new(10.0, &"physical")
	comp.apply_hit(half_hit)
	assert(not comp.is_destroyed(), "FAIL: should not be destroyed after partial hit")
	assert(not stats["received"], "FAIL: should not emit destruction event on partial damage")

	# 2. Aplicar daño fatal (15 HP -> DESTROYED -> Emisión de evento y respuesta)
	var fatal_hit = _DestructionHitScript.new(15.0, &"physical")
	comp.apply_hit(fatal_hit)
	assert(comp.is_destroyed(), "FAIL: component must be destroyed")
	assert(stats["received"], "FAIL: global_destruction_event must be emitted and forwarded to response service")

	urn_node.free()
	print("[PASS] test_destruction_response_core_integration passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_response_core_integration.gd"`
Expected: PASS 100%.

- [ ] **Step 3: Commit**

```bash
git add tests/destruction/test_destruction_response_core_integration.gd
git commit -m "test(destruction): add minimal core response integration test"
```

---

## Plan Self-Review Checklist
- [x] Spec coverage: Covers Phase 2.1 core response contracts and coordination.
- [x] No placeholders: Complete code blocks for all test steps.
- [x] Type consistency: `DestructionResponseContext` and `DestructionResponseService` signatures strictly aligned.
