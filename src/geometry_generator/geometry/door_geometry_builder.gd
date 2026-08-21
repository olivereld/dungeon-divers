# DoorGeometryBuilder
extends RefCounted

## Generador procedural de geometría 3D para hojas de puerta y portales ensamblados (Fase M2 & Arquitectura Unificada).
## Construye:
## 1. Superficie "DoorWood": Tablones verticales arqueados y travesaños horizontales biselados.
## 2. Superficie "DoorIron": Aldaba de hierro forjado y herrajes de forja.
## 3. Ensamblaje semántico portal completo (Arch + DoorLeaf) como GeneratedAsset.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")
const _DoorGeometryConfigScript = preload("res://src/geometry_generator/config/door_geometry_config.gd")
const _ArchGeometryConfigScript = preload("res://src/geometry_generator/config/arch_geometry_config.gd")
const _ArchGeometryBuilderScript = preload("res://src/geometry_generator/geometry/arch_geometry_builder.gd")
const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")

func build_door_leaf_mesh(config = null):
	if config == null:
		config = _DoorGeometryConfigScript.new()

	var g_mesh = _GeneratedMeshScript.new()
	g_mesh.component_id = 0

	var st_wood := SurfaceTool.new()
	var st_iron := SurfaceTool.new()

	st_wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_iron.begin(Mesh.PRIMITIVE_TRIANGLES)

	var total_w: float = config.door_width
	var total_h: float = config.door_height
	var thickness: float = config.door_thickness
	var num_planks: int = maxi(2, config.door_plank_count)
	var batten_depth: float = config.door_batten_depth

	var center_offset := Vector3.ZERO
	var center_x: float = center_offset.x
	var base_y: float = center_offset.y
	var center_z: float = center_offset.z

	var half_w: float = total_w * 0.5
	var half_d: float = thickness * 0.5
	var arch_radius: float = half_w
	var spring_y: float = base_y + maxf(0.5, total_h - arch_radius)

	# 1. TABLONES VERTICALES (WOOD)
	var plank_w: float = total_w / float(num_planks)
	var bevel: float = 0.015
	var seam_gap: float = 0.006

	for p in range(num_planks):
		var p_min_x: float = center_x - half_w + (float(p) * plank_w) + (seam_gap * 0.5)
		var p_max_x: float = center_x - half_w + (float(p + 1) * plank_w) - (seam_gap * 0.5)
		_build_arched_plank(st_wood, p_min_x, p_max_x, spring_y, arch_radius, half_d, bevel, center_x, base_y, center_z)

	# 2. TRAVESAÑOS HORIZONTALES (WOOD)
	var batten_h: float = 0.22
	var batten_w: float = total_w - 0.04
	var upper_y: float = spring_y - 0.28
	var lower_y: float = base_y + 0.52

	# Delantero (+Z)
	_build_beveled_batten(st_wood, center_x - batten_w * 0.5, center_x + batten_w * 0.5, upper_y - batten_h * 0.5, upper_y + batten_h * 0.5, center_z + half_d, center_z + half_d + batten_depth, 0.018)
	_build_beveled_batten(st_wood, center_x - batten_w * 0.5, center_x + batten_w * 0.5, lower_y - batten_h * 0.5, lower_y + batten_h * 0.5, center_z + half_d, center_z + half_d + batten_depth, 0.018)

	# Trasero (-Z)
	_build_beveled_batten(st_wood, center_x - batten_w * 0.5, center_x + batten_w * 0.5, upper_y - batten_h * 0.5, upper_y + batten_h * 0.5, center_z - half_d - batten_depth, center_z - half_d, 0.018)
	_build_beveled_batten(st_wood, center_x - batten_w * 0.5, center_x + batten_w * 0.5, lower_y - batten_h * 0.5, lower_y + batten_h * 0.5, center_z - half_d - batten_depth, center_z - half_d, 0.018)

	# 3. ALDABA DE HIERRO (IRON)
	var knocker_x: float = center_x - total_w * 0.22
	var knocker_y: float = (upper_y + lower_y) * 0.5
	var knocker_r: float = config.door_knocker_radius

	_build_iron_knocker(st_iron, Vector3(knocker_x, knocker_y, center_z + half_d), knocker_r, 1.0)
	_build_iron_knocker(st_iron, Vector3(knocker_x, knocker_y, center_z - half_d), knocker_r, -1.0)

	# 4. COMMIT DE SUPERFICIES
	var mesh := ArrayMesh.new()
	st_wood.generate_tangents()
	mesh = st_wood.commit(mesh)
	mesh.surface_set_name(mesh.get_surface_count() - 1, "DoorWood")

	var iron_arrays = st_iron.commit_to_arrays()
	if iron_arrays.size() > 0 and iron_arrays[Mesh.ARRAY_VERTEX] != null and iron_arrays[Mesh.ARRAY_VERTEX].size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, iron_arrays)
		mesh.surface_set_name(mesh.get_surface_count() - 1, "DoorIron")

	g_mesh.mesh = mesh
	g_mesh.bounds = AABB(Vector3(-half_w, 0.0, -half_d - batten_depth), Vector3(total_w, total_h, (half_d + batten_depth) * 2.0))

	# Aplicar Materiales PBR
	g_mesh.material_slots[0] = _WallMaterialFactoryScript.create_wood_material()
	if mesh.get_surface_count() > 1:
		g_mesh.material_slots[1] = _WallMaterialFactoryScript.create_iron_material()

	# Colisión de la hoja
	var col_leaf := BoxShape3D.new()
	col_leaf.size = Vector3(total_w, total_h, thickness + (batten_depth * 2.0))
	g_mesh.add_collision_shape(col_leaf, Transform3D(Basis(), Vector3(center_x, total_h * 0.5, center_z)))

	return g_mesh

