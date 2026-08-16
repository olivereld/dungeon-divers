class_name BiomeProfile
extends Resource

## Perfil visual y mapeo de tiles para el GridMap.
## Permite asignar una MeshLibrary completa o asignar modelos 3D (.gltf/.glb/Mesh) por slot.

@export_group("MeshLibrary Completa")
@export var mesh_library: MeshLibrary = null

@export_group("Modelos 3D por Slot (GLTF / GLB / PackedScene / Mesh)")
@export var floor_scene: PackedScene = null
@export var dungeon_floor_scene: PackedScene = null
@export var wall_scene: PackedScene = null
@export var wall_corner_scene: PackedScene = null
@export var wall_corner_small_scene: PackedScene = null
@export var wall_endcap_scene: PackedScene = null
@export var wall_tsplit_scene: PackedScene = null
@export var column_scene: PackedScene = null
@export var door_scene: PackedScene = null
@export var locked_door_scene: PackedScene = null
@export var stairs_down_scene: PackedScene = null
@export var stairs_up_scene: PackedScene = null

@export_group("Mapeo de Tiles (Índices en MeshLibrary)")
@export var floor_index: int = 0
@export var wall_index: int = 1
@export var wall_corner_index: int = 2
@export var wall_cap_index: int = 3
@export var door_index: int = 4
@export var locked_door_index: int = 5
@export var stairs_down_index: int = 6
@export var stairs_up_index: int = 7
@export var spawn_marker_index: int = 8         # Marker 3D Spawn
@export var objective_marker_index: int = 9     # Marker 3D Objetivo
@export var wall_corner_small_index: int = 10   # Corner pequeño
@export var wall_endcap_index: int = 11         # Remate de pared (Endcap)
@export var dungeon_floor_index: int = 12       # Suelo de piedra para muros y pasillos
@export var wall_tsplit_index: int = 13         # Muro en T (T-split)
@export var column_index: int = 14              # Columna / Pilar 3D
@export var corridor_index: int = -1            # -1 = usar dungeon_floor_index si está asignado, o floor_index

@export_group("Colores Placeholder (Para desarrollo sin assets)")
@export var floor_color: Color = Color("#2d2d2d")
@export var dungeon_floor_color: Color = Color("#3a3a3a")
@export var wall_color: Color = Color("#6b6b6b")
@export var column_color: Color = Color("#7f8c8d")
@export var door_color: Color = Color("#8b5e3c")
@export var locked_door_color: Color = Color("#e74c3c")
@export var stairs_color: Color = Color("#3c5e8b")
@export var spawn_color: Color = Color("#2ecc71")
@export var objective_color: Color = Color("#f1c40f")
@export var corridor_color: Color = Color("#252525")

func has_custom_assets() -> bool:
	return mesh_library != null
