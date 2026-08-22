class_name MeshGalleryCatalog
extends RefCounted

## Catálogo declarativo central del Mesh Generation Lab.
## Registra todas las piezas, configuraciones y generadores disponibles para inspección,
## organizadas jerárquicamente por Categorías -> Objetos/Grupos -> Variantes.

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

## Retorna las entradas planas correspondientes a una categoría por su ID.
func get_entries_for_category(cat_id: StringName) -> Array[MeshGalleryEntry]:
	for cat in _categories:
		if cat.id == cat_id:
			var list: Array[MeshGalleryEntry] = []
			for item in cat.entries:
				list.append(item as MeshGalleryEntry)
			return list
	return []

## Retorna los grupos con sus respectivas variantes para una categoría.
func get_grouped_entries_for_category(cat_id: StringName) -> Array[Dictionary]:
	var entries = get_entries_for_category(cat_id)
	var groups: Array[Dictionary] = []
	var group_map: Dictionary = {}

	for entry in entries:
		var gid: StringName = entry.group_id
		if not group_map.has(gid):
			var g_dict: Dictionary = {
				"group_id": gid,
				"group_name": entry.group_name,
				"variants": []
			}
			group_map[gid] = g_dict
			groups.append(g_dict)
		group_map[gid].variants.append(entry)

	return groups

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
			"Muro Recto con Relieve",
			"src/geometry_generator/facade/dungeon_geometry_generator.gd",
			"Malla volumétrica continua real del dungeon con zócalo, cornisa, bisel y ladrillos decorativos en relieve.",
			&"wall_continuous",
			{"layout": "STRAIGHT", "decoration": true},
			&"wall_straight", "Muro Recto Continuo", "Estándar con Relieve"
		),
		_create_entry(
			&"wall_continuous_convex",
			&"walls",
			"🧱 Muros Procedurales 3D",
			"Esquina Convexa (90°)",
			"src/geometry_generator/facade/dungeon_geometry_generator.gd",
			"Esquina exterior continua con inglete automático y unión volumétrica cerrada.",
			&"wall_continuous",
			{"layout": "CORNER_CONVEX", "decoration": true},
			&"wall_convex", "Esquina Convexa Continua", "Estándar (90°)"
		),
		_create_entry(
			&"wall_continuous_concave",
			&"walls",
			"🧱 Muros Procedurales 3D",
			"Esquina Cóncava (Interior)",
			"src/geometry_generator/facade/dungeon_geometry_generator.gd",
			"Esquina interior continua con biselado y transición limpia de zócalo.",
			&"wall_continuous",
			{"layout": "CORNER_CONCAVE", "decoration": true},
			&"wall_concave", "Esquina Cóncava Continua", "Estándar Interior"
		),
		_create_entry(
			&"wall_continuous_opening",
			&"walls",
			"🧱 Muros Procedurales 3D",
			"Muro con Vano de Puerta",
			"src/geometry_generator/facade/dungeon_geometry_generator.gd",
			"Muro continuo con hueco perimetral exacto tallado mediante WallOpeningManifest.",
			&"wall_continuous",
			{"layout": "STRAIGHT", "opening": true, "decoration": true},
			&"wall_opening", "Muro con Vano Tallado", "Vano de Puerta"
		),
		_create_entry(
			&"wall_continuous_room",
			&"walls",
			"🧱 Muros Procedurales 3D",
			"Habitación Integrada 4x4",
			"src/dungeon_generator/presentation/dungeon_presentation_builder.gd",
			"Habitación 4x4 completa mostrando el ensamble continuo de paredes y baldosas de suelo.",
			&"wall_continuous",
			{"layout": "ROOM_BOX", "decoration": true},
			&"wall_room", "Habitación de Mazmorra", "Habitación 4x4 Box"
		),
		_create_entry(
			&"wall_straight_window",
			&"walls",
			"🧱 Muros Procedurales 3D",
			"Muro 3x2 con Ventana de Celda",
			"src/geometry_generator/fixtures/wall_showcase_geometry_builder.gd",
			"Muro recto de 3 cubos (6.0m) x 2 de alto (4.0m) con ventana arqueada central, alféizar, reja de hierro forjado y ladrillos.",
			&"wall_showcase_prop",
			{"variant": 0},
			&"wall_showcase_3x2", "Muro Recto 3x2 (Straight Wall)", "Ventana Enrejada de Celda"
		),
		_create_entry(
			&"wall_straight_pilaster",
			&"walls",
			"🧱 Muros Procedurales 3D",
			"Muro 3x2 con Pilastra Central",
			"src/geometry_generator/fixtures/wall_showcase_geometry_builder.gd",
			"Muro recto de 3x2 con pilar central de refuerzo saliente, chaflanes a 45°, moldura de imposta y ladrillos.",
			&"wall_showcase_prop",
			{"variant": 1},
			&"wall_showcase_3x2", "Muro Recto 3x2 (Straight Wall)", "Pilastra Central de Refuerzo"
		),
		_create_entry(
			&"wall_straight_fissure",
			&"walls",
			"🧱 Muros Procedurales 3D",
			"Muro 3x2 con Grieta y Relieve",
			"src/geometry_generator/fixtures/wall_showcase_geometry_builder.gd",
			"Muro recto de 3x2 atravesado por una profunda grieta diagonal, 4 grupos de ladrillos estilizados y brotes de vegetación.",
			&"wall_showcase_prop",
			{"variant": 2},
			&"wall_showcase_3x2", "Muro Recto 3x2 (Straight Wall)", "Grieta Diagonal y Vegetación"
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
			{"pattern": _FloorTileConfigScript.PatternType.STYLIZED_STONE},
			&"floor_pattern", "Patrones de Baldosas de Suelo", "Piedra Estilizada"
		),
		_create_entry(
			&"floor_cobblestone",
			&"floors",
			"🔲 Suelos & Patrones Estocásticos",
			"Adoquines de Piedra (COBBLESTONE)",
			"src/floor_tile_generator/geometry/floor_surface_mesh_builder.gd",
			"Adoquines pequeños de piedra con micro-desplazamientos de textura estocástica.",
			&"floor_surface",
			{"pattern": _FloorTileConfigScript.PatternType.COBBLESTONE},
			&"floor_pattern", "Patrones de Baldosas de Suelo", "Adoquines (Cobblestone)"
		),
		_create_entry(
			&"floor_brick",
			&"floors",
			"🔲 Suelos & Patrones Estocásticos",
			"Ladrillo de Suelo (BRICK)",
			"src/floor_tile_generator/geometry/floor_surface_mesh_builder.gd",
			"Disposición de ladrillos rectangulares entrelazados con separación de mortero.",
			&"floor_surface",
			{"pattern": _FloorTileConfigScript.PatternType.BRICK},
			&"floor_pattern", "Patrones de Baldosas de Suelo", "Ladrillo de Suelo"
		),
		_create_entry(
			&"floor_smooth_slabs",
			&"floors",
			"🔲 Suelos & Patrones Estocásticos",
			"Grandes Losas Suaves (SMOOTH_SLABS)",
			"src/floor_tile_generator/geometry/floor_surface_mesh_builder.gd",
			"4 losas grandes con biselado suave y variación de altura por ruido perlin.",
			&"floor_surface",
			{"pattern": _FloorTileConfigScript.PatternType.SMOOTH_SLABS},
			&"floor_pattern", "Patrones de Baldosas de Suelo", "Grandes Losas Suaves"
		),
		_create_entry(
			&"floor_ruined_tiles",
			&"floors",
			"🔲 Suelos & Patrones Estocásticos",
			"Suelo en Ruinas (RUINED_TILES)",
			"src/floor_tile_generator/geometry/floor_surface_mesh_builder.gd",
			"Suelo de mazmorra con losas rotas, huecos y micro-desplazamientos estocásticos.",
			&"floor_surface",
			{"pattern": _FloorTileConfigScript.PatternType.RUINED_TILES},
			&"floor_pattern", "Patrones de Baldosas de Suelo", "Suelo en Ruinas"
		)
	])

	# 3. Puertas, Arcos y Portales (DungeonDoorSpawner & WallMeshBuilder)
	_add_category(&"doors", "🚪 Puertas & Portales", [
		_create_entry(
			&"door_assembled_closed",
			&"doors",
			"🚪 Puertas & Portales",
			"Portal Completo Ensamblado",
			"src/dungeon_generator/presentation/dungeon_door_spawner.gd",
			"Conjunto de arco de piedra + hoja de puerta batiente interactiva.",
			&"door_portal",
			{"door_type": _DoorTypeScript.DoorType.CLOSED_DOOR},
			&"door_portal", "Portales de Mazmorra", "Puerta Ensamblada Cerrada"
		),
		_create_entry(
			&"door_assembled_locked",
			&"doors",
			"🚪 Puertas & Portales",
			"Puerta con Candado (LOCKED_DOOR)",
			"src/dungeon_generator/presentation/dungeon_door_spawner.gd",
			"Portal cerrado con cerradura dorada que requiere llave.",
			&"door_portal",
			{"door_type": _DoorTypeScript.DoorType.LOCKED_DOOR},
			&"door_portal", "Portales de Mazmorra", "Puerta con Candado"
		),
		_create_entry(
			&"door_arch_stone",
			&"doors",
			"🚪 Puertas & Portales",
			"Arco de Piedra Solo",
			"src/wall_mesh_generator/core/wall_mesh_builder.gd",
			"Arco de mampostería con jambas biseladas y dovelas talladas.",
			&"wall_modular",
			{"piece": _WallMeshConfigScript.PieceType.ARCH},
			&"door_portal", "Portales de Mazmorra", "Arco de Piedra Solo"
		),
		_create_entry(
			&"door_wood_leaf",
			&"doors",
			"🚪 Puertas & Portales",
			"Hoja de Puerta de Madera",
			"src/wall_mesh_generator/core/wall_mesh_builder.gd",
			"Hoja de madera reforzada con herrajes metálicos y aldaba.",
			&"wall_modular",
			{"piece": _WallMeshConfigScript.PieceType.DOOR},
			&"door_portal", "Portales de Mazmorra", "Hoja de Madera Sola"
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
			{"is_downward": false},
			&"stairs", "Escaleras de Mazmorra", "Escalera Ascendente (Up)"
		),
		_create_entry(
			&"stairs_descending",
			&"stairs",
			"🪜 Escaleras & Niveles",
			"Escalera de Bajada (STAIRS_DOWN)",
			"src/dungeon_generator/presentation/dungeon_stair_spawner.gd",
			"Escalera descendente hacia el piso inferior.",
			&"stairs",
			{"is_downward": true},
			&"stairs", "Escaleras de Mazmorra", "Escalera Descendente (Down)"
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
			{"flicker": true, "energy": 1.6},
			&"torch", "Antorcha de Pared", "Estándar con Llama Activa"
		),
		_create_entry(
			&"brazier_pedestal_flicker",
			&"lighting",
			"🔥 Antorchas & Iluminación",
			"Brasero Gótico de Pie (Pedestal Brazier)",
			"src/geometry_generator/fixtures/brazier_geometry_builder.gd",
			"Peana de piedra escalonada, fuste acanalado con flejes de hierro forjado, corona de almenas, brasas incandescentes y carbón volcánico.",
			&"brazier_light",
			{"flicker": true, "energy": 2.2},
			&"brazier", "Brasero Gótico de Pie", "Estándar con Brasas"
		),
		_create_entry(
			&"lantern_hanging_flicker",
			&"lighting",
			"🔥 Antorchas & Iluminación",
			"Farol Colgante Gótico (Hanging Lantern)",
			"src/geometry_generator/fixtures/lantern_geometry_builder.gd",
			"Anilla hexagonal de suspensión, cúpula acampanada con cornisas achaflanadas, jaula de arcos ojivales y núcleo de cristal translúcido.",
			&"lantern_light",
			{"is_wall_mounted": false, "flicker": true, "energy": 2.0},
			&"lantern_hang", "Farol Colgante Gótico", "Suspensión de Techo"
		),
		_create_entry(
			&"lantern_wall_flicker",
			&"lighting",
			"🔥 Antorchas & Iluminación",
			"Farol de Pared con Brazo y Voluta (Wall Lantern)",
			"src/geometry_generator/fixtures/lantern_geometry_builder.gd",
			"Cuerpo gótico hexagonal con aguja superior, sostenido por debajo mediante brazo horizontal de forja, placa de pared y ménsula inferior en voluta (S-Scroll).",
			&"lantern_light",
			{"is_wall_mounted": true, "glass_color": Color(1.0, 0.85, 0.40, 1.0), "flicker": true, "energy": 2.2},
			&"lantern_wall", "Farol de Pared con Ménsula", "Montado en Muro"
		),
		_create_entry(
			&"candle_holder_flicker",
			&"lighting",
			"🔥 Antorchas & Iluminación",
			"Candelabro Gótico de 3 Velas (Candle Holder)",
			"src/geometry_generator/fixtures/candle_holder_geometry_builder.gd",
			"Peana circular escalonada, fuste central con 4 puntales de refuerzo, 2 brazos curvos simétricos, 3 cazoletas, velas de cera derretida y llamas emisivas.",
			&"candle_holder_light",
			{"flicker": true, "energy": 1.8},
			&"candle_holder", "Candelabro Gótico de 3 Velas", "Candelabro de Mesa"
		),
		_create_entry(
			&"candle_cluster_medium",
			&"lighting",
			"🔥 Antorchas & Iluminación",
			"Cúmulo de Velas en Suelo (12 Velas)",
			"src/geometry_generator/fixtures/candle_cluster_geometry_builder.gd",
			"Agrupación estocástica de velas de distintas alturas e inclinaciones, charcos de cera fundida en el suelo, gotas esculpidas y llamas emisivas.",
			&"candle_cluster_light",
			{"density": 1, "candle_count": 12, "flicker": true, "energy": 2.2},
			&"candle_cluster", "Cúmulo de Velas en Suelo", "Medio (12 Velas)"
		),
		_create_entry(
			&"candle_cluster_dense",
			&"lighting",
			"🔥 Antorchas & Iluminación",
			"Santuario / Alfombra de Velas (24 Velas)",
			"src/geometry_generator/fixtures/candle_cluster_geometry_builder.gd",
			"Gran densidad de velas agrupadas para cubrir una baldosa completa con charcos de cera derretida entrelazados y múltiples llamas parpadeantes.",
			&"candle_cluster_light",
			{"density": 2, "candle_count": 24, "flicker": true, "energy": 2.8},
			&"candle_cluster", "Cúmulo de Velas en Suelo", "Denso (24 Velas - Santuario)"
		)
	])

	# 6. Props y Objetos de Suelo (Floor Props)
	_add_category(&"props", "📦 Props de Suelo (Floor Props)", [
		_create_entry(
			&"wooden_crate_standard",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Caja de Madera Reforzada (Wooden Crate)",
			"src/geometry_generator/fixtures/crate_geometry_builder.gd",
			"Caja cúbica de madera estilizada con paneles acanalados, marco perimetral de listones biselados, refuerzo diagonal en Z y 8 cantoneras de hierro forjado.",
			&"crate_prop",
			{"stack": false},
			&"crate", "Caja de Madera (Wooden Crate)", "Caja Estándar"
		),
		_create_entry(
			&"wooden_crate_stack",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Apilamiento de Cajas de Madera (Crate Stack)",
			"src/geometry_generator/fixtures/crate_geometry_builder.gd",
			"Composición dinámica de cajas de madera apiladas y rotadas orgánicamente sobre una baldosa del dungeon.",
			&"crate_prop",
			{"stack": true},
			&"crate", "Caja de Madera (Wooden Crate)", "Apilamiento de Cajas"
		),
		_create_entry(
			&"wooden_barrel_standard",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Barril de Madera Abombado (Wooden Barrel)",
			"src/geometry_generator/fixtures/barrel_geometry_builder.gd",
			"Barril de duelas de madera abombadas con brocal rehundido, tapa plana acanalada y zunchos de hierro forjado.",
			&"barrel_prop",
			{"cluster": false},
			&"barrel", "Barril de Madera (Wooden Barrel)", "Barril Estándar"
		),
		_create_entry(
			&"wooden_barrel_cluster",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Conjunto de Barriles (Barrel Duo)",
			"src/geometry_generator/fixtures/barrel_geometry_builder.gd",
			"Composición estilizada de dos barriles (uno erguido y otro tumbado en el suelo) con colisiones físicas precisas.",
			&"barrel_prop",
			{"cluster": true},
			&"barrel", "Barril de Madera (Wooden Barrel)", "Dúo de Barriles (Vertical & Tumbado)"
		),
		_create_entry(
			&"wooden_chest_closed",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Cofre de Madera Cerrado (Closed Chest)",
			"src/geometry_generator/fixtures/chest_geometry_builder.gd",
			"Cofre con cajón inferior hueco, cantoneras de hierro, bocallave y tapa abovedada cerrada.",
			&"chest_prop",
			{"open": false, "loot": false, "open_angle_deg": 0.0},
			&"chest", "Cofre de Mazmorra (Dungeon Chest)", "Cerrado"
		),
		_create_entry(
			&"wooden_chest_open",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Cofre Abierto 145° (Open Chest)",
			"src/geometry_generator/fixtures/chest_geometry_builder.gd",
			"Cofre con la tapa abovedada rotada hacia atrás 145° alrededor de la bisagra trasera superior.",
			&"chest_prop",
			{"open": true, "loot": false, "open_angle_deg": 145.0},
			&"chest", "Cofre de Mazmorra (Dungeon Chest)", "Abierto 145°"
		),
		_create_entry(
			&"wooden_chest_loot",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Cofre con Tesoro Abierto (Loot Chest)",
			"src/geometry_generator/fixtures/chest_geometry_builder.gd",
			"Cofre abierto con resplandor dorado de botín y acumulación de monedas de oro en su interior.",
			&"chest_prop",
			{"open": true, "loot": true, "open_angle_deg": 145.0},
			&"chest", "Cofre de Mazmorra (Dungeon Chest)", "Abierto con Tesoro / Botín"
		),
		_create_entry(
			&"burlap_sack_standing",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Saco de Arpillera de Pie (Burlap Sack)",
			"src/geometry_generator/fixtures/sack_geometry_builder.gd",
			"Saco de tela de arpillera / lino con panza orgánica, cuello fruncido con cuerda de cáñamo y corona superior.",
			&"sack_prop",
			{"cluster": false},
			&"sack", "Saco de Arpillera (Burlap Sack)", "Saco Individual de Pie"
		),
		_create_entry(
			&"burlap_sack_cluster",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Grupo de Sacos de Arpillera (Sack Trio Cluster)",
			"src/geometry_generator/fixtures/sack_geometry_builder.gd",
			"Composición orgánica de 3 sacos de provisiones erguidos de pie con diferentes escalas y rotaciones.",
			&"sack_prop",
			{"cluster": true},
			&"sack", "Saco de Arpillera (Burlap Sack)", "Grupo de 3 Sacos"
		),
		_create_entry(
			&"rubble_pile_small",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Montículo Pequeño de Escombros",
			"src/geometry_generator/fixtures/rubble_geometry_builder.gd",
			"Montículo de escombros de baja altura con bloques de piedra caídos, fragmentos de ladrillo terracota y grava de suelo.",
			&"rubble_prop",
			{"preset": 0, "include_props": false},
			&"rubble", "Derrumbe de Escombros (Rubble)", "Montículo Pequeño (~1.0m)"
		),
		_create_entry(
			&"rubble_pile_large",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Gran Colapso de Muro y Techo",
			"src/geometry_generator/fixtures/rubble_geometry_builder.gd",
			"Gran acumulación de mampostería derruida con grandes sillares angulares, esquirlas, ladrillos rotos y sustrato de polvo.",
			&"rubble_prop",
			{"preset": 2, "include_props": false},
			&"rubble", "Derrumbe de Escombros (Rubble)", "Gran Colapso Masivo (~2.4m)"
		),
		_create_entry(
			&"rubble_with_props",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Derrumbe con Cajas y Barriles Aplastados",
			"src/geometry_generator/fixtures/rubble_geometry_builder.gd",
			"Colapso masivo de mazmorra que entierra y aplasta una caja de madera y un barril entre los bloques de roca caídos.",
			&"rubble_prop",
			{"preset": 1, "include_props": true},
			&"rubble", "Derrumbe de Escombros (Rubble)", "Colapso con Props Aplastados"
		),
		_create_entry(
			&"stone_altar_compact",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Altar de Piedra Compacto (1.25m)",
			"src/geometry_generator/fixtures/altar_geometry_builder.gd",
			"Altar ceremonial compacto (~1.25m) con pedestal escalonado, 4 pilastras y losa volada con bisel.",
			&"altar_prop",
			{"preset": 0},
			&"altar", "Altar de Piedra (Stone Altar)", "Compacto (1.25m)"
		),
		_create_entry(
			&"stone_altar_standard",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Altar de Piedra Estándar (1.80m)",
			"src/geometry_generator/fixtures/altar_geometry_builder.gd",
			"Altar de mazmorra de longitud media (~1.80m) con molduras, pilastras robustas y cuenca superior.",
			&"altar_prop",
			{"preset": 1},
			&"altar", "Altar de Piedra (Stone Altar)", "Estándar (1.80m)"
		),
		_create_entry(
			&"stone_altar_monumental",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Gran Altar Ceremonial (2.40m)",
			"src/geometry_generator/fixtures/altar_geometry_builder.gd",
			"Altar monumental de 2.40m de longitud para salas de jefes y santuarios de mazmorra.",
			&"altar_prop",
			{"preset": 2},
			&"altar", "Altar de Piedra (Stone Altar)", "Monumental Ceremonial (2.40m)"
		),
		_create_entry(
			&"tombstone_classic",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Lápida Arqueada Clásica (Classic Tombstone)",
			"src/geometry_generator/fixtures/tombstone_geometry_builder.gd",
			"Lápida tradicional de cementerio con estela arqueada, marco perimetral biselado y relieve de cruz.",
			&"tombstone_prop",
			{"style": 0},
			&"tombstone", "Lápida de Piedra (Tombstone)", "Arqueada Clásica con Cruz"
		),
		_create_entry(
			&"tombstone_cross",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Cruz Celta Monumental (Celtic Cross)",
			"src/geometry_generator/fixtures/tombstone_geometry_builder.gd",
			"Cruz gótica/celta sobre pedestal escalonado con aureola circular concéntrica y medallón tallado.",
			&"tombstone_prop",
			{"style": 1},
			&"tombstone", "Lápida de Piedra (Tombstone)", "Cruz Celta Monumental"
		),
		_create_entry(
			&"tombstone_broken",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Lápida Antigua Fracturada (Broken Tombstone)",
			"src/geometry_generator/fixtures/tombstone_geometry_builder.gd",
			"Lápida antigua rota con tocón quebrado en la base, losa superior caída en el suelo y esquirlas.",
			&"tombstone_prop",
			{"style": 2},
			&"tombstone", "Lápida de Piedra (Tombstone)", "Lápida Fracturada / Rota"
		),
		_create_entry(
			&"table_long_banquet",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Mesa Larga de Banquete (Long Banquet Table)",
			"src/geometry_generator/fixtures/table_geometry_builder.gd",
			"Mesa comunal larga de 2.40m con 3 tablones de roble, bastidor reforzado, patas de caballete A-frame y viga longitudinal.",
			&"table_prop",
			{"style": 0},
			&"table", "Mesa de Taberna (Tavern Table)", "Larga de Banquete (2.40m Caballete)"
		),
		_create_entry(
			&"table_round_tavern",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Mesa Redonda de Taberna (Round Tavern Table)",
			"src/geometry_generator/fixtures/table_geometry_builder.gd",
			"Mesa circular de taberna con tablero de madera facetado, aro perimetral de hierro forjado, fuste central, base en cruz y 4 tirantes a 45°.",
			&"table_prop",
			{"style": 1},
			&"table", "Mesa de Taberna (Tavern Table)", "Redonda con Aro de Hierro (1.15m)"
		),
		_create_entry(
			&"table_stout_square",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Mesa Robusta con Botas de Hierro (Stout Table)",
			"src/geometry_generator/fixtures/table_geometry_builder.gd",
			"Mesa pesada de 1.60m con 4 tablones gruesos, faldón perimetral y 4 patas acampanadas con fundas de hierro en la base.",
			&"table_prop",
			{"style": 2},
			&"table", "Mesa de Taberna (Tavern Table)", "Robusta Cuadrada con Botas de Hierro (1.60m)"
		),
		_create_entry(
			&"chair_tavern_stool",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Taburete Redondo de Taberna (Round Stool)",
			"src/geometry_generator/fixtures/chair_geometry_builder.gd",
			"Taburete de madera con asiento circular ranurado, 4 patas inclinadas y reposapiés inferior.",
			&"chair_prop",
			{"style": 0},
			&"chair", "Silla de Taberna (Tavern Chair)", "Taburete Redondo (0.48m)"
		),
		_create_entry(
			&"chair_gothic_highback",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Silla Gótica de Respaldo Alto (Gothic High-Back)",
			"src/geometry_generator/fixtures/chair_geometry_builder.gd",
			"Silla ceremonial con arco conopial superior, 5 barrotillos verticales calados y molduras en las patas.",
			&"chair_prop",
			{"style": 1},
			&"chair", "Silla de Taberna (Tavern Chair)", "Gótica de Respaldo Alto (1.15m)"
		),
		_create_entry(
			&"chair_tavern_armchair",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Sillón de Taberna con Reposabrazos (Tavern Armchair)",
			"src/geometry_generator/fixtures/chair_geometry_builder.gd",
			"Sillón robusto de mazmorra con 2 reposabrazos esculpidos en voluta y respaldo de 3 tablones gruesos.",
			&"chair_prop",
			{"style": 2},
			&"chair", "Silla de Taberna (Tavern Chair)", "Sillón con Reposabrazos (1.05m)"
		),
		_create_entry(
			&"bookshelf_empty",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Librería de Mazmorra Vacía (Empty Bookshelf)",
			"src/geometry_generator/fixtures/bookshelf_geometry_builder.gd",
			"Mueble de librería de 4 baldas de roble con zócalo, laterales reforzados, panel trasero y cornisa.",
			&"bookshelf_prop",
			{"style": 0},
			&"bookshelf", "Librería de Mazmorra (Bookshelf)", "Librería Vacía (4 Baldas)"
		),
		_create_entry(
			&"bookshelf_filled",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Librería Llena de Tomos y Libros (Filled Bookshelf)",
			"src/geometry_generator/fixtures/bookshelf_geometry_builder.gd",
			"Librería completa con hileras de libros coloridos de cuero (rojos, azules, verdes y dorados), tomos inclinados y pilas horizontales.",
			&"bookshelf_prop",
			{"style": 1},
			&"bookshelf", "Librería de Mazmorra (Bookshelf)", "Llena de Libros y Tomos"
		),
		_create_entry(
			&"bookshelf_gothic",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Librería Gótica con Copete Arcano (Gothic Bookshelf)",
			"src/geometry_generator/fixtures/bookshelf_geometry_builder.gd",
			"Librería monumental gótica rematada con copete ornamental superior y tomos arcanos.",
			&"bookshelf_prop",
			{"style": 2},
			&"bookshelf", "Librería de Mazmorra (Bookshelf)", "Gótica con Copete Arcano"
		),
		_create_entry(
			&"sarcophagus_stone_closed",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Sarcófago de Piedra Gótica Cerrado (Closed Stone Sarcophagus)",
			"src/geometry_generator/fixtures/sarcophagus_geometry_builder.gd",
			"Sarcófago de piedra tallada de cripta con zócalo, 4 pilastras de esquina, arquerías góticas y losa pesada cerrada.",
			&"sarcophagus_prop",
			{"style": 0, "is_open": false},
			&"sarcophagus", "Sarcófago y Féretro (Sarcophagus)", "Piedra Gótica Cerrado"
		),
		_create_entry(
			&"sarcophagus_stone_open",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Sarcófago de Piedra Gótica Abierto (Open Stone Sarcophagus)",
			"src/geometry_generator/fixtures/sarcophagus_geometry_builder.gd",
			"Sarcófago de piedra tallada con la tapa desplazada e inclinada diagonalmente sobre el reborde, revelando el interior hueco.",
			&"sarcophagus_prop",
			{"style": 0, "is_open": true},
			&"sarcophagus", "Sarcófago y Féretro (Sarcophagus)", "Piedra Gótica Abierto"
		),
		_create_entry(
			&"sarcophagus_wood_closed",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Féretro de Madera Rústica Cerrado (Closed Wood Coffin)",
			"src/geometry_generator/fixtures/sarcophagus_geometry_builder.gd",
			"Féretro rústico de tablones de madera con refuerzos estructurales y tapa cerrada.",
			&"sarcophagus_prop",
			{"style": 1, "is_open": false},
			&"sarcophagus", "Sarcófago y Féretro (Sarcophagus)", "Madera Rústica Cerrado"
		),
		_create_entry(
			&"sarcophagus_wood_open",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Féretro de Madera Rústica Abierto (Open Wood Coffin)",
			"src/geometry_generator/fixtures/sarcophagus_geometry_builder.gd",
			"Féretro rústico de madera con la tapa entreabierta y apoyada sobre el borde.",
			&"sarcophagus_prop",
			{"style": 1, "is_open": true},
			&"sarcophagus", "Sarcófago y Féretro (Sarcophagus)", "Madera Rústica Abierto"
		),
		_create_entry(
			&"bench_church_pew",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Banco de Templo / Iglesia (Church Pew)",
			"src/geometry_generator/fixtures/bench_geometry_builder.gd",
			"Banco ceremonial de madera noble con costados altos, reposabrazos, balaustres torneados, respaldo inclinado y soporte central.",
			&"bench_prop",
			{"style": 0},
			&"bench", "Bancas y Banquetas (Bench)", "Banco de Iglesia / Templo"
		),
		_create_entry(
			&"bench_stone_orior",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Banco Monumental de Piedra (Stone Orior)",
			"src/geometry_generator/fixtures/bench_geometry_builder.gd",
			"Banco monumental de piedra tallada con patas en voluta, losa de asiento pesada con bisel y respaldo decorado.",
			&"bench_prop",
			{"style": 1},
			&"bench", "Bancas y Banquetas (Bench)", "Banco Monumental de Piedra"
		),
		_create_entry(
			&"bench_tavern_hall",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Banco de Taberna con Cojines (Tavern Hall Bench)",
			"src/geometry_generator/fixtures/bench_geometry_builder.gd",
			"Banco estilizado de taberna con respaldo arqueado, barrotes, reposabrazos y 2 cojines acolchados mullidos.",
			&"bench_prop",
			{"style": 2},
			&"bench", "Bancas y Banquetas (Bench)", "Taberna con Cojines"
		),
		_create_entry(
			&"bench_rustic_backless",
			&"props",
			"📦 Props de Suelo (Floor Props)",
			"Banqueta Corrida Rústica (Backless Bench)",
			"src/geometry_generator/fixtures/bench_geometry_builder.gd",
			"Banqueta corrida rústica sin respaldo con asiento de tablón grueso y travesaño longitudinal inferior.",
			&"bench_prop",
			{"style": 3},
			&"bench", "Bancas y Banquetas (Bench)", "Banqueta Corrida Sin Respaldo"
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
	p_params: Dictionary,
	p_group_id: StringName = &"",
	p_group_name: String = "",
	p_variant_name: String = ""
) -> MeshGalleryEntry:
	return _EntryScript.new(
		p_id, p_cat_id, p_cat_name, p_name, p_script, p_desc, p_generator_id, p_params,
		p_group_id, p_group_name, p_variant_name
	)

func _add_category(cat_id: StringName, cat_name: String, entries: Array[MeshGalleryEntry]) -> void:
	_categories.append({
		"id": cat_id,
		"name": cat_name,
		"entries": entries
	})
	for e in entries:
		_entries_by_id[e.id] = e
