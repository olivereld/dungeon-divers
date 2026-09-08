extends SceneTree

func _init() -> void:
	test_dano_normal()
	test_dano_cero()
	test_sobre_dano()
	test_no_negativos()
	test_destroyed()
	print("test_integrity: OK")
	quit()

func test_dano_normal() -> void:
	var i := Integrity.new(50.0)
	assert(i.apply_damage(20.0) == 20.0)
	assert(i.integrity == 30.0)

func test_dano_cero() -> void:
	var i := Integrity.new(50.0)
	assert(i.apply_damage(0.0) == 0.0)
	assert(i.integrity == 50.0)

func test_sobre_dano() -> void:
	var i := Integrity.new(30.0)
	assert(i.apply_damage(999.0) == 30.0)
	assert(i.integrity == 0.0)

func test_no_negativos() -> void:
	var i := Integrity.new(30.0)
	i.apply_damage(999.0)
	assert(i.integrity >= 0.0)

func test_destroyed() -> void:
	var i := Integrity.new(10.0)
	assert(not i.is_destroyed())
	i.apply_damage(10.0)
	assert(i.is_destroyed())
