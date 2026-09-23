extends SceneTree

const _WorldRendererScript = preload("res://src/world_renderer/world_renderer.gd")
const BUSH_GLB_PATH: String = "res://models/nature/bush/bush_1.glb"

func _init() -> void:
	print("Testing bush baking...")
	var glb: PackedScene = load(BUSH_GLB_PATH)
	assert(glb != null)
	var inst: Node = glb.instantiate()
	
	# Find chain to MeshInstance3D
	var chain: Array[Node3D] = []
	_find_chain(inst, chain)
	print("Found chain with %d nodes: %s" % [chain.size(), chain.back().name])
	
	var accumulated_xf := Transform3D.IDENTITY
	for node in chain:
		accumulated_xf = accumulated_xf * node.transform
	
	var mi: MeshInstance3D = chain.back() as MeshInstance3D
	var orig_mesh: Mesh = mi.mesh
	var mat: Material = mi.get_surface_override_material(0) if mi.get_surface_override_material(0) else orig_mesh.surface_get_material(0)
	
	print("Orig material: ", mat)
	print("Accumulated transform: ", accumulated_xf)
	
	inst.queue_free()
	quit(0)

func _find_chain(curr: Node, current_chain: Array[Node3D]) -> bool:
	if curr is Node3D:
		current_chain.append(curr)
	if curr is MeshInstance3D and curr.mesh != null:
		return true
	for c in curr.get_children():
		if _find_chain(c, current_chain):
			return true
	if curr is Node3D:
		current_chain.pop_back()
	return false
