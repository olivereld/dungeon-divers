extends Node3D

## Controlador de la escena de pruebas interactiva para el generador de paredes y esquinas estilizadas.
## Permite seleccionar el tipo de pieza (Pared Recta / Esquina en L), ajustar dimensiones y ver la construcción secuencial.

const _WallMeshConfigScript = preload("res://src/wall_mesh_generator/config/wall_mesh_config.gd")
const _WallMeshBuilderScript = preload("res://src/wall_mesh_generator/core/wall_mesh_builder.gd")
const _WallSequenceControllerScript = preload("res://src/wall_mesh_generator/core/wall_sequence_controller.gd")
const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")

# Nodos 3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var wall_mesh_instance: MeshInstance3D = $WallMeshInstance

# Nodos UI
@onready var option_piece_type: OptionButton = %OptionPieceType
@onready var slider_length: HSlider = %SliderLength
@onready var label_length: Label = %LabelLength
@onready var slider_height_cubes: HSlider = %SliderHeightCubes
@onready var label_height_cubes: Label = %LabelHeightCubes
@onready var spin_seed: SpinBox = %SpinSeed
@onready var option_preset: OptionButton = %OptionPreset

# Controles Secuenciales
@onready var option_seq_mode: OptionButton = %OptionSeqMode
@onready var slider_progress: HSlider = %SliderProgress
@onready var label_progress_info: Label = %LabelProgressInfo
@onready var btn_play_pause: Button = %BtnPlayPause
@onready var label_stats: Label = %LabelStats

var _config: WallMeshConfig
var _builder: WallMeshBuilder
var _sequence_controller: WallSequenceController
var _current_preset: int = 0
var _is_playing: bool = false
var _play_timer: float = 0.0
var _play_interval: float = 0.12

# Control de Cámara Orbital
var _is_dragging_orbit: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _camera_distance: float = 7.5
var _camera_target: Vector3 = Vector3(1.0, 2.0, 1.0)

func _ready() -> void:
	_config = _WallMeshConfigScript.new()
	_config.piece_type = _WallMeshConfigScript.PieceType.WALL
	_config.cube_size = 2.0
	_config.cubes_high = 2
	_config.wall_length_cubes = 2
	_config.seed = 1337

	_builder = _WallMeshBuilderScript.new()
	_sequence_controller = _WallSequenceControllerScript.new()

	_setup_ui()
	_connect_signals()
	_rebuild_wall(true)

func _setup_ui() -> void:
	option_piece_type.clear()
	option_piece_type.add_item("🧱 Pared Recta (Wall)", 0)
	option_piece_type.add_item("🔄 Esquina en L (Corner)", 1)
	option_piece_type.select(0)

	option_preset.clear()
	option_preset.add_item("Stylized Slate (Referencia)", 0)
	option_preset.add_item("Dungeon Warm Stone", 1)
	option_preset.add_item("Dark Crypt", 2)
	option_preset.add_item("Sandstone Ruins", 3)
	option_preset.select(0)

	option_seq_mode.clear()
	option_seq_mode.add_item("Parte por Parte (Zócalo ➔ Panel ➔ Ladrillos)", 0)
	option_seq_mode.add_item("Por Hilada / Etapa", 1)
	option_seq_mode.add_item("Porcentaje Continuo", 2)
	option_seq_mode.select(0)

	slider_length.value = _config.wall_length_cubes
	slider_height_cubes.value = _config.cubes_high
	spin_seed.value = _config.seed

	_update_ui_labels()

func _connect_signals() -> void:
	option_piece_type.item_selected.connect(func(idx: int):
		_config.piece_type = idx as WallMeshConfig.PieceType
		var is_corner: bool = (_config.piece_type == WallMeshConfig.PieceType.CORNER)
		slider_length.editable = not is_corner
		slider_length.modulate = Color(0.5, 0.5, 0.5, 0.5) if is_corner else Color.WHITE
		_update_ui_labels()
		_rebuild_wall(true)
	)

	slider_length.value_changed.connect(func(v: float):
		_config.wall_length_cubes = int(v)
		_update_ui_labels()
		_rebuild_wall(true)
	)
	slider_height_cubes.value_changed.connect(func(v: float):
		_config.cubes_high = int(v)
		_update_ui_labels()
		_rebuild_wall(true)
	)
	spin_seed.value_changed.connect(func(v: float):
		_config.seed = int(v)
		_rebuild_wall(true)
	)
	%BtnRandomSeed.pressed.connect(func():
		spin_seed.value = randi() % 999999
	)
	option_preset.item_selected.connect(func(idx: int):
		_current_preset = idx
		_apply_materials()
	)

	# Secuencia
	option_seq_mode.item_selected.connect(func(idx: int):
		_sequence_controller.set_mode(idx as WallSequenceController.StepMode)
		_sync_slider_range()
	)
	slider_progress.value_changed.connect(func(v: float):
		if not _is_playing:
			_set_sequence_step(int(v))
	)
	btn_play_pause.pressed.connect(_toggle_play_pause)
	%BtnStepPrev.pressed.connect(func():
		_pause()
		_set_mesh(_sequence_controller.step_backward())
		_sync_slider_value()
	)
	%BtnStepNext.pressed.connect(func():
		_pause()
		_set_mesh(_sequence_controller.step_forward())
		_sync_slider_value()
	)
	%BtnResetSeq.pressed.connect(func():
		_pause()
		_set_mesh(_sequence_controller.reset())
		_sync_slider_value()
	)
	%BtnCompleteSeq.pressed.connect(func():
		_pause()
		_set_mesh(_sequence_controller.complete())
		_sync_slider_value()
	)

