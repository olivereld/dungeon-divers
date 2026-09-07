class_name WallPathGeometry
extends RefCounted

## Representación geométrica intermedia de un recorrido continuo de muro (bucle cerrado o cadena abierta).
## Agrupa la centerline 3D y los vértices de perfil offset reales (ProfileVertex).
## Permite unificar la generación de malla para WallComponent y WallSection.

const _WallProfileBuilderScript = preload("res://src/geometry_generator/geometry/wall_profile_builder.gd")
const _WallSectionScript = preload("res://src/geometry_generator/data/wall_section.gd")
const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")

var points_3d: Array[Vector3] = []
var profiles: Array = [] # Array de ProfileVertex
var corners: Array: # Compatibilidad temporal durante refactorización
	get:
		return profiles
	set(value):
		profiles = value
var is_closed: bool = false
var has_start_cap: bool = false
var has_end_cap: bool = false
var aabb: AABB = AABB()
var metadata: Dictionary = {}

func get_segment_count() -> int:
	var n: int = points_3d.size()
	if n < 2:
		return 0
	return n if is_closed else (n - 1)

func get_profile(idx: int):
	if idx >= 0 and idx < profiles.size():
		return profiles[idx]
	return null

func get_corner(idx: int):
	return get_profile(idx)

static func from_section(
	section: _WallSectionScript,
	config: _WallGeometryConfigScript
) -> RefCounted:
	var path_geom = new()
	if section == null or section.points.size() < 2:
		return path_geom

	if config == null:
		config = _WallGeometryConfigScript.new()

	var tile_size: float = config.cube_size
	var total_h: float = config.get_total_height()
	var w_thin: float = config.wall_thickness
	var d: float = config.trim_overhang
	var w_thick: float = w_thin + (d * 2.0)

	# 1. Deduplicar puntos consecutivos
	var clean_pts: Array[Vector2i] = []
	for pt in section.points:
		if clean_pts.is_empty() or clean_pts[clean_pts.size() - 1] != pt:
			clean_pts.append(pt)

	if section.is_closed_loop and clean_pts.size() > 2 and clean_pts[0] == clean_pts[clean_pts.size() - 1]:
		clean_pts.pop_back()

	var n: int = clean_pts.size()
	if n < 2:
		return path_geom

	# 2. Construir puntos 3D y AABB
	var pts_3d: Array[Vector3] = []
	var aabb_calc := AABB()
	var aabb_init := false
	for pt in clean_pts:
		var p3 := Vector3(float(pt.x) * tile_size, 0.0, float(pt.y) * tile_size)
		pts_3d.append(p3)
		if not aabb_init:
			aabb_calc = AABB(p3, Vector3(0.01, total_h, 0.01))
			aabb_init = true
		else:
			aabb_calc = aabb_calc.expand(p3)
			aabb_calc = aabb_calc.expand(p3 + Vector3(0.0, total_h, 0.0))

	var is_closed: bool = section.is_closed_loop and (n >= 3)

	# 3. Vecinos 3D para offsets
	var start_neighbor_3d := Vector3.INF
	if not is_closed and section.start_miter_neighbor != _WallSectionScript.INVALID_NEIGHBOR:
		start_neighbor_3d = Vector3(
			float(section.start_miter_neighbor.x) * tile_size,
			0.0,
			float(section.start_miter_neighbor.y) * tile_size
		)

	var end_neighbor_3d := Vector3.INF
	if not is_closed and section.end_miter_neighbor != _WallSectionScript.INVALID_NEIGHBOR:
		end_neighbor_3d = Vector3(
			float(section.end_miter_neighbor.x) * tile_size,
			0.0,
			float(section.end_miter_neighbor.y) * tile_size
		)

	# 4. Calcular perfiles continuos vía intersección de líneas offset
	var builder := _WallProfileBuilderScript.new()
	var resolved_profiles = builder.compute_path_profiles(
		pts_3d,
		is_closed,
		start_neighbor_3d,
		end_neighbor_3d,
		w_thick,
		w_thin,
		d
	)

	path_geom.points_3d = pts_3d
	path_geom.profiles = resolved_profiles
	path_geom.is_closed = is_closed
	path_geom.has_start_cap = section.has_start_cap
	path_geom.has_end_cap = section.has_end_cap
	path_geom.aabb = aabb_calc
	path_geom.metadata = {
		"component_id": section.component_id,
		"section_id": section.id,
		"room_id": section.room_id,
		"variant_id": section.variant_id
	}

	return path_geom

