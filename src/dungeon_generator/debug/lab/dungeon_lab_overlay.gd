class_name DungeonLabOverlay
extends RefCounted

signal overlay_changed

var _show_room_bounds: bool = true
var _show_template_footprint: bool = true
var _show_entrances: bool = true
var _show_corridors: bool = true
var _show_internal_doors: bool = true
var _show_semantic_labels: bool = true
var _show_template_id: bool = true
var _show_stairs: bool = true
var _show_zone_map: bool = false

var show_room_bounds: bool:
	get: return _show_room_bounds
	set(v):
		_show_room_bounds = v
		overlay_changed.emit()

var show_template_footprint: bool:
	get: return _show_template_footprint
	set(v):
		_show_template_footprint = v
		overlay_changed.emit()

var show_entrances: bool:
	get: return _show_entrances
	set(v):
		_show_entrances = v
		overlay_changed.emit()

var show_corridors: bool:
	get: return _show_corridors
	set(v):
		_show_corridors = v
		overlay_changed.emit()

var show_internal_doors: bool:
	get: return _show_internal_doors
	set(v):
		_show_internal_doors = v
		overlay_changed.emit()

var show_semantic_labels: bool:
	get: return _show_semantic_labels
	set(v):
		_show_semantic_labels = v
		overlay_changed.emit()

var show_template_id: bool:
	get: return _show_template_id
	set(v):
		_show_template_id = v
		overlay_changed.emit()

var show_stairs: bool:
	get: return _show_stairs
	set(v):
		_show_stairs = v
		overlay_changed.emit()

var show_zone_map: bool:
	get: return _show_zone_map
	set(v):
		_show_zone_map = v
		overlay_changed.emit()

var _show_spatial_overlay: bool = false
var show_spatial_overlay: bool:
	get: return _show_spatial_overlay
	set(v):
		_show_spatial_overlay = v
		overlay_changed.emit()

var _show_corridor_details: bool = false
var show_corridor_details: bool:
	get: return _show_corridor_details
	set(v):
		_show_corridor_details = v
		overlay_changed.emit()

var _show_semantics_overlay: bool = false
var show_semantics_overlay: bool:
	get: return _show_semantics_overlay
	set(v):
		_show_semantics_overlay = v
		overlay_changed.emit()

# Nuevos Overlays de Composición Espacial Global
var _show_composition_anchors: bool = false
var show_composition_anchors: bool:
	get: return _show_composition_anchors
	set(v):
		_show_composition_anchors = v
		overlay_changed.emit()

var _show_progression_axis: bool = false
var show_progression_axis: bool:
	get: return _show_progression_axis
	set(v):
		_show_progression_axis = v
		overlay_changed.emit()

var _show_main_path_composition: bool = false
var show_main_path_composition: bool:
	get: return _show_main_path_composition
	set(v):
		_show_main_path_composition = v
		overlay_changed.emit()

var _show_branch_zones: bool = false
var show_branch_zones: bool:
	get: return _show_branch_zones
	set(v):
		_show_branch_zones = v
		overlay_changed.emit()

var _show_density_zones: bool = false
var show_density_zones: bool:
	get: return _show_density_zones
	set(v):
		_show_density_zones = v
		overlay_changed.emit()

# Visualización de anclas antes/después del placement: "both", "before", "after"
var _anchors_timing_mode: StringName = &"both"
var anchors_timing_mode: StringName:
	get: return _anchors_timing_mode
	set(v):
		_anchors_timing_mode = v
		overlay_changed.emit()

