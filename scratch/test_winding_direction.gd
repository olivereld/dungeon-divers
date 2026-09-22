extends SceneTree

func _init() -> void:
	# Test triangle with vertices:
	# v0 = (0, 0, 0)
	# v1 = (1, 0, 0)
	# v2 = (0, 0, 1)
	# Looking from (0, 10, 0) looking down:
	# (0, 0) -> (1, 0) is right (+X)
	# (0, 0) -> (0, 1) is down (+Z)
	# Moving 0 -> 1 -> 2 is CLOCKWISE on screen!
	# In Godot, counter-clockwise (CCW) is FRONT-facing.
	# So (0, 1, 2) is CLOCKWISE, meaning its back face is seen from above!
	# Let's verify with Camera3D and MeshInstance3D.
	var cam := Camera3D.new()
	cam.position = Vector3(0.5, 2.0, 0.5)
	cam.look_at(Vector3(0.5, 0.0, 0.5), Vector3.FORWARD)

	print("Camera forward: %s" % str(-cam.global_transform.basis.z))
	quit()
