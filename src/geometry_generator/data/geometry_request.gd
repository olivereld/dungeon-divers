class_name GeometryRequest
extends RefCounted

## DTO para encapsular los parámetros de entrada hacia el generador de geometría.

enum GeometryType {
	WALL,
	FLOOR,
	COLUMN,
	ARCH,
	DOOR_FRAME,
	CUSTOM
}

var type: GeometryType = GeometryType.WALL
var grid = null # CellGrid
var opening_manifest = null # WallOpeningManifest
var wall_config = null # WallGeometryConfig
var collision_config = null # CollisionConfig
var decoration_config = null # DecorationConfig
var parent_node: Node3D = null
var use_clustering: bool = true