## Construye un portal arquitectónico ensamblado (Arco de piedra + Hoja de puerta)
func build_portal_assembly(arch_cfg = null, door_cfg = null, is_open: bool = false, is_locked: bool = false):
	var asset = _GeneratedAssetScript.new()
	asset.asset_id = &"door_portal_locked" if is_locked else (&"door_portal_open" if is_open else &"door_portal_closed")

	# 1. Slot "arch" (Arco de piedra)
	var arch_builder = _ArchGeometryBuilderScript.new()
	var g_arch = arch_builder.build_arch_mesh(arch_cfg)
	asset.add_mesh(&"arch", g_arch)

	# 2. Slot "leaf" (Hoja de madera)
	var g_leaf = build_door_leaf_mesh(door_cfg)

	var leaf_xform := Transform3D.IDENTITY
	if is_open:
		# Puerta abierta: rotada sobre su bisagra izquierda
		var pivot_x: float = -(door_cfg.door_width * 0.5 if door_cfg != null else 0.53)
		var basis_rot := Basis(Vector3.UP, deg_to_rad(80.0))
		leaf_xform.origin = Vector3(pivot_x, 0.0, 0.0)
		leaf_xform.basis = basis_rot
		leaf_xform.origin += basis_rot * Vector3(-pivot_x, 0.0, 0.0)

	asset.add_mesh(&"leaf", g_leaf, leaf_xform)

	asset.metadata["is_open"] = is_open
	asset.metadata["is_locked"] = is_locked

	return asset

# ==============================================================================
# SUB-CONSTRUCTORES GEOMÉTRICOS DE TABLONES, TRAVESAÑOS Y ALDABAS
# ==============================================================================

static func _build_arched_plank(
	st: SurfaceTool, min_x: float, max_x: float, spring_y: float,
	arch_radius: float, half_d: float, bevel: float,
	center_x: float, base_y: float, center_z: float
) -> void:
	var num_segs: int = 6
	var step_x: float = (max_x - min_x) / float(num_segs)

	var front_pts: Array[Vector3] = []
	var back_pts: Array[Vector3] = []
	var front_inner_pts: Array[Vector3] = []
	var back_inner_pts: Array[Vector3] = []

	for i in range(num_segs + 1):
		var x: float = min_x + (float(i) * step_x)
		var dx: float = x - center_x
		var top_y: float = spring_y
		if absf(dx) < arch_radius:
			top_y = spring_y + sqrt(maxf(0.0, (arch_radius * arch_radius) - (dx * dx)))

		front_pts.append(Vector3(x, top_y, center_z + half_d))
		back_pts.append(Vector3(x, top_y, center_z - half_d))
		front_inner_pts.append(Vector3(x, top_y - bevel, center_z + half_d - bevel))
		back_inner_pts.append(Vector3(x, top_y - bevel, center_z - half_d + bevel))

	for i in range(num_segs):
		var p0: Vector3 = Vector3(front_pts[i].x, base_y, front_pts[i].z)
		var p1: Vector3 = Vector3(front_pts[i + 1].x, base_y, front_pts[i + 1].z)
		var p2: Vector3 = front_pts[i + 1]
		var p3: Vector3 = front_pts[i]
		_add_quad_direct(st, p0, p1, p2, p3)

	for i in range(num_segs):
		var p0: Vector3 = Vector3(back_pts[i].x, base_y, back_pts[i].z)
		var p1: Vector3 = Vector3(back_pts[i + 1].x, base_y, back_pts[i + 1].z)
		var p2: Vector3 = back_pts[i + 1]
		var p3: Vector3 = back_pts[i]
		_add_quad_direct(st, p1, p0, p3, p2)

	_add_quad_direct(
		st,
		Vector3(front_pts[0].x, base_y, center_z - half_d),
		Vector3(front_pts[0].x, base_y, center_z + half_d),
		front_pts[0],
		back_pts[0]
	)

	_add_quad_direct(
		st,
		Vector3(front_pts[num_segs].x, base_y, center_z + half_d),
		Vector3(front_pts[num_segs].x, base_y, center_z - half_d),
		back_pts[num_segs],
		front_pts[num_segs]
	)

	for i in range(num_segs):
		_add_quad_direct(st, front_pts[i], front_pts[i + 1], back_pts[i + 1], back_pts[i])

	_add_quad_direct(
		st,
		Vector3(min_x, base_y, center_z + half_d),
		Vector3(max_x, base_y, center_z + half_d),
		Vector3(max_x, base_y, center_z - half_d),
		Vector3(min_x, base_y, center_z - half_d)
	)

