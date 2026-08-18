class_name BiomeProfile
extends Resource

## Perfil visual y mapeo de tiles para el GridMap y entidades de la Fase 8.
## 100% libre de lógica de generación.

@export_group("MeshLibrary Principal")
@export var mesh_library: MeshLibrary = null

@export_group("Modelos 3D por Slot (PackedScene / GLTF)")
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
@export var key_scene: PackedScene = null
@export var treasure_scene: PackedScene = null
@export var spawn_scene: PackedScene = null
@export var boss_scene: PackedScene = null

@export_group("Mapeo de Tiles (Índices en MeshLibrary)")
@export var floor_index: int = 0
@export var wall_index: int = 1
@export var wall_corner_index: int = 2
@export var wall_cap_index: int = 3
@export var door_index: int = 4
@export var locked_door_index: int = 5
@export var stairs_down_index: int = 6
@export var stairs_up_index: int = 7
@export var spawn_marker_index: int = 8
@export var objective_marker_index: int = 9
@export var wall_corner_small_index: int = 10
@export var wall_endcap_index: int = 11
@export var dungeon_floor_index: int = 12
@export var wall_tsplit_index: int = 13
@export var column_index: int = 14
@export var obstacle_index: int = 15
@export var corridor_index: int = -1 # -1 = usar dungeon_floor_index si existe, o floor_index

@export_group("Colores Placeholder (Exclusivo para QA / Debug)")
@export var floor_color: Color = Color("#f1d240")         # Suelo de habitación (Amarillo)
@export var dungeon_floor_color: Color = Color("#38b861") # Suelo de pasillo (Verde)
@export var wall_color: Color = Color("#6b6b6b")
@export var column_color: Color = Color("#7f8c8d")
@export var obstacle_color: Color = Color("#8e44ad")
@export var door_color: Color = Color("#8b5e3c")
@export var locked_door_color: Color = Color("#e74c3c")
@export var stairs_color: Color = Color("#3c5e8b")
@export var spawn_color: Color = Color("#2ecc71")
@export var objective_color: Color = Color("#f1c40f")
@export var corridor_color: Color = Color("#38b861")      # Suelo de pasillo (Verde)

func has_custom_assets() -> bool:
	return mesh_library != null

func validate_profile(is_placeholder_mode: bool = false) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []

	if not is_placeholder_mode and mesh_library == null:
		diagnostics.append({
			"code": "MISSING_MESH_LIBRARY",
			"severity": "FATAL",
			"stage": "biome_profile",
			"entity_id": null,
			"message": "BiomeProfile has no MeshLibrary assigned in production mode."
		})
		return diagnostics

	if mesh_library != null:
		var item_list: PackedInt32Array = mesh_library.get_item_list()
		var required_indices := {
			"floor_index": floor_index,
			"wall_index": wall_index,
		}

		for slot_name in required_indices.keys():
			var idx: int = required_indices[slot_name]
			if idx < 0 or not item_list.has(idx):
				diagnostics.append({
					"code": "INVALID_TILE_MAPPING",
					"severity": "ERROR",
					"stage": "biome_profile",
					"entity_id": slot_name,
					"message": "Required tile mapping '%s' with index %d is not found in MeshLibrary." % [slot_name, idx]
				})

	return diagnostics
