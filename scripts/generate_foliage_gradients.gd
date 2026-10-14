extends SceneTree

func _init() -> void:
	print("Generating botanical foliage gradient textures...")
	_generate_gradient("res://assets/texture/foliage/flowers/flower_gradient_lavender.png", [
		{"pos": 0.00, "col": Color("#8a50a6")}, # Pétalo lavanda/violeta
		{"pos": 0.25, "col": Color("#ba7ed6")}, # Tono lila brillante
		{"pos": 0.45, "col": Color("#cfc153")}, # Centro/estambres dorado
		{"pos": 0.55, "col": Color("#4d692b")}, # Sépalos/cáliz verde cálido
		{"pos": 0.80, "col": Color("#354b1f")}, # Tallo verde bosque
		{"pos": 1.00, "col": Color("#222f16")}  # Base terrosa
	])

	_generate_gradient("res://assets/texture/foliage/flowers/flower_gradient_poppy.png", [
		{"pos": 0.00, "col": Color("#d43d1a")}, # Pétalo rojo amapola
		{"pos": 0.25, "col": Color("#ea6520")}, # Borde naranja vivo
		{"pos": 0.42, "col": Color("#ffe140")}, # Centro dorado
		{"pos": 0.55, "col": Color("#546927")}, # Tallo superior
		{"pos": 0.80, "col": Color("#3a4e1b")}, # Tallo verde oliva
		{"pos": 1.00, "col": Color("#202c11")}  # Raíz / suelo
	])

	_generate_gradient("res://assets/texture/foliage/flowers/flower_gradient_daisy.png", [
		{"pos": 0.00, "col": Color("#f4f0e4")}, # Pétalo blanco marfil
		{"pos": 0.25, "col": Color("#fdf9eb")}, # Pétalo crema
		{"pos": 0.42, "col": Color("#e8b323")}, # Botón central amarillo dorado
		{"pos": 0.55, "col": Color("#5f782c")}, # Cáliz
		{"pos": 0.80, "col": Color("#42591e")}, # Tallo
		{"pos": 1.00, "col": Color("#263612")}  # Base
	])

	_generate_gradient("res://assets/texture/foliage/mushrooms/mushroom_gradient_amanita.png", [
		{"pos": 0.00, "col": Color("#ba1c11")}, # Sombrero rojo amanita escarlata
		{"pos": 0.20, "col": Color("#e03a18")}, # Sombrero rojo bermellón brillante
		{"pos": 0.38, "col": Color("#eb6028")}, # Borde sombrero anaranjado
		{"pos": 0.45, "col": Color("#f0ede1")}, # Láminas / anillo blanco crema
		{"pos": 0.70, "col": Color("#e6e0cf")}, # Estipe / tallo marfil
		{"pos": 1.00, "col": Color("#4a3c2c")}  # Volva / micelio terroso
	])

	_generate_gradient("res://assets/texture/foliage/mushrooms/mushroom_gradient_boletus.png", [
		{"pos": 0.00, "col": Color("#72411e")}, # Sombrero marrón boletus castaño
		{"pos": 0.22, "col": Color("#8a542a")}, # Sombrero castaño dorado
		{"pos": 0.40, "col": Color("#b3854b")}, # Poros / esponja marrón claro
		{"pos": 0.55, "col": Color("#ded3b8")}, # Tallo beige crema
		{"pos": 0.80, "col": Color("#c4b79b")}, # Base tallo engrosada
		{"pos": 1.00, "col": Color("#221810")}  # Humus del mantillo oscuro
	])

	_generate_gradient("res://assets/texture/foliage/mushrooms/mushroom_gradient_chanterelle.png", [
		{"pos": 0.00, "col": Color("#e69612")}, # Sombrero rebozuelo amarillo yema
		{"pos": 0.25, "col": Color("#f5b027")}, # Sombrero oro brillante
		{"pos": 0.45, "col": Color("#f0aa24")}, # Pliegues himenio anaranjado
		{"pos": 0.70, "col": Color("#db9021")}, # Pie albaricoque
		{"pos": 1.00, "col": Color("#4d3a22")}  # Base terrosa
	])

	print("Gradient textures generated successfully!")
	quit(0)

func _generate_gradient(dest_path: String, stops: Array) -> void:
	var w := 512
	var h := 512
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)

	for y in range(h):
		var v: float = float(y) / float(h - 1) # 0 en punta (árbol/flor/sombrero), 1 en base
		var base_col: Color = _sample_stops(stops, v)

		for x in range(w):
			var u: float = float(x) / float(w - 1)
			# Variación horizontal suave de tinte para matizar clusters orgánicos por coordenadas
			var u_var: float = (u - 0.5) * 0.16
			var final_col: Color = base_col
			final_col.r = clampf(final_col.r + u_var * 0.6, 0.0, 1.0)
			final_col.g = clampf(final_col.g + u_var * 0.4, 0.0, 1.0)
			final_col.b = clampf(final_col.b - u_var * 0.3, 0.0, 1.0)
			img.set_pixel(x, y, final_col)

	var global_path: String = ProjectSettings.globalize_path(dest_path)
	var dir_path: String = global_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var err: Error = img.save_png(global_path)
	assert(err == OK, "Failed to save PNG to %s, error code: %d" % [dest_path, err])
	print("Saved %s" % dest_path)

func _sample_stops(stops: Array, t: float) -> Color:
	if stops.is_empty():
		return Color.WHITE
	if t <= stops[0].pos:
		return stops[0].col
	if t >= stops[stops.size() - 1].pos:
		return stops[stops.size() - 1].col

	for i in range(stops.size() - 1):
		var s0 = stops[i]
		var s1 = stops[i + 1]
		if t >= s0.pos and t <= s1.pos:
			var range_len: float = s1.pos - s0.pos
			var local_t: float = (t - s0.pos) / maxf(range_len, 0.0001)
			return s0.col.lerp(s1.col, local_t)

	return stops[stops.size() - 1].col