static func _build_beveled_batten(
	st: SurfaceTool, min_x: float, max_x: float, min_y: float, max_y: float,
	min_z: float, max_z: float, bevel: float
) -> void:
	var b: float = clampf(bevel, 0.002, minf((max_x - min_x) * 0.2, minf((max_y - min_y) * 0.2, (max_z - min_z) * 0.45)))
	var p0 := Vector3(min_x, min_y, min_z)
	var p1 := Vector3(max_x, min_y, min_z)
	var p2 := Vector3(max_x, max_y, min_z)
	var p3 := Vector3(min_x, max_y, min_z)
	var p4 := Vector3(min_x + b, min_y + b, max_z)
	var p5 := Vector3(max_x - b, min_y + b, max_z)
	var p6 := Vector3(max_x - b, max_y - b, max_z)
	var p7 := Vector3(min_x + b, max_y - b, max_z)

	_add_quad_direct(st, p4, p5, p6, p7)
	_add_quad_direct(st, Vector3(min_x, min_y, max_z - b), Vector3(max_x, min_y, max_z - b), p5, p4)
	_add_quad_direct(st, p7, p6, Vector3(max_x, max_y, max_z - b), Vector3(min_x, max_y, max_z - b))
	_add_quad_direct(st, p0, p1, Vector3(max_x, min_y, max_z - b), Vector3(min_x, min_y, max_z - b))
	_add_quad_direct(st, Vector3(min_x, max_y, max_z - b), Vector3(max_x, max_y, max_z - b), p2, p3)
	_add_quad_direct(st, p0, Vector3(min_x, min_y, max_z - b), Vector3(min_x, max_y, max_z - b), p3)
	_add_quad_direct(st, Vector3(max_x, min_y, max_z - b), p1, p2, Vector3(max_x, max_y, max_z - b))

static func _build_iron_knocker(st: SurfaceTool, mount_pos: Vector3, radius: float, side_facing: float) -> void:
	var base_r: float = radius * 0.35
	var base_h: float = 0.025
	var base_segs: int = 8

	for i in range(base_segs):
		var a0: float = (float(i) / float(base_segs)) * TAU
		var a1: float = (float(i + 1) / float(base_segs)) * TAU
		var v0 := mount_pos + Vector3(cos(a0) * base_r, sin(a0) * base_r, 0.0)
		var v1 := mount_pos + Vector3(cos(a1) * base_r, sin(a1) * base_r, 0.0)
		var v2 := mount_pos + Vector3(cos(a1) * base_r, sin(a1) * base_r, base_h * side_facing)
		var v3 := mount_pos + Vector3(cos(a0) * base_r, sin(a0) * base_r, base_h * side_facing)

		if side_facing > 0.0:
			_add_quad_direct(st, v0, v1, v2, v3)
		else:
			_add_quad_direct(st, v1, v0, v3, v2)

	var ring_center := mount_pos + Vector3(0.0, -radius * 0.75, base_h * side_facing + (radius * 0.15 * side_facing))
	var ring_r: float = radius * 0.70
	var tube_r: float = radius * 0.16
	var ring_segs: int = 12

	for i in range(ring_segs):
		var a0: float = (float(i) / float(ring_segs)) * TAU
		var a1: float = (float(i + 1) / float(ring_segs)) * TAU
		var p0 := ring_center + Vector3(cos(a0) * ring_r, sin(a0) * ring_r, 0.0)
		var p1 := ring_center + Vector3(cos(a1) * ring_r, sin(a1) * ring_r, 0.0)
		_build_cylinder_segment(st, p0, p1, tube_r, 6)

static func _build_cylinder_segment(st: SurfaceTool, start_p: Vector3, end_p: Vector3, radius: float, sides: int) -> void:
	var axis: Vector3 = (end_p - start_p).normalized()
	var ref_up := Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var tangent: Vector3 = axis.cross(ref_up).normalized()
	var bitangent: Vector3 = axis.cross(tangent).normalized()

	for i in range(sides):
		var a0: float = (float(i) / float(sides)) * TAU
		var a1: float = (float(i + 1) / float(sides)) * TAU
		var off0: Vector3 = (tangent * cos(a0) + bitangent * sin(a0)) * radius
		var off1: Vector3 = (tangent * cos(a1) + bitangent * sin(a1)) * radius

		var p0: Vector3 = start_p + off0
		var p1: Vector3 = end_p + off0
		var p2: Vector3 = end_p + off1
		var p3: Vector3 = start_p + off1
		_add_quad_direct(st, p0, p1, p2, p3)

static func _add_quad_direct(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	_add_triangle_direct(st, p0, p1, p2)
	_add_triangle_direct(st, p0, p2, p3)

static func _add_triangle_direct(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3) -> void:
	var normal: Vector3 = (p1 - p0).cross(p2 - p0).normalized()
	st.set_normal(normal)
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(p0)
	st.set_normal(normal)
	st.set_uv(Vector2(1.0, 0.0))
	st.add_vertex(p1)
	st.set_normal(normal)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(p2)
