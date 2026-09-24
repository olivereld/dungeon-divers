class_name DungeonWorldBridge
extends RefCounted

## Puente desacoplado que traduce un DungeonPOI en un DungeonConfig y coordina
## la invocación de DungeonPipeline garantizando determinismo estricto.
## No contiene lógica interna de mazmorras; su responsabilidad es la traducción
## limpia del contrato: World POI -> DungeonConfig -> DungeonPipeline.

const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")

static func create_dungeon_config(poi: RefCounted) -> RefCounted:
	var cfg = _DungeonConfigScript.new()
	
	cfg.dungeon_id = poi.identity.dungeon_id
	cfg.archetype_id = poi.archetype_id
	cfg.total_floors = poi.total_floors
	
	# Autoridad de semilla canónica
	cfg.seed = poi.identity.dungeon_seed
	cfg.use_fixed_seed = true
	
	# Escala de salas según el tier del POI
	cfg.min_target_rooms = 5 + poi.tier * 2
	cfg.max_target_rooms = 10 + poi.tier * 3
	
	return cfg

static func generate_dungeon_from_poi(poi: RefCounted) -> RefCounted:
	var cfg = create_dungeon_config(poi)
	var pipeline = _DungeonPipelineScript.new()
	return pipeline.generate(cfg)
