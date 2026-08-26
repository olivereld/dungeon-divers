# Profile-Driven Composition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Hacer que los perfiles JSON de habitación (`ProfileRoom`) sean la autoridad efectiva sobre qué props se colocan, cuántos se colocan (`primary`, `secondary`, `support`), su presupuesto de iluminación y qué relaciones prop-fixture se permiten, manteniendo al algoritmo de GDScript como autoridad sobre la posición, clearance, occupancy y scoring.

**Architecture:** 
`PresentationRoomContext.room_profile` (`ProfileRoom`) → `DecorationCompositionResolver` → `DecorationCompositionPlanner`.
El planner consume las reglas de `ProfileComposition` (`primary`, `secondary`, `support`), las restricciones de `ProfileRoomIntent`, las luminarias y presupuesto de `ProfileLighting` y las reglas relacionales de `ProfileRelationship`, seleccionando assets desde `DecorationPalette` mediante coincidencia de tags sin hardcoding en GDScript.

**Tech Stack:** Godot 4.6, GDScript, JSON, `RefCounted`, tests `SceneTree` ejecutados en modo headless.

---

## Global Constraints

- **JSON decide el QUÉ y CUÁNTO:** assets permitidos, límites (`min_count`, `max_count`), tags (`asset_tags`, `forbidden_tags`), presupuesto de luz y relaciones espaciales.
- **GDScript decide el DÓNDE:** anclajes, scoring, ocupación, clearance, no solapamiento y reservas de puertas/escaleras.
- **Cero condicionales por nombre:** Prohibido usar `if room_name == "crypt"` o `if purpose == CRYPT: spawn_sarcophagus()`. Todo debe ser impulsado por las reglas del `ProfileRoom`.
- **Pureza e inmutabilidad:** Planner y resolver no crean nodos `Node3D` ni mutan `CellGrid`.
- **Benchmark único:** `MAUSOLEUM` (`crypt`, `tomb`, `royal_tomb`, `sacristy`, etc.) es el benchmark de esta fase. No expandir a otros arquetipos todavía.
- **Compatibilidad retroactiva:** Si un `room_context` no contiene `room_profile`, debe haber fallback al registry actual sin errores.

---

## Mapa de Archivos

