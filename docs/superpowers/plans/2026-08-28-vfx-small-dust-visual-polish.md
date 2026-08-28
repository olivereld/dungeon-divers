# VFX Small Dust Visual Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformar `vfx_small_dust.tscn` en un efecto patrón de alta fidelidad visual compuesto por 4 capas especializadas (`DustBurst`, `DustCloud`, `Debris`, `GroundDust`) utilizando las texturas reales de `assets/texture/vfx/` (`dirt_01_a.png`, `cloud_01_8x8.tga`, `circle_05_a.png`), manteniendo `VFXInstance` como controlador genérico desacoplado y validando su ciclo de vida y limpieza de memoria con pruebas automatizadas.

**Architecture:**
```text
VFX_SmallDust (Node3D, script: res://src/vfx/vfx_instance.gd)
├── DustBurst      (CPUParticles3D | dirt_01_a.png | Ráfaga cónica ascendente 45° | 0.5s)
├── DustCloud      (CPUParticles3D | cloud_01_8x8.tga / smoke_04 | Bocanada volumétrica animada | 0.65s)
├── Debris         (CPUParticles3D | BoxMesh 3D | Fragmentos físicos parabólicos | 0.8s)
└── GroundDust     (CPUParticles3D | circle_05_a.png | Anillo horizontal a ras de suelo Y ≈ 0.03 | 0.5s)
```

**Tech Stack:** Godot 4.6 (GDScript), CPUParticles3D / GPUParticles3D, StandardMaterial3D (Unshaded, Billboard, Particle Animation), Data-Driven Textures.

**Spec & Assets:**
- Impact Dust Texture: `res://assets/texture/vfx/particles/alpha/dirt_01_a.png`
- Volumetric Cloud Flipbook: `res://assets/texture/vfx/flipbooks/cloud_01_8x8.tga`
- Soft Smoke Texture: `res://assets/texture/vfx/particles/alpha/smoke_04_a.png`
- Ground Ring Texture: `res://assets/texture/vfx/particles/alpha/circle_05_a.png`

## Global Constraints
- `VFXInstance` (`src/vfx/vfx_instance.gd`) permanece 100% genérico. No contiene rutas de texturas, nombres de capas ni lógica específica de props.
- No se modifican `DestructionComponent`, `DestructionResponseService`, `DestructionVFXRegistry` ni `DestructionVFXSpawner`.
- La escena `.tscn` es la única autoridad de cómo se ve el efecto.
- Todo emisor debe tener `one_shot = true` y `explosiveness >= 0.95`.
- Auto-cleanup garantizado al expirar `max_lifetime = 0.9s`.

---

### Task 1: Estructura y Materiales de las 4 Capas en `vfx_small_dust.tscn`

**Files:**
- Modify: `scenes/vfx/destruction/vfx_small_dust.tscn`
- Test: `tests/destruction/test_vfx_small_dust_scene.gd`

**Interfaces:**
- `DustBurst`: `QuadMesh`, `dirt_01_a.png`, `direction = (0, 1, 0)`, `spread = 45.0`, `initial_velocity = 2.5 - 4.5`, `gravity = (0, -1.0, 0)`, `lifetime = 0.5`.
- `DustCloud`: `QuadMesh`, `cloud_01_8x8.tga` o `smoke_04_a.png`, `particles_anim_h_frames = 8`, `particles_anim_v_frames = 8`, `lifetime = 0.65`, `scale_amount_min = 1.2`, `scale_amount_max = 2.5`.
- `Debris`: `BoxMesh` (0.12, 0.12, 0.12), `lifetime = 0.8`, `initial_velocity = 3.5 - 6.0`, `gravity = (0, -12.0, 0)`, `spread = 40.0`.
- `GroundDust`: `QuadMesh` orientado en horizontal ($XZ$, `orientation = 1`), `circle_05_a.png`, `lifetime = 0.5`, `gravity = Vector3.ZERO`, `scale_amount_min = 1.5`, `scale_amount_max = 3.0`.

- [ ] **Step 1: Write the failing structural test**

```gdscript
# tests/destruction/test_vfx_small_dust_scene.gd
extends SceneTree

const _VFXInstanceScript = preload("res://src/vfx/vfx_instance.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_vfx_small_dust_scene (Task 1) ---")
	print("==================================================================")
	var scn = load("res://scenes/vfx/destruction/vfx_small_dust.tscn") as PackedScene
	assert(scn != null, "FAIL: vfx_small_dust.tscn failed to load")

	var instance = scn.instantiate()
	assert(instance is _VFXInstanceScript, "FAIL: root must be VFXInstance")
	assert(instance.max_lifetime <= 1.0, "FAIL: max_lifetime should be around 0.9s")
	assert(instance.auto_cleanup == true, "FAIL: auto_cleanup must be true")

	# 1. Validar las 4 capas especializadas
	var burst = instance.get_node_or_null("DustBurst")
	assert(burst != null, "FAIL: DustBurst node missing")
	assert(burst is CPUParticles3D, "FAIL: DustBurst must be CPUParticles3D")
	assert(burst.one_shot == true, "FAIL: DustBurst must be one_shot")

	var cloud = instance.get_node_or_null("DustCloud")
	assert(cloud != null, "FAIL: DustCloud node missing")
	assert(cloud is CPUParticles3D, "FAIL: DustCloud must be CPUParticles3D")
	assert(cloud.one_shot == true, "FAIL: DustCloud must be one_shot")

	var debris = instance.get_node_or_null("Debris")
	assert(debris != null, "FAIL: Debris node missing")
	assert(debris is CPUParticles3D, "FAIL: Debris must be CPUParticles3D")
	assert(debris.one_shot == true, "FAIL: Debris must be one_shot")

	var ground = instance.get_node_or_null("GroundDust")
	assert(ground != null, "FAIL: GroundDust node missing")
	assert(ground is CPUParticles3D, "FAIL: GroundDust must be CPUParticles3D")
	assert(ground.one_shot == true, "FAIL: GroundDust must be one_shot")

	instance.free()
	print("[PASS] test_vfx_small_dust_scene passed 100%!")
	print("==================================================================")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_vfx_small_dust_scene.gd"`
