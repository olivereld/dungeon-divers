class_name RiverRenderer
extends RefCounted

## Renderizador dedicado y desacoplado para la red de ríos y sus orillas físicas.
## CONTRATO ESTRICTO DE PRESENTACIÓN:
## 1. NUNCA modifica WorldCell.height ni la verdad del terreno.
## 2. NUNCA recalcula la hidrología, cuencas o direcciones de flujo.
## 3. Consume RiverNetwork, River.points y River.widths como fuente única de verdad geométrica.

static func build_river_node(result: WorldResult, profile: WorldProfile = null) -> Node3D:
	if result == null or result.hydrology == null:
		return null

	if profile == null:
		profile = WorldProfile.new()

	var hydro = result.hydrology
	var rivers: Array = []
	var network = hydro.get_river_network()
	if network is RiverNetwork and not network.rivers.is_empty():
		rivers = network.rivers
	else:
		rivers = hydro.rivers

	if rivers.is_empty():
		return null

	var river_root := Node3D.new()
	river_root.name = "RiverRendererRoot"

	# 1. Maya de agua de ríos
	var water_mat := _create_water_material(profile)
	var river_mesh := build_river_mesh(result, profile)
	if river_mesh != null and river_mesh.get_surface_count() > 0:
		var river_mi := MeshInstance3D.new()
		river_mi.name = "RiversMesh"
		river_mi.mesh = river_mesh
		river_mi.set_surface_override_material(0, water_mat)
		river_root.add_child(river_mi)

	# 2. Maya de orillas físicas (River Banks) si bank_width > 0.0
	if profile.river_bank_width > 0.0:
		var bank_mat := _create_bank_material(profile)
		var bank_mesh := build_bank_mesh(result, profile)
		if bank_mesh != null and bank_mesh.get_surface_count() > 0:
			var bank_mi := MeshInstance3D.new()
			bank_mi.name = "RiverBanksMesh"
			bank_mi.mesh = bank_mesh
			bank_mi.set_surface_override_material(0, bank_mat)
			river_root.add_child(bank_mi)

	return river_root

static func _create_water_material(profile: WorldProfile) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.0, 1.0, 1.0, profile.water_transparency)
	mat.roughness = profile.water_roughness
	mat.metallic = 0.15
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

static func _create_bank_material(profile: WorldProfile) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	mat.roughness = 0.92
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