static func from_component_loop(
	loop_raw: Array,
	comp_id: int,
	config: _WallGeometryConfigScript
) -> RefCounted:
	var path_geom = new()
	if loop_raw.is_empty():
		return path_geom

	if config == null:
		config = _WallGeometryConfigScript.new()

	var tile_size: float = config.cube_size
	var total_h: float = config.get_total_height()
	var w_thin: float = config.wall_thickness
	var d: float = config.trim_overhang
	var w_thick: float = w_thin + (d * 2.0)

	var clean_pts: Array[Vector2i] = []
	for pt_raw in loop_raw:
		var pt_vec: Vector2i = pt_raw as Vector2i
		if clean_pts.is_empty() or clean_pts[clean_pts.size() - 1] != pt_vec:
			clean_pts.append(pt_vec)

	if clean_pts.size() > 1 and clean_pts[0] == clean_pts[clean_pts.size() - 1]:
		clean_pts.pop_back()

	var n: int = clean_pts.size()
	if n < 3:
		return path_geom

	var pts_3d: Array[Vector3] = []
	var aabb_calc := AABB()
	var aabb_init := false
	for pt in clean_pts:
		var p3 := Vector3(float(pt.x) * tile_size, 0.0, float(pt.y) * tile_size)
		pts_3d.append(p3)
		if not aabb_init:
			aabb_calc = AABB(p3, Vector3(0.01, total_h, 0.01))
			aabb_init = true
		else:
			aabb_calc = aabb_calc.expand(p3)
			aabb_calc = aabb_calc.expand(p3 + Vector3(0.0, total_h, 0.0))

	var builder := _WallProfileBuilderScript.new()
	var resolved_profiles = builder.compute_path_profiles(
		pts_3d,
		true,
		Vector3.INF,
		Vector3.INF,
		w_thick,
		w_thin,
		d
	)

	path_geom.points_3d = pts_3d
	path_geom.profiles = resolved_profiles
	path_geom.is_closed = true
	path_geom.has_start_cap = false
	path_geom.has_end_cap = false
	path_geom.aabb = aabb_calc
	path_geom.metadata = {
		"component_id": comp_id
	}

	return path_geom

static func from_component_chain(
	chain_raw: Array,
	comp_id: int,
	config: _WallGeometryConfigScript
) -> RefCounted:
	var path_geom = new()
	if chain_raw.is_empty():
		return path_geom

	if config == null:
		config = _WallGeometryConfigScript.new()

	var tile_size: float = config.cube_size
	var total_h: float = config.get_total_height()
	var w_thin: float = config.wall_thickness
	var d: float = config.trim_overhang
	var w_thick: float = w_thin + (d * 2.0)

	var clean_pts: Array[Vector2i] = []
	for pt_raw in chain_raw:
		var pt_vec: Vector2i = pt_raw as Vector2i
		if clean_pts.is_empty() or clean_pts[clean_pts.size() - 1] != pt_vec:
			clean_pts.append(pt_vec)

	var n: int = clean_pts.size()
	if n < 2:
		return path_geom

	var pts_3d: Array[Vector3] = []
	var aabb_calc := AABB()
	var aabb_init := false
	for pt in clean_pts:
		var p3 := Vector3(float(pt.x) * tile_size, 0.0, float(pt.y) * tile_size)
		pts_3d.append(p3)
		if not aabb_init:
			aabb_calc = AABB(p3, Vector3(0.01, total_h, 0.01))
			aabb_init = true
		else:
			aabb_calc = aabb_calc.expand(p3)
			aabb_calc = aabb_calc.expand(p3 + Vector3(0.0, total_h, 0.0))

	var builder := _WallProfileBuilderScript.new()
	var resolved_profiles = builder.compute_path_profiles(
		pts_3d,
		false,
		Vector3.INF,
		Vector3.INF,
		w_thick,
		w_thin,
		d
	)

	path_geom.points_3d = pts_3d
	path_geom.profiles = resolved_profiles
	path_geom.is_closed = false
	path_geom.has_start_cap = true
	path_geom.has_end_cap = true
	path_geom.aabb = aabb_calc
	path_geom.metadata = {
		"component_id": comp_id
	}

	return path_geom
