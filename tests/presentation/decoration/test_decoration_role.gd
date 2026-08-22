extends SceneTree

const DecorationRoleScript = preload("res://src/presentation/decoration/decoration_role.gd")
const PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_decoration_role ---")
	print("==================================================================")

	# 1. Test Roles enum
	assert(DecorationRoleScript.Role.FOCAL == 0)
	assert(DecorationRoleScript.Role.SUPPORT == 1)
	assert(DecorationRoleScript.Role.AMBIENT == 2)
	assert(DecorationRoleScript.Role.FUNCTIONAL == 3)

	assert(DecorationRoleScript.role_to_name(DecorationRoleScript.Role.FOCAL) == "FOCAL")
	assert(DecorationRoleScript.role_to_name(DecorationRoleScript.Role.SUPPORT) == "SUPPORT")
	assert(DecorationRoleScript.role_to_name(DecorationRoleScript.Role.AMBIENT) == "AMBIENT")
	assert(DecorationRoleScript.role_to_name(DecorationRoleScript.Role.FUNCTIONAL) == "FUNCTIONAL")

	assert(DecorationRoleScript.name_to_role("focal") == DecorationRoleScript.Role.FOCAL)
	assert(DecorationRoleScript.name_to_role("ambient") == DecorationRoleScript.Role.AMBIENT)
	print("  [OK] DecorationRole contract and helpers verified.")

	# 2. Test PropStyle with Role
	var s_focal := PropStyleScript.new(
		&"sarc", PropStyleScript.Type.SARCOPHAGUS, PropPlacementModeScript.Mode.CENTER,
		1, null, &"sarcophagus_prop", {}, DecorationRoleScript.Role.FOCAL
	)
	assert(s_focal.role == DecorationRoleScript.Role.FOCAL)

	var s_support := PropStyleScript.new(
		&"pew", PropStyleScript.Type.BENCH, PropPlacementModeScript.Mode.WALL,
		1, null, &"bench_prop", {}, DecorationRoleScript.Role.SUPPORT
	)
	assert(s_support.role == DecorationRoleScript.Role.SUPPORT)
	print("  [OK] PropStyle role assignment verified.")

	print("[PASS] test_decoration_role completed successfully!")
	quit(0)
