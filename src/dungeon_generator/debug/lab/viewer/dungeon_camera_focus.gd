class_name DungeonCameraFocus
extends RefCounted

## Pure utility for computing camera focus points for full dungeon framing and room-level inspection.
## 100% pure math with safe fallbacks for degenerate / empty AABBs.

## Computes the geometric center of an AABB.
static func compute_center(aabb_min: Vector3, aabb_max: Vector3) -> Vector3:
	var extents := aabb_max - aabb_min
	if extents.x <= 0.001 and extents.y <= 0.001 and extents.z <= 0.001:
		return Vector3.ZERO
	return (aabb_min + aabb_max) * 0.5

## Computes the world-space center of a RoomData.
static func compute_room_focus(room: RefCounted, cell_size: float = 2.0) -> Vector3:
	if room == null or not ("rect" in room):
		return Vector3.ZERO
	
	var r_rect: Rect2i = room.rect
	var world_x: float = (float(r_rect.position.x) + float(r_rect.size.x) * 0.5) * cell_size
	var world_z: float = (float(r_rect.position.y) + float(r_rect.size.y) * 0.5) * cell_size
	return Vector3(world_x, 0.0, world_z)
