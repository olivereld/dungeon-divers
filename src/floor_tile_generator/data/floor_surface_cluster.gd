class_name FloorSurfaceCluster
extends RefCounted

## DTO que representa un cluster de suelo (región de habitación o corredor) con sus descriptores y malla generada.

var cluster_id: int = 0
var cells: Array = []
var descriptors: Array = []
var mesh: ArrayMesh = null
var collision_shapes: Array = []
var collision_transforms: Array = []
var aabb: AABB = AABB()
var metadata: Dictionary = {}

func _init(p_cluster_id: int = 0) -> void:
	cluster_id = p_cluster_id
	cells = []
	descriptors = []
	collision_shapes = []
	collision_transforms = []
	aabb = AABB()
	metadata = {}

func add_collision_shape(shape: Shape3D, xform: Transform3D = Transform3D.IDENTITY) -> void:
	if shape != null:
		collision_shapes.append(shape)
		collision_transforms.append(xform)

func to_mesh_instance(name_prefix: String = "FloorCluster") -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = "%s_%d" % [name_prefix, cluster_id]
	inst.mesh = mesh
	return inst

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
