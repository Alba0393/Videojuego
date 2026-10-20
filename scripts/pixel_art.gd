class_name PixelArt
extends RefCounted

## Generador de pixel art en tiempo de ejecución.
##
## Cada pose se describe como un conjunto de rectángulos en una rejilla de
## 16x25 píxeles. Se dibujan sobre una `Image`, se le añade un contorno
## automático y se convierte en `ImageTexture` (con filtro nearest desde el
## Sprite2D). No se usa ningún archivo de imagen.

const W: int = 16
const H: int = 25
const PIXEL_SCALE: float = 4.0

## Orden de dibujo de las partes (de atrás hacia delante).
const DRAW_ORDER := ["arm_b", "leg_b", "foot_b", "leg_f", "foot_f", "torso", "belt", "arm_f", "head", "hair", "eye"]

static var _cache: Dictionary = {}


## Devuelve (y cachea) la textura de una pose para una paleta dada.
static func get_texture(pose: String, palette_id: int) -> ImageTexture:
	var key := "%s#%d" % [pose, palette_id]
	if _cache.has(key):
		return _cache[key]
	var img := _build(pose, palette_id)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


# ---------------------------------------------------------------------------
# Paletas
# ---------------------------------------------------------------------------
static func _palette(palette_id: int) -> Dictionary:
	if palette_id == 2:
		return {
			"outline": Color(0.07, 0.07, 0.12),
			"skin": Color(0.94, 0.78, 0.64),
			"hair": Color(0.12, 0.10, 0.20),
			"eye": Color(0.10, 0.10, 0.15),
			"shirt": Color(0.28, 0.48, 0.92),
			"shirt_dark": Color(0.18, 0.30, 0.65),
			"belt": Color(0.20, 0.22, 0.32),
			"pants": Color(0.20, 0.22, 0.34),
			"boots": Color(0.14, 0.14, 0.20),
			"accent": Color(0.62, 0.86, 1.0),
		}
	return {
		"outline": Color(0.10, 0.06, 0.07),
		"skin": Color(0.96, 0.80, 0.66),
		"hair": Color(0.22, 0.14, 0.12),
		"eye": Color(0.10, 0.10, 0.15),
		"shirt": Color(0.85, 0.25, 0.30),
		"shirt_dark": Color(0.60, 0.16, 0.22),
		"belt": Color(0.28, 0.28, 0.38),
		"pants": Color(0.22, 0.24, 0.36),
		"boots": Color(0.16, 0.16, 0.22),
		"accent": Color(1.0, 0.90, 0.45),
	}


# ---------------------------------------------------------------------------
# Poses base
# ---------------------------------------------------------------------------
static func _stand() -> Dictionary:
	return {
		"head": [6, 3, 4, 4, "skin"],
		"hair": [6, 2, 4, 2, "hair"],
		"eye": [9, 4, 1, 1, "eye"],
		"torso": [5, 7, 6, 8, "shirt"],
		"belt": [5, 14, 6, 1, "belt"],
		"arm_b": [4, 8, 2, 5, "shirt_dark"],
		"arm_f": [10, 8, 2, 5, "skin"],
		"leg_b": [5, 15, 2, 7, "pants"],
		"leg_f": [8, 15, 2, 7, "pants"],
		"foot_b": [4, 22, 3, 2, "boots"],
		"foot_f": [7, 22, 3, 2, "boots"],
	}


static func _air() -> Dictionary:
	var p := _stand()
	p["head"] = [6, 2, 4, 4, "skin"]
	p["hair"] = [6, 1, 4, 2, "hair"]
	p["eye"] = [9, 3, 1, 1, "eye"]
	p["torso"] = [5, 6, 6, 8, "shirt"]
	p["belt"] = [5, 13, 6, 1, "belt"]
	p["arm_b"] = [4, 7, 2, 5, "shirt_dark"]
	p["arm_f"] = [10, 7, 2, 5, "skin"]
	p["leg_b"] = [6, 14, 2, 5, "pants"]
	p["leg_f"] = [9, 14, 2, 5, "pants"]
	p["foot_b"] = [5, 18, 3, 2, "boots"]
	p["foot_f"] = [8, 18, 3, 2, "boots"]
	return p


