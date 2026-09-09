class_name TerrainMeshBuilder
extends RefCounted

const _TerrainColorResolverScript = preload("res://src/world_generator/presentation/terrain_color_resolver.gd")

static func build_mesh(result: WorldResult, cell_size: float = 1.0, profile: WorldProfile = null) -> ArrayMesh:
	var w := result.dimensions.x
	var h := result.dimensions.y

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	# Grid vertices
	for y in range(h):
		for x in range(w):
			var cell := result.get_cell(Vector2i(x, y))
			var pos := Vector3(float(x) * cell_size, cell.height, float(y) * cell_size)
			vertices.append(pos)
			uvs.append(Vector2(float(x) / float(w), float(y) / float(h)))

			# Resolve procedural terrain albedo color from profile and cell ecology/topography
			var col: Color = _TerrainColorResolverScript.resolve_vertex_color(cell, profile)
			colors.append(col)

	# Compute indices
	for y in range(h - 1):
		for x in range(w - 1):
			var i0 := y * w + x
			var i1 := y * w + (x + 1)
			var i2 := (y + 1) * w + x
			var i3 := (y + 1) * w + (x + 1)

			# Quad triangles
			indices.append(i0)
			indices.append(i1)
			indices.append(i2)

			indices.append(i1)
			indices.append(i3)
			indices.append(i2)

	# Compute normals
	normals.resize(vertices.size())
	for i in range(normals.size()):
		normals[i] = Vector3.UP

	for i in range(0, indices.size(), 3):
		var v0 := vertices[indices[i]]
		var v1 := vertices[indices[i + 1]]
		var v2 := vertices[indices[i + 2]]
		var n := (v1 - v0).cross(v2 - v0).normalized()
		normals[indices[i]] += n
		normals[indices[i + 1]] += n
		normals[indices[i + 2]] += n

	for i in range(normals.size()):
		normals[i] = normals[i].normalized()

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
