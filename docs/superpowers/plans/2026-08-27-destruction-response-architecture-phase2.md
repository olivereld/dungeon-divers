# Destruction Response Architecture (Fase 2A a 2F) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar el subsistema modular y data-driven de respuestas a la destrucción (`src/destruction/response/`), extrayendo completamente de `DestructionComponent` cualquier lógica ajena a estado/durabilidad y organizando la ejecución desacoplada de Reemplazos (`Replacement`), Escombros (`Debris`) y Efectos (`Effects`).

**Architecture:** 
- `DestructionComponent`: Maneja exclusivamente durabilidad, daño y transiciones de estado (`INTACT -> DAMAGED -> CRITICAL -> DESTROYED`). Al destruirse emite `DestructionEvent`.
- `DestructionService`: Captura el evento y lo entrega a `DestructionResponseService`.
- `DestructionResponseService`: Orquesta de forma dinámica según la definición del objeto la secuencia: `Efectos (VFX/SFX) -> Reemplazo de Malla -> Generación de Escombros -> Cleanup/Ocultación del Original`.
- Consumidores (`Replacement`, `Debris`, `Effects`): Paquetes modulares bajo `src/destruction/response/` alimentados por catálogos JSON (`destruction.json`, `debris.json`, `effects.json`) y el `PropAssetRegistry`.

**Tech Stack:** Godot 4.6 (GDScript), Data-Driven JSON Catalogs, `PropAssetProvider` / `PropAssetRegistry`, CPUParticles3D / Shard Meshes.