static func _merged(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for key in overrides:
		out[key] = overrides[key]
	return out


# ---------------------------------------------------------------------------
# Definición de todas las poses
# ---------------------------------------------------------------------------
static func _pose(pose: String) -> Dictionary:
	match pose:
		"idle_0":
			return _stand()
		"idle_1":
			return _merged(_stand(), {
				"head": [6, 4, 4, 4, "skin"], "hair": [6, 3, 4, 2, "hair"], "eye": [9, 5, 1, 1, "eye"],
				"arm_b": [4, 9, 2, 5, "shirt_dark"], "arm_f": [10, 9, 2, 5, "skin"],
			})
		"walk_0":
			return _stand()
		"walk_1":
			return _merged(_stand(), {
				"leg_f": [10, 15, 2, 6, "pants"], "foot_f": [10, 21, 3, 2, "boots"],
				"leg_b": [4, 16, 2, 6, "pants"], "foot_b": [3, 22, 3, 2, "boots"],
				"arm_f": [11, 8, 2, 5, "skin"], "arm_b": [3, 9, 2, 5, "shirt_dark"],
			})
		"walk_2":
			return _merged(_stand(), {
				"leg_f": [8, 16, 2, 6, "pants"], "foot_f": [7, 22, 3, 2, "boots"],
				"leg_b": [6, 15, 2, 7, "pants"], "foot_b": [5, 22, 3, 2, "boots"],
			})
		"walk_3":
			return _merged(_stand(), {
				"leg_f": [5, 16, 2, 6, "pants"], "foot_f": [4, 22, 3, 2, "boots"],
				"leg_b": [9, 15, 2, 6, "pants"], "foot_b": [9, 21, 3, 2, "boots"],
				"arm_f": [9, 9, 2, 5, "skin"], "arm_b": [5, 8, 2, 5, "shirt_dark"],
			})
		"jump":
			return _merged(_air(), {
				"arm_f": [10, 3, 2, 6, "skin"], "arm_b": [4, 3, 2, 6, "shirt_dark"],
			})
		"fall":
			return _merged(_air(), {
				"arm_f": [11, 8, 2, 4, "skin"], "arm_b": [3, 8, 2, 4, "shirt_dark"],
				"leg_f": [8, 15, 2, 5, "pants"], "leg_b": [5, 15, 2, 5, "pants"],
			})
		"crouch":
			return {
				"head": [6, 9, 4, 4, "skin"], "hair": [6, 8, 4, 2, "hair"], "eye": [9, 10, 1, 1, "eye"],
				"torso": [5, 13, 6, 5, "shirt"], "belt": [5, 17, 6, 1, "belt"],
				"arm_b": [4, 14, 2, 4, "shirt_dark"], "arm_f": [10, 14, 2, 4, "skin"],
				"leg_b": [5, 18, 2, 4, "pants"], "leg_f": [8, 18, 2, 4, "pants"],
				"foot_b": [4, 22, 3, 2, "boots"], "foot_f": [7, 22, 3, 2, "boots"],
			}
		"dash":
			return _merged(_stand(), {
				"head": [7, 3, 4, 4, "skin"], "hair": [7, 2, 4, 2, "hair"], "eye": [10, 4, 1, 1, "eye"],
				"torso": [6, 7, 6, 8, "shirt"], "belt": [6, 14, 6, 1, "belt"],
				"arm_b": [4, 8, 2, 4, "shirt_dark"], "arm_f": [11, 9, 4, 2, "skin"],
				"leg_b": [4, 15, 2, 7, "pants"], "leg_f": [9, 15, 2, 7, "pants"],
				"foot_b": [2, 22, 3, 2, "boots"], "foot_f": [10, 22, 3, 2, "boots"],
			})
		"block_ground":
			return _merged(_stand(), {
				"arm_f": [10, 7, 3, 8, "shirt_dark"],
				"fx": [[11, 8, 2, 6, "skin"]],
			})
		"block_air":
			return _merged(_air(), {
				"arm_f": [10, 6, 3, 8, "shirt_dark"],
				"fx": [[11, 7, 2, 6, "skin"]],
			})
		"hurt":
			return _merged(_stand(), {
				"head": [4, 4, 4, 4, "skin"], "hair": [4, 3, 4, 2, "hair"], "eye": [5, 5, 1, 1, "eye"],
				"torso": [4, 8, 6, 8, "shirt"], "belt": [4, 15, 6, 1, "belt"],
				"arm_b": [2, 9, 2, 5, "shirt_dark"], "arm_f": [9, 9, 2, 3, "skin"],
				"fx": [[11, 9, 2, 2, "skin"]],
				"leg_b": [5, 16, 2, 7, "pants"], "leg_f": [8, 16, 2, 7, "pants"],
				"foot_b": [4, 22, 3, 2, "boots"], "foot_f": [7, 22, 3, 2, "boots"],
			})
		"ko":
			return {
				"torso": [5, 20, 7, 4, "shirt"], "belt": [11, 20, 1, 4, "belt"],
				"head": [1, 19, 4, 4, "skin"], "hair": [1, 18, 4, 2, "hair"],
				"arm_b": [5, 24, 3, 1, "shirt_dark"], "arm_f": [6, 18, 3, 2, "skin"],
				"leg_b": [12, 19, 3, 3, "pants"], "leg_f": [12, 22, 3, 3, "pants"],
				"foot_b": [14, 22, 2, 2, "boots"], "foot_f": [14, 19, 2, 2, "boots"],
			}

		# --- Ataques de tierra ---
		"light":
			return _merged(_stand(), {
				"arm_f": [10, 9, 2, 3, "skin"],
				"fx": [[12, 9, 4, 2, "skin"], [15, 9, 1, 2, "accent"]],
			})
		"medium":
			return _merged(_stand(), {
				"leg_f": [9, 13, 2, 3, "pants"], "foot_f": [15, 13, 2, 2, "boots"],
				"fx": [[11, 13, 4, 3, "pants"], [14, 12, 1, 2, "accent"]],
			})
		"heavy":
			return _merged(_stand(), {
				"head": [6, 4, 4, 4, "skin"], "hair": [6, 3, 4, 2, "hair"], "eye": [9, 5, 1, 1, "eye"],
				"arm_f": [10, 6, 2, 3, "skin"],
				"fx": [[12, 6, 4, 3, "skin"], [15, 5, 1, 4, "accent"]],
			})
		"special":
			return _merged(_stand(), {
				"head": [6, 4, 4, 4, "skin"], "hair": [6, 3, 4, 2, "hair"], "eye": [9, 5, 1, 1, "eye"],
				"arm_f": [10, 1, 2, 7, "skin"],
				"fx": [[10, 1, 3, 2, "accent"], [9, 0, 5, 1, "accent"]],
			})

		# --- Ataques aéreos ---
		"air_light":
			return _merged(_air(), {
				"arm_f": [10, 8, 2, 3, "skin"],
				"fx": [[12, 8, 4, 2, "skin"], [15, 8, 1, 2, "accent"]],
			})
		"air_medium":
			return _merged(_air(), {
				"leg_f": [9, 12, 2, 3, "pants"], "foot_f": [15, 12, 2, 2, "boots"],
				"fx": [[11, 12, 4, 3, "pants"], [14, 11, 1, 2, "accent"]],
			})
		"air_heavy":
			return _merged(_air(), {
				"arm_f": [10, 5, 2, 3, "skin"],
				"fx": [[12, 5, 4, 3, "skin"], [15, 4, 1, 4, "accent"]],
			})
		"air_special":
			return _merged(_air(), {
				"arm_f": [9, 16, 2, 3, "skin"],
				"fx": [[9, 19, 4, 2, "skin"], [10, 21, 2, 2, "accent"]],
			})

	return _stand()


# ---------------------------------------------------------------------------
# Render
# ---------------------------------------------------------------------------
static func _build(pose: String, palette_id: int) -> Image:
	var pal := _palette(palette_id)
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var parts: Dictionary = _pose(pose)
	for key in DRAW_ORDER:
		if parts.has(key):
			_draw_rect(img, parts[key], pal)
	if parts.has("fx"):
		for rect in parts["fx"]:
			_draw_rect(img, rect, pal)

	_add_outline(img, pal["outline"])
	return img


static func _draw_rect(img: Image, rect: Array, pal: Dictionary) -> void:
	var x: int = rect[0]
	var y: int = rect[1]
	var w: int = rect[2]
	var h: int = rect[3]
	var color: Color = pal.get(rect[4], Color(1, 0, 1))
	for py in range(y, y + h):
		for px in range(x, x + w):
			if px >= 0 and px < W and py >= 0 and py < H:
				img.set_pixel(px, py, color)


## Añade un contorno de 1 píxel alrededor de la silueta.
static func _add_outline(img: Image, color: Color) -> void:
	var occupied: Array = []
	occupied.resize(W * H)
	for y in H:
		for x in W:
			occupied[y * W + x] = img.get_pixel(x, y).a > 0.01

	var neighbors := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in H:
		for x in W:
			if occupied[y * W + x]:
				continue
			for d in neighbors:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or nx >= W or ny < 0 or ny >= H:
					continue
				if occupied[ny * W + nx]:
					img.set_pixel(x, y, color)
					break
