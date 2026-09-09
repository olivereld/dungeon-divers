# test_entity_matrix.gd
# Valida la matriz de composición de capacidades para los 9 EntityKind del dominio.
# Confirma que el modelo de composición soporta todos los arquetipos sin crear subclases
# concretas ni violar la pureza de Entity / LivingEntity / ObjectEntity.
extends SceneTree

func _init() -> void:
	test_player_composition()
	test_npc_composition()
	test_creature_composition()
	test_monster_composition()
	test_summon_composition()
	test_automaton_composition()
	test_turret_composition()
	test_trap_composition()
	test_destructible_object_composition()
	print("test_entity_matrix: OK")
	quit()

func _create_living_stats() -> DerivedStats:
	var base := AttributeSet.new()
	return StatCalculator.calculate_derived_stats(1, base, {})

func test_player_composition() -> void:
	var derived := _create_living_stats()
	var player := LivingEntity.new(
		EntityIdentity.new("player_01", EntityKind.Type.PLAYER, "Valeroso"),
		Health.new(derived.max_hp),
		derived
	)
	player.add_capability(Entity.CAPABILITY_TARGETABLE, Targetable.new(true, Targetable.Category.LIVING))
	player.add_capability(Entity.CAPABILITY_FACTION, Faction.new(FactionId.Type.PLAYER_PARTY, "Grupo de Aventureros"))
	player.add_capability(Entity.CAPABILITY_SPECIES, Species.new(SpeciesId.Type.HUMANITY, "Humano"))

	assert(player is LivingEntity)
	assert(player.is_alive())
	assert(player.has_capability(Entity.CAPABILITY_TARGETABLE))
	assert(player.get_capability(Entity.CAPABILITY_TARGETABLE).category == Targetable.Category.LIVING)
	assert(player.has_capability(Entity.CAPABILITY_FACTION))
	assert(player.has_capability(Entity.CAPABILITY_SPECIES))

func test_npc_composition() -> void:
	var derived := _create_living_stats()
	var npc := LivingEntity.new(
		EntityIdentity.new("npc_01", EntityKind.Type.NPC, "Aldeano Juan"),
		Health.new(derived.max_hp),
		derived
	)
	npc.add_capability(Entity.CAPABILITY_TARGETABLE, Targetable.new(true, Targetable.Category.LIVING))
	npc.add_capability(Entity.CAPABILITY_FACTION, Faction.new(FactionId.Type.VILLAGERS, "Aldeanos"))
	npc.add_capability(Entity.CAPABILITY_SPECIES, Species.new(SpeciesId.Type.HUMANITY, "Humano"))

	assert(npc is LivingEntity)
	assert(npc.has_capability(Entity.CAPABILITY_FACTION))
	assert(npc.has_capability(Entity.CAPABILITY_SPECIES))

func test_creature_composition() -> void:
	var derived := _create_living_stats()
	var wolf := LivingEntity.new(
		EntityIdentity.new("wolf_01", EntityKind.Type.CREATURE, "Lobo Feroz"),
		Health.new(derived.max_hp),
		derived
	)
	wolf.add_capability(Entity.CAPABILITY_TARGETABLE, Targetable.new(true, Targetable.Category.LIVING))
	wolf.add_capability(Entity.CAPABILITY_SPECIES, Species.new(SpeciesId.Type.BEASTS, "Bestia"))

	assert(wolf is LivingEntity)
	assert(wolf.has_capability(Entity.CAPABILITY_SPECIES))
	assert(not wolf.has_capability(Entity.CAPABILITY_FACTION)) # Criatura sin facción política

func test_monster_composition() -> void:
	var derived := _create_living_stats()
	var goblin := LivingEntity.new(
		EntityIdentity.new("goblin_01", EntityKind.Type.MONSTER, "Goblin Lancero"),
		Health.new(derived.max_hp),
		derived
	)
	goblin.add_capability(Entity.CAPABILITY_TARGETABLE, Targetable.new(true, Targetable.Category.LIVING))
	goblin.add_capability(Entity.CAPABILITY_FACTION, Faction.new(FactionId.Type.GOBLINS, "Tribu Goblin"))
	goblin.add_capability(Entity.CAPABILITY_SPECIES, Species.new(SpeciesId.Type.GOBLINOID, "Goblinoide"))

	assert(goblin is LivingEntity)
	assert(goblin.has_capability(Entity.CAPABILITY_FACTION))
	assert(goblin.has_capability(Entity.CAPABILITY_SPECIES))

