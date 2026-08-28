# Dynamic Data-Driven Archetypes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the Dungeon Archetype system into a 100% data-driven architecture where archetypes are dynamically discovered and loaded from `resources/dungeon_profiles/archetypes/` without hardcoded enums or GDScript modifications.

**Architecture:** Introduce `ArchetypeRegistry` for filesystem-based dynamic discovery and cataloging of archetype profiles. Refactor `DungeonArchetype`, `DungeonConfig`, and `ProfileLoader` to use string-based archetype identifiers (`StringName`) with legacy backwards-compatibility, and decouple decoration/architectural resolvers from specific dungeon type names.

**Tech Stack:** Godot 4.6 (GDScript), JSON Data Contracts, TDD.

**Spec:** User architecture requirement: "El código nunca debe ser la fuente de verdad de los Archetypes. La fuente de verdad será resources/dungeon_profiles/archetypes/."

## Global Constraints
- Archetype discovery must read files from `resources/dungeon_profiles/archetypes/*.json` automatically.
- No GDScript code modification should be necessary when adding a new archetype JSON file.
- Maintain backwards compatibility for existing tests and integer-based configs.
- 100% test coverage with contract-based testing rather than hardcoded name testing.

---

### Task 1: Archetype Registry & Filesystem Discovery in ProfileLoader

**Files:**
- Create: `src/dungeon_generator/profiles/archetype_registry.gd`
- Modify: `src/dungeon_generator/profiles/profile_loader.gd`
- Test: `tests/profiles/test_dynamic_archetype_discovery.gd`

**Interfaces:**
- Produces: `ArchetypeRegistry.discover_archetypes(base_path: String) -> Dictionary` (id -> filepath)
- Produces: `ArchetypeRegistry.get_available_archetype_ids() -> Array[StringName]`
- Produces: `ProfileLoader.get_archetype_registry() -> ArchetypeRegistry`
- Produces: `ProfileLoader.list_available_archetypes() -> Array[StringName]`

- [ ] **Step 1: Write the failing test for ArchetypeRegistry and discovery**

```gdscript
# tests/profiles/test_dynamic_archetype_discovery.gd
extends SceneTree

func _init() -> void:
	print("--- Running test_dynamic_archetype_discovery ---")
	var registry_script = preload("res://src/dungeon_generator/profiles/archetype_registry.gd")
	var loader_script = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

	var registry = registry_script.new()
	var discovered: Dictionary = registry.discover_archetypes("res://resources/dungeon_profiles/archetypes/")
	assert(not discovered.is_empty(), "Must discover at least one archetype in directory")
	assert(discovered.has(&"necropolis"), "Must discover necropolis archetype dynamically")

	var loader = loader_script.new()
	var available = loader.list_available_archetypes()
	assert(available.has(&"necropolis"), "ProfileLoader must expose discovered archetypes")

	# Test loading dynamically discovered archetype
	var arch = loader.load_archetype("necropolis")
	assert(arch != null and arch.id == &"necropolis", "Must load discovered archetype")

	print("[PASS] test_dynamic_archetype_discovery passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/profiles/test_dynamic_archetype_discovery.gd"`
Expected: FAIL (script does not exist)

- [ ] **Step 3: Implement ArchetypeRegistry and update ProfileLoader**

```gdscript
# src/dungeon_generator/profiles/archetype_registry.gd
class_name ArchetypeRegistry
extends RefCounted

var _archetype_files: Dictionary = {} # StringName (id) -> String (filepath)

func discover_archetypes(dir_path: String = "res://resources/dungeon_profiles/archetypes/") -> Dictionary:
	_archetype_files.clear()
	var clean_path = dir_path if dir_path.ends_with("/") else dir_path + "/"
	var dir = DirAccess.open(clean_path)
	if dir != null:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var raw_id = file_name.get_basename()
				var full_path = clean_path + file_name
				_archetype_files[StringName(raw_id)] = full_path
			file_name = dir.get_next()
		dir.list_dir_end()
	return _archetype_files

func has_archetype(id: StringName) -> bool:
	return _archetype_files.has(id)

func get_filepath(id: StringName) -> String:
	return _archetype_files.get(id, "")

func get_available_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for k in _archetype_files.keys():
		result.append(k)
	return result
```

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/profiles/test_dynamic_archetype_discovery.gd"`
Expected: PASS