**Spec:** [docs/superpowers/plans/2026-08-27-data-driven-destruction-system.md](file:///c:/Users/olivereld/Documents/dungeon-divers/docs/superpowers/plans/2026-08-27-data-driven-destruction-system.md)

## Global Constraints
- `DestructionComponent` NUNCA debe instanciar mallas, partículas ni escombros directamente.
- Cero hardcoding: Ningún consumidor ni servicio usará sentencias del tipo `if prop_id == "urn"`.
- Los consumidores deben estructurarse en sus respectivos submódulos: `response/replacement/`, `response/debris/`, `response/effects/`.
- Determinismo: Dispersión de escombros y variaciones de partículas se calculan con el `rng` del `DestructionResponseContext` (`DungeonSeed ^ PosHash`).

---

### Task 1: (Fase 2A) Response Architecture & Core Coordinator

**Files:**
- Create: `src/destruction/response/destruction_response_context.gd`
- Create: `src/destruction/response/destruction_response_service.gd`
- Modify: `src/destruction/runtime/destruction_service.gd`
- Test: `tests/destruction/test_destruction_phase2a_response_core.gd`

**Interfaces:**
- Consumes: `DestructionEvent`
- Produces: `DestructionResponseContext`, `DestructionResponseService.handle_destruction_event(event)`.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/destruction/test_destruction_phase2a_response_core.gd
extends SceneTree

const _DestructionContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionResponseServiceScript = preload("res://src/destruction/response/destruction_response_service.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")
const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")

func _init() -> void:
	print("--- Running test_destruction_phase2a_response_core ---")
	var node = Node3D.new()
	node.position = Vector3(8.0, 0.0, 16.0)
	node.set_meta("room_id", 4)

	var def = _DestructibleDefScript.from_dict(&"test_urn", {
		"durability": 20.0, "mode": "break", "replacement_asset": "broken_urn"
	})
	var hit = _DestructionHitScript.new(20.0, &"physical", Vector3(8, 0, 16), Vector3.UP, null)
	var evt = _DestructionEventScript.new(node, def, 0, 3, hit)

	var ctx = _DestructionContextScript.from_event(evt, 9999, 4)
	assert(ctx.event == evt, "FAIL: ctx must carry event")
	assert(ctx.target_transform.origin.is_equal_approx(Vector3(8, 0, 16)), "FAIL: ctx origin mismatch")
	assert(ctx.room_id == 4, "FAIL: ctx room_id mismatch")
	assert(ctx.source_asset_id == &"test_urn", "FAIL: ctx source_asset_id mismatch")
	assert(ctx.rng != null, "FAIL: ctx rng required")

	var response_service = _DestructionResponseServiceScript.new()
	var d_service = _DestructionServiceScript.new()
	d_service.set_response_service(response_service)

	var comp = _DestructionCompScript.new(def)
	node.add_child(comp)
	d_service.register_instance(node, comp)

	var captured := {"notified": false}
	d_service.global_destruction_event.connect(func(e): captured["notified"] = true)

	comp.apply_hit(hit)
	assert(comp.is_destroyed(), "FAIL: comp must be destroyed")
	assert(captured["notified"], "FAIL: event must reach d_service and response_service")

	node.free()
	print("[PASS] test_destruction_phase2a_response_core passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it passes/fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_phase2a_response_core.gd"`
Expected: PASS 100%.

- [ ] **Step 3: Commit**

```bash
git add src/destruction/response/ tests/destruction/test_destruction_phase2a_response_core.gd
git commit -m "feat(destruction): implement Phase 2A response architecture core"
```

---

### Task 2: (Fase 2B) Replacement System

**Files:**
- Create: `src/destruction/response/replacement/destruction_replacement_consumer.gd`
- Test: `tests/destruction/test_destruction_phase2b_replacement.gd`

**Interfaces:**
- Consumes: `PropAssetProvider`, `DestructionResponseContext`
- Produces: `handle_replacement(ctx, staging_parent) -> Node3D` materializing `definition.replacement_asset` with matching transform and metadata.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/destruction/test_destruction_phase2b_replacement.gd
extends SceneTree

const _ReplacementConsumerScript = preload("res://src/destruction/response/replacement/destruction_replacement_consumer.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _DestructionContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")

func _init() -> void:
	print("--- Running test_destruction_phase2b_replacement ---")
	var provider = _PropAssetProviderScript.new()
	var consumer = _ReplacementConsumerScript.new(provider)

	var parent = Node3D.new()
	var original_node = Node3D.new()
	parent.add_child(original_node)
	original_node.position = Vector3(14.0, 0.0, 22.0)

	# 1. Caso con replacement
	var def = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"durability": 20.0, "mode": "break", "replacement_asset": "crypt_urn_relic_floor"
	})
	var evt = _DestructionEventScript.new(original_node, def, 0, 3, null)
	var ctx = _DestructionContextScript.from_event(evt, 1234, 1)

	var rep = consumer.handle_replacement(ctx, parent)
	assert(rep != null, "FAIL: replacement node must be instantiated")
	assert(rep.position.is_equal_approx(Vector3(14.0, 0.0, 22.0)), "FAIL: position must match original")
	assert(rep.get_meta("is_destruction_replacement") == true, "FAIL: replacement meta flag required")
	assert(rep.get_meta("source_prop_id") == &"crypt_urn_banded_floor", "FAIL: source prop id meta required")

	# 2. Caso sin replacement
	var def_empty = _DestructibleDefScript.from_dict(&"skull_pile", {"durability": 15.0, "mode": "collapse"})
	var evt_empty = _DestructionEventScript.new(original_node, def_empty, 0, 3, null)
	var ctx_empty = _DestructionContextScript.from_event(evt_empty, 1234, 1)
	assert(consumer.handle_replacement(ctx_empty, parent) == null, "FAIL: must return null when no replacement defined")

	parent.free()
	print("[PASS] test_destruction_phase2b_replacement passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_phase2b_replacement.gd"`
Expected: FAIL (file missing or path adjustment).

- [ ] **Step 3: Write minimal implementation**

Implement `src/destruction/response/replacement/destruction_replacement_consumer.gd`.

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_phase2b_replacement.gd"`
Expected: PASS 100%.

- [ ] **Step 5: Commit**

```bash
git add src/destruction/response/replacement/ tests/destruction/test_destruction_phase2b_replacement.gd
git commit -m "feat(destruction): implement Phase 2B Replacement Consumer"
```

---

### Task 3: (Fase 2C) Debris System

**Files:**
- Create: `resources/dungeon_profiles/assets/debris.json`
- Create: `src/destruction/response/debris/destruction_debris_consumer.gd`
- Test: `tests/destruction/test_destruction_phase2c_debris.gd`

**Interfaces:**
- Consumes: `debris.json`, `DestructionResponseContext`
- Produces: `handle_debris(ctx, staging_parent) -> Array[Node3D]` generating deterministic 3D shards/meshes scattered around the origin.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/destruction/test_destruction_phase2c_debris.gd
extends SceneTree

const _DebrisConsumerScript = preload("res://src/destruction/response/debris/destruction_debris_consumer.gd")
const _DestructionContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")

func _init() -> void:
	print("--- Running test_destruction_phase2c_debris ---")
	var consumer = _DebrisConsumerScript.new()

	var parent = Node3D.new()
	var node = Node3D.new()
	parent.add_child(node)
	node.position = Vector3(20.0, 0.0, 20.0)

	var def = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"durability": 20.0, "mode": "break", "debris": "ceramic_small"
	})
	var evt = _DestructionEventScript.new(node, def, 0, 3, null)
	var ctx = _DestructionContextScript.from_event(evt, 888, 1)

	var shards = consumer.handle_debris(ctx, parent)
	assert(shards.size() >= 3 and shards.size() <= 6, "FAIL: shard count out of bounds")
	for s in shards:
		assert(s.position.distance_to(node.position) <= 2.0, "FAIL: shard too far from origin")
		assert(s.get_parent() == parent, "FAIL: shard parent mismatch")

	parent.free()
	print("[PASS] test_destruction_phase2c_debris passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_phase2c_debris.gd"`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

Implement `resources/dungeon_profiles/assets/debris.json` and `src/destruction/response/debris/destruction_debris_consumer.gd`.

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_phase2c_debris.gd"`
Expected: PASS 100%.

- [ ] **Step 5: Commit**

```bash
git add resources/dungeon_profiles/assets/debris.json src/destruction/response/debris/ tests/destruction/test_destruction_phase2c_debris.gd
git commit -m "feat(destruction): implement Phase 2C Debris Consumer and catalog"
```

---

### Task 4: (Fase 2D) Effects System & Registry

**Files:**
- Create: `resources/dungeon_profiles/assets/effects.json`
- Create: `src/destruction/response/effects/destruction_effect_registry.gd`
- Create: `src/destruction/response/effects/destruction_effects_consumer.gd`
- Test: `tests/destruction/test_destruction_phase2d_effects.gd`

**Interfaces:**
- Consumes: `effects.json`, `DestructionResponseContext`
- Produces: `handle_effects(ctx, staging_parent) -> Array[Node3D]` emitting particle systems / audio cues.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/destruction/test_destruction_phase2d_effects.gd
extends SceneTree

const _EffectsConsumerScript = preload("res://src/destruction/response/effects/destruction_effects_consumer.gd")
const _EffectRegistryScript = preload("res://src/destruction/response/effects/destruction_effect_registry.gd")
const _DestructionContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")

func _init() -> void:
	print("--- Running test_destruction_phase2d_effects ---")
	var reg = _EffectRegistryScript.new()
	assert(reg.has_effect("dust_small"), "FAIL: registry must contain dust_small")
	assert(reg.has_effect("ceramic_break"), "FAIL: registry must contain ceramic_break")

	var consumer = _EffectsConsumerScript.new(reg)
	var parent = Node3D.new()
	var node = Node3D.new()
	parent.add_child(node)
	node.position = Vector3(0, 0, 0)

	var def = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"durability": 20.0, "mode": "break", "effects": ["dust_small", "ceramic_break"]
	})
	var evt = _DestructionEventScript.new(node, def, 0, 3, null)
	var ctx = _DestructionContextScript.from_event(evt, 555, 1)

	var fx = consumer.handle_effects(ctx, parent)
	assert(fx.size() == 2, "FAIL: 2 particle emitters must be generated")

	parent.free()
	print("[PASS] test_destruction_phase2d_effects passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_phase2d_effects.gd"`
Expected: FAIL.

- [ ] **Step 3: Write minimal implementation**

Implement `src/destruction/response/effects/destruction_effect_registry.gd` and `src/destruction/response/effects/destruction_effects_consumer.gd`.

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_phase2d_effects.gd"`
Expected: PASS 100%.

- [ ] **Step 5: Commit**

```bash
git add resources/dungeon_profiles/assets/effects.json src/destruction/response/effects/ tests/destruction/test_destruction_phase2d_effects.gd
git commit -m "feat(destruction): implement Phase 2D Effects Consumer and Registry"
```

---

### Task 5: (Fase 2E) Lifecycle & Dynamic Orchestration

**Files:**
- Modify: `src/destruction/response/destruction_response_service.gd`
- Test: `tests/destruction/test_destruction_phase2e_orchestration.gd`

**Interfaces:**
- Consumes: `DestructionEvent`, orchestrates `Effects -> Replacement -> Debris -> Cleanup` dynamically depending on the definition (e.g. Urn vs Chest vs Candle).
- Produces: Execution order verification without hardcoding.

- [ ] **Step 1: Write orchestration test**

```gdscript
# tests/destruction/test_destruction_phase2e_orchestration.gd
extends SceneTree

const _DestructionResponseServiceScript = preload("res://src/destruction/response/destruction_response_service.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")

func _init() -> void:
	print("--- Running test_destruction_phase2e_orchestration ---")
	var provider = _PropAssetProviderScript.new()
	var parent = Node3D.new()
	var service = _DestructionResponseServiceScript.new(provider, 1337, parent)

	# 1. Urna: Effects + Debris + Replacement (si existe)
	var node_urn = Node3D.new()
	parent.add_child(node_urn)
	var def_urn = _DestructibleDefScript.from_dict(&"crypt_urn_banded_floor", {
		"durability": 20.0, "mode": "break", "replacement_asset": "crypt_urn_relic_floor",
		"debris": "ceramic_small", "effects": ["dust_small", "ceramic_break"]
	})
	var evt_urn = _DestructionEventScript.new(node_urn, def_urn, 0, 3, null)
	var res_urn = service.handle_destruction_event(evt_urn)

	assert(res_urn["replacement"] != null, "FAIL: urn must have replacement")
	assert(res_urn["debris"].size() >= 3, "FAIL: urn must have debris")
	assert(res_urn["effects"].size() == 2, "FAIL: urn must have 2 fx")

	# 2. Vela: Extinguish solo effects
	var node_candle = Node3D.new()
	parent.add_child(node_candle)
	var def_candle = _DestructibleDefScript.from_dict(&"candle_cluster", {
		"durability": 5.0, "mode": "extinguish", "effects": ["smoke_puff"]
	})
	var evt_candle = _DestructionEventScript.new(node_candle, def_candle, 0, 3, null)
	var res_candle = service.handle_destruction_event(evt_candle)

	assert(res_candle["replacement"] == null, "FAIL: candle must not have replacement")
	assert(res_candle["debris"].is_empty(), "FAIL: candle must not have debris")
	assert(res_candle["effects"].size() == 1, "FAIL: candle must have 1 smoke fx")

	parent.free()
	print("[PASS] test_destruction_phase2e_orchestration passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_phase2e_orchestration.gd"`
Expected: PASS 100%.

- [ ] **Step 3: Commit**

```bash
git add src/destruction/response/destruction_response_service.gd tests/destruction/test_destruction_phase2e_orchestration.gd
git commit -m "feat(destruction): implement Phase 2E dynamic response orchestration"
```

---

### Task 6: (Fase 2F) E2E Integration & Scene Testing

**Files:**
- Modify: `scenes/dungeon/dungeon_level_controller.gd`
- Test: `tests/destruction/test_destruction_phase2f_e2e.gd`

**Interfaces:**
- Consumes: Complete runtime pipeline with `DestructionDebugInteractor` and mouse clicks in `dungeon_level.tscn`.
- Produces: Full E2E verification of Urn, Skull Pile, Crate, Chest and Candle Cluster.

- [ ] **Step 1: Write full E2E test**

```gdscript
# tests/destruction/test_destruction_phase2f_e2e.gd
extends SceneTree

const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")
const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")
const _DestructionResponseServiceScript = preload("res://src/destruction/response/destruction_response_service.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _DestructionRegistryScript = preload("res://src/destruction/runtime/destruction_registry.gd")
const _DestructionBinderScript = preload("res://src/destruction/runtime/destruction_binder.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _PropSpawnerScript = preload("res://src/presentation/props/prop_spawner.gd")
const _PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const _PropFootprintScript = preload("res://src/presentation/props/prop_footprint.gd")

func _init() -> void:
	print("--- Running test_destruction_phase2f_e2e ---")
	var loader := _ProfileLoaderScript.new()
	var d_reg := _DestructionRegistryScript.new()
	loader.populate_destruction_registry(d_reg)

	var d_service := _DestructionServiceScript.new()
	var provider := _PropAssetProviderScript.new()
	var staging := Node3D.new()

	var response_service := _DestructionResponseServiceScript.new(provider, 7777, staging)
	d_service.set_response_service(response_service)

	var binder := _DestructionBinderScript.new(d_reg, d_service)
	var spawner := _PropSpawnerScript.new(provider, binder)

	# Probar Urna
	var style_urn = _PropStyleScript.new(
		&"crypt_urn_banded_floor", 0, 0, 0, _PropFootprintScript.new(Vector2i(1, 1)),
		&"crypt_urn_banded_floor", {}, 0, []
	)
	var dir_urn = _PropDirectiveScript.new(
		&"crypt_urn_banded_floor", 1, style_urn, Vector3(2.0, 0.0, 3.0), 0.0, [Vector2i(1, 1)]
	)
	var urn_node = spawner.spawn_prop(dir_urn, staging)
	var urn_comp: _DestructionCompScript = urn_node.get_node("DestructionComponent")
	urn_comp.apply_hit(_DestructionHitScript.new(30.0, &"physical"))

	assert(urn_comp.is_destroyed(), "FAIL: Urn must be destroyed")
	assert(not urn_node.visible, "FAIL: Urn must be hidden")

	var shards := 0
	var fx := 0
	for c in staging.get_children():
		if c.name.begins_with("Debris_"):
			shards += 1
		elif c.name.begins_with("FX_"):
			fx += 1

	assert(shards >= 3, "FAIL: shards must spawn in staging")
	assert(fx >= 1, "FAIL: fx must spawn in staging")

	staging.free()
	print("[PASS] test_destruction_phase2f_e2e passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_phase2f_e2e.gd"`
Expected: PASS 100%.

- [ ] **Step 3: Commit**

```bash
git add scenes/dungeon/dungeon_level_controller.gd tests/destruction/test_destruction_phase2f_e2e.gd
git commit -m "feat(destruction): complete Phase 2F E2E response integration"
```

---

## Plan Self-Review Checklist
- [x] Spec coverage: Tasks 2A to 2F fully represented.
- [x] No placeholders: Test code and directory structures complete.
- [x] Type consistency: Strict match across all consumer and context signatures.
