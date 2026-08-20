extends Node3D

## Visor 3D interactivo en tiempo real para inspeccionar y probar los patrones de suelo procedurales (FloorTileGenerator).

const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const _DungeonFloorGeneratorScript = preload("res://src/floor_tile_generator/facade/dungeon_floor_generator.gd")
const _CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")
const _DungeonFloorSpawnerScript = preload("res://src/dungeon_generator/presentation/dungeon_floor_spawner.gd")

# Nodos 3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var floor_container: Node3D = $FloorContainer
@onready var light_pivot: Node3D = $LightPivot

# Nodos UI
@onready var option_pattern: OptionButton = %OptionPattern
@onready var option_layout: OptionButton = %OptionLayout
@onready var option_preset: OptionButton = %OptionPreset
@onready var spin_seed: SpinBox = %SpinSeed
@onready var slider_tile_size: HSlider = %SliderTileSize
@onready var label_tile_size: Label = %LabelTileSize
@onready var slider_margin: HSlider = %SliderMargin
@onready var label_margin: Label = %LabelMargin
@onready var label_stats: Label = %LabelStats
@onready var check_rotate: CheckBox = %CheckRotate

var _generator := _DungeonFloorGeneratorScript.new()
var _spawner := _DungeonFloorSpawnerScript.new()
var _config: FloorTileConfig

# Control de Cámara Orbital
var _is_dragging_orbit: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _camera_distance: float = 8.0
var _camera_pitch: float = -35.0
var _camera_yaw: float = 45.0
var _camera_target: Vector3 = Vector3.ZERO

func _ready() -> void:
	_config = _FloorTileConfigScript.new()
	_config.tile_size = 2.0
	_config.margin = 0.035
	_config.pattern = _FloorTileConfigScript.PatternType.STYLIZED_STONE
	_config.collision_mode = _FloorTileConfigScript.CollisionMode.COMPOUND_BOX
	_config.seed = 1337

	_setup_ui()
	_rebuild_floor()

func _setup_ui() -> void:
	# Patrones
	option_pattern.clear()
	option_pattern.add_item("Stylized Stone (Zelda/Diablo)", _FloorTileConfigScript.PatternType.STYLIZED_STONE)
	option_pattern.add_item("Cobblestone (Adoquines)", _FloorTileConfigScript.PatternType.COBBLESTONE)
	option_pattern.add_item("Brick (Ladrillos)", _FloorTileConfigScript.PatternType.BRICK)
	option_pattern.add_item("Smooth Slabs (Losas Amplias)", _FloorTileConfigScript.PatternType.SMOOTH_SLABS)
	option_pattern.add_item("Ruined Tiles (Suelo Agrietado)", _FloorTileConfigScript.PatternType.RUINED_TILES)
	option_pattern.select(0)
	option_pattern.item_selected.connect(_on_pattern_changed)

	# Layouts
	option_layout.clear()
	option_layout.add_item("Habitación 3x3 (9 baldosas)", 0)
	option_layout.add_item("Baldosa Única 1x1", 1)
	option_layout.add_item("Sala Grande 5x5 (25 baldosas)", 2)
	option_layout.add_item("Sala en forma de L", 3)
	option_layout.add_item("Corredor 1x6", 4)
	option_layout.select(0)
	option_layout.item_selected.connect(func(_idx): _rebuild_floor())

	# Material Presets
	option_preset.clear()
	option_preset.add_item("Pizarra Estilizada (Slate)", 0)
	option_preset.add_item("Piedra Cálida (Warm Stone)", 1)
	option_preset.add_item("Cripta Oscura (Dark Crypt)", 2)
	option_preset.add_item("Ruinas Arenisca (Sandstone)", 3)
	option_preset.select(0)
	option_preset.item_selected.connect(_on_preset_changed)

	# Sliders
	slider_tile_size.value = _config.tile_size
	slider_tile_size.value_changed.connect(func(v):
		_config.tile_size = v
		label_tile_size.text = "Tamaño Baldosa: %.1fm" % v
		_rebuild_floor()
	)
	label_tile_size.text = "Tamaño Baldosa: %.1fm" % _config.tile_size

	slider_margin.value = _config.margin
	slider_margin.value_changed.connect(func(v):
		_config.margin = v
		label_margin.text = "Mortero / Junta: %.3fm" % v
		_rebuild_floor()
	)
	label_margin.text = "Mortero / Junta: %.3fm" % _config.margin

	# Semilla
	spin_seed.value = _config.seed
	spin_seed.value_changed.connect(func(v):
		_config.seed = int(v)
		_rebuild_floor()
	)

