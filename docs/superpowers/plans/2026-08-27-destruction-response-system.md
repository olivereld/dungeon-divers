# Destruction Response System (Fase 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar el subsistema de respuestas a la destrucción (`DestructionResponseService`) con consumidores desacoplados para reemplazo de mallas (`Replacement`), generación de escombros (`Debris`) y efectos audiovisuales (`Effects`), configurados mediante catálogos JSON data-driven sin tocar el core de `DestructionComponent`.

**Architecture:** Cuando un `DestructionComponent` alcanza el estado `DESTROYED`, emite un `DestructionEvent` inmutable que es capturado por `DestructionResponseService`. Este servicio delega en tres consumidores independientes (`DestructionReplacementConsumer`, `DestructionDebrisConsumer`, `DestructionEffectsConsumer`) utilizando un `DestructionResponseContext` determinista alimentado por el `DungeonSeed` y el transform espacial del objeto.

**Tech Stack:** Godot 4.6 (GDScript), Data-Driven JSON Catalogs (`debris.json`, `effects.json`, `destruction.json`), `PropAssetProvider` / `PropAssetRegistry`.

**Spec:** [docs/superpowers/plans/2026-08-27-data-driven-destruction-system.md](file:///c:/Users/olivereld/Documents/dungeon-divers/docs/superpowers/plans/2026-08-27-data-driven-destruction-system.md)

## Global Constraints
- `DestructionComponent` nunca debe instanciar mallas, escombros ni partículas directamente; sólo gestiona estado y emite eventos.
- Cero hardcoding de IDs de assets (`if prop_id == "urn"` prohibido). Toda configuración proviene de `destruction.json`, `debris.json` y `effects.json`.
- Consumidores reutilizan `PropAssetRegistry` / `PropAssetProvider` existente.
- Determinismo: Toda dispersión y variabilidad de escombros/VFX debe ser reproducible a partir de la semilla.

---

### Task 1: Catálogos Data-Driven (`debris.json` & `effects.json`)

**Files:**
- Create: `resources/dungeon_profiles/assets/debris.json`
- Create: `resources/dungeon_profiles/assets/effects.json`
- Test: `tests/destruction/test_destruction_catalogs_schema.gd`

**Interfaces:**
- Produces: JSON schemas para resolver definiciones de escombros (`ceramic_small`, `bones_small`, `wood_splinters`, `stone_fragments`) y efectos (`dust_small`, `ceramic_break`, `bone_scatter`, `smoke_puff`).

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/destruction/test_destruction_catalogs_schema.gd
extends SceneTree

func _init() -> void:
	print("--- Running test_destruction_catalogs_schema ---")
	var debris_file = FileAccess.open("res://resources/dungeon_profiles/assets/debris.json", FileAccess.READ)
	assert(debris_file != null, "FAIL: debris.json must exist")
	var debris_json = JSON.parse_string(debris_file.get_as_text())
	assert(debris_json is Dictionary and debris_json.has("debris"), "FAIL: debris.json schema invalid")
	assert(debris_json["debris"].has("ceramic_small"), "FAIL: ceramic_small debris required")

	var effects_file = FileAccess.open("res://resources/dungeon_profiles/assets/effects.json", FileAccess.READ)
	assert(effects_file != null, "FAIL: effects.json must exist")
	var effects_json = JSON.parse_string(effects_file.get_as_text())
	assert(effects_json is Dictionary and effects_json.has("effects"), "FAIL: effects.json schema invalid")
	assert(effects_json["effects"].has("dust_small"), "FAIL: dust_small effect required")

	print("[PASS] test_destruction_catalogs_schema passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_catalogs_schema.gd"`
Expected: FAIL (files missing).

- [ ] **Step 3: Write minimal implementation**

Create `resources/dungeon_profiles/assets/debris.json` with entries for `ceramic_small`, `bones_small`, `wood_splinters`, `stone_fragments`.
Create `resources/dungeon_profiles/assets/effects.json` with entries for `dust_small`, `ceramic_break`, `bone_scatter`, `smoke_puff`.

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_catalogs_schema.gd"`
Expected: PASS 100%.

- [ ] **Step 5: Commit**

```bash
git add resources/dungeon_profiles/assets/debris.json resources/dungeon_profiles/assets/effects.json tests/destruction/test_destruction_catalogs_schema.gd
git commit -m "feat(destruction): add debris and effects data-driven catalogs"
```

---

### Task 2: Contexto de Respuesta (`DestructionResponseContext`)

**Files:**
- Create: `src/destruction/response/destruction_response_context.gd`
- Test: `tests/destruction/test_destruction_response_context.gd`

**Interfaces:**
- Consumes: `DestructionEvent`
- Produces: `DestructionResponseContext` with `event`, `global_transform`, `room_id`, `seed_value`, `rng`.

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
	node.global_position = Vector3(5, 0, 10)
	var def = _DestructibleDefScript.from_dict(&"test_urn", {"durability": 20.0, "mode": "break"})
	var evt = _DestructionEventScript.new(node, def, 0, 3, null)

	var ctx = _DestructionContextScript.from_event(evt, 12345, 1)
	assert(ctx.event == evt, "FAIL: context must retain event")
	assert(ctx.global_transform.origin == Vector3(5, 0, 10), "FAIL: transform origin mismatch")
	assert(ctx.seed_value == 12345, "FAIL: seed mismatch")
	assert(ctx.room_id == 1, "FAIL: room_id mismatch")
	assert(ctx.rng != null, "FAIL: rng must be initialized")

	node.free()
	print("[PASS] test_destruction_response_context passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_response_context.gd"`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

Implement `src/destruction/response/destruction_response_context.gd` with factory `from_event(evt, seed, room_id)` initializing `RandomNumberGenerator` with seed.

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_response_context.gd"`
Expected: PASS 100%.

- [ ] **Step 5: Commit**

```bash
git add src/destruction/response/destruction_response_context.gd tests/destruction/test_destruction_response_context.gd
git commit -m "feat(destruction): implement DestructionResponseContext"
```

---

### Task 3: Consumidor de Reemplazo (`DestructionReplacementConsumer`)

**Files:**
- Create: `src/destruction/response/destruction_replacement_consumer.gd`
- Test: `tests/destruction/test_destruction_replacement_consumer.gd`

**Interfaces:**
- Consumes: `PropAssetProvider`, `DestructionResponseContext`
- Produces: `spawn_replacement(ctx) -> Node3D` materializing `definition.replacement_asset` at `ctx.global_transform`.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/destruction/test_destruction_replacement_consumer.gd
extends SceneTree

const _ReplacementConsumerScript = preload("res://src/destruction/response/destruction_replacement_consumer.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _DestructionContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")

func _init() -> void:
	print("--- Running test_destruction_replacement_consumer ---")
	var provider = _PropAssetProviderScript.new()
	var consumer = _ReplacementConsumerScript.new(provider)

	var parent = Node3D.new()
	var node = Node3D.new()
	parent.add_child(node)
	node.global_position = Vector3(2.0, 0.0, 4.0)

	var def = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"durability": 20.0,
		"mode": "break",
		"replacement_asset": "crypt_urn_relic_floor"
	})
	var evt = _DestructionEventScript.new(node, def, 0, 3, null)
	var ctx = _DestructionContextScript.from_event(evt, 999, 1)

	var rep_node = consumer.handle_replacement(ctx, parent)
	assert(rep_node != null, "FAIL: replacement node must be materialized")
	assert(rep_node.global_position.is_equal_approx(Vector3(2.0, 0.0, 4.0)), "FAIL: position must match original")

	parent.free()
	print("[PASS] test_destruction_replacement_consumer passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_replacement_consumer.gd"`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

Implement `src/destruction/response/destruction_replacement_consumer.gd`.

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_replacement_consumer.gd"`
Expected: PASS 100%.

- [ ] **Step 5: Commit**

```bash
git add src/destruction/response/destruction_replacement_consumer.gd tests/destruction/test_destruction_replacement_consumer.gd
git commit -m "feat(destruction): implement DestructionReplacementConsumer"
```

---

### Task 4: Consumidor de Escombros (`DestructionDebrisConsumer`)

**Files:**
- Create: `src/destruction/response/destruction_debris_consumer.gd`
- Test: `tests/destruction/test_destruction_debris_consumer.gd`

**Interfaces:**
- Consumes: `debris.json`, `DestructionResponseContext`
- Produces: `spawn_debris(ctx, staging_parent) -> Array[Node3D]` spawning scattered visual debris meshes around the destroyed object.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/destruction/test_destruction_debris_consumer.gd
extends SceneTree

const _DebrisConsumerScript = preload("res://src/destruction/response/destruction_debris_consumer.gd")
const _DestructionContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")

func _init() -> void:
	print("--- Running test_destruction_debris_consumer ---")
	var consumer = _DebrisConsumerScript.new()

	var parent = Node3D.new()
	var node = Node3D.new()
	parent.add_child(node)
	node.global_position = Vector3(10.0, 0.0, 10.0)

	var def = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"durability": 20.0,
		"mode": "break",
		"debris": "ceramic_small"
	})
	var evt = _DestructionEventScript.new(node, def, 0, 3, null)
	var ctx = _DestructionContextScript.from_event(evt, 42, 1)

	var spawned = consumer.handle_debris(ctx, parent)
	assert(spawned.size() >= 2 and spawned.size() <= 6, "FAIL: debris count must be within catalog bounds")
	for deb in spawned:
		assert(deb.global_position.distance_to(node.global_position) <= 2.0, "FAIL: debris must be scattered near origin")

	parent.free()
	print("[PASS] test_destruction_debris_consumer passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_debris_consumer.gd"`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

Implement `src/destruction/response/destruction_debris_consumer.gd` reading `debris.json` and creating procedural or mesh shards with deterministic offset and rotation.

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_debris_consumer.gd"`
Expected: PASS 100%.

- [ ] **Step 5: Commit**

```bash
git add src/destruction/response/destruction_debris_consumer.gd tests/destruction/test_destruction_debris_consumer.gd
git commit -m "feat(destruction): implement DestructionDebrisConsumer"
```

---

### Task 5: Consumidor de Efectos (`DestructionEffectsConsumer`)

**Files:**
- Create: `src/destruction/response/destruction_effects_consumer.gd`
- Test: `tests/destruction/test_destruction_effects_consumer.gd`

**Interfaces:**
- Consumes: `effects.json`, `DestructionResponseContext`
- Produces: `trigger_effects(ctx, staging_parent) -> Array[Node]` creating particle emitters or audio triggers.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/destruction/test_destruction_effects_consumer.gd
extends SceneTree

const _EffectsConsumerScript = preload("res://src/destruction/response/destruction_effects_consumer.gd")
const _DestructionContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")

func _init() -> void:
	print("--- Running test_destruction_effects_consumer ---")
	var consumer = _EffectsConsumerScript.new()

	var parent = Node3D.new()
	var node = Node3D.new()
	parent.add_child(node)
	node.global_position = Vector3(0, 0, 0)

	var def = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"durability": 20.0,
		"mode": "break",
		"effects": ["dust_small", "ceramic_break"]
	})
	var evt = _DestructionEventScript.new(node, def, 0, 3, null)
	var ctx = _DestructionContextScript.from_event(evt, 100, 1)

	var fx_nodes = consumer.handle_effects(ctx, parent)
	assert(fx_nodes.size() == 2, "FAIL: must trigger 2 effect handlers")

	parent.free()
	print("[PASS] test_destruction_effects_consumer passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_effects_consumer.gd"`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

Implement `src/destruction/response/destruction_effects_consumer.gd` reading `effects.json` and creating temporary GPUParticles3D / CPUParticles3D with one_shot autostart.

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_effects_consumer.gd"`
Expected: PASS 100%.

- [ ] **Step 5: Commit**

```bash
git add src/destruction/response/destruction_effects_consumer.gd tests/destruction/test_destruction_effects_consumer.gd
git commit -m "feat(destruction): implement DestructionEffectsConsumer"
```

---

### Task 6: Coordinador Global (`DestructionResponseService`) e Integración

**Files:**
- Create: `src/destruction/response/destruction_response_service.gd`
- Modify: `src/destruction/runtime/destruction_service.gd`
- Modify: `scenes/dungeon/dungeon_level_controller.gd`
- Test: `tests/destruction/test_destruction_response_integration.gd`

**Interfaces:**
- Consumes: `DestructionEvent`, delegates to Consumers, updates staging scene.
- Produces: Full E2E destruction pipeline in `dungeon_level.tscn`.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/destruction/test_destruction_response_integration.gd
extends SceneTree

const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")
const _DestructionResponseServiceScript = preload("res://src/destruction/response/destruction_response_service.gd")
const _DestructionBinderScript = preload("res://src/destruction/runtime/destruction_binder.gd")
const _DestructionRegistryScript = preload("res://src/destruction/runtime/destruction_registry.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _PropSpawnerScript = preload("res://src/presentation/props/prop_spawner.gd")
const _PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const _PropFootprintScript = preload("res://src/presentation/props/prop_footprint.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")

func _init() -> void:
	print("--- Running test_destruction_response_integration ---")
	var d_reg = _DestructionRegistryScript.new()
	var d_service = _DestructionServiceScript.new()
	var provider = _PropAssetProviderScript.new()
	var response_service = _DestructionResponseServiceScript.new(provider)
	d_service.set_response_service(response_service)

	var binder = _DestructionBinderScript.new(d_reg, d_service)
	var spawner = _PropSpawnerScript.new(provider, binder)

	var parent = Node3D.new()
	var style = _PropStyleScript.new(
		&"crypt_urn_banded_floor", 0, 0, 0, _PropFootprintScript.new(Vector2i(1, 1)),
		&"crypt_urn_banded_floor", {}, 0, []
	)
	var directive = _PropDirectiveScript.new(
		&"crypt_urn_banded_floor", 1, style, Vector3(0, 0, 0), 0.0, [Vector2i(0, 0)]
	)

	var urn_node = spawner.spawn_prop(directive, parent)
	var comp: _DestructionCompScript = null
	for c in urn_node.get_children():
		if c is _DestructionCompScript:
			comp = c
			break

	# Fatal Hit
	comp.apply_hit(_DestructionHitScript.new(50.0, &"physical"))

	# Verify replacement/debris spawned under parent
	assert(parent.get_child_count() > 1, "FAIL: responses must spawn replacement or debris into parent")
	assert(not urn_node.visible, "FAIL: original urn must be hidden")

	parent.free()
	print("[PASS] test_destruction_response_integration passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_response_integration.gd"`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

Implement `DestructionResponseService`, connect to `DestructionService.destroyed` signal, wire to `dungeon_level_controller.gd`.

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_response_integration.gd"`
Expected: PASS 100%.

- [ ] **Step 5: Commit**

```bash
git add src/destruction/response/destruction_response_service.gd src/destruction/runtime/destruction_service.gd scenes/dungeon/dungeon_level_controller.gd tests/destruction/test_destruction_response_integration.gd
git commit -m "feat(destruction): integrate DestructionResponseService with runtime pipeline"
```

---

## Plan Self-Review Checklist
- [x] Spec coverage: Covered replacement, debris, effects, context, service and catalogs.
- [x] No placeholders: All code blocks, types and tests fully written out.
- [x] Type consistency: `DestructionResponseContext`, `DestructionReplacementConsumer`, `DestructionDebrisConsumer`, `DestructionEffectsConsumer`, `DestructionResponseService` names match throughout.
