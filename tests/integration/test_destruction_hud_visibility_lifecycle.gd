extends SceneTree

const _ControllerScript = preload("res://scenes/dungeon/dungeon_level_controller.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_hud_visibility_lifecycle ---")
	print("==================================================================")
	var ctrl = _ControllerScript.new()
	ctrl.name = "DungeonLevelControllerTest"
	root.add_child(ctrl)
	await process_frame

	var hud = ctrl.get_node_or_null("DestructionDebugHUD") as CanvasLayer
	var interactor = ctrl.get_node_or_null("DestructionDebugInteractor")
	assert(hud != null, "FAIL: DestructionDebugHUD must exist")
	assert(interactor != null, "FAIL: DestructionDebugInteractor must exist")

	# 1. En estado inicial (2D Preview / READY_2D) debe estar OCULTO y DESACTIVADO
	print("[Test] Verificando estado en 2D Preview...")
	assert(hud.visible == false, "FAIL: DestructionDebugHUD must be hidden in 2D preview mode")
	assert(interactor.enabled == false, "FAIL: DestructionDebugInteractor must be disabled in 2D preview mode")
	print("   [OK] HUD oculto e Interactor deshabilitado en 2D.")

	# 2. Al materializar 3D (READY_3D) debe hacerse VISIBLE y ACTIVO
	print("[Test] Materializando 3D...")
	ctrl.build_3d_presentation()
	await process_frame

	assert(hud.visible == true, "FAIL: DestructionDebugHUD must be visible in 3D presentation mode")
	assert(interactor.enabled == true, "FAIL: DestructionDebugInteractor must be enabled in 3D presentation mode")
	print("   [OK] HUD visible e Interactor habilitado en 3D.")

	# 3. Al conmutar de regreso a 2D debe volver a OCULTARSE
	print("[Test] Conmutando a vista 2D...")
	if ctrl.visualizer != null:
		ctrl.visualizer.is_2d_preview_mode = true
	ctrl._on_toggle_2d_view_requested()
	await process_frame

	assert(hud.visible == false, "FAIL: DestructionDebugHUD must be hidden when toggling back to 2D")
	assert(interactor.enabled == false, "FAIL: DestructionDebugInteractor must be disabled when toggling back to 2D")
	print("   [OK] HUD oculto nuevamente en 2D.")

	ctrl.free()
	print("[PASS] test_destruction_hud_visibility_lifecycle passed 100%!")
	print("==================================================================")
	quit(0)
