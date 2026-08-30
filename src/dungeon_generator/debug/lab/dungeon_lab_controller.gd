class_name DungeonLabController
extends RefCounted

signal generation_started
signal generation_completed(result: Dictionary)
signal generation_failed(reason: String)
signal floor_changed(floor_idx: int)

const _PipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _MultiFloorGenScript = preload("res://src/dungeon_generator/core/multi_floor_generator.gd")
const _ConfigScript = preload("res://src/dungeon_generator/debug/lab/dungeon_lab_configuration.gd")
const _DungeonFloorDataScript = preload("res://src/dungeon_generator/core/data/dungeon_floor_data.gd")

var _pipeline: _PipelineScript
var _multi_floor_gen: _MultiFloorGenScript
var _current_result: Dictionary = {}
var _current_floor_idx: int = 0

func _init() -> void:
	_pipeline = _PipelineScript.new()
	_multi_floor_gen = _MultiFloorGenScript.new(_pipeline)

func generate_dungeon(config: _ConfigScript) -> Dictionary:
	var errors := config.validate()
	if not errors.is_empty():
		var msg := "Invalid configuration: " + ", ".join(errors)
		generation_failed.emit(msg)
		return {}

	generation_started.emit()
	var d_cfg = config.to_dungeon_config()

	var result: Dictionary = {}
	if config.floor_count > 1:
		var mf_res = _multi_floor_gen.generate_multi_floor(d_cfg, config.seed)
		var floors_list: Array = []
		if mf_res != null and mf_res.is_valid:
			for fn in mf_res.get_floor_numbers():
				floors_list.append(mf_res.get_floor(fn))
		result = {
			"floors": floors_list,
			"vertical_connections": mf_res.vertical_connections if mf_res != null else [],
			"total_floors": floors_list.size(),
			"overall_success": (mf_res != null and mf_res.is_valid and not floors_list.is_empty()),
			"multi_floor_result": mf_res
		}
	else:
		var single_res = _pipeline.generate(d_cfg)
		var floor_data = null
		if single_res != null:
			floor_data = _DungeonFloorDataScript.new(1, single_res.grid, single_res.rooms, single_res.doors)
		result = {
			"floors": [floor_data] if floor_data != null else [],
			"vertical_connections": [],
			"total_floors": 1 if floor_data != null else 0,
			"overall_success": (single_res != null),
			"dungeon_result": single_res
		}

	if not result.get("overall_success", false):
		generation_failed.emit("Pipeline reported generation failure for seed %d" % config.seed)
		return {}

	_current_result = result
	_current_floor_idx = 0
	generation_completed.emit(_current_result)
	return _current_result

func set_current_floor(floor_idx: int) -> void:
	_current_floor_idx = floor_idx
	floor_changed.emit(floor_idx)

func get_current_floor_result():
	var floors: Array = _current_result.get("floors", [])
	if _current_floor_idx >= 0 and _current_floor_idx < floors.size():
		return floors[_current_floor_idx]
	return null

func get_current_result() -> Dictionary:
	return _current_result
