extends SceneTree

func _init() -> void:
	test_targetable_por_defecto()
	test_no_targetable()
	test_transicion_de_estado()
	test_category()
	print("test_targetable: OK")
	quit()

func test_targetable_por_defecto() -> void:
	assert(Targetable.new().is_targetable())

func test_no_targetable() -> void:
	assert(not Targetable.new(false).is_targetable())

func test_transicion_de_estado() -> void:
	var t := Targetable.new(true)
	t.set_targetable(false)
	assert(not t.is_targetable())
	t.set_targetable(true)
	assert(t.is_targetable())

func test_category() -> void:
	var t_default := Targetable.new()
	assert(t_default.category == Targetable.Category.ANY)

	var t_living := Targetable.new(true, Targetable.Category.LIVING)
	assert(t_living.category == Targetable.Category.LIVING)

	var t_obj := Targetable.new(true, Targetable.Category.OBJECT)
	assert(t_obj.category == Targetable.Category.OBJECT)

	var t_dest := Targetable.new(true, Targetable.Category.DESTRUCTIBLE)
	assert(t_dest.category == Targetable.Category.DESTRUCTIBLE)
