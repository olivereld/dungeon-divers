# Hardening de Archetypes + Decoración Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidar una arquitectura 100% data-driven para arquetipos y decoración, unificando el identificador canónico en `archetype_id: StringName`, eliminando fallbacks de props hardcodeados en GDScript y blindando los contratos para que añadir nuevos arquetipos/salas en JSON requiera cero cambios de código.

**Architecture:** Se establece `archetype_id: StringName` como identificador canónico en todo el pipeline (desde `DungeonConfig` hasta `DungeonSemanticResult`). `ArchetypeCatalog` y `ProfileLoader` actúan como únicas autoridades de descubrimiento y carga de `ProfileBundle`. `DecorationPaletteResolver` y `DecorationCompositionPlanner` resuelven reglas y estilos directamente desde los catálogos JSON (`props.json`, `fixtures.json`, perfiles de arquetipo/sala), eliminando cualquier lista estática o `match` hardcodeado en GDScript.

**Tech Stack:** Godot 4.6 (GDScript puro, Data-Driven Architecture, JSON catalogs, Value Objects).

**Spec:** User architecture requirements for Pure Data-Driven decoupling (Zero code changes for new archetypes).

## Global Constraints
- El código conoce contratos; los JSON conocen contenido.
- `archetype_id: StringName` es el único identificador canónico en todo el sistema.
- Cero listas de props o fixtures hardcodeadas en fallbacks de GDScript.
- Un arquetipo inválido o no encontrado debe fallar de forma temprana (Fail Fast), no inventar mazmorras silenciosamente.

---

### Task 1: Unificación Canónica en `DungeonSemanticResult` y `DungeonConfig`

**Files:**
- Modify: `src/dungeon_generator/config/dungeon_config.gd`
- Modify: `src/dungeon_generator/core/semantic/data/dungeon_semantic_result.gd`
- Modify: `src/dungeon_generator/core/semantic/semantic_orchestrator.gd`
- Modify: `src/dungeon_generator/pipeline/dungeon_pipeline.gd`

**Interfaces:**
- Produces: `DungeonSemanticResult.archetype_id: StringName`, `DungeonConfig.archetype_id: StringName`.

- [ ] **Step 1: Modificar `dungeon_config.gd`**
  - Establecer `@export var archetype_id: StringName = &"necropolis"` como propiedad canónica.
  - Asegurar que `get_effective_archetype_id()` retorne siempre `archetype_id` limpio.

- [ ] **Step 2: Modificar `dungeon_semantic_result.gd`**
  - Establecer `var archetype_id: StringName = &""`.
  - Proveer helper `get_archetype_id() -> StringName`.

- [ ] **Step 3: Conectar `semantic_orchestrator.gd` y `dungeon_pipeline.gd`**
  - Asignar directamente `result.archetype_id = config.get_effective_archetype_id()`.

---

### Task 2: `DungeonArchetype`, `RoomPurpose` y `ArchitecturalStyle` como Normalizadores Puros

**Files:**
- Modify: `src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd`
- Modify: `src/dungeon_generator/core/semantic/archetype/room_purpose.gd`
- Modify: `src/dungeon_generator/core/semantic/archetype/architectural_style.gd`

**Interfaces:**
- Produces: `resolve_id(val: Variant) -> StringName`, `to_name(val: Variant) -> String`.

- [ ] **Step 1: Refactorizar `dungeon_archetype.gd`**
  - Eliminar cualquier enum de tipos fijos.
  - Mantener `resolve_id(val) -> StringName` puramente normalizador.

- [ ] **Step 2: Refactorizar `room_purpose.gd`**
  - Eliminar enums de propósitos cerrados.
  - Normalizar `resolve_id(val) -> StringName`.

- [ ] **Step 3: Refactorizar `architectural_style.gd`**
  - Normalizar `resolve_id(val) -> StringName`.

---

### Task 3: `ArchetypeCatalog` y `ProfileLoader` 100% Data-Driven

**Files:**
- Modify: `src/dungeon_generator/profiles/archetype_catalog.gd`
- Modify: `src/dungeon_generator/profiles/profile_loader.gd`

**Interfaces:**
- Consumes: `archetype_id: StringName`.
- Produces: `ProfileBundle` cargado desde JSON, o error explícito Fail Fast.

- [ ] **Step 1: Refactorizar `archetype_catalog.gd`**
  - Única autoridad de escaneo de `resources/dungeon_profiles/archetypes/`.

- [ ] **Step 2: Refactorizar `profile_loader.gd`**
  - Si el catálogo no conoce el `archetype_id`, emitir error explícito Fail Fast sin fallbacks genéricos ocultos.
  - Cargar `ProfileBundle` completo.

---

### Task 4: Purga de Fallbacks Hardcodeados en `DecorationPaletteResolver`

**Files:**
- Modify: `src/presentation/decoration/decoration_palette_resolver.gd`

**Interfaces:**
- Consumes: `bundle: ProfileBundle`, `purp_id: StringName`.
- Produces: `DecorationPalette` generado 100% desde `bundle.assets` y `bundle.rooms`.

- [ ] **Step 1: Eliminar listas estáticas de props en `decoration_palette_resolver.gd`**
  - Erradicar `["crate_wooden_standard", "barrel_wood_small", "crypt_urn_banded_floor", ...]`.
  - Extraer props dinámicamente desde `bundle.assets.get_props_by_tag(...)`.

- [ ] **Step 2: Dinamizar fixtures**
  - Construir estilos de fixtures basados exclusivamente en `bundle.archetype` y `r_prof.lighting`.

---

### Task 5: Limpieza de Resolución Defensiva en `DungeonPresentationBuilder`

**Files:**
- Modify: `src/dungeon_generator/presentation/dungeon_presentation_builder.gd`

**Interfaces:**
- Consumes: `semantic_result.archetype_id`.

- [ ] **Step 1: Simplificar extracción de arquetipo**
  - `var archetype_id: StringName = semantic_result.archetype_id`.
  - Cargar bundle una única vez y propagarlo limpiamente.

---

### Task 6: Auditoría de Consumidores Restantes

**Files:**
- Modify: `scenes/dungeon/dungeon_level_controller.gd`
- Modify: `src/presentation/architecture/presentation_profile_resolver.gd`
- Modify: `src/presentation/architecture/presentation_context_builder.gd`
- Modify: `src/presentation/showcase/room_archetype_lab/room_archetype_lab_generator.gd`

- [ ] **Step 1: Actualizar todos los consumidores**
  - Garantizar uso estricto de `archetype_id` y `purpose` como `StringName`.
