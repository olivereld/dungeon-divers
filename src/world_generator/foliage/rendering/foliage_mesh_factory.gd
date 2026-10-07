class_name FoliageMeshFactory
extends RefCounted

## Generador y caché de mallas procedimentales de quads cruzados (crossed-quads)
## para foliage masivo estilizado (hierba, arbustos pequeños, flores).
## Diseñado para máxima eficiencia con MultiMeshInstance3D y shaders de viento.

static var _mesh_cache: Dictionary = {}

## Obtiene una malla del caché o la crea si no existe
static func get_or_create_mesh(quad_count: int = 2, width: float = 1.0, height: float = 1.0) -> ArrayMesh:
	var key := "%d_%.2f_%.2f" % [quad_count, width, height]
	if _mesh_cache.has(key) and _mesh_cache[key] != null:
		return _mesh_cache[key]

	var mesh := create_crossed_quad_mesh(quad_count, width, height)
	_mesh_cache[key] = mesh
	return mesh


## Construye un ArrayMesh procedural con quads cruzados alrededor del eje vertical Y
static func create_crossed_quad_mesh(quad_count: int = 2, width: float = 1.0, height: float = 1.0) -> ArrayMesh:
	var q_count := clampi(quad_count, 1, 8)
	var half_w := width * 0.5

	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array() # UV2.y almacena el peso de viento (0 en raíz, 1 en punta)
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	var angle_step := PI / float(q_count)

	for q in range(q_count):
		var angle := float(q) * angle_step
		var dir_x := cos(angle) * half_w
		var dir_z := sin(angle) * half_w
		var base_idx := vertices.size()

		# Vértices del quad
		var v_bl := Vector3(-dir_x, 0.0, -dir_z)
		var v_br := Vector3(dir_x, 0.0, dir_z)
		var v_tr := Vector3(dir_x, height, dir_z)
		var v_tl := Vector3(-dir_x, height, dir_z)

		vertices.append(v_bl)
		vertices.append(v_br)
		vertices.append(v_tr)
		vertices.append(v_tl)

		# Coordenadas UV estándar para texturas (0,0 arriba-izq, 1,1 abajo-der)
		uvs.append(Vector2(0.0, 1.0)) # Base izquierda
		uvs.append(Vector2(1.0, 1.0)) # Base derecha
		uvs.append(Vector2(1.0, 0.0)) # Punta derecha
		uvs.append(Vector2(0.0, 0.0)) # Punta izquierda

		# UV2: Peso de viento en Y (0.0 raíz, 1.0 punta)
		uv2s.append(Vector2(0.0, 0.0))
		uv2s.append(Vector2(1.0, 0.0))
		uv2s.append(Vector2(1.0, 1.0))
		uv2s.append(Vector2(0.0, 1.0))

		# Normales estilizadas hacia arriba para iluminación toon uniforme
		var upward_norm := Vector3(0.0, 1.0, 0.0)
		normals.append(upward_norm)
		normals.append(upward_norm)
		normals.append(upward_norm)
		normals.append(upward_norm)

		# Triángulos (frente)
		indices.append(base_idx + 0)
		indices.append(base_idx + 1)
		indices.append(base_idx + 2)

		indices.append(base_idx + 0)
		indices.append(base_idx + 2)
		indices.append(base_idx + 3)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