- [ ] **Step 5: Commit changes**

```bash
git add src/dungeon_generator/profiles/archetype_registry.gd src/dungeon_generator/profiles/profile_loader.gd tests/profiles/test_dynamic_archetype_discovery.gd
git commit -m "feat(profiles): add dynamic archetype registry discovery"
```

---

### Task 2: Decouple DungeonArchetype and DungeonConfig from Fixed Enums

**Files:**
- Modify: `src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd`
- Modify: `src/dungeon_generator/config/dungeon_config.gd`
- Test: `tests/dungeon_generator/test_dynamic_dungeon_archetype_contract.gd`

**Interfaces:**
- Produces: `DungeonConfig.archetype_id: StringName` (default `&"necropolis"`)
- Produces: `DungeonArchetype.resolve_id(val: Variant) -> StringName`
- Consumes: `ArchetypeRegistry`

- [ ] **Step 1: Write the failing test for dynamic archetype contract**

```gdscript
# tests/dungeon_generator/test_dynamic_dungeon_archetype_contract.gd
extends SceneTree

func _init() -> void:
	print("--- Running test_dynamic_dungeon_archetype_contract ---")
	var archetype_script = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
	var config_script = preload("res://src/dungeon_generator/config/dungeon_config.gd")

	# Test StringName resolution
	assert(archetype_script.resolve_id(&"necropolis") == &"necropolis", "StringName must resolve directly")
	assert(archetype_script.resolve_id("temple") == &"temple", "String must resolve to StringName")
	assert(archetype_script.resolve_id(1) == &"necropolis", "Legacy int enum must map gracefully")

	var cfg = config_script.new()
	cfg.archetype_id = &"necropolis"
	assert(cfg.get_effective_archetype_id() == &"necropolis", "Config must provide effective archetype_id")

	print("[PASS] test_dynamic_dungeon_archetype_contract passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/dungeon_generator/test_dynamic_dungeon_archetype_contract.gd"`
Expected: FAIL

- [ ] **Step 3: Update DungeonArchetype and DungeonConfig**

Implement `resolve_id(val)` in `dungeon_archetype.gd` and `archetype_id` with `get_effective_archetype_id()` in `dungeon_config.gd`.

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/dungeon_generator/test_dynamic_dungeon_archetype_contract.gd"`
Expected: PASS

- [ ] **Step 5: Commit changes**

```bash
git add src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd src/dungeon_generator/config/dungeon_config.gd tests/dungeon_generator/test_dynamic_dungeon_archetype_contract.gd
git commit -m "refactor(archetype): decouple DungeonArchetype and DungeonConfig from fixed enums"
```

---

### Task 3: Decouple Decoration and Presentation Resolvers from Specific Archetype Enums

**Files:**
- Modify: `src/presentation/decoration/decoration_palette_resolver.gd`
- Modify: `src/presentation/architecture/presentation_profile_resolver.gd`
- Test: `tests/profiles/test_data_driven_style_resolution.gd`

**Interfaces:**
- Produces: `DecorationPaletteResolver.resolve_palette_by_id(archetype_id: StringName, room_purpose: int, profile) -> DecorationPalette`
- Produces: `PresentationProfileResolver.resolve_profile_by_archetype(archetype_id: StringName, purpose: int)`

- [ ] **Step 1: Write the failing test for data-driven style resolution**

```gdscript
# tests/profiles/test_data_driven_style_resolution.gd
extends SceneTree

func _init() -> void:
	print("--- Running test_data_driven_style_resolution ---")
	var palette_resolver_script = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
	var resolver := palette_resolver_script.new()

	# Resolve by StringName archetype ID
	var pal = resolver.resolve_palette_for_archetype(&"necropolis", 0, null)
	assert(pal != null, "Must resolve valid decoration palette for archetype ID")

	print("[PASS] test_data_driven_style_resolution passed 100%!")
	quit(0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/profiles/test_data_driven_style_resolution.gd"`
