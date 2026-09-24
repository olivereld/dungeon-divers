class_name DungeonSessionData
extends RefCounted

## Almacén singleton en memoria que preserva el estado de transición entre el Mundo y la Mazmorra.

static var active_poi: RefCounted = null
static var active_dungeon_result: RefCounted = null
static var saved_player_overworld_position: Vector3 = Vector3.ZERO
static var return_scene_path: String = "res://src/world_generator/scenes/chunk_world_integration.tscn"
static var return_world_seed: int = 12345
static var return_render_distance: int = 4