func _process(delta: float) -> void:
	if _is_playing:
		_play_timer += delta
		if _play_timer >= _play_interval:
			_play_timer = 0.0
			var next_mesh: ArrayMesh = _sequence_controller.step_forward()
			_set_mesh(next_mesh)
			_sync_slider_value()
			if _sequence_controller.is_completed():
				_pause()

func _update_ui_labels() -> void:
	if _config.piece_type == WallMeshConfig.PieceType.CORNER:
		label_length.text = "Tipo: Esquina en L (%.1f x %.1f m)" % [_config.cube_size, _config.cube_size]
	else:
		label_length.text = "Longitud: %d cubos (%.1fm)" % [_config.wall_length_cubes, _config.get_total_length()]
	label_height_cubes.text = "Altura: %d cubos (%.1fm)" % [_config.cubes_high, _config.get_total_height()]

func _rebuild_wall(reset_seq: bool = true) -> void:
	var mode: WallSequenceController.StepMode = option_seq_mode.selected as WallSequenceController.StepMode
	_sequence_controller.setup(_config, mode)
	_sync_slider_range()

	# Centrar la cámara según el tipo de pieza
	if _config.piece_type == WallMeshConfig.PieceType.CORNER:
		_camera_target = Vector3(_config.cube_size * 0.5, _config.get_total_height() * 0.5, _config.cube_size * 0.5)
	else:
		_camera_target = Vector3(_config.get_total_length() * 0.5, _config.get_total_height() * 0.5, 0.0)
	_update_camera_transform()

	if reset_seq:
		_set_mesh(_sequence_controller.complete())
		_sync_slider_value()

func _set_sequence_step(step: int) -> void:
	var mesh: ArrayMesh = _sequence_controller.jump_to_step(step)
	_set_mesh(mesh)
	_update_progress_info()

func _set_mesh(mesh: ArrayMesh) -> void:
	wall_mesh_instance.mesh = mesh
	_apply_materials()
	_update_stats(mesh)
	_update_progress_info()

func _apply_materials() -> void:
	_WallMaterialFactoryScript.apply_materials_to_mesh_instance(
		wall_mesh_instance,
		_current_preset as WallMaterialFactory.MaterialPreset
	)

func _sync_slider_range() -> void:
	slider_progress.min_value = 0
	slider_progress.max_value = _sequence_controller.get_total_steps()
	slider_progress.value = _sequence_controller.get_current_step()
	_update_progress_info()

func _sync_slider_value() -> void:
	slider_progress.value = _sequence_controller.get_current_step()
	_update_progress_info()

func _update_progress_info() -> void:
	var cur: int = _sequence_controller.get_current_step()
	var total: int = _sequence_controller.get_total_steps()
	var pct: float = _sequence_controller.get_progress_ratio() * 100.0
	label_progress_info.text = "Paso: %d / %d (%.1f%%)" % [cur, total, pct]

func _update_stats(mesh: ArrayMesh) -> void:
	if mesh == null:
		label_stats.text = "Malla: 0 vértices"
		return
	var total_verts: int = 0
	for s in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		if not arrays.is_empty() and arrays[Mesh.ARRAY_VERTEX] != null:
			total_verts += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()

	var aabb: AABB = mesh.get_aabb()
	label_stats.text = "Vértices: %d | Superficies: %d\nAABB: %.2f x %.2f x %.2f m" % [
		total_verts,
		mesh.get_surface_count(),
		aabb.size.x, aabb.size.y, aabb.size.z
	]

func _toggle_play_pause() -> void:
	if _is_playing:
		_pause()
	else:
		_play()

func _play() -> void:
	if _sequence_controller.is_completed():
		_sequence_controller.reset()
	_is_playing = true
	btn_play_pause.text = "⏸ Pausar"

func _pause() -> void:
	_is_playing = false
	btn_play_pause.text = "▶ Construir Secuencial"

# --- Control de Cámara Orbital con Mouse ---
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging_orbit = mb.pressed
			_last_mouse_pos = mb.position
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = maxf(2.0, _camera_distance - 0.6)
			_update_camera_transform()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = minf(30.0, _camera_distance + 0.6)
			_update_camera_transform()

	elif event is InputEventMouseMotion and _is_dragging_orbit:
		var mm := event as InputEventMouseMotion
		var delta_pos: Vector2 = mm.position - _last_mouse_pos
		_last_mouse_pos = mm.position

		camera_pivot.rotation.y -= delta_pos.x * 0.008
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - delta_pos.y * 0.008, -1.3, 1.3)
		_update_camera_transform()

func _update_camera_transform() -> void:
	camera_pivot.position = _camera_target
	camera.position = Vector3(0.0, 0.0, _camera_distance)
