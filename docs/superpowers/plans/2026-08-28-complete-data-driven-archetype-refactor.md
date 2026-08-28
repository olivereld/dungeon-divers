# Complete Data-Driven Archetype Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish `ArchetypeCatalog` and `archetypes.json` as the single source of truth for dungeon archetypes, fully decoupling all presentation builders, resolvers, controllers, and profile loaders from hardcoded enums and specific dungeon names.

**Architecture:** 
1. `resources/dungeon_profiles/archetypes/archetypes.json` defines available archetypes and their profile files.
2. `ArchetypeCatalog` reads, validates, indexes, and queries archetypes dynamically.
3. `DungeonArchetype` becomes a lightweight runtime value type holding `id: StringName`.
4. `ProfileLoader`, `PresentationProfileResolver`, `DecorationPaletteResolver`, and `DungeonPresentationBuilder` query `ArchetypeCatalog` and profile configurations dynamically without hardcoded names or `match` blocks.

**Tech Stack:** Godot 4.6 (GDScript), JSON configuration, TDD.

**Spec:** "El código nunca debe ser la fuente de verdad de los Archetypes. La fuente de verdad será resources/dungeon_profiles/archetypes/."

## Global Constraints
- Adding a new archetype JSON file and entry to `archetypes.json` must immediately make it available to all generators, loaders, and resolvers without any GDScript edits.
- `DungeonArchetype` must not contain a fixed enum of known themes (`MAUSOLEUM`, `CRYPT`, etc.).
- Backwards compatibility must be preserved for legacy integer conversions during migration.
- 100% test pass rate on all unit, profile, multilevel, and integration suites.

---

### Task 1: Single Source of Truth (`archetypes.json`) & `ArchetypeCatalog`

**Files:**
- Create: `resources/dungeon_profiles/archetypes/archetypes.json`
- Create: `src/dungeon_generator/profiles/archetype_catalog.gd`
- Test: `tests/profiles/test_archetype_catalog.gd`

**Interfaces:**
- Produces: `ArchetypeCatalog.get_ids() -> Array[StringName]`
- Produces: `ArchetypeCatalog.has_archetype(id: StringName) -> bool`
- Produces: `ArchetypeCatalog.get_profile_path(id: StringName) -> String`
- Produces: `ArchetypeCatalog.reload() -> void`

- [ ] **Step 1: Create `archetypes.json` manifest**

```json
{
    "schema_version": 1,
    "archetypes": [
        {
            "id": "necropolis",
            "file": "necropolis.json"
        }
    ]
}
```

- [ ] **Step 2: Write failing test for `ArchetypeCatalog`**

```gdscript
# tests/profiles/test_archetype_catalog.gd
extends SceneTree

func _init() -> void:
	print("--- Running test_archetype_catalog ---")
	var catalog_script = preload("res://src/dungeon_generator/profiles/archetype_catalog.gd")
	var catalog = catalog_script.new("res://resources/dungeon_profiles/archetypes/")

	var ids = catalog.get_ids()
	assert(not ids.is_empty(), "Must discover registered archetypes")
	assert(catalog.has_archetype(&"necropolis"), "Must have necropolis archetype")
	assert(catalog.get_profile_path(&"necropolis").ends_with("necropolis.json"), "Path must resolve correctly")
	assert(not catalog.has_archetype(&"non_existent"), "Must return false for unknown archetypes")

	print("[PASS] test_archetype_catalog passed 100%!")
	quit(0)
```

- [ ] **Step 3: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/profiles/test_archetype_catalog.gd"`
Expected: FAIL (script does not exist)

- [ ] **Step 4: Implement `ArchetypeCatalog`**

```gdscript
# src/dungeon_generator/profiles/archetype_catalog.gd
class_name ArchetypeCatalog
extends RefCounted

var _base_path: String = ""
var _entries: Dictionary = {} # StringName -> String (full path)

func _init(base_path: String = "res://resources/dungeon_profiles/archetypes/") -> void:
	_base_path = base_path if base_path.ends_with("/") else base_path + "/"
	reload()

func reload() -> void:
	_entries.clear()
	var manifest_path = _base_path + "archetypes.json"
	if FileAccess.file_exists(manifest_path):
		var file = FileAccess.open(manifest_path, FileAccess.READ)
		if file:
			var json = JSON.parse_string(file.get_as_text())
			if json is Dictionary and json.has("archetypes") and json["archetypes"] is Array:
				for item in json["archetypes"]:
					if item is Dictionary and item.has("id") and item.has("file"):
						_entries[StringName(item["id"])] = _base_path + str(item["file"])
	
	# Auto-discover unlisted JSON files as fallback
	var dir = DirAccess.open(_base_path)
	if dir != null:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json") and file_name != "archetypes.json":
				var id = StringName(file_name.get_basename())
				if not _entries.has(id):
					_entries[id] = _base_path + file_name
			file_name = dir.get_next()
		dir.list_dir_end()

func get_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for k in _entries.keys():
		result.append(k)
	return result

func has_archetype(id: StringName) -> bool:
	return _entries.has(id)

func get_profile_path(id: StringName) -> String:
	return _entries.get(id, "")
```

- [ ] **Step 5: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/profiles/test_archetype_catalog.gd"`
Expected: PASS

- [ ] **Step 6: Commit changes**

```bash
git add resources/dungeon_profiles/archetypes/archetypes.json src/dungeon_generator/profiles/archetype_catalog.gd tests/profiles/test_archetype_catalog.gd
git commit -m "feat(archetype): create single source of truth manifest and ArchetypeCatalog"
```

---

### Task 2: Refactor `DungeonArchetype` & `ProfileLoader` to Use `ArchetypeCatalog`

