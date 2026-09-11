class_name WaterSurfaceData
extends RefCounted

## Contrato de datos geométrico unificado para superficies de agua (ríos, lagos y confluencias).
## Totalmente desacoplado de los buffers de terreno. Se convierte directamente a ArrayMesh.

var vertices: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var uvs: PackedVector2Array = PackedVector2Array()
var uv2_flow: PackedVector2Array = PackedVector2Array()
var colors: PackedColorArray = PackedColorArray()
var indices: PackedInt32Array = PackedInt32Array()

func clear() -> void:
	vertices.clear()
	normals.clear()
	uvs.clear()
	uv2_flow.clear()
	colors.clear()
	indices.clear()

func add_vertex(pos: Vector3, normal: Vector3, uv: Vector2, flow_dir: Vector2, col: Color) -> int:
	var idx: int = vertices.size()
	vertices.append(pos)
	normals.append(normal)
	uvs.append(uv)
	uv2_flow.append(flow_dir)
	colors.append(col)
	return idx

func add_triangle(i0: int, i1: int, i2: int) -> void:
	indices.append(i0)
	indices.append(i1)
	indices.append(i2)

func append_surface(other: WaterSurfaceData) -> void:
	if other == null or other.vertices.is_empty():
		return
	var offset: int = vertices.size()
	vertices.append_array(other.vertices)
	normals.append_array(other.normals)
	uvs.append_array(other.uvs)
	uv2_flow.append_array(other.uv2_flow)
	colors.append_array(other.colors)
	for idx in other.indices:
		indices.append(offset + idx)

func to_array_mesh() -> ArrayMesh:
	if vertices.is_empty() or indices.is_empty():
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2_flow
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