func _on_pattern_changed(idx: int) -> void:
	_config.pattern = option_pattern.get_item_id(idx) as FloorTileConfig.PatternType
	_rebuild_floor()

func _on_preset_changed(idx: int) -> void:
	_config.material_preset = option_preset.get_item_id(idx)
	_rebuild_floor()

func _create_grid_layout() -> CellGrid:
	var layout_type: int = option_layout.get_selected_id()
	var grid: CellGrid = null

	match layout_type:
		1: # 1x1
			grid = _CellGridScript.new(1, 1, _CellGridScript.CellType.WALL)
			grid.set_cell(Vector2i(0, 0), _CellGridScript.CellType.FLOOR)
			_camera_target = Vector3(_config.tile_size * 0.5, 0.0, _config.tile_size * 0.5)
			_camera_distance = 4.5
		2: # 5x5
			grid = _CellGridScript.new(5, 5, _CellGridScript.CellType.WALL)
			for y in range(5):
				for x in range(5):
					grid.set_cell(Vector2i(x, y), _CellGridScript.CellType.FLOOR)
			_camera_target = Vector3(2.5 * _config.tile_size, 0.0, 2.5 * _config.tile_size)
			_camera_distance = 12.0
		3: # L-Room
			grid = _CellGridScript.new(4, 4, _CellGridScript.CellType.WALL)
			for y in range(4):
				grid.set_cell(Vector2i(0, y), _CellGridScript.CellType.FLOOR)
			for x in range(1, 4):
				grid.set_cell(Vector2i(x, 3), _CellGridScript.CellType.FLOOR)
			_camera_target = Vector3(2.0 * _config.tile_size, 0.0, 2.0 * _config.tile_size)
			_camera_distance = 9.0
		4: # Corredor 1x6
			grid = _CellGridScript.new(6, 1, _CellGridScript.CellType.WALL)
			for x in range(6):
				grid.set_cell(Vector2i(x, 0), _CellGridScript.CellType.CORRIDOR)
			_camera_target = Vector3(3.0 * _config.tile_size, 0.0, 0.5 * _config.tile_size)
			_camera_distance = 10.0
		_: # 3x3
			grid = _CellGridScript.new(3, 3, _CellGridScript.CellType.WALL)
			for y in range(3):
				for x in range(3):
					grid.set_cell(Vector2i(x, y), _CellGridScript.CellType.FLOOR)
			_camera_target = Vector3(1.5 * _config.tile_size, 0.0, 1.5 * _config.tile_size)
			_camera_distance = 7.5

	return grid

func _rebuild_floor() -> void:
	# Limpiar hijos anteriores
	for child in floor_container.get_children():
		child.queue_free()

	var grid := _create_grid_layout()
	var start_time := Time.get_ticks_usec()
	var res = _generator.generate_floor_surface(grid, _config, _config.seed)
	var elapsed_ms := float(Time.get_ticks_usec() - start_time) / 1000.0

	_spawner.spawn_floor(res, floor_container)

	label_stats.text = "Stats: %d baldosas | %d losas/piedras | %d clusters | %.2f ms" % [
		res.total_tiles_generated,
		res.total_descriptors_count,
		res.clusters.size(),
		elapsed_ms
	]
	_update_camera()

func _process(delta: float) -> void:
	if check_rotate.button_pressed:
		_camera_yaw += delta * 15.0
		_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_dragging_orbit = mb.pressed
			_last_mouse_pos = mb.position
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = maxf(2.0, _camera_distance - 0.6)
			_update_camera()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = minf(25.0, _camera_distance + 0.6)
			_update_camera()

	elif event is InputEventMouseMotion and _is_dragging_orbit:
		var mm := event as InputEventMouseMotion
		var delta := mm.position - _last_mouse_pos
		_last_mouse_pos = mm.position

		_camera_yaw -= delta.x * 0.35
		_camera_pitch = clampf(_camera_pitch - (delta.y * 0.35), -85.0, -5.0)
		_update_camera()

func _update_camera() -> void:
	if camera_pivot == null or camera == null:
		return

	camera_pivot.position = _camera_target
	camera_pivot.rotation_degrees = Vector3(_camera_pitch, _camera_yaw, 0.0)
	camera.position = Vector3(0.0, 0.0, _camera_distance)
