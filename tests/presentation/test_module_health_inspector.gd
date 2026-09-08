extends SceneTree

const _StatusScript = preload("res://src/presentation/showcase/module_health/dungeon_module_status.gd")
const _RegistryScript = preload("res://src/presentation/showcase/module_health/dungeon_module_registry.gd")
const _InspectorScript = preload("res://src/presentation/showcase/module_health/dungeon_module_inspector.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_module_health_inspector ---")
	print("==================================================================")

	# 1. Test DungeonModuleStatus contract and helpers
	var status := _StatusScript.new()
	status.id = "test_mod"
	status.name = "TestModule"
	status.path = "res://src/test_mod.gd"
	status.category = "Test"
	status.state = _StatusScript.State.AVAILABLE
	status.is_used_by_pipeline = true

	assert(status.get_state_symbol() == "🟢", "FAIL: AVAILABLE symbol must be 🟢")
	assert(status.get_pipeline_symbol() == "🟢 USED", "FAIL: pipeline symbol must be 🟢 USED")
	print("  [OK] DungeonModuleStatus AVAILABLE + USED helpers verified")

	status.state = _StatusScript.State.MISSING
	status.is_used_by_pipeline = false
	assert(status.get_state_symbol() == "🔴", "FAIL: MISSING symbol must be 🔴")
	assert(status.get_pipeline_symbol() == "🔴 NOT USED", "FAIL: pipeline symbol must be 🔴 NOT USED")
	print("  [OK] DungeonModuleStatus MISSING + NOT USED helpers verified")

	# 2. Test DungeonModuleRegistry declarations
	var modules = _RegistryScript.get_modules()
	assert(modules.size() >= 2, "FAIL: Registry must contain module declarations")
	var ids: Array[String] = []
	for m in modules:
		assert(m.has("id") and m.has("name") and m.has("path") and m.has("category"), "FAIL: Module entry missing required keys")
		ids.append(m["id"])
	assert(ids.has("boundary_extractor"), "FAIL: Registry must declare boundary_extractor")
	assert(ids.has("component_extractor"), "FAIL: Registry must declare component_extractor")
	print("  [OK] DungeonModuleRegistry contains %d declared modules" % modules.size())

	# 3. Test DungeonModuleInspector execution
	var inspector := _InspectorScript.new()
	var results = inspector.inspect()
	assert(results.size() == modules.size(), "FAIL: Inspector output size must match registry count")

	var status_map: Dictionary = {}
	for s in results:
		status_map[s.id] = s
		print("    - %s" % s.to_display_string())

	# BoundaryExtractor check
	assert(status_map.has("boundary_extractor"), "FAIL: boundary_extractor must be present")
	var be: _StatusScript = status_map["boundary_extractor"]
	assert(be.state == _StatusScript.State.AVAILABLE, "FAIL: boundary_extractor must be AVAILABLE")
	assert(be.is_used_by_pipeline == true, "FAIL: boundary_extractor must be marked USED by pipeline")
	print("  [OK] BoundaryExtractor verified: AVAILABLE & USED")

	# ComponentExtractor check
	assert(status_map.has("component_extractor"), "FAIL: component_extractor must be present")
	var ce: _StatusScript = status_map["component_extractor"]
	assert(ce.state == _StatusScript.State.AVAILABLE, "FAIL: component_extractor must be AVAILABLE")
	assert(ce.is_used_by_pipeline == true, "FAIL: component_extractor must be marked USED by pipeline")
	print("  [OK] ComponentExtractor verified: AVAILABLE & USED")

	# WallGeometryBuilder check
	assert(status_map.has("wall_geometry_builder"), "FAIL: wall_geometry_builder must be present")
	var wgb: _StatusScript = status_map["wall_geometry_builder"]
	assert(wgb.state == _StatusScript.State.AVAILABLE, "FAIL: wall_geometry_builder must be AVAILABLE")
	assert(wgb.is_used_by_pipeline == true, "FAIL: wall_geometry_builder must be marked USED by pipeline")
	print("  [OK] WallGeometryBuilder verified: AVAILABLE & USED")

	# ArchGeometryBuilder check (exists on disk, but NOT in DungeonGeometryGenerator pipeline)
	assert(status_map.has("arch_geometry_builder"), "FAIL: arch_geometry_builder must be present")
	var agb: _StatusScript = status_map["arch_geometry_builder"]
	assert(agb.state == _StatusScript.State.AVAILABLE, "FAIL: arch_geometry_builder must be AVAILABLE")
	assert(agb.is_used_by_pipeline == false, "FAIL: arch_geometry_builder must be marked NOT USED by pipeline")
	print("  [OK] ArchGeometryBuilder verified: AVAILABLE & NOT USED (Pipeline separation confirmed)")

	# Missing module check
	var missing_def = {
		"id": "non_existent_module",
		"name": "NonExistentModule",
		"path": "res://src/geometry_generator/extraction/does_not_exist.gd",
		"category": "Topology"
	}
	var missing_status = inspector._inspect_module(missing_def)
	assert(missing_status.state == _StatusScript.State.MISSING, "FAIL: Missing module must report MISSING")
	assert(missing_status.is_used_by_pipeline == false, "FAIL: Missing module must be NOT USED")
	print("  [OK] Missing module detection verified: 🔴 MISSING")

	# 4. Test MeshGalleryRenderer Integration
	const _RendererScript = preload("res://src/presentation/showcase/mesh_gallery_renderer.gd")
	var renderer = _RendererScript.new()
	assert(renderer.get("_module_inspector") != null, "FAIL: MeshGalleryRenderer must instantiate _module_inspector")
	renderer._refresh_module_health()
	var r_statuses = renderer.get_module_statuses()
	assert(r_statuses.size() == modules.size(), "FAIL: MeshGalleryRenderer must hold full status array")
	print("  [OK] MeshGalleryRenderer integration verified: %d statuses loaded via _refresh_module_health()" % r_statuses.size())

	print("\n>>> ALL CHECKS PASSED: MODULE HEALTH INSPECTOR FULLY VERIFIED! <<<\n")
	quit(0)
