class_name GeneratedFloorCluster
extends RefCounted

## Representa una región conexa de suelo generada como cluster 3D independiente (ArrayMesh + Colisión).

var cluster_id: int = 0
var mesh: ArrayMesh = null
var collision_shapes: Array[Shape3D] = []
var collision_transforms: Array[Transform3D] = []
var aabb: AABB = AABB()
var cells: Array[Vector2i] = []
var metadata: Dictionary = {}

func _init(p_cluster_id: int = 0) -> void:
	cluster_id = p_cluster_id
	collision_shapes = []
	collision_transforms = []
	cells = []
	metadata = {}

func add_collision_shape(shape: Shape3D, xform: Transform3D = Transform3D.IDENTITY) -> void:
	if shape != null:
		collision_shapes.append(shape)
		collision_transforms.append(xform)

## Convierte el cluster en un MeshInstance3D listo para agregarse a la escena.
func to_mesh_instance(name_prefix: String = "FloorCluster") -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = "%s_%d" % [name_prefix, cluster_id]
	inst.mesh = mesh
	return inst

## Crea el StaticBody3D con las formas de colisión física registradas en el cluster.
func create_collision_body(body_name: String = "FloorStaticBody") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	for i in range(collision_shapes.size()):
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D_%d" % i
		col.shape = collision_shapes[i]
		col.transform = collision_transforms[i]
		body.add_child(col)
	return body
