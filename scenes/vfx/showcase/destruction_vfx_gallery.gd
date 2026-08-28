class_name DestructionVFXGallery
extends Node3D

## Laboratorio visual interactivo para previsualización, ajuste fino y benchmarking
## de efectos visuales (VFX) de destrucción sobre un suelo de mazmorra.

const _VFXRegistryScript = preload("res://src/destruction/response/effects/destruction_vfx_registry.gd")
const _VFXSpawnerScript = preload("res://src/destruction/response/effects/destruction_vfx_spawner.gd")

@export var selected_effect_id: String = "small_dust"
@export var preview_scale: float = 1.0

var _registry: _VFXRegistryScript = null
var _spawner: _VFXSpawnerScript = null
var _spawn_point: Node3D = null
var _vfx_container: Node3D = null

# UI Controls
var _ui_canvas: CanvasLayer = null
var _effect_option_btn: OptionButton = null
var _scale_slider: HSlider = null
var _scale_label: Label = null
var _auto_repeat_check: CheckBox = null
var _stats_label: Label = null

var _auto_repeat_timer: float = 0.0

func _ready() -> void:
	_registry = _VFXRegistryScript.new()
	_spawner = _VFXSpawnerScript.new(_registry)

	_spawn_point = get_node_or_null("SpawnPoint")
	if _spawn_point == null:
		_spawn_point = Node3D.new()
		_spawn_point.name = "SpawnPoint"
		_spawn_point.position = Vector3(0, 0.05, 0)
		add_child(_spawn_point)

	_vfx_container = get_node_or_null("VFXContainer")
	if _vfx_container == null:
		_vfx_container = Node3D.new()
		_vfx_container.name = "VFXContainer"
		add_child(_vfx_container)

	_setup_ui()

func _process(delta: float) -> void:
	if _auto_repeat_check != null and _auto_repeat_check.button_pressed:
		_auto_repeat_timer += delta
		if _auto_repeat_timer >= 1.2:
			_auto_repeat_timer = 0.0
			spawn_selected_effect()

	if _stats_label != null:
		var active_count = _vfx_container.get_child_count()
		_stats_label.text = "Active VFX Nodes: %d | Scale: %.2fx" % [active_count, preview_scale]

func spawn_selected_effect() -> Node3D:
	if _spawner == null or _spawn_point == null or _vfx_container == null:
		return null

	var xform := _spawn_point.global_transform
	var node = _spawner.spawn_effect(selected_effect_id, xform, _vfx_container)
	if node != null:
		node.scale = Vector3.ONE * preview_scale
		print("[VFXGallery] Spawning '%s' at %s (Scale: %.2f)" % [selected_effect_id, str(_spawn_point.global_position), preview_scale])
	return node

func clear_all() -> void:
	if _vfx_container != null:
		for child in _vfx_container.get_children():
			child.queue_free()

func _setup_ui() -> void:
	_ui_canvas = CanvasLayer.new()
	add_child(_ui_canvas)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 240)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(20, 20)
	_ui_canvas.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "VFX Destruction Laboratory"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	# Effect Selector
	_effect_option_btn = OptionButton.new()
	var all_effects = _registry.get_all_effect_ids()
	for i in range(all_effects.size()):
		_effect_option_btn.add_item(all_effects[i], i)
		if all_effects[i] == selected_effect_id:
			_effect_option_btn.selected = i

	_effect_option_btn.item_selected.connect(func(idx):
		selected_effect_id = _effect_option_btn.get_item_text(idx)
	)
	vbox.add_child(_effect_option_btn)

	# Scale Control
	var scale_hbox = HBoxContainer.new()
	var lbl_s = Label.new()
	lbl_s.text = "Scale:"
	scale_hbox.add_child(lbl_s)

	_scale_slider = HSlider.new()
	_scale_slider.min_value = 0.4
	_scale_slider.max_value = 2.5
	_scale_slider.step = 0.1
	_scale_slider.value = preview_scale
	_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale_slider.value_changed.connect(func(val):
		preview_scale = val
	)
	scale_hbox.add_child(_scale_slider)
	vbox.add_child(scale_hbox)

	# Buttons
	var btn_play = Button.new()
	btn_play.text = "[ SPACE ] Play VFX Burst"
	btn_play.pressed.connect(func(): spawn_selected_effect())
	vbox.add_child(btn_play)

	var btn_burst5 = Button.new()
	btn_burst5.text = "Burst Sequence (3x)"
	btn_burst5.pressed.connect(func():
		for i in range(3):
			var offset = Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
			var xform = Transform3D(Basis(), _spawn_point.global_position + offset)
			var node = _spawner.spawn_effect(selected_effect_id, xform, _vfx_container)
			if node != null:
				node.scale = Vector3.ONE * preview_scale
	)
	vbox.add_child(btn_burst5)

	_auto_repeat_check = CheckBox.new()
	_auto_repeat_check.text = "Auto Repeat (every 1.2s)"
	vbox.add_child(_auto_repeat_check)

	var btn_clear = Button.new()
	btn_clear.text = "Clear All"
	btn_clear.pressed.connect(clear_all)
	vbox.add_child(btn_clear)

	_stats_label = Label.new()
	_stats_label.text = "Active Nodes: 0"
	vbox.add_child(_stats_label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			spawn_selected_effect()
		elif event.keycode == KEY_C:
			clear_all()
