# Asset Pipeline v2: Pipeline Completamente Data-Driven para Modelos 3D y Props (Zero GDScript Hardcoding)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformar el sistema de props en un pipeline 100% data-driven donde cualquier nuevo modelo 3D (`.glb` / `.tscn`) o prop procedural se registre y configure exclusivamente a través de [props.json](file:///c:/Users/olivereld/Documents/dungeon-divers/resources/dungeon_profiles/assets/props.json), eliminando todo hardcodeo en GDScript en [prop_asset_registry.gd](file:///c:/Users/olivereld/Documents/dungeon-divers/src/presentation/decoration/assets/prop_asset_registry.gd) y soportando variantes ponderadas de mallas externas.

**Architecture:** 
1. [props.json](file:///c:/Users/olivereld/Documents/dungeon-divers/resources/dungeon_profiles/assets/props.json) se convierte en la única fuente de verdad autoritativa para todos los props (procedurales y `PACKED_SCENE`).
2. [ProfileLoader](file:///c:/Users/olivereld/Documents/dungeon-divers/src/dungeon_generator/profiles/profile_loader.gd) deserializa de forma robusta las definiciones de assets, validando tipos de origen (`packed_scene` vs `procedural`), parámetros de instanciación, colisiones y offsets.
3. [PropAssetRegistry](file:///c:/Users/olivereld/Documents/dungeon-divers/src/presentation/decoration/assets/prop_asset_registry.gd) queda limpio de definiciones hardcodeadas en GDScript, poblándose íntegramente desde [props.json](file:///c:/Users/olivereld/Documents/dungeon-divers/resources/dungeon_profiles/assets/props.json).
4. Se introduce un validador de contratos de assets (`PropAssetValidator`) y soporte para variantes ponderadas de modelos 3D (`pillar_stone`, `pillar_stone_cracked`).

**Tech Stack:** Godot 4.6.1 GDScript, JSON Schema v1, PackedScene, GLB 3D Pipeline.

---

## Global Constraints

- **Zero GDScript Asset Hardcoding**: Ningún `prop_id` individual ni ruta de escena debe estar escrita como constante o función de registro en archivos GDScript (`prop_asset_registry.gd`, `prop_asset_provider.gd`, etc.).
- **TDD Estricto**: Cada tarea inicia con un test automatizado fallido (`failing test`) y finaliza con verificación verde.
- **Resiliencia y Fallback**: Si una escena `.tscn` o `.glb` externa no existe o falla su carga, el pipeline registra una advertencia clara y no interrumpe la generación de la mazmorra.
- **Preservación Arquitectónica**: No modificar el núcleo del generador procedural (`DungeonPipeline`, `DecorationCompositionPlanner`, `CellGrid`).

---

## Plan Tasks

### Task 1: Migración Integral de Definiciones a `props.json`

**Files:**
- Modify: `resources/dungeon_profiles/assets/props.json`
- Test: `tests/presentation/decoration/test_props_json_schema_completeness.gd`

**Interfaces:**
- Consumes: JSON data format para `props.json`.
- Produces: Definición exhaustiva de todos los props clásicos (sarcófagos, tumbas, urnas, altares, bancos, cofres, cajas, etc.) con especificación formal `"source": { "type": "procedural" | "packed_scene", ... }`.

- [ ] **Step 1: Escribir el test de completitud del esquema de `props.json`**
  Crear `tests/presentation/decoration/test_props_json_schema_completeness.gd` para verificar que cada prop en `props.json` tiene `source.type`, `tags`, `footprint`, `collision`, `placement` y `scale`.
- [ ] **Step 2: Ejecutar el test y confirmar el fallo / gaps actuales**
- [ ] **Step 3: Actualizar `props.json` con todas las definiciones procedurales y externas estructuradas**
- [ ] **Step 4: Ejecutar el test y verificar que pasa con 100% de cobertura**

---

### Task 2: Refactorización de `PropAssetRegistry` (Eliminación de Hardcodeo GDScript)

**Files:**
- Modify: `src/presentation/decoration/assets/prop_asset_registry.gd`
- Modify: `src/dungeon_generator/profiles/profile_loader.gd`
- Test: `tests/presentation/decoration/test_prop_asset_registry_data_driven.gd`

**Interfaces:**
- Consumes: `ProfileLoader.populate_prop_asset_registry(registry)`.
- Produces: `PropAssetRegistry` puro, libre de listas estáticas de props en código fuente GDScript.

- [ ] **Step 1: Escribir test unitario de carga 100% data-driven en `test_prop_asset_registry_data_driven.gd`**
- [ ] **Step 2: Ejecutar el test y confirmar el comportamiento inicial**
- [ ] **Step 3: Limpiar `_register_default_definitions()` en `prop_asset_registry.gd` y delegar en `ProfileLoader`**
- [ ] **Step 4: Ejecutar los tests de regresión de registry y spawner**

---

### Task 3: Soporte de Variantes Ponderadas de Modelos 3D y Validación de Contratos

**Files:**
- Create: `src/presentation/decoration/assets/prop_asset_validator.gd`
- Create: `assets/scenes/props/pillar_stone_cracked.tscn`
- Modify: `resources/dungeon_profiles/assets/props.json`
- Modify: `src/dungeon_generator/profiles/profile_loader.gd`
- Test: `tests/presentation/decoration/test_3d_model_variants_pipeline.gd`

**Interfaces:**
- Consumes: Variantes declaradas en `props.json` (`variants: [ { "id": "...", "weight": 30.0 } ]`).
- Produces: `PropAssetValidator.validate_registry(registry)` y resolución probabilística de variantes 3D al materializar.

- [ ] **Step 1: Escribir test para variantes 3D (`test_3d_model_variants_pipeline.gd`)**
- [ ] **Step 2: Implementar `PropAssetValidator` para verificar mallas, colisiones y pivots de modelos externos**
- [ ] **Step 3: Crear escena de benchmark de variante (`pillar_stone_cracked.tscn`) y registrarla en `props.json`**
- [ ] **Step 4: Ejecutar el test y verificar resolución de variantes ponderadas**

---

### Task 4: Validación End-to-End en Mazmorras (Benchmark Crypt & Royal Tomb)

**Files:**
- Test: `tests/presentation/decoration/test_external_3d_pipeline_e2e.gd`

**Interfaces:**
- Consumes: Generación completa de mazmorras multi-semilla con el nuevo pipeline v2.
- Produces: Reporte de diagnóstico confirmando que tanto modelos procedurales como mallas externas conviven con variantes y sin tocar GDScript.

- [ ] **Step 1: Escribir test end-to-end de 100 semillas con modelos 3D y variantes**
- [ ] **Step 2: Ejecutar benchmark de 100 semillas y confirmar 100% de éxito**
- [ ] **Step 3: Documentar guía para artistas sobre cómo agregar cualquier `.glb` en 2 pasos**

---

## Verification Plan

### Automated Tests
```powershell
# 1. Validación de esquema data-driven
powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/presentation/decoration/test_props_json_schema_completeness.gd"

# 2. Validación de registro sin GDScript hardcodeado
powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/presentation/decoration/test_prop_asset_registry_data_driven.gd"

# 3. Validación de variantes de modelos 3D
powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/presentation/decoration/test_3d_model_variants_pipeline.gd"

# 4. Benchmark completo de 100 semillas
powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/presentation/decoration/test_crypt_benchmark_100_seeds.gd"
```
