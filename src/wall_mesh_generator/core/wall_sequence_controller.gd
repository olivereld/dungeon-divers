class_name WallSequenceController
extends RefCounted

## Controlador de generación y animación secuencial para paredes de ladrillo.
## Permite avanzar progresivamente (ladrillo por ladrillo o hilada por hilada).

signal sequence_step_changed(current_step: int, total_steps: int, current_mesh: ArrayMesh)
signal sequence_completed(final_mesh: ArrayMesh)
signal sequence_reset

enum StepMode {
	BRICK_BY_BRICK,
	COURSE_BY_COURSE,
	PERCENTAGE
}

const _WallMeshBuilderScript = preload("res://src/wall_mesh_generator/core/wall_mesh_builder.gd")

var _builder := _WallMeshBuilderScript.new()
var _config: WallMeshConfig
var _manifest: Array[Dictionary] = []
var _current_step: int = 0
var _total_steps: int = 0
var _mode: StepMode = StepMode.BRICK_BY_BRICK
var _courses: Array[int] = [] # Almacena el número acumulado de ladrillos hasta cada hilada

func setup(config: WallMeshConfig, mode: StepMode = StepMode.BRICK_BY_BRICK) -> void:
	_config = config if config != null else WallMeshConfig.new()
	_mode = mode
	_manifest = _builder.build_brick_manifest(_config)
	_calculate_steps()
	_current_step = 0
	sequence_reset.emit()

func _calculate_steps() -> void:
	_courses.clear()
	if _manifest.is_empty():
		_total_steps = 0
		return

	match _mode:
		StepMode.BRICK_BY_BRICK:
			_total_steps = _manifest.size()
		StepMode.COURSE_BY_COURSE:
			var max_c: int = 0
			for b in _manifest:
				max_c = maxi(max_c, b["course"])
			_total_steps = max_c + 1
			# Contar ladrillos acumulados por hilada
			for c in range(_total_steps):
				var count: int = 0
				for b in _manifest:
					if b["course"] <= c:
						count += 1
				_courses.append(count)
		StepMode.PERCENTAGE:
			_total_steps = 100

func get_current_step() -> int:
	return _current_step

func get_total_steps() -> int:
	return _total_steps

func is_completed() -> bool:
	return _current_step >= _total_steps

func set_mode(mode: StepMode) -> void:
	if _mode == mode:
		return
	var pct: float = get_progress_ratio()
	_mode = mode
	_calculate_steps()
	set_progress_ratio(pct)

func get_progress_ratio() -> float:
	if _total_steps == 0:
		return 1.0
	return float(_current_step) / float(_total_steps)

func set_progress_ratio(ratio: float) -> ArrayMesh:
	var target_step: int = int(round(clampf(ratio, 0.0, 1.0) * float(_total_steps)))
	return jump_to_step(target_step)

func step_forward(steps: int = 1) -> ArrayMesh:
	return jump_to_step(_current_step + steps)

func step_backward(steps: int = 1) -> ArrayMesh:
	return jump_to_step(_current_step - steps)

func reset() -> ArrayMesh:
	return jump_to_step(0)

func complete() -> ArrayMesh:
	return jump_to_step(_total_steps)

func jump_to_step(step: int) -> ArrayMesh:
	_current_step = clampi(step, 0, _total_steps)
	var active_bricks: int = _get_active_brick_count_for_step(_current_step)

	var mesh: ArrayMesh = _builder.build_mesh_from_subset(_config, active_bricks, _manifest)
	sequence_step_changed.emit(_current_step, _total_steps, mesh)

	if is_completed():
		sequence_completed.emit(mesh)

	return mesh

func _get_active_brick_count_for_step(step: int) -> int:
	if step <= 0:
		return 0
	if step >= _total_steps:
		return _manifest.size()

	match _mode:
		StepMode.BRICK_BY_BRICK:
			return step
		StepMode.COURSE_BY_COURSE:
			var idx: int = clampi(step - 1, 0, _courses.size() - 1)
			return _courses[idx]
		StepMode.PERCENTAGE:
			var ratio: float = float(step) / 100.0
			return int(round(ratio * float(_manifest.size())))

	return step