func test_summon_composition() -> void:
	var derived := _create_living_stats()
	var fire_elemental := LivingEntity.new(
		EntityIdentity.new("elemental_01", EntityKind.Type.SUMMON, "Espíritu de Fuego"),
		Health.new(derived.max_hp),
		derived
	)
	fire_elemental.add_capability(Entity.CAPABILITY_TARGETABLE, Targetable.new(true, Targetable.Category.LIVING))
	fire_elemental.add_capability(Entity.CAPABILITY_FACTION, Faction.new(FactionId.Type.PLAYER_PARTY, "Grupo de Aventureros"))
	fire_elemental.add_capability(Entity.CAPABILITY_SPECIES, Species.new(SpeciesId.Type.ELEMENTAL, "Elemental"))

	assert(fire_elemental is LivingEntity)
	assert(fire_elemental.has_capability(Entity.CAPABILITY_SPECIES))

func test_automaton_composition() -> void:
	var automaton = ObjectEntity.new(EntityIdentity.new("golem_01", EntityKind.Type.AUTOMATON, "Golem de Piedra"))
	automaton.add_capability(Entity.CAPABILITY_DESTRUCTIBLE, Destructible.new(Integrity.new(150.0)))
	automaton.add_capability(Entity.CAPABILITY_TARGETABLE, Targetable.new(true, Targetable.Category.OBJECT))
	automaton.add_capability(Entity.CAPABILITY_AUTOMATED, Automated.new(true))
	automaton.add_capability(Entity.CAPABILITY_FACTION, Faction.new(FactionId.Type.GUARDS, "Guardia Real"))

	assert(automaton is ObjectEntity)
	assert(not (automaton is LivingEntity))
	assert(automaton.has_capability(Entity.CAPABILITY_AUTOMATED))
	assert(not automaton.has_capability(Entity.CAPABILITY_SPECIES)) # No biológico

func test_turret_composition() -> void:
	var turret = ObjectEntity.new(EntityIdentity.new("turret_01", EntityKind.Type.TURRET, "Torreta Centinela"))
	turret.add_capability(Entity.CAPABILITY_DESTRUCTIBLE, Destructible.new(Integrity.new(80.0)))
	turret.add_capability(Entity.CAPABILITY_TARGETABLE, Targetable.new(true, Targetable.Category.OBJECT))
	turret.add_capability(Entity.CAPABILITY_AUTOMATED, Automated.new(true))
	turret.add_capability(Entity.CAPABILITY_FACTION, Faction.new(FactionId.Type.GUARDS, "Guardia Real"))

	assert(turret is ObjectEntity)
	assert(not (turret is LivingEntity))
	assert(not turret.has_capability(Entity.CAPABILITY_SPECIES))

func test_trap_composition() -> void:
	var trap := ObjectEntity.new(EntityIdentity.new("trap_01", EntityKind.Type.TRAP, "Trampa de Espinas"))
	trap.add_capability(Entity.CAPABILITY_DESTRUCTIBLE, Destructible.new(Integrity.new(30.0)))
	trap.add_capability(Entity.CAPABILITY_TRIGGERABLE, Triggerable.new(true))
	trap.add_capability(Entity.CAPABILITY_TARGETABLE, Targetable.new(true, Targetable.Category.OBJECT))

	assert(trap is ObjectEntity)
	assert(trap.has_capability(Entity.CAPABILITY_TRIGGERABLE))
	assert(not trap.has_capability(Entity.CAPABILITY_SPECIES))

func test_destructible_object_composition() -> void:
	var barrel := ObjectEntity.new(EntityIdentity.new("barrel_01", EntityKind.Type.DESTRUCTIBLE_OBJECT, "Barril de Roble"))
	barrel.add_capability(Entity.CAPABILITY_DESTRUCTIBLE, Destructible.new(Integrity.new(25.0)))
	barrel.add_capability(Entity.CAPABILITY_TARGETABLE, Targetable.new(true, Targetable.Category.DESTRUCTIBLE))

	assert(barrel is ObjectEntity)
	assert(barrel.has_capability(Entity.CAPABILITY_DESTRUCTIBLE))
	assert(not barrel.has_capability(Entity.CAPABILITY_SPECIES))
	assert(not barrel.has_capability(Entity.CAPABILITY_FACTION))
