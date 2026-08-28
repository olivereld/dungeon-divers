class_name DestructionDebugHUD
extends CanvasLayer

## Panel de telemetría y HUD en pantalla para inspeccionar impactos y estados de destrucción en tiempo real.

const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")
const _DestructionStateScript = preload("res://src/destruction/core/destruction_state.gd")
const _DestructionModeScript = preload("res://src/destruction/core/destruction_mode.gd")

var _panel: PanelContainer = null
var _label_title: Label = null
var _label_state: Label = null
var _label_durability: Label = null
var _label_details: Label = null
var _progress_bar: ProgressBar = null

func _init() -> void:
	layer = 100
	_build_ui()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "DestructionDebugPanel"
	_panel.anchor_left = 0.02
	_panel.anchor_top = 0.02
	_panel.offset_left = 10
	_panel.offset_top = 10
	_panel.custom_minimum_size = Vector2(280, 140)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_label_title = Label.new()
	_label_title.text = "Destruction Inspector: [Idle]"
	_label_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vbox.add_child(_label_title)

	_label_state = Label.new()
	_label_state.text = "State: N/A"
	vbox.add_child(_label_state)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(250, 16)
	_progress_bar.max_value = 100.0
	_progress_bar.value = 100.0
	_progress_bar.show_percentage = false
	vbox.add_child(_progress_bar)

	_label_durability = Label.new()
	_label_durability.text = "Durability: -- / --"
	vbox.add_child(_label_durability)

	_label_details = Label.new()
	_label_details.text = "L-Click: 10 Dmg | R-Click: Instant Destroy"
	_label_details.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(_label_details)

	add_child(_panel)

func update_telemetry(node: Node3D, comp: _DestructionCompScript, last_damage: float = 0.0) -> void:
	if comp == null or comp.definition == null:
		clear_telemetry()
		return

	var asset_id = String(comp.definition.id)
	var node_name = node.name if node != null else "Unknown"
	_label_title.text = "Asset: %s (%s)" % [asset_id, node_name]

	var state_name = _DestructionStateScript.to_name(comp.current_state)
	_label_state.text = "State: %s (Mode: %s)" % [state_name, _DestructionModeScript.to_name(comp.definition.destruction_mode)]

	_label_durability.text = "Durability: %.1f / %.1f (Hit: -%.1f)" % [comp.current_durability, comp.max_durability, last_damage]
	_progress_bar.max_value = comp.max_durability
	_progress_bar.value = comp.current_durability

	match comp.current_state:
		_DestructionStateScript.State.INTACT:
			_label_state.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		_DestructionStateScript.State.DAMAGED:
			_label_state.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		_DestructionStateScript.State.CRITICAL:
			_label_state.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2))
		_DestructionStateScript.State.DESTROYED:
			_label_state.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))

func clear_telemetry() -> void:
	_label_title.text = "Destruction Inspector: [Idle]"
	_label_state.text = "State: N/A"
	_label_state.remove_theme_color_override("font_color")
	_label_durability.text = "Durability: -- / --"
	_progress_bar.value = 0.0

func get_title_text() -> String:
	return _label_title.text if _label_title != null else ""

func get_state_text() -> String:
	return _label_state.text if _label_state != null else ""

func get_durability_text() -> String:
	return _label_durability.text if _label_durability != null else ""
