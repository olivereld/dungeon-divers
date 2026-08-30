class_name DungeonCameraFraming
extends RefCounted

## Pure utility for calculating bounding boxes, centers, and framing parameters.
## Testable headless without SceneTree or Node dependencies.

enum ProjectionMode {
	PERSPECTIVE = 0,
	ORTHOGONAL = 1,
}

## Computes center, distance, and orthographic size to frame an AABB.
static func compute_framing(
	aabb_min: Vector3,
	aabb_max: Vector3,
	projection_mode: int = ProjectionMode.ORTHOGONAL,
	fov_or_default_size: float = 20.0
) -> Dictionary:
	var extents: Vector3 = aabb_max - aabb_min
	
	# Degenerate / Empty / Inverted AABB fallback
	if extents.x <= 0.001 and extents.y <= 0.001 and extents.z <= 0.001:
		return {
			"center": Vector3.ZERO,
			"distance": 30.0,
			"ortho_size": maxf(fov_or_default_size, 10.0),
			"is_degenerate": true
		}
	
	var center: Vector3 = (aabb_min + aabb_max) * 0.5
	var max_horizontal: float = maxf(extents.x, extents.z)
	var max_dim: float = maxf(max_horizontal, extents.y)
	
	# For isometric 45 deg yaw & ~35.264 deg pitch:
	# The diagonal bounding box requires ~1.25x margin for comfortable framing.
	var ortho_size: float = max_dim * 1.25 + 6.0
	
	# Perspective distance calculation
	var fov_rad: float = deg_to_rad(maxf(fov_or_default_size, 15.0))
	var distance: float = (max_dim * 0.6) / tan(fov_rad * 0.5) + 10.0
	
	return {
		"center": center,
		"distance": distance,
		"ortho_size": ortho_size,
		"is_degenerate": false
	}

## Computes the AABB encompassing all children with VisualInstance3D / CollisionShape3D / Node3D in a hierarchy.
static func compute_hierarchy_aabb(root_node: Node3D) -> Dictionary:
	if root_node == null or root_node.get_child_count() == 0:
		return {
			"min": Vector3.ZERO,
			"max": Vector3.ZERO,
			"valid": false
		}
	
	var min_vec := Vector3(INF, INF, INF)
	var max_vec := Vector3(-INF, -INF, -INF)
	var found_any := false
	
	# Stack stores tuple: [node: Node, parent_accum_xf: Transform3D]
	var initial_xf: Transform3D = root_node.global_transform if root_node.is_inside_tree() else root_node.transform
	var stack: Array[Dictionary] = [{"node": root_node, "xf": initial_xf}]
	
	while not stack.is_empty():
		var item: Dictionary = stack.pop_back()
		var node: Node = item["node"]
		var current_xf: Transform3D = item["xf"]
		
		if node is VisualInstance3D:
			var vis_node: VisualInstance3D = node as VisualInstance3D
			var aabb: AABB = vis_node.get_aabb()
			if aabb.size.length_squared() > 0.0001:
				for corner_idx in 8:
					var pt: Vector3 = aabb.get_endpoint(corner_idx)
					var world_pt: Vector3 = current_xf * pt
					min_vec.x = minf(min_vec.x, world_pt.x)
					min_vec.y = minf(min_vec.y, world_pt.y)
					min_vec.z = minf(min_vec.z, world_pt.z)
					max_vec.x = maxf(max_vec.x, world_pt.x)
					max_vec.y = maxf(max_vec.y, world_pt.y)
					max_vec.z = maxf(max_vec.z, world_pt.z)
				found_any = true
		elif node is Node3D and node != root_node:
			var node_3d: Node3D = node as Node3D
			var pos: Vector3 = current_xf.origin
			min_vec.x = minf(min_vec.x, pos.x)
			min_vec.y = minf(min_vec.y, pos.y)
			min_vec.z = minf(min_vec.z, pos.z)
			max_vec.x = maxf(max_vec.x, pos.x)
			max_vec.y = maxf(max_vec.y, pos.y)
			max_vec.z = maxf(max_vec.z, pos.z)
			found_any = true
		
		for c in node.get_children():
			if c is Node3D:
				var child_3d: Node3D = c as Node3D
				var child_xf: Transform3D = child_3d.global_transform if child_3d.is_inside_tree() else (current_xf * child_3d.transform)
				stack.push_back({"node": c, "xf": child_xf})
			else:
				stack.push_back({"node": c, "xf": current_xf})
	
	if not found_any or min_vec.x == INF:
		return {
			"min": Vector3.ZERO,
			"max": Vector3.ZERO,
			"valid": false
		}
	
	return {
		"min": min_vec,
		"max": max_vec,
		"valid": true
	}
