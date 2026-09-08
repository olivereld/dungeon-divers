class_name DungeonModuleInspector
extends RefCounted

## Inspector engine for generator module health within the Laboratory.
## Inspects file availability and dynamically reads preload dependency declarations
## in DungeonGeometryGenerator without modifying the generator facade.

const DungeonModuleStatus = preload("res://src/presentation/showcase/module_health/dungeon_module_status.gd")
const DungeonModuleRegistry = preload("res://src/presentation/showcase/module_health/dungeon_module_registry.gd")

const GENERATOR_FACADE_PATH := "res://src/geometry_generator/facade/dungeon_geometry_generator.gd"

## Executes full health inspection for all registered modules.
func inspect() -> Array[DungeonModuleStatus]:
	var results: Array[DungeonModuleStatus] = []
	for definition in DungeonModuleRegistry.get_modules():
		results.append(_inspect_module(definition))
	_check_pipeline_usage(results)
	return results

## Inspects a single module definition for file existence and compilability.
func _inspect_module(definition: Dictionary) -> DungeonModuleStatus:
	var status := DungeonModuleStatus.new()
	status.id = definition.get("id", "")
	status.name = definition.get("name", "")
	status.path = definition.get("path", "")
	status.category = definition.get("category", "")

	if not ResourceLoader.exists(status.path) and not FileAccess.file_exists(status.path):
		status.state = DungeonModuleStatus.State.MISSING
		status.message = "File does not exist"
		return status

	var script = load(status.path)
	if script == null:
		status.state = DungeonModuleStatus.State.ERROR
		status.message = "Script could not be loaded"
		return status

	status.state = DungeonModuleStatus.State.AVAILABLE
	status.message = "Script available"
	return status

## Discovers pipeline dependencies by reading preload() declarations without modifying the generator.
func _check_pipeline_usage(results: Array[DungeonModuleStatus]) -> void:
	var active_pipeline_deps := _discover_generator_pipeline_dependencies(GENERATOR_FACADE_PATH)
	for status in results:
		if status.state == DungeonModuleStatus.State.AVAILABLE:
			status.is_used_by_pipeline = active_pipeline_deps.has(status.path)

## Parses preload() statements from a Godot script file.
func _extract_preloaded_paths_from_file(file_path: String) -> Array[String]:
	var paths: Array[String] = []
	if not FileAccess.file_exists(file_path):
		return paths

	var content := FileAccess.get_file_as_string(file_path)
	if content.is_empty():
		return paths

	var regex := RegEx.new()
	var err := regex.compile('preload\\s*\\(\\s*["\']([^"\']+)["\']\\s*\\)')
	if err != OK:
		return paths

	var matches = regex.search_all(content)
	for m in matches:
		var p: String = m.get_string(1)
		paths.append(p)
	return paths

## Recursively extracts all dependencies preloaded by the generator facade and its sub-modules.
func _discover_generator_pipeline_dependencies(root_path: String = GENERATOR_FACADE_PATH) -> Dictionary:
	var dependencies: Dictionary = {}
	var visited: Dictionary = {}
	var queue: Array[String] = [root_path]

	while not queue.is_empty():
		var current_path: String = queue.pop_front()
		if visited.has(current_path):
			continue
		visited[current_path] = true

		var preloaded := _extract_preloaded_paths_from_file(current_path)
		for p in preloaded:
			dependencies[p] = true
			if p.begins_with("res://src/geometry_generator/") and not visited.has(p):
				queue.append(p)

	return dependencies
