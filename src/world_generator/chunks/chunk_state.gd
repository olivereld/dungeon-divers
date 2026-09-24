class_name ChunkLifecycle
extends RefCounted

## Definición formal del ciclo de vida y contenedor de estado de un Chunk.
## Separa explícitamente los datos procedurales (ChunkData) de la vista en Main Thread (ChunkView).

enum ChunkState {
	UNREQUESTED = 0,
	WAITING_HYDROLOGY = 1,
	QUEUED = 2,
	GENERATING = 3,
	READY = 4,
	ACTIVATING = 5,
	VISIBLE = 6,
	CACHED = 7
}

enum ActivationStage {
	NONE = 0,
	TERRAIN_MESH = 1,
	COLLISION = 2,
	WATER = 3,
	POI = 4,
	VEGETATION = 5,
	COMPLETE = 6
}

class ChunkRecord extends RefCounted:
	var coord: Vector2i
	var state: int = ChunkState.UNREQUESTED
	var token: int = 0
	var data: ChunkData = null
	var view: Node3D = null
	var priority: float = 0.0
	var last_accessed_msec: int = 0

	func _init(p_coord: Vector2i = Vector2i.ZERO) -> void:
		coord = p_coord
		last_accessed_msec = Time.get_ticks_msec()

	func is_visible() -> bool:
		return state == ChunkState.VISIBLE and view != null

	func is_ready() -> bool:
		return state == ChunkState.READY and data != null

	func is_cached() -> bool:
		return state == ChunkState.CACHED and data != null

	func touch() -> void:
		last_accessed_msec = Time.get_ticks_msec()