- **Modify:** [profile_composition.gd](file:///c:/Users/olivereld/Documents/dungeon-divers/src/dungeon_generator/profiles/profile_composition.gd) — Modelo tipado extendido con `support: Array[ProfileCompositionRule]`, `get_all_rules()`, y `get_rules_by_role()`.
- **Modify:** [profile_loader.gd](file:///c:/Users/olivereld/Documents/dungeon-divers/src/dungeon_generator/profiles/profile_loader.gd) — Parseo seguro de `composition.support` además de `primary` y `secondary`.
- **Modify:** [decoration_composition_resolver.gd](file:///c:/Users/olivereld/Documents/dungeon-divers/src/presentation/decoration/decoration_composition_resolver.gd) — Extraer y propagar `room_context.room_profile` al planner.
- **Modify:** [decoration_composition_planner.gd](file:///c:/Users/olivereld/Documents/dungeon-divers/src/presentation/decoration/composition/decoration_composition_planner.gd) — Consumir `ProfileRoom` para derivar la colocación de reglas (primary, secondary, support), resolución de relaciones prop-fixture y presupuesto de iluminación.
- **Create:** [test_profile_driven_composition.gd](file:///c:/Users/olivereld/Documents/dungeon-divers/tests/profiles/test_profile_driven_composition.gd) — Suite exhaustiva de pruebas unitarias y de integración espacial.

---

## Tareas de Implementación

### Task 1: Extender el Contrato de Composición (`ProfileComposition` y `ProfileLoader`)
**Files:**
- Modify: `src/dungeon_generator/profiles/profile_composition.gd`
- Modify: `src/dungeon_generator/profiles/profile_loader.gd`
- Test: `tests/profiles/test_profile_driven_composition.gd`

**Interfaces:**
```gdscript
# ProfileComposition
var primary: ProfileCompositionRule = null
var secondary: Array[ProfileCompositionRule] = []
var support: Array[ProfileCompositionRule] = []

func get_all_rules() -> Array[ProfileCompositionRule] # Devuelve primary, secondary, support en orden
func get_rules_by_role() -> Dictionary # {"primary": [...], "secondary": [...], "support": [...]}
```

- [ ] **Step 1: Escribir test unitario de carga y modelo de soporte**
- [ ] **Step 2: Ejecutar test y verificar que falla**
- [ ] **Step 3: Implementar `support` en `profile_composition.gd` y `_parse_composition_rule` en `profile_loader.gd`**
- [ ] **Step 4: Ejecutar test y verificar que pasa**

---

### Task 2: Integrar `ProfileRoom` en `DecorationCompositionPlanner`
**Files:**
- Modify: `src/presentation/decoration/decoration_composition_resolver.gd`
- Modify: `src/presentation/decoration/composition/decoration_composition_planner.gd`
- Test: `tests/profiles/test_profile_driven_composition.gd`

**Detalle Técnico:**
- `DecorationCompositionPlanner.plan_room_composition` extrae `var profile_room = room_context.room_profile if room_context != null and "room_profile" in room_context else null`.
- Si `profile_room != null`:
  1. Utiliza `profile_room.intent` para clearance y tags permitidos/prohibidos.
  2. Itera sobre las reglas de `profile_room.composition.get_all_rules()`.
  3. Para cada regla, filtra los props disponibles en `DecorationPalette` cuyos tags coincidan con `asset_tags` y no contengan `forbidden_tags`.
  4. Ejecuta el pipeline determinista existente de colocación: scoring de candidatos, respeto de clearance y registro en `DecorationOccupancyMap`.
- Si `profile_room == null`: conserva el fallback legacy a `_purpose_registry`.

- [ ] **Step 1: Escribir test de colocación de props primarios y secundarios impulsados por JSON**
- [ ] **Step 2: Ejecutar test y verificar que falla**
- [ ] **Step 3: Implementar el consumo de `ProfileRoom` en `DecorationCompositionPlanner`**
- [ ] **Step 4: Ejecutar test y verificar que pasa**

---

### Task 3: Conectar Relaciones Prop-Fixture y Presupuesto de Iluminación desde JSON
**Files:**
- Modify: `src/presentation/decoration/composition/decoration_composition_planner.gd`
- Test: `tests/profiles/test_profile_driven_composition.gd`

**Detalle Técnico:**
- Si `profile_room != null`:
  1. Conectar `profile_room.relationships`: resolver luminarias compañeras (ej. velas cerca del sarcófago o farol sobre el altar) según las declaraciones en `profile_room.relationships`.
  2. Conectar `profile_room.lighting`: respetar `profile_room.lighting.budget` y las ranuras `wall`, `floor`, `hanging` al planificar luminarias ambientales y relacionales.

- [ ] **Step 1: Escribir test de relaciones y presupuesto de iluminación desde JSON**
- [ ] **Step 2: Ejecutar test y verificar que falla**
- [ ] **Step 3: Implementar la resolución relacional y de iluminación en el planner**
- [ ] **Step 4: Ejecutar test y verificar que pasa**

---

### Task 4: Benchmark de Composición en Cripta y Validación de Exclusiones
**Files:**
- Test: `tests/profiles/test_profile_driven_composition.gd`

**Verificaciones Clave:**
1. **CRYPT**: Coloca sarcófago o entierros perimetrales, velas asociadas, y respeta la ausencia de altares o asientos.
2. **TOMB**: Coloca sarcófago central como `PRIMARY` con clearance focal y prohíbe altares.
3. **SACRISTY**: Coloca altar ceremonial central como `PRIMARY` con velas compañeras y bancos (`pews`) en pared.
4. **MORTUARY**: Coloca mesa de embalsamamiento / altar como `PRIMARY` y urnas canópicas secundarias.
5. **Data-Driven Proof**: Modificar programáticamente el `max_count` de una regla en el perfil produce exactamente la cantidad de props solicitada sin cambios en el código de GDScript.

- [ ] **Step 1: Implementar suite de benchmark completa en `test_profile_driven_composition.gd`**
- [ ] **Step 2: Ejecutar suite de pruebas completa**
- [ ] **Step 3: Confirmar cero regresiones en la suite de pruebas del proyecto**

---

## Plan de Verificación

### Tests Automatizados
```bash
& "C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe" --headless -s res://tests/profiles/test_profile_driven_composition.gd
```