Expected: FAIL

- [ ] **Step 3: Implement data-driven resolution in resolvers**

Update `DecorationPaletteResolver` and `PresentationProfileResolver` to accept string identifiers (`StringName`) alongside legacy int enums.

- [ ] **Step 4: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/profiles/test_data_driven_style_resolution.gd"`
Expected: PASS

- [ ] **Step 5: Commit changes**

```bash
git add src/presentation/decoration/decoration_palette_resolver.gd src/presentation/architecture/presentation_profile_resolver.gd tests/profiles/test_data_driven_style_resolution.gd
git commit -m "feat(presentation): data-driven archetype palette and profile resolution"
```

---

### Task 4: The Zero-Code Test (Create New Archetype on Disk Without GDScript Changes)

**Files:**
- Create: `tests/integration/test_zero_code_new_archetype_pipeline.gd`

**Interfaces:**
- Consumes: `ProfileLoader`, `MultiFloorGenerator`, `DungeonPresentationBuilder`

- [ ] **Step 1: Write the end-to-end zero-code test**

```gdscript
# tests/integration/test_zero_code_new_archetype_pipeline.gd
extends SceneTree

func _init() -> void:
	print("--- Running test_zero_code_new_archetype_pipeline (The Acid Test) ---")
	var temp_arch_path = "res://resources/dungeon_profiles/archetypes/test_celestial_sanctum.json"
	
	# 1. Create brand new archetype JSON on disk dynamically
	var test_json = {
		"schema_version": 1,
		"id": "test_celestial_sanctum",
		"display_name": "Celestial Sanctum",
		"purpose_weights": {"crypt": 1.0, "hall": 2.0},
		"gameplay_purpose_map": {"START": ["entrance"], "BOSS": ["crypt"], "EXPLORE": ["hall"]},
		"room_purpose_distribution": {"entrance": 0.2, "hall": 0.5, "crypt": 0.3},
		"global_settings": {"min_rooms": 5, "max_rooms": 10, "decoration_density": 0.5},
		"architectural_style": {
			"floor_style": "smooth_slabs", "wall_style": "dark_stone",
			"door_style": "stone_arch", "stairs_style": "stone",
			"material_profile": "necropolis_stone"
		},
		"room_rules": {"allow_duplicate_purposes": true, "guaranteed": ["entrance"]},
		"rooms": {"entrance": "entrance.json", "hall": "hall.json", "crypt": "crypt.json"}
	}
	
	var file = FileAccess.open(temp_arch_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(test_json, "    "))
	file.close()

	# 2. Verify ProfileLoader automatically discovers and loads it
	var loader_script = preload("res://src/dungeon_generator/profiles/profile_loader.gd")
	var loader = loader_script.new()
	var available = loader.list_available_archetypes()
	assert(available.has(&"test_celestial_sanctum"), "Dynamic archetype must be auto-discovered")

	var bundle = loader.load_full_archetype_bundle("test_celestial_sanctum")
	assert(bundle != null and bundle.archetype != null, "Must load full archetype bundle for new archetype")
	assert(bundle.archetype.id == &"test_celestial_sanctum", "Archetype ID must match")

	# 3. Clean up test file
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_arch_path))
	print("[PASS] test_zero_code_new_archetype_pipeline passed 100%! Zero code changes required for new archetypes.")
	quit(0)
```

- [ ] **Step 2: Run test to verify it passes**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/integration/test_zero_code_new_archetype_pipeline.gd"`
Expected: PASS

- [ ] **Step 3: Run entire test suite to guarantee zero regressions**

Run: `powershell -Command "& 'C:\Users\olivereld\Documents\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --script tests/run_all_tests.gd"`
Expected: ALL TESTS PASS

- [ ] **Step 4: Commit changes**

```bash
git add tests/integration/test_zero_code_new_archetype_pipeline.gd
git commit -m "test(archetype): verify zero-code addition of new archetypes via filesystem discovery"
```
