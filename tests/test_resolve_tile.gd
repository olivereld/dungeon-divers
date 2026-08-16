extends SceneTree

func _init() -> void:
	print("--- Testing new wall/corner resolution logic ---")

	var resolve_tile = func(n: bool, s: bool, w: bool, e: bool, nw: bool, ne: bool, sw: bool, se: bool) -> Dictionary:
		var rot_0: int = 0
		var rot_90: int = 16
		var rot_180: int = 10
		var rot_270: int = 22
		var wall_idx: int = 1
		var corner_idx: int = 2

		# 1. Outer Corner (Vértice de sala - ningún cardinal es transitable)
		if not n and not s and not w and not e:
			if se and not sw and not ne and not nw: return {"type": "CORNER", "orient": rot_90}
			if sw and not se and not ne and not nw: return {"type": "CORNER", "orient": rot_0}
			if ne and not nw and not se and not sw: return {"type": "CORNER", "orient": rot_180}
			if nw and not ne and not se and not sw: return {"type": "CORNER", "orient": rot_270}
			if se: return {"type": "CORNER", "orient": rot_90}
			if sw: return {"type": "CORNER", "orient": rot_0}
			if ne: return {"type": "CORNER", "orient": rot_180}
			if nw: return {"type": "CORNER", "orient": rot_270}
			return {"type": "WALL", "orient": rot_0}

		# 2. Si solo tiene 1 dirección cardinal transitable -> Muro Recto directo
		var cardinal_count: int = (1 if n else 0) + (1 if s else 0) + (1 if w else 0) + (1 if e else 0)
		if cardinal_count == 1:
			if n or s:
				return {"type": "WALL", "orient": rot_0}
			else:
				return {"type": "WALL", "orient": rot_90}

		# 3. Si tiene 2 direcciones cardinales opuestas transitables (ej. N y S en un muro delgado o pasillo)
		if (n and s) and not w and not e:
			return {"type": "WALL", "orient": rot_0}
		if (w and e) and not n and not s:
			return {"type": "WALL", "orient": rot_90}

		# 4. Si tiene 2 direcciones adyacentes transitables (ej. S y E)
		# Si una de las direcciones es una pared continua (ej. en una puerta, donde la pared continúa al Oeste):
		# Al lado de una puerta en pared horizontal: s=floor, e=door, pero w=wall y n=wall -> la pared es horizontal!
		if (s or n) and (w != e):
			# Si tiene continuidad horizontal (w o e es pared sólida)
			if (s and not n) or (n and not s):
				return {"type": "WALL", "orient": rot_0}

		if (w or e) and (n != s):
			# Si tiene continuidad vertical (n o s es pared sólida)
			if (w and not e) or (e and not w):
				return {"type": "WALL", "orient": rot_90}

		# 5. Esquinas interiores (L-turns genuinos)
		if s and e: return {"type": "CORNER", "orient": rot_90}
		if n and e: return {"type": "CORNER", "orient": rot_180}
		if n and w: return {"type": "CORNER", "orient": rot_270}
		if s and w: return {"type": "CORNER", "orient": rot_0}

		return {"type": "WALL", "orient": rot_0}

	# Test Cases:
	# A. North wall straight: s=true, others=false, sw=true, se=true
	var res_straight = resolve_tile.call(false, true, false, false, false, false, true, true)
	print("Room North Wall: ", res_straight)
	assert(res_straight["type"] == "WALL" and res_straight["orient"] == 0)

	# B. Top-Left outer corner: all cardinal=false, se=true
	var res_tl_corner = resolve_tile.call(false, false, false, false, false, false, false, true)
	print("Top-Left Outer Corner: ", res_tl_corner)
	assert(res_tl_corner["type"] == "CORNER" and res_tl_corner["orient"] == 16)

	# C. Left of door on North wall: s=true (floor), e=true (door), w=false (wall continues), n=false (outside)
	var res_door_left = resolve_tile.call(false, true, false, true, false, false, true, true)
	print("Left of Door on North Wall: ", res_door_left)
	assert(res_door_left["type"] == "WALL" and res_door_left["orient"] == 0)

	# D. Right of door on North wall: s=true (floor), w=true (door), e=false (wall continues), n=false (outside)
	var res_door_right = resolve_tile.call(false, true, true, false, false, false, true, true)
	print("Right of Door on North Wall: ", res_door_right)
	assert(res_door_right["type"] == "WALL" and res_door_right["orient"] == 0)

	# E. Vertical corridor wall: e=true (corridor), n=false, s=false, w=false
	var res_corridor_v = resolve_tile.call(false, false, false, true, false, false, false, false)
	print("Vertical Corridor Left Wall: ", res_corridor_v)
	assert(res_corridor_v["type"] == "WALL" and res_corridor_v["orient"] == 16)

	# F. Horizontal corridor wall: s=true (corridor), n=false, w=false, e=false
	var res_corridor_h = resolve_tile.call(false, true, false, false, false, false, false, false)
	print("Horizontal Corridor Top Wall: ", res_corridor_h)
	assert(res_corridor_h["type"] == "WALL" and res_corridor_h["orient"] == 0)

	print("\nALL TEST CASES PASSED PERFECTLY!")
	quit(0)
