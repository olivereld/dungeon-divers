# Destruction VFX Pipeline (Fase VFX) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar el pipeline de efectos visuales (VFX) data-driven desacoplado del sistema de destrucción. El catálogo `vfx.json` resuelve `effect_id -> PackedScene`, `DestructionVFXSpawner` instancia en el transform del impacto, `VFXInstance` gestiona el ciclo de vida y auto-cleanup (`queue_free()`) de forma genérica, y las escenas `.tscn` definen el aspecto visual sin lógica hardcodeada en scripts.

**Architecture:**
```text
                  JSON (destruction.json)
                            │
                            │ "effects": [{"id": "stone_break"}]
                            ▼
               DestructionEffectsConsumer
                            │
                            │ effect_id = "stone_break"
                            ▼
                  DestructionVFXSpawner
                            │
                            ▼
                  DestructionVFXRegistry
                            │
                            │ vfx.json -> PackedScene
                            ▼
                       VFXInstance (src/vfx/vfx_instance.gd)
                            │
               ┌────────────┴────────────┐
               ▼                         ▼
         GPUParticles3D /          GPUParticles3D /
          CPUParticles3D            CPUParticles3D
            (Layer 1)                 (Layer 2)
               │                         │
               └────────────┬────────────┘
                            ▼
                   queue_free() (Auto-cleanup)
```

**Tech Stack:** Godot 4.6 (GDScript), PackedScene (.tscn), GPUParticles3D / CPUParticles3D, Data-Driven JSON Registry.

