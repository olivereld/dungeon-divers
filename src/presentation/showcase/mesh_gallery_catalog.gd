class_name MeshGalleryCatalog
extends RefCounted

## Catálogo declarativo central del Mesh Generation Lab.
## Registra todas las piezas, configuraciones y generadores disponibles para inspección.

const _EntryScript = preload("res://src/presentation/showcase/mesh_gallery_entry.gd")
const _WallMeshConfigScript = preload("res://src/wall_mesh_generator/config/wall_mesh_config.gd")
const _FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const _DoorTypeScript = preload("res://src/dungeon_generator/core/data/door_type.gd")

var _categories: Array[Dictionary] = []
var _entries_by_id: Dictionary = {}

func _init() -> void:
	_register_all_entries()

## Retorna la lista de todas las categorías disponibles.
func get_categories() -> Array[Dictionary]:
	return _categories

## Retorna las entradas correspondientes a una categoría por su ID.
func get_entries_for_category(cat_id: StringName) -> Array[MeshGalleryEntry]:
	for cat in _categories:
		if cat.id == cat_id:
			var list: Array[MeshGalleryEntry] = []
			for item in cat.entries:
				list.append(item as MeshGalleryEntry)
			return list
	return []

## Retorna una entrada específica por su ID único.
func get_entry(entry_id: StringName) -> MeshGalleryEntry:
	return _entries_by_id.get(entry_id, null)

## Cuenta el total de entradas registradas.
func get_total_entry_count() -> int:
	return _entries_by_id.size()