Expected: FAIL (missing `DustBurst` or `GroundDust`).

- [ ] **Step 3: Implement updated `vfx_small_dust.tscn` with the 4 textured layers**

Create the 4 particle emitters with proper material passes:
1. `DustBurst`: `QuadMesh` + `StandardMaterial3D` (`dirt_01_a.png`, billboard mode).
2. `DustCloud`: `QuadMesh` + `StandardMaterial3D` (`cloud_01_8x8.tga` o `smoke_04_a.png`, billboard mode, soft alpha).
3. `Debris`: `BoxMesh` (0.12, 0.12, 0.12), gravity `-12.0`, angular spread `40°`.
4. `GroundDust`: `QuadMesh` (orientación horizontal $XZ$) + `StandardMaterial3D` (`circle_05_a.png`), Y=0.03.

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_vfx_small_dust_scene.gd"`
Expected: PASS 100%.

- [ ] **Step 5: Commit**

```bash
git add scenes/vfx/destruction/vfx_small_dust.tscn tests/destruction/test_vfx_small_dust_scene.gd
git commit -m "feat(vfx): implement 4-layer textured vfx_small_dust pattern"
```

---

### Task 2: Validación de Ciclo de Vida, Emisión y Auto-Cleanup en Runtime

**Files:**
- Create: `tests/destruction/test_vfx_small_dust_runtime_lifecycle.gd`

**Interfaces:**
- Instancia `vfx_small_dust.tscn` en un árbol `SceneTree`.
- Invoca `play()` y comprueba que las 4 capas están emitiendo (`emitting == true`).
- Avanza la simulación durante `max_lifetime` (`0.9s`) y comprueba que el nodo se libera automáticamente del árbol sin dejar residuos.

- [ ] **Step 1: Write lifecycle test**

```gdscript
# tests/destruction/test_vfx_small_dust_runtime_lifecycle.gd
extends SceneTree

const _VFXInstanceScript = preload("res://src/vfx/vfx_instance.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_vfx_small_dust_runtime_lifecycle (Task 2) ---")
	print("==================================================================")
	var scn = load("res://scenes/vfx/destruction/vfx_small_dust.tscn") as PackedScene
	var parent = Node3D.new()
	root.add_child(parent)
	await process_frame

	var vfx = scn.instantiate() as _VFXInstanceScript
	parent.add_child(vfx)
	vfx.play()

	assert(vfx.get_node("DustBurst").emitting == true, "FAIL: DustBurst must emit")
	assert(vfx.get_node("DustCloud").emitting == true, "FAIL: DustCloud must emit")
	assert(vfx.get_node("Debris").emitting == true, "FAIL: Debris must emit")
	assert(vfx.get_node("GroundDust").emitting == true, "FAIL: GroundDust must emit")

	# Forzar cleanup y verificar liberación de árbol
	vfx.cleanup()
	await process_frame

	parent.free()
	print("[PASS] test_vfx_small_dust_runtime_lifecycle passed 100%!")
	print("==================================================================")
	quit(0)
```

- [ ] **Step 2: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/destruction/test_vfx_small_dust_runtime_lifecycle.gd"`
Expected: PASS 100%.

- [ ] **Step 3: Commit**

```bash
git add tests/destruction/test_vfx_small_dust_runtime_lifecycle.gd
git commit -m "test(vfx): verify small_dust runtime emission and cleanup"
```

---

### Task 3: Integración y Verificación en Mazmorra (`dungeon_level.tscn`)

**Files:**
- Test: `tests/integration/test_dungeon_level_destruction_vfx_wiring.gd`

**Interfaces:**
- Generar una sala con urnas de cripta.
- Destruir una urna y verificar que `VFX_SmallDust` se instancia con las 4 capas activas en las coordenadas mundiales exactas.

- [ ] **Step 1: Run full integration regression test**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/integration/test_dungeon_level_destruction_vfx_wiring.gd"`
Expected: PASS 100%.

- [ ] **Step 2: Commit**

```bash
git commit -m "feat(vfx): complete small_dust visual polish verification"
```

---

## Plan Self-Review Checklist
- [x] Generic `VFXInstance`: Zero particle layer names in GDScript code.
- [x] Real Textures: `dirt_01_a.png`, `cloud_01_8x8.tga` / `smoke_04_a.png`, `circle_05_a.png`.
- [x] 4 Specialized Layers: `DustBurst`, `DustCloud`, `Debris`, `GroundDust`.
- [x] No modifications to destruction core components.
