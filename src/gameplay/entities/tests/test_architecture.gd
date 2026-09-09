# test_architecture.gd
# Tests de arquitectura: protegen reglas conceptuales, no solo números.
# Si alguno de estos falla, algo rompió la separación Living/Object que
# es el objetivo central de Entities v1.
#
# NOTA: Godot 4.6 rechaza `ObjectEntity is LivingEntity` como error de
# análisis estático (sabe que un ObjectEntity nunca puede ser LivingEntity).
# Para que los tests corran como checks de runtime, usamos variables sin tipo
# explícito (Variant) donde sea necesario.
extends SceneTree

func _init() -> void:
	test_object_entity_no_es_living()
	test_living_entity_si_es_living()
	test_targetable_no_implica_living()
	test_destructible_no_implica_living()
	test_faction_no_implica_living()
	test_species_no_es_faction()
	test_targetable_no_es_combattarget()
	test_objeto_puede_tener_faccion_sin_especie()
	print("test_architecture: OK")
	quit()

func test_object_entity_no_es_living() -> void:
	var barrel = ObjectEntity.new(EntityIdentity.new("barrel_003", EntityKind.Type.DESTRUCTIBLE_OBJECT))
	assert(not (barrel is LivingEntity))

func test_living_entity_si_es_living() -> void:
	var base := AttributeSet.new()
	var derived := StatCalculator.calculate_derived_stats(1, base, {})
	var player = LivingEntity.new(
		EntityIdentity.new("player_002", EntityKind.Type.PLAYER),
		Health.new(derived.max_hp),
		derived
	)
	assert(player is LivingEntity)

func test_targetable_no_implica_living() -> void:
	var turret = ObjectEntity.new(EntityIdentity.new("turret_003", EntityKind.Type.TURRET))
	turret.add_capability(Entity.CAPABILITY_TARGETABLE, Targetable.new(true, Targetable.Category.OBJECT))
	assert(turret.has_capability(Entity.CAPABILITY_TARGETABLE))
	assert(not (turret is LivingEntity))

func test_destructible_no_implica_living() -> void:
	var crate = ObjectEntity.new(EntityIdentity.new("crate_001", EntityKind.Type.DESTRUCTIBLE_OBJECT))
	crate.add_capability(Entity.CAPABILITY_DESTRUCTIBLE, Destructible.new(Integrity.new(20.0)))
	assert(not (crate is LivingEntity))

func test_faction_no_implica_living() -> void:
	var guard_turret = ObjectEntity.new(EntityIdentity.new("guard_turret_001", EntityKind.Type.TURRET))
	guard_turret.add_capability(Entity.CAPABILITY_FACTION, Faction.new(FactionId.Type.GUARDS))
	assert(not (guard_turret is LivingEntity))

func test_species_no_es_faction() -> void:
	# Species y Faction son ortogonales: un Humano puede pertenecer a la Guardia o ser Renegado,
	# y un Goblinoide pertenece a los Goblins pero podría pertenecer a otra facción.
	var human := Species.new(SpeciesId.Type.HUMANITY, "Humano")
	var guards := Faction.new(FactionId.Type.GUARDS, "Guardia")
	assert(human.get_script() != guards.get_script())
	assert(human.id != guards.id)

func test_targetable_no_es_combattarget() -> void:
	# Targetable aplica a cofres, barriles y puertas para inspección o interacción,
	# sin obligar a involucrar sistemas de combate.
	var chest := ObjectEntity.new(EntityIdentity.new("chest_001", EntityKind.Type.DESTRUCTIBLE_OBJECT))
	chest.add_capability(Entity.CAPABILITY_TARGETABLE, Targetable.new(true, Targetable.Category.OBJECT))
	var targetable: Targetable = chest.get_capability(Entity.CAPABILITY_TARGETABLE)
	assert(targetable.category == Targetable.Category.OBJECT)
	assert(not chest.has_capability(Entity.CAPABILITY_DESTRUCTIBLE)) # No todo targetable es destruible

func test_objeto_puede_tener_faccion_sin_especie() -> void:
	# Objetos inorgánicos como torretas o trampas defensivas pueden pertenecer a una facción
	# sin poseer biología (Species).
	var turret := ObjectEntity.new(EntityIdentity.new("turret_004", EntityKind.Type.TURRET))
	turret.add_capability(Entity.CAPABILITY_FACTION, Faction.new(FactionId.Type.PLAYER_PARTY))
	assert(turret.has_capability(Entity.CAPABILITY_FACTION))
	assert(not turret.has_capability(Entity.CAPABILITY_SPECIES))