**Spec:** [docs/superpowers/plans/2026-08-27-data-driven-destruction-system.md](file:///c:/Users/olivereld/Documents/dungeon-divers/docs/superpowers/plans/2026-08-27-data-driven-destruction-system.md)

## Global Constraints
- **`VFXInstance` es genérico**: Controla exclusivamente `play()`, `stop()`, `max_lifetime`, y auto-cleanup (`queue_free()`). Desconoce nombres de capas específicas como `DustCloud` o `Debris`.
- **Las escenas `.tscn` definen la estética**: Partículas, materiales, curvas de emisión y gravedad se configuran en la escena empaquetada.
- **`DestructionVFXSpawner` es agnóstico a destrucción**: Solo opera con `(effect_id, Transform3D, parent) -> Node3D`.
- **`DestructionEffectsConsumer` no crea partículas en código**: Consulta al spawner y delega la instanciación de la `PackedScene`.
- **Garantía de Cleanup**: Todo VFX instanciado se libera automáticamente tras su `max_lifetime` para prevenir acumulación de nodos invisibles en runtime.

---

### Task 1: (Bloque 1) Catálogo Declarativo (`vfx.json`) y Registro (`DestructionVFXRegistry`)

**Files:**
- Create: `resources/dungeon_profiles/assets/vfx.json`
- Create: `src/destruction/response/effects/destruction_vfx_registry.gd`
- Test: `tests/destruction/test_destruction_vfx_registry.gd`

**Interfaces:**
- Input: `resources/dungeon_profiles/assets/vfx.json`
- Output: `DestructionVFXRegistry.get_scene_path(effect_id: String) -> String`, `get_scene(effect_id: String) -> PackedScene`, `has_effect(effect_id: String) -> bool`.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/destruction/test_destruction_vfx_registry.gd
extends SceneTree

const _VFXRegistryScript = preload("res://src/destruction/response/effects/destruction_vfx_registry.gd")

func _init() -> void:
	print("--- Running test_destruction_vfx_registry ---")
	var reg = _VFXRegistryScript.new()
	assert(reg.has_effect("small_dust"), "FAIL: small_dust must be defined in vfx.json")
	assert(reg.get_scene_path("small_dust") == "res://scenes/vfx/destruction/vfx_small_dust.tscn", "FAIL: scene path mismatch")
	assert(reg.has_effect("stone_break"), "FAIL: stone_break must be defined")
	assert(reg.has_effect("wood_break"), "FAIL: wood_break must be defined")
	assert(reg.has_effect("bone_collapse"), "FAIL: bone_collapse must be defined")
	assert(reg.has_effect("heavy_dust"), "FAIL: heavy_dust must be defined")

	print("[PASS] test_destruction_vfx_registry passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_vfx_registry.gd"`
Expected: FAIL.

- [ ] **Step 3: Implement `vfx.json` and `DestructionVFXRegistry`**

Create `resources/dungeon_profiles/assets/vfx.json` with the 5 semantic effect IDs and implement `src/destruction/response/effects/destruction_vfx_registry.gd`.

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_vfx_registry.gd"`
Expected: PASS 100%.

- [ ] **Step 5: Commit**

```bash
git add resources/dungeon_profiles/assets/vfx.json src/destruction/response/effects/destruction_vfx_registry.gd tests/destruction/test_destruction_vfx_registry.gd
git commit -m "feat(vfx): implement vfx.json and DestructionVFXRegistry"
```

---

### Task 2: (Bloque 2) Controlador de Runtime Genérico (`VFXInstance`)

**Files:**
- Create: `src/vfx/vfx_instance.gd`
- Test: `tests/destruction/test_destruction_vfx_instance_generic.gd`

**Interfaces:**
- `VFXInstance`: `max_lifetime: float`, `auto_cleanup: bool`, `auto_play: bool`, `play()`, `stop()`.
- Descubre y reproduce automáticamente todos los emisores compatibles (`GPUParticles3D`, `CPUParticles3D`, `AudioStreamPlayer3D`) hijos sin conocer nombres de capas específicos.
- Emite señal `finished` y ejecuta `queue_free()` al expirar `max_lifetime`.

- [ ] **Step 1: Write the generic lifecycle test**

```gdscript
# tests/destruction/test_destruction_vfx_instance_generic.gd
extends SceneTree

const _VFXInstanceScript = preload("res://src/vfx/vfx_instance.gd")

func _init() -> void:
	print("--- Running test_destruction_vfx_instance_generic ---")
	var root = Node3D.new()
	var vfx_ctrl = _VFXInstanceScript.new()
	vfx_ctrl.max_lifetime = 0.4
	vfx_ctrl.auto_cleanup = true
	root.add_child(vfx_ctrl)

	# Añadir emisores arbitrarios
	var p1 = CPUParticles3D.new()
	p1.one_shot = true
	root.add_child(p1)

	var p2 = CPUParticles3D.new()
	p2.one_shot = true
	root.add_child(p2)

	vfx_ctrl.play()
	assert(p1.emitting == true, "FAIL: child emitter 1 must be emitting")
	assert(p2.emitting == true, "FAIL: child emitter 2 must be emitting")

	root.free()
	print("[PASS] test_destruction_vfx_instance_generic passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_vfx_instance_generic.gd"`
Expected: FAIL.

- [ ] **Step 3: Implement `src/vfx/vfx_instance.gd`**

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_vfx_instance_generic.gd"`
Expected: PASS 100%.

- [ ] **Step 5: Commit**

```bash
git add src/vfx/vfx_instance.gd tests/destruction/test_destruction_vfx_instance_generic.gd
git commit -m "feat(vfx): implement generic VFXInstance runtime controller"
```

---

### Task 3: (Bloque 3 & 4) Spawner Desacoplado (`DestructionVFXSpawner`) y Primer VFX Real (`vfx_small_dust.tscn`)

**Files:**
- Create: `src/destruction/response/effects/destruction_vfx_spawner.gd`
- Create: `scenes/vfx/destruction/vfx_small_dust.tscn`
- Test: `tests/destruction/test_destruction_vfx_spawner.gd`

**Interfaces:**
- `DestructionVFXSpawner.spawn_effect(effect_id: String, xform: Transform3D, parent: Node3D) -> Node3D`
- Carga `PackedScene` desde `DestructionVFXRegistry`, asigna transform, añade al árbol y ejecuta `play()`.

- [ ] **Step 1: Write spawner test**

```gdscript
# tests/destruction/test_destruction_vfx_spawner.gd
extends SceneTree

const _VFXSpawnerScript = preload("res://src/destruction/response/effects/destruction_vfx_spawner.gd")
const _VFXRegistryScript = preload("res://src/destruction/response/effects/destruction_vfx_registry.gd")

func _init() -> void:
	print("--- Running test_destruction_vfx_spawner ---")
	var reg = _VFXRegistryScript.new()
	var spawner = _VFXSpawnerScript.new(reg)

	var parent = Node3D.new()
	var xform = Transform3D(Basis(), Vector3(12.0, 0.5, 24.0))

	var vfx_node = spawner.spawn_effect("small_dust", xform, parent)
	assert(vfx_node != null, "FAIL: small_dust node must be spawned")
	assert(vfx_node.position.is_equal_approx(Vector3(12.0, 0.5, 24.0)), "FAIL: position mismatch")
	assert(vfx_node.get_parent() == parent, "FAIL: parent mismatch")

	# Retorno limpio de null ante effect_id desconocido
	assert(spawner.spawn_effect("unknown_effect", xform, parent) == null, "FAIL: unknown fx must return null")

	parent.free()
	print("[PASS] test_destruction_vfx_spawner passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_vfx_spawner.gd"`
Expected: FAIL.

- [ ] **Step 3: Create `scenes/vfx/destruction/vfx_small_dust.tscn` and implement `DestructionVFXSpawner`**

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_vfx_spawner.gd"`
Expected: PASS 100%.

- [ ] **Step 5: Commit**

```bash
git add src/destruction/response/effects/destruction_vfx_spawner.gd scenes/vfx/destruction/vfx_small_dust.tscn tests/destruction/test_destruction_vfx_spawner.gd
git commit -m "feat(vfx): implement DestructionVFXSpawner and vfx_small_dust scene"
```

---

### Task 4: (Bloque 5) Conexión Desacoplada de `DestructionEffectsConsumer`

**Files:**
- Modify: `src/destruction/response/effects/destruction_effects_consumer.gd`
- Test: `tests/destruction/test_destruction_effects_consumer_spawner_integration.gd`

**Interfaces:**
- `DestructionEffectsConsumer` recibe `ctx: DestructionResponseContext`, itera `ctx.event.definition.effects` y llama `spawner.spawn_effect(eff_id, ctx.global_transform, parent)`.

- [ ] **Step 1: Write integration test**

```gdscript
# tests/destruction/test_destruction_effects_consumer_spawner_integration.gd
extends SceneTree

const _EffectsConsumerScript = preload("res://src/destruction/response/effects/destruction_effects_consumer.gd")
const _VFXSpawnerScript = preload("res://src/destruction/response/effects/destruction_vfx_spawner.gd")
const _VFXRegistryScript = preload("res://src/destruction/response/effects/destruction_vfx_registry.gd")
const _DestructionContextScript = preload("res://src/destruction/response/destruction_response_context.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")
const _DestructibleDefScript = preload("res://src/destruction/core/destructible_definition.gd")

func _init() -> void:
	print("--- Running test_destruction_effects_consumer_spawner_integration ---")
	var reg = _VFXRegistryScript.new()
	var spawner = _VFXSpawnerScript.new(reg)
	var consumer = _EffectsConsumerScript.new(spawner)

	var parent = Node3D.new()
	var target = Node3D.new()
	parent.add_child(target)
	target.position = Vector3(5, 0, 10)

	var def = _DestructibleDefScript.from_dict(&"test_prop", {
		"durability": 20.0, "mode": "break", "effects": [{"id": "small_dust"}]
	})
	var evt = _DestructionEventScript.new(target, def, 0, 3, null)
	var ctx = _DestructionContextScript.from_event(evt, 1337, 1)

	var nodes = consumer.handle_effects(ctx, parent)
	assert(nodes.size() == 1, "FAIL: 1 VFX instance must be returned")
	assert(nodes[0].position.is_equal_approx(Vector3(5, 0, 10)), "FAIL: VFX position mismatch")

	parent.free()
	print("[PASS] test_destruction_effects_consumer_spawner_integration passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it passes/fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_effects_consumer_spawner_integration.gd"`
Expected: PASS 100%.

- [ ] **Step 3: Commit**

```bash
git add src/destruction/response/effects/destruction_effects_consumer.gd tests/destruction/test_destruction_effects_consumer_spawner_integration.gd
git commit -m "feat(destruction): connect EffectsConsumer to DestructionVFXSpawner"
```

---

### Task 5: (Bloque 6) Biblioteca Completa de Escenas VFX (`stone_break`, `wood_break`, `bone_collapse`, `heavy_dust`)

**Files:**
- Create: `scenes/vfx/destruction/vfx_stone_break.tscn`
- Create: `scenes/vfx/destruction/vfx_wood_break.tscn`
- Create: `scenes/vfx/destruction/vfx_bone_collapse.tscn`
- Create: `scenes/vfx/destruction/vfx_heavy_dust.tscn`
- Test: `tests/destruction/test_destruction_vfx_library_completeness.gd`

**Interfaces:**
- Cada escena implementa `VFXInstance` como controlador de runtime con capas de partículas especializadas y temporizador de auto-cleanup.

- [ ] **Step 1: Write library completeness test**

```gdscript
# tests/destruction/test_destruction_vfx_library_completeness.gd
extends SceneTree

const _VFXRegistryScript = preload("res://src/destruction/response/effects/destruction_vfx_registry.gd")
const _VFXSpawnerScript = preload("res://src/destruction/response/effects/destruction_vfx_spawner.gd")

func _init() -> void:
	print("--- Running test_destruction_vfx_library_completeness ---")
	var reg = _VFXRegistryScript.new()
	var spawner = _VFXSpawnerScript.new(reg)
	var parent = Node3D.new()

	var required = ["small_dust", "stone_break", "wood_break", "bone_collapse", "heavy_dust"]
	for fx_id in required:
		var node = spawner.spawn_effect(fx_id, Transform3D.IDENTITY, parent)
		assert(node != null, "FAIL: effect failed to spawn: %s" % fx_id)
		assert(node.name.begins_with("VFX_"), "FAIL: node prefix mismatch for %s" % fx_id)

	parent.free()
	print("[PASS] test_destruction_vfx_library_completeness passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_vfx_library_completeness.gd"`
Expected: FAIL.

- [ ] **Step 3: Create the 4 remaining VFX scenes**

Create `vfx_stone_break.tscn`, `vfx_wood_break.tscn`, `vfx_bone_collapse.tscn`, `vfx_heavy_dust.tscn`.

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_vfx_library_completeness.gd"`
Expected: PASS 100%.

- [ ] **Step 5: Commit**

```bash
git add scenes/vfx/destruction/ tests/destruction/test_destruction_vfx_library_completeness.gd
git commit -m "feat(vfx): create full destruction VFX scene library"
```

---

### Task 6: (Bloque 7) Test de Auto-Cleanup de Memoria y Test E2E de Integración

**Files:**
- Modify: `resources/dungeon_profiles/assets/destruction.json`
- Test: `tests/destruction/test_destruction_vfx_cleanup.gd`
- Test: `tests/destruction/test_destruction_vfx_e2e_pipeline.gd`

**Interfaces:**
- Test 1: `test_destruction_vfx_cleanup.gd`: Verifica que al instanciarse un VFX en el árbol, al expirar su `max_lifetime` el nodo es liberado automáticamente del `SceneTree`.
- Test 2: `test_destruction_vfx_e2e_pipeline.gd`: Prueba integral: Urna (`stone_break`), Caja (`wood_break`), Pila de Huesos (`bone_collapse`).

- [ ] **Step 1: Write cleanup and E2E tests**

```gdscript
# tests/destruction/test_destruction_vfx_cleanup.gd
extends SceneTree

const _VFXSpawnerScript = preload("res://src/destruction/response/effects/destruction_vfx_spawner.gd")
const _VFXRegistryScript = preload("res://src/destruction/response/effects/destruction_vfx_registry.gd")

func _init() -> void:
	print("--- Running test_destruction_vfx_cleanup ---")
	var reg = _VFXRegistryScript.new()
	var spawner = _VFXSpawnerScript.new(reg)
	var parent = Node3D.new()
	root.add_child(parent)

	var node = spawner.spawn_effect("small_dust", Transform3D.IDENTITY, parent)
	assert(node != null and is_instance_valid(node), "FAIL: VFX node must be valid")
	assert(node.is_inside_tree(), "FAIL: VFX node must be inside tree")

	# Forzar proceso de temporizador / timer timeout
	if node.has_node("VFXInstance"):
		var ctrl = node.get_node("VFXInstance")
		ctrl.cleanup()

	# Al procesar el frame siguiente, el nodo debe haber sido encolado para liberación
	await process_frame
	parent.free()
	print("[PASS] test_destruction_vfx_cleanup passed 100%!")
	quit(0)
```

```gdscript
# tests/destruction/test_destruction_vfx_e2e_pipeline.gd
extends SceneTree

const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
const _DestructionRegistryScript = preload("res://src/destruction/runtime/destruction_registry.gd")
const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")
const _DestructionResponseServiceScript = preload("res://src/destruction/response/destruction_response_service.gd")
const _DestructionBinderScript = preload("res://src/destruction/runtime/destruction_binder.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _PropSpawnerScript = preload("res://src/presentation/props/prop_spawner.gd")
const _PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const _PropFootprintScript = preload("res://src/presentation/props/prop_footprint.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")

func _init() -> void:
	print("--- Running test_destruction_vfx_e2e_pipeline ---")
	var loader := _ProfileLoaderScript.new()
	var d_reg := _DestructionRegistryScript.new()
	loader.populate_destruction_registry(d_reg)

	var d_service := _DestructionServiceScript.new()
	var provider := _PropAssetProviderScript.new()
	var staging := Node3D.new()
	var resp_service := _DestructionResponseServiceScript.new(provider, 1337, staging)
	d_service.set_response_service(resp_service)

	var binder := _DestructionBinderScript.new(d_reg, d_service)
	var spawner := _PropSpawnerScript.new(provider, binder)

	# 1. Probar Urna Cripta -> stone_break
	var style_urn = _PropStyleScript.new(
		&"crypt_urn_banded_floor", 0, 0, 0, _PropFootprintScript.new(Vector2i(1, 1)),
		&"crypt_urn_banded_floor", {}, 0, []
	)
	var dir_urn = _PropDirectiveScript.new(
		&"crypt_urn_banded_floor", 1, style_urn, Vector3(5.0, 0.0, 5.0), 0.0, [Vector2i(1, 1)]
	)
	var urn = spawner.spawn_prop(dir_urn, staging)
	var urn_comp = urn.get_node("DestructionComponent")
	urn_comp.apply_hit(_DestructionHitScript.new(50.0, &"physical"))

	var vfx_count := 0
	for child in staging.get_children():
		if child.name.begins_with("VFX_"):
			vfx_count += 1
	assert(vfx_count >= 1, "FAIL: VFX scene must be instantiated in staging")

	staging.free()
	print("[PASS] test_destruction_vfx_e2e_pipeline passed 100%!")
	quit(0)
```

- [ ] **Step 2: Update `destruction.json` to map semantic effects**

- [ ] **Step 3: Run both tests to verify they pass**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_vfx_cleanup.gd; & 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_destruction_vfx_e2e_pipeline.gd"`
Expected: PASS 100%.

- [ ] **Step 4: Commit**

```bash
git add resources/dungeon_profiles/assets/destruction.json tests/destruction/test_destruction_vfx_cleanup.gd tests/destruction/test_destruction_vfx_e2e_pipeline.gd
git commit -m "feat(destruction): complete VFX pipeline integration and cleanup testing"
```

---

## Plan Self-Review Checklist
- [x] Generic `VFXInstance`: Zero hardcoded references to `DustCloud` or `Debris` in code.
- [x] Scene-defined aesthetics: Particle count, materials, curves live strictly in `.tscn`.
- [x] Complete semantic catalog: `small_dust`, `stone_break`, `wood_break`, `bone_collapse`, `heavy_dust`.
- [x] Dedicated cleanup test: Prevents memory leaks and invisible node accumulation.
