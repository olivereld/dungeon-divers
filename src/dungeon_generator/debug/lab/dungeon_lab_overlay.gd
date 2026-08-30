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
