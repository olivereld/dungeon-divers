extends SceneTree

## Herramienta para renderizar y guardar una captura visual del showcase de rocas.
## Guarda la imagen directamente en el directorio de artefactos para inspección inmediata.

const ShowcaseScript = preload("res://src/rock_generation/scenes/rock_showcase.gd")
const OUTPUT_PATH: String = "C:/Users/olivereld/.gemini/antigravity-ide/brain/697086af-3400-4cff-85fb-a4e76ebe1a79/rock_showcase_render.png"

var _frames_waited: int = 0
var _viewport: SubViewport = null

func _init() -> void:
	print("--- Iniciando renderizado de Rock Showcase ---")
	var root_window: Window = root
	root_window.size = Vector2i(1280, 720)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root_window.add_child(_viewport)

	var showcase_node: Node3D = Node3D.new()
	showcase_node.set_script(ShowcaseScript)
	_viewport.add_child(showcase_node)

func _process(delta: float) -> bool:
	_frames_waited += 1
	if _frames_waited >= 10:
		var img: Image = _viewport.get_texture().get_image()
		if img != null and not img.is_empty():
			var err: Error = img.save_png(OUTPUT_PATH)
			if err == OK:
				print("Captura guardada exitosamente en: ", OUTPUT_PATH)
			else:
				printerr("Error al guardar la imagen PNG: ", err)
		else:
			printerr("La textura del viewport retornó una imagen vacía o nula.")
		quit(0)
		return true
	return false