**Files:**
- Modify: `src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd`
- Modify: `src/dungeon_generator/profiles/profile_loader.gd`
- Test: `tests/profiles/test_profile_loader.gd`

**Interfaces:**
- Consumes: `ArchetypeCatalog`
- Produces: `DungeonArchetype.new(id: StringName)`
- Produces: `ProfileLoader.load_archetype(id: Variant) -> ProfileArchetype`

- [ ] **Step 1: Update `DungeonArchetype` to be a pure data value class**

```gdscript
class_name DungeonArchetype
extends RefCounted

## Modelo de valor que representa la identidad de un arquetipo.

var id: StringName = &"generic"

func _init(p_id: Variant = &"generic") -> void:
	id = resolve_id(p_id)

static func resolve_id(val: Variant) -> StringName:
	if val is StringName:
		return val
	if val is String:
		return StringName((val as String).to_lower())
	if val is int:
		match int(val):
			1: return &"necropolis"
			2: return &"fortress"
			3: return &"temple"
			4: return &"mine"
			_: return &"generic"
	return &"generic"

func is_valid() -> bool:
	return not id.is_empty() and id != &"generic"

func _to_string() -> String:
	return str(id)
```

- [ ] **Step 2: Update `ProfileLoader` to use `ArchetypeCatalog`**

```gdscript
const _ArchetypeCatalogScript = preload("res://src/dungeon_generator/profiles/archetype_catalog.gd")
var _catalog: _ArchetypeCatalogScript = null

# In _init:
_catalog = _ArchetypeCatalogScript.new(base_path + "archetypes/")

func get_catalog() -> _ArchetypeCatalogScript:
	return _catalog

func load_archetype(archetype_id: Variant) -> _ProfileArchetypeScript:
	var target_id := DungeonArchetype.resolve_id(archetype_id)
	var path := _catalog.get_profile_path(target_id) if _catalog != null else ""
	if path.is_empty():
		path = base_path + "archetypes/" + str(target_id) + ".json"
	
	var json_data = _read_json_file(path)
	if not (json_data is Dictionary):
		return null
	# ... parsing as before ...
```

- [ ] **Step 3: Run `tests/profiles/test_profile_loader.gd`**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/profiles/test_profile_loader.gd"`
Expected: PASS

- [ ] **Step 4: Commit changes**

```bash
git add src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd src/dungeon_generator/profiles/profile_loader.gd tests/profiles/test_profile_loader.gd
git commit -m "refactor(profiles): wire ProfileLoader to ArchetypeCatalog and convert DungeonArchetype to value object"
```

---

### Task 3: Decouple `PresentationProfileResolver` and `DecorationPaletteResolver`

**Files:**
- Modify: `src/presentation/architecture/presentation_profile_resolver.gd`
- Modify: `src/presentation/decoration/decoration_palette_resolver.gd`
- Modify: `src/dungeon_generator/presentation/dungeon_presentation_builder.gd`
- Test: `tests/presentation/test_presentation_builder_modular.gd`

**Interfaces:**
- Consumes: `ProfileBundle`, `ProfileArchetypeStyle`, `ProfileRoom`
- Produces: `PresentationProfileResolver.resolve_from_archetype_style(style: ProfileArchetypeStyle, purpose: int)`

- [ ] **Step 1: Update `PresentationProfileResolver` to resolve based on archetype style data**

Remove hardcoded `match` by dungeon name. Let `PresentationProfileResolver` resolve properties from the `ProfileBundle.archetype.architectural_style` or default style maps.

- [ ] **Step 2: Update `DecorationPaletteResolver` to use tag-driven matching**

Ensure `DecorationPaletteResolver` maps palette styles based on the archetype style's `material_profile` and room purpose intents.

- [ ] **Step 3: Run tests to verify presentation integrity**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/presentation/test_presentation_builder_modular.gd; & 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/profiles/test_data_driven_style_resolution.gd"`
Expected: PASS

- [ ] **Step 4: Commit changes**

```bash
git add src/presentation/architecture/presentation_profile_resolver.gd src/presentation/decoration/decoration_palette_resolver.gd src/dungeon_generator/presentation/dungeon_presentation_builder.gd
git commit -m "refactor(presentation): decouple presentation and decoration resolvers from hardcoded dungeon names"
```

---

### Task 4: Runtime Controller & Zero-Code Dynamic Archetype Verification

**Files:**
- Modify: `scenes/dungeon/dungeon_level_controller.gd`
- Create: `tests/integration/test_dynamic_archetype_catalog_pipeline.gd`

**Interfaces:**
- Consumes: `ArchetypeCatalog`, `DungeonConfig`

- [ ] **Step 1: Update `DungeonLevelController` to use dynamic archetype ID**

Replace any remaining `DungeonArchetype.Type` assumptions with `config.get_effective_archetype_id()`.

- [ ] **Step 2: Write end-to-end dynamic catalog verification test**

Test that:
1. Dynamically writes a new theme `ancient_catacombs.json` and updates `archetypes.json`.
2. Reloads `ArchetypeCatalog`.
3. Runs the multi-floor pipeline with `archetype_id = &"ancient_catacombs"`.
4. Validates geometry, decoration, and destruction bindings.
5. Cleans up test manifest entries and files.

- [ ] **Step 3: Run the end-to-end test and full regression suite**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/integration/test_dynamic_archetype_catalog_pipeline.gd; & 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/run_all_tests.gd"`
Expected: ALL PASS (100%)

- [ ] **Step 4: Commit changes**

```bash
git add scenes/dungeon/dungeon_level_controller.gd tests/integration/test_dynamic_archetype_catalog_pipeline.gd
git commit -m "feat(pipeline): complete data-driven archetype catalog pipeline with end-to-end verification"
```