## Construye la cinta continua de agua para todos los ríos de la red
static func build_river_mesh(result: WorldResult, profile: WorldProfile = null) -> ArrayMesh:
	if result == null or result.hydrology == null:
		return null
	if profile == null:
		profile = WorldProfile.new()

	var hydro = result.hydrology
	var rivers: Array = []
	var network = hydro.get_river_network()
	if network is RiverNetwork and not network.rivers.is_empty():
		rivers = network.rivers
	else:
		rivers = hydro.rivers

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var shallow_col: Color = profile.water_color_shallow
	var river_col: Color = profile.water_color_river
	var lake_col: Color = profile.water_color_lake

	for river in rivers:
		var raw_pts: Array = river.points if (river is River or "points" in river) else river.get("points", [])
		if raw_pts.size() < 2:
			continue

		var raw_widths: Array = river.widths if (river is River or "widths" in river) else river.get("widths", [])
		if raw_widths.size() != raw_pts.size():
			raw_widths = []
			for p_idx in range(raw_pts.size()):
				raw_widths.append(profile.river_min_width)

		var spline_data := _generate_catmull_rom_with_widths(raw_pts, raw_widths, 4)
		var smooth_pts: Array[Vector3] = spline_data["points"]
		var smooth_widths: Array[float] = spline_data["widths"]
		var total_pts: int = smooth_pts.size()
		if total_pts < 2:
			continue

		var river_start_idx: int = vertices.size()

		for j in range(total_pts):
			var p: Vector3 = smooth_pts[j]
			var prog: float = float(j) / float(maxi(total_pts - 1, 1))

			var tangent: Vector3
			if j == 0:
				tangent = (smooth_pts[1] - smooth_pts[0]).normalized()
			elif j == total_pts - 1:
				tangent = (smooth_pts[j] - smooth_pts[j - 1]).normalized()
			else:
				tangent = (smooth_pts[j + 1] - smooth_pts[j - 1]).normalized()
			tangent.y = 0.0
			if tangent.length_squared() < 0.0001:
				tangent = Vector3(0.0, 0.0, 1.0)
			else:
				tangent = tangent.normalized()

			var perp := Vector3(-tangent.z, 0.0, tangent.x).normalized()
			var w: float = smooth_widths[j] / maxf(profile.cell_size, 0.01)

			var lx: float = p.x + perp.x * (w * 0.5)
			var lz: float = p.z + perp.z * (w * 0.5)
			var rx: float = p.x - perp.x * (w * 0.5)
			var rz: float = p.z - perp.z * (w * 0.5)

			var ground_l: float = _sample_terrain_elevation(result, lx, lz)
			var ground_r: float = _sample_terrain_elevation(result, rx, rz)
			var ly: float = ground_l + 0.025
			var ry: float = ground_r + 0.025

			var grid_l := Vector2i(clampi(int(round(lx)), 0, profile.width - 1), clampi(int(round(lz)), 0, profile.height - 1))
			var grid_r := Vector2i(clampi(int(round(rx)), 0, profile.width - 1), clampi(int(round(rz)), 0, profile.height - 1))
			if hydro.is_lake(grid_l):
				var lake_data = hydro.get_cell_data(grid_l)
				if lake_data.has("water_height"):
					ly = maxf(ly, float(lake_data["water_height"]))
			if hydro.is_lake(grid_r):
				var lake_data = hydro.get_cell_data(grid_r)
				if lake_data.has("water_height"):
					ry = maxf(ry, float(lake_data["water_height"]))

			var col: Color
			if prog < 0.35:
				col = shallow_col.lerp(river_col, prog / 0.35)
			else:
				col = river_col.lerp(lake_col, (prog - 0.35) / 0.65)
			col.a = clampf(0.80 + prog * 0.12, 0.0, 0.95)

			vertices.append(Vector3(lx, ly, lz))
			vertices.append(Vector3(rx, ry, rz))

			normals.append(Vector3.UP)
			normals.append(Vector3.UP)

			colors.append(col)
			colors.append(col)

			uvs.append(Vector2(0.0, prog))
			uvs.append(Vector2(1.0, prog))

		for j in range(total_pts - 1):
			var v0: int = river_start_idx + (j * 2)
			var v1: int = v0 + 1
			var v2: int = v0 + 2
			var v3: int = v0 + 3

			indices.append(v0)
			indices.append(v1)
			indices.append(v2)

			indices.append(v1)
			indices.append(v3)
			indices.append(v2)

	if vertices.is_empty():
		return null

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## Construye la franja lateral de orillas de grava y fango adyacente al lecho del río
static func build_bank_mesh(result: WorldResult, profile: WorldProfile = null) -> ArrayMesh:
	if result == null or result.hydrology == null:
		return null
	if profile == null:
		profile = WorldProfile.new()

	var hydro = result.hydrology
	var rivers: Array = []
	var network = hydro.get_river_network()
	if network is RiverNetwork and not network.rivers.is_empty():
		rivers = network.rivers
	else:
		rivers = hydro.rivers

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var bank_inner_col := Color(0.24, 0.18, 0.12, 0.70)  # Fango húmedo en contacto con el agua
	var bank_outer_col := Color(0.38, 0.32, 0.22, 0.0)   # Desvanecimiento al terreno circundante

	var bank_w_extra: float = (profile.river_bank_width * 0.5) / maxf(profile.cell_size, 0.01)

	for river in rivers:
		var raw_pts: Array = river.points if (river is River or "points" in river) else river.get("points", [])
		if raw_pts.size() < 2:
			continue

		var raw_widths: Array = river.widths if (river is River or "widths" in river) else river.get("widths", [])
		var spline_data := _generate_catmull_rom_with_widths(raw_pts, raw_widths, 4)
		var smooth_pts: Array[Vector3] = spline_data["points"]
		var smooth_widths: Array[float] = spline_data["widths"]
		var total_pts: int = smooth_pts.size()
		if total_pts < 2:
			continue

		var bank_start_idx: int = vertices.size()

		# Para cada punto de la orilla generamos 4 vértices: [Outer Left, Inner Left, Inner Right, Outer Right]
		for j in range(total_pts):
			var p: Vector3 = smooth_pts[j]
			var prog: float = float(j) / float(maxi(total_pts - 1, 1))

			var tangent: Vector3
			if j == 0:
				tangent = (smooth_pts[1] - smooth_pts[0]).normalized()
			elif j == total_pts - 1:
				tangent = (smooth_pts[j] - smooth_pts[j - 1]).normalized()
			else:
				tangent = (smooth_pts[j + 1] - smooth_pts[j - 1]).normalized()
			tangent.y = 0.0
			tangent = tangent.normalized() if tangent.length_squared() >= 0.0001 else Vector3(0.0, 0.0, 1.0)

			var perp := Vector3(-tangent.z, 0.0, tangent.x).normalized()
			var half_w: float = (smooth_widths[j] / maxf(profile.cell_size, 0.01)) * 0.5
			var outer_w: float = half_w + bank_w_extra

			# Izquierda exterior e interior
			var l_outer_x: float = p.x + perp.x * outer_w
			var l_outer_z: float = p.z + perp.z * outer_w
			var l_inner_x: float = p.x + perp.x * half_w
			var l_inner_z: float = p.z + perp.z * half_w

			# Derecha interior y exterior
			var r_inner_x: float = p.x - perp.x * half_w
			var r_inner_z: float = p.z - perp.z * half_w
			var r_outer_x: float = p.x - perp.x * outer_w
			var r_outer_z: float = p.z - perp.z * outer_w

			var y_lo: float = _sample_terrain_elevation(result, l_outer_x, l_outer_z) + 0.015
			var y_li: float = _sample_terrain_elevation(result, l_inner_x, l_inner_z) + 0.018
			var y_ri: float = _sample_terrain_elevation(result, r_inner_x, r_inner_z) + 0.018
			var y_ro: float = _sample_terrain_elevation(result, r_outer_x, r_outer_z) + 0.015

			# 4 vértices
			vertices.append(Vector3(l_outer_x, y_lo, l_outer_z))
			vertices.append(Vector3(l_inner_x, y_li, l_inner_z))
			vertices.append(Vector3(r_inner_x, y_ri, r_inner_z))
			vertices.append(Vector3(r_outer_x, y_ro, r_outer_z))

			normals.append(Vector3.UP)
			normals.append(Vector3.UP)
			normals.append(Vector3.UP)
			normals.append(Vector3.UP)

			colors.append(bank_outer_col)
			colors.append(bank_inner_col)
			colors.append(bank_inner_col)
			colors.append(bank_outer_col)

			uvs.append(Vector2(0.0, prog))
			uvs.append(Vector2(0.3, prog))
			uvs.append(Vector2(0.7, prog))
			uvs.append(Vector2(1.0, prog))

		# Conectar los quads de orilla izquierda y orilla derecha
		for j in range(total_pts - 1):
			var base: int = bank_start_idx + (j * 4)
			var lo0: int = base
			var li0: int = base + 1
			var ri0: int = base + 2
			var ro0: int = base + 3

			var lo1: int = base + 4
			var li1: int = base + 5
			var ri1: int = base + 6
			var ro1: int = base + 7

			# Orilla izquierda (lo -> li)
			indices.append(lo0)
			indices.append(li0)
			indices.append(lo1)

			indices.append(li0)
			indices.append(li1)
			indices.append(lo1)

			# Orilla derecha (ri -> ro)
			indices.append(ri0)
			indices.append(ro0)
			indices.append(ri1)

			indices.append(ro0)
			indices.append(ro1)
			indices.append(ri1)

	if vertices.is_empty():
		return null

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _generate_catmull_rom_with_widths(raw_pts: Array, raw_widths: Array, sub_divisions: int = 4) -> Dictionary:
	var pts_res: Array[Vector3] = []
	var widths_res: Array[float] = []
	var n: int = raw_pts.size()
	if n < 2:
		for i in range(n):
			pts_res.append(raw_pts[i] as Vector3)
			widths_res.append(float(raw_widths[i]) if i < raw_widths.size() else 0.5)
		return { "points": pts_res, "widths": widths_res }

	for i in range(n - 1):
		var p0: Vector3 = raw_pts[maxi(i - 1, 0)]
		var p1: Vector3 = raw_pts[i]
		var p2: Vector3 = raw_pts[i + 1]
		var p3: Vector3 = raw_pts[mini(i + 2, n - 1)]

		var w0: float = float(raw_widths[maxi(i - 1, 0)]) if maxi(i - 1, 0) < raw_widths.size() else 0.5
		var w1: float = float(raw_widths[i]) if i < raw_widths.size() else 0.5
		var w2: float = float(raw_widths[i + 1]) if i + 1 < raw_widths.size() else 0.5
		var w3: float = float(raw_widths[mini(i + 2, n - 1)]) if mini(i + 2, n - 1) < raw_widths.size() else 0.5

		for step in range(sub_divisions):
			var t := float(step) / float(sub_divisions)
			var t2 := t * t
			var t3 := t2 * t

			var pt := 0.5 * (
				(2.0 * p1) +
				(-p0 + p2) * t +
				(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
				(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
			)
			var w := 0.5 * (
				(2.0 * w1) +
				(-w0 + w2) * t +
				(2.0 * w0 - 5.0 * w1 + 4.0 * w2 - w3) * t2 +
				(-w0 + 3.0 * w1 - 3.0 * w2 + w3) * t3
			)
			pts_res.append(pt)
			widths_res.append(maxf(w, 0.12))

	pts_res.append(raw_pts[n - 1] as Vector3)
	widths_res.append(maxf(float(raw_widths[n - 1]) if n - 1 < raw_widths.size() else 0.5, 0.12))
	return { "points": pts_res, "widths": widths_res }

static func _sample_terrain_elevation(result: WorldResult, world_x: float, world_z: float) -> float:
	if result == null:
		return 0.0
	var w: int = result.dimensions.x
	var h: int = result.dimensions.y

	var x0: int = clampi(int(floor(world_x)), 0, w - 2)
	var z0: int = clampi(int(floor(world_z)), 0, h - 2)
	var x1: int = x0 + 1
	var z1: int = z0 + 1

	var u: float = clampf(world_x - float(x0), 0.0, 1.0)
	var v: float = clampf(world_z - float(z0), 0.0, 1.0)

	var c00 := result.get_cell(Vector2i(x0, z0))
	var c10 := result.get_cell(Vector2i(x1, z0))
	var c01 := result.get_cell(Vector2i(x0, z1))
	var c11 := result.get_cell(Vector2i(x1, z1))

	var h00: float = c00.height if c00 != null else 0.0
	var h10: float = c10.height if c10 != null else 0.0
	var h01: float = c01.height if c01 != null else 0.0
	var h11: float = c11.height if c11 != null else 0.0

	if u + v <= 1.0:
		return h00 + u * (h10 - h00) + v * (h01 - h00)
	else:
		return h11 + (1.0 - u) * (h01 - h11) + (1.0 - v) * (h10 - h11)
