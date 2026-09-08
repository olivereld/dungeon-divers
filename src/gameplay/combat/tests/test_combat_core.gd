extends SceneTree

var rng := RandomNumberGenerator.new()
rng.seed = 12345

func _init() -> void:
	test_guaranteed_hit()
	test_guaranteed_miss()
	test_guaranteed_critical()
	test_guaranteed_normal()
	print("Combat core tests passed.")
	quit()