func _register_all_entries() -> void:
	_categories.clear()
	_entries_by_id.clear()

	# 1. Muros Continuos Volumétricos (DungeonGeometryGenerator)
	_add_category(&"walls", "🧱 Muros Procedurales 3D", [
		_create_entry(
			&"wall_continuous_straight",
			&"walls",
			"🧱 Muros Procedurales 3D",
			"Muro Continuo con Ladrillos en Relieve",
			"src/geometry_generator/facade/dungeon_geometry_generator.gd",
			"Malla volumétrica continua real del dungeon con zócalo, cornisa, bisel y ladrillos decorativos en relieve.",
			&"wall_continuous",
			{"layout": "STRAIGHT", "decoration": true}
		),
		_create_entry(
			&"wall_continuous_convex",
			&"walls",
			"🧱 Muros Procedurales 3D",
			"Esquina Convexa Continua (90°)",
			"src/geometry_generator/facade/dungeon_geometry_generator.gd",
			"Esquina exterior continua con inglete automático y unión volumétrica cerrada.",
			&"wall_continuous",
			{"layout": "CORNER_CONVEX", "decoration": true}
		),
		_create_entry(
			&"wall_continuous_concave",
			&"walls",
			"🧱 Muros Procedurales 3D",
			"Esquina Cóncava Continua (Interior)",
			"src/geometry_generator/facade/dungeon_geometry_generator.gd",
			"Esquina interior continua con biselado y transición limpia de zócalo.",
			&"wall_continuous",
			{"layout": "CORNER_CONCAVE", "decoration": true}
		),
		_create_entry(
			&"wall_continuous_opening",
			&"walls",
			"🧱 Muros Procedurales 3D",
			"Muro con Vano de Puerta Tallado",
			"src/geometry_generator/facade/dungeon_geometry_generator.gd",
			"Muro continuo con hueco perimetral exacto tallado mediante WallOpeningManifest.",
			&"wall_continuous",
			{"layout": "STRAIGHT", "opening": true, "decoration": true}
		),
		_create_entry(
			&"wall_continuous_room",
			&"walls",
			"🧱 Muros Procedurales 3D",
			"Habitación Integrada 4x4 (Muros + Suelo)",
			"src/dungeon_generator/presentation/dungeon_presentation_builder.gd",
			"Habitación 4x4 completa mostrando el ensamble continuo de paredes y baldosas de suelo.",
			&"wall_continuous",
			{"layout": "ROOM_BOX", "decoration": true}
		)
	])

	# 2. Suelos y Patrones Estocásticos (DungeonFloorGenerator)
	_add_category(&"floors", "🔲 Suelos & Patrones Estocásticos", [
		_create_entry(
			&"floor_stylized_stone",
			&"floors",
			"🔲 Suelos & Patrones Estocásticos",
			"Piedra Estilizada (STYLIZED_STONE)",
			"src/floor_tile_generator/geometry/floor_surface_mesh_builder.gd",
			"Losas entrelazadas estilizadas tipo Zelda / Diablo con biseles perimetrales y variación tonal.",
			&"floor_surface",
			{"pattern": _FloorTileConfigScript.PatternType.STYLIZED_STONE}
		),
		_create_entry(
			&"floor_cobblestone",
			&"floors",
			"🔲 Suelos & Patrones Estocásticos",
			"Adoquines de Piedra (COBBLESTONE)",
			"src/floor_tile_generator/geometry/floor_surface_mesh_builder.gd",
			"Adoquines pequeños de piedra con micro-desplazamientos de textura estocástica.",
			&"floor_surface",
			{"pattern": _FloorTileConfigScript.PatternType.COBBLESTONE}
		),
		_create_entry(
			&"floor_brick",
			&"floors",
			"🔲 Suelos & Patrones Estocásticos",
			"Ladrillo de Suelo (BRICK)",
			"src/floor_tile_generator/geometry/floor_surface_mesh_builder.gd",
			"Disposición de ladrillos rectangulares entrelazados con separación de mortero.",
			&"floor_surface",
			{"pattern": _FloorTileConfigScript.PatternType.BRICK}
		),
		_create_entry(
			&"floor_smooth_slabs",
			&"floors",
			"🔲 Suelos & Patrones Estocásticos",
			"Losas Suaves Amplias (SMOOTH_SLABS)",
			"src/floor_tile_generator/geometry/floor_surface_mesh_builder.gd",
			"4 losas grandes con biselado suave y variación de altura por ruido perlin.",
			&"floor_surface",
			{"pattern": _FloorTileConfigScript.PatternType.SMOOTH_SLABS}
		),
		_create_entry(
			&"floor_ruined_tiles",
			&"floors",
			"🔲 Suelos & Patrones Estocásticos",
			"Suelo en Ruinas (RUINED_TILES)",
			"src/floor_tile_generator/geometry/floor_surface_mesh_builder.gd",
			"Suelo de mazmorra con losas rotas, huecos y micro-desplazamientos estocásticos.",
			&"floor_surface",
			{"pattern": _FloorTileConfigScript.PatternType.RUINED_TILES}
		)
	])

	# 3. Puertas, Arcos y Portales (DungeonDoorSpawner & WallMeshBuilder)
	_add_category(&"doors", "🚪 Puertas & Portales", [
		_create_entry(
			&"door_arch_stone",
			&"doors",
			"🚪 Puertas & Portales",
			"Arco de Piedra Procedural",
			"src/wall_mesh_generator/core/wall_mesh_builder.gd",
			"Arco de mampostería con jambas biseladas y dovelas talladas.",
			&"wall_modular",
			{"piece": _WallMeshConfigScript.PieceType.ARCH}
		),
		_create_entry(
			&"door_wood_leaf",
			&"doors",
			"🚪 Puertas & Portales",
			"Hoja de Puerta de Madera",
			"src/wall_mesh_generator/core/wall_mesh_builder.gd",
			"Hoja de madera reforzada con herrajes metálicos y aldaba.",
			&"wall_modular",
			{"piece": _WallMeshConfigScript.PieceType.DOOR}
		),
		_create_entry(
			&"door_assembled_closed",
			&"doors",
			"🚪 Puertas & Portales",
			"Portal Completo Ensamblado",
			"src/dungeon_generator/presentation/dungeon_door_spawner.gd",
			"Conjunto de arco de piedra + hoja de puerta batiente interactiva.",
			&"door_portal",
			{"door_type": _DoorTypeScript.DoorType.CLOSED_DOOR}
		),
		_create_entry(
			&"door_assembled_locked",
			&"doors",
			"🚪 Puertas & Portales",
			"Puerta con Candado (LOCKED_DOOR)",
			"src/dungeon_generator/presentation/dungeon_door_spawner.gd",
			"Portal cerrado con cerradura dorada que requiere llave.",
			&"door_portal",
			{"door_type": _DoorTypeScript.DoorType.LOCKED_DOOR}
		)
	])

	# 4. Escaleras & Conexiones Verticales (DungeonStairSpawner)
	_add_category(&"stairs", "🪜 Escaleras & Niveles", [
		_create_entry(
			&"stairs_ascending",
			&"stairs",
			"🪜 Escaleras & Niveles",
			"Escalera de Subida (STAIRS_UP)",
			"src/dungeon_generator/presentation/dungeon_stair_spawner.gd",
			"Escalera de peldaños de piedra con descansillo de embarque para pisos superiores.",
			&"stairs",
			{"is_downward": false}
		),
		_create_entry(
			&"stairs_descending",
			&"stairs",
			"🪜 Escaleras & Niveles",
			"Escalera de Bajada (STAIRS_DOWN)",
			"src/dungeon_generator/presentation/dungeon_stair_spawner.gd",
			"Escalera descendente hacia el piso inferior.",
			&"stairs",
			{"is_downward": true}
		)
	])

	# 5. Iluminación y Antorchas (DungeonLightSpawner)
	_add_category(&"lighting", "🔥 Antorchas & Iluminación", [
		_create_entry(
			&"torch_wall_flicker",
			&"lighting",
			"🔥 Antorchas & Iluminación",
			"Antorcha de Pared con Parpadeo Activo",
			"src/dungeon_lighting/presentation/dungeon_light_spawner.gd",
			"Soporte de hierro forjado, vástago, llama emisiva, luz puntual y parpadeo orgánico por ruido continuo.",
			&"torch_light",
			{"flicker": true, "energy": 1.6}
		)
	])

func _create_entry(
	p_id: StringName,
	p_cat_id: StringName,
	p_cat_name: String,
	p_name: String,
	p_script: String,
	p_desc: String,
	p_generator_id: StringName,
	p_params: Dictionary
) -> MeshGalleryEntry:
	return _EntryScript.new(
		p_id, p_cat_id, p_cat_name, p_name, p_script, p_desc, p_generator_id, p_params
	)

func _add_category(cat_id: StringName, cat_name: String, entries: Array[MeshGalleryEntry]) -> void:
	_categories.append({
		"id": cat_id,
		"name": cat_name,
		"entries": entries
	})
	for e in entries:
		_entries_by_id[e.id] = e
