# test_species.gd
# Valida el componente Species y su integración como capacidad opcional en Entity.
extends SceneTree

func _init() -> void:
	test_species_creacion_y_propiedades()
	test_is_same_species()
	test_species_como_capacidad_en_entidad_viva()
	test_entidad_objeto_no_requiere_species()
	print("test_species: OK")
	quit()

func test_species_creacion_y_propiedades() -> void:
	var species := Species.new(SpeciesId.Type.HUMANITY, "Humano")
	assert(species.id == SpeciesId.Type.HUMANITY)
	assert(species.display_name == "Humano")

func test_is_same_species() -> void:
	var human1 := Species.new(SpeciesId.Type.HUMANITY, "Humano 1")
	var human2 := Species.new(SpeciesId.Type.HUMANITY, "Humano 2")
	var orc := Species.new(SpeciesId.Type.ORCOID, "Orco")

	assert(human1.is_same_species(human2))
	assert(not human1.is_same_species(orc))
	assert(not human1.is_same_species(null))

func test_species_como_capacidad_en_entidad_viva() -> void:
	var identity := EntityIdentity.new("player_001", EntityKind.Type.PLAYER, "Hero")
	var base := AttributeSet.new()
	var derived := StatCalculator.calculate_derived_stats(1, base, {})
	var player := LivingEntity.new(identity, Health.new(derived.max_hp), derived)

	assert(not player.has_capability(Entity.CAPABILITY_SPECIES))
	player.add_capability(Entity.CAPABILITY_SPECIES, Species.new(SpeciesId.Type.HUMANITY, "Humano"))

	assert(player.has_capability(Entity.CAPABILITY_SPECIES))
	var sp: Species = player.get_capability(Entity.CAPABILITY_SPECIES)
	assert(sp != null)
	assert(sp.id == SpeciesId.Type.HUMANITY)

func test_entidad_objeto_no_requiere_species() -> void:
	var turret := ObjectEntity.new(EntityIdentity.new("turret_001", EntityKind.Type.TURRET, "Torreta Arcana"))
	assert(not turret.has_capability(Entity.CAPABILITY_SPECIES))
	assert(turret.try_get_capability(Entity.CAPABILITY_SPECIES) == null)
