class_name MoveLibrary
extends RefCounted

## Biblioteca central de movimientos. Se construye una sola vez de forma
## perezosa y se consulta con `MoveLibrary.get_move(id)`.
##
## Tabla de diseño (a 60 fps):
##   Ligero   → rápido, poco daño, mucha ventana para encadenar.
##   Medio    → más alcance y daño, encadena sobre todo a pesado/especial.
##   Pesado   → lento y castigable, gran daño y derribo.
##   Especial → finisher lanzadera con invulnerabilidad breve al inicio.

static var _moves: Dictionary = {}


static func get_move(id: String) -> MoveData:
	if _moves.is_empty():
		_build()
	return _moves.get(id)


static func has(id: String) -> bool:
	if _moves.is_empty():
		_build()
	return _moves.has(id)


static func _mk(cfg: Dictionary) -> MoveData:
	var m := MoveData.new()
	for key in cfg:
		m.set(key, cfg[key])
	return m


static func _build() -> void:
	# ---------------------------------------------------------------- TIERRA
	_moves["light"] = _mk({
		"id": "light", "display_name": "Jab", "kind": "light",
		"damage": 5.0, "startup": 0.050, "active": 0.050, "recovery": 0.100,
		"hitbox_size": Vector2(54.0, 34.0), "hitbox_offset": Vector2(40.0, -14.0),
		"hitstun": 0.20, "blockstun": 0.10, "hitstop": 2, "block_hitstop": 1,
		"knockback": Vector2(150.0, -70.0),
		"chain_into": PackedStringArray(["light", "medium", "heavy", "special", "low_kick"]),
		"max_chains": 2,
		"slash_color": Color(1.0, 0.95, 0.55, 0.85), "slash_rotation": -0.35,
	})

	_moves["medium"] = _mk({
		"id": "medium", "display_name": "Patada media", "kind": "medium",
		"damage": 10.0, "startup": 0.117, "active": 0.083, "recovery": 0.200,
		"hitbox_size": Vector2(78.0, 40.0), "hitbox_offset": Vector2(54.0, -10.0),
		"hitstun": 0.28, "blockstun": 0.16, "hitstop": 3, "block_hitstop": 2,
		"knockback": Vector2(230.0, -100.0),
		"chain_into": PackedStringArray(["heavy", "special", "advancing_blow"]),
		"max_chains": 1,
		"slash_color": Color(1.0, 0.68, 0.25, 0.85), "slash_rotation": -0.15,
	})

	_moves["heavy"] = _mk({
		"id": "heavy", "display_name": "Golpe pesado", "kind": "heavy",
		"damage": 18.0, "startup": 0.217, "active": 0.100, "recovery": 0.367,
		"hitbox_size": Vector2(84.0, 54.0), "hitbox_offset": Vector2(54.0, -16.0),
		"hitstun": 0.40, "blockstun": 0.217, "hitstop": 5, "block_hitstop": 2,
		"knockback": Vector2(360.0, -230.0),
		"chain_into": PackedStringArray(["special"]),
		"max_chains": 1,
		"slash_color": Color(1.0, 0.35, 0.2, 0.9), "slash_rotation": -0.05,
	})

	_moves["special"] = _mk({
		"id": "special", "display_name": "Golpe ascendente", "kind": "special",
		"damage": 24.0, "startup": 0.300, "active": 0.133, "recovery": 0.500,
		"hitbox_size": Vector2(80.0, 70.0), "hitbox_offset": Vector2(48.0, -30.0),
		"hitstun": 0.50, "blockstun": 0.267, "hitstop": 6, "block_hitstop": 3,
		"knockback": Vector2(170.0, -560.0), "launcher": true, "invuln": 0.066,
		"chain_into": PackedStringArray(), "max_chains": 0, "is_ender": true,
		"slash_color": Color(0.8, 0.45, 1.0, 0.9), "slash_rotation": -1.1,
	})

	_moves["low_kick"] = _mk({
		"id": "low_kick", "display_name": "Patada baja", "kind": "medium",
		"damage": 9.0, "startup": 0.130, "active": 0.083, "recovery": 0.250,
		"hitbox_size": Vector2(66.0, 24.0), "hitbox_offset": Vector2(48.0, 22.0),
		"hitstun": 0.26, "blockstun": 0.18, "hitstop": 3, "block_hitstop": 2,
		"knockback": Vector2(170.0, -60.0),
		"chain_into": PackedStringArray(["special"]),
		"max_chains": 1,
		"slash_color": Color(1.0, 0.6, 0.2, 0.85), "slash_rotation": 0.2,
	})

	_moves["advancing_blow"] = _mk({
		"id": "advancing_blow", "display_name": "Embestida", "kind": "heavy",
		"damage": 20.0, "startup": 0.200, "active": 0.100, "recovery": 0.320,
		"hitbox_size": Vector2(80.0, 44.0), "hitbox_offset": Vector2(60.0, -10.0),
		"hitstun": 0.40, "blockstun": 0.22, "hitstop": 5, "block_hitstop": 2,
		"knockback": Vector2(430.0, -190.0), "momentum": 280.0,
		"chain_into": PackedStringArray(["special"]),
		"max_chains": 1,
		"slash_color": Color(1.0, 0.4, 0.25, 0.9), "slash_rotation": 0.0,
	})

	# ---------------------------------------------------------------- AIRE
	_moves["air_light"] = _mk({
		"id": "air_light", "display_name": "Jab aéreo", "kind": "light", "airborne": true,
		"damage": 4.0, "startup": 0.050, "active": 0.060, "recovery": 0.120,
		"hitbox_size": Vector2(56.0, 30.0), "hitbox_offset": Vector2(40.0, 6.0),
		"hitstun": 0.18, "blockstun": 0.10, "hitstop": 2, "block_hitstop": 1,
		"knockback": Vector2(110.0, -40.0),
		"chain_into": PackedStringArray(["air_light", "air_medium", "air_heavy", "air_special"]),
		"max_chains": 2,
		"slash_color": Color(1.0, 0.95, 0.55, 0.85), "slash_rotation": 0.2,
	})

	_moves["air_medium"] = _mk({
		"id": "air_medium", "display_name": "Patada aérea", "kind": "medium", "airborne": true,
		"damage": 8.0, "startup": 0.100, "active": 0.080, "recovery": 0.180,
		"hitbox_size": Vector2(70.0, 40.0), "hitbox_offset": Vector2(46.0, 10.0),
		"hitstun": 0.24, "blockstun": 0.14, "hitstop": 3, "block_hitstop": 2,
		"knockback": Vector2(150.0, -30.0),
		"chain_into": PackedStringArray(["air_heavy", "air_special"]),
		"max_chains": 1,
		"slash_color": Color(1.0, 0.68, 0.25, 0.85), "slash_rotation": 0.3,
	})

	_moves["air_heavy"] = _mk({
		"id": "air_heavy", "display_name": "Palanca aérea", "kind": "heavy", "airborne": true,
		"damage": 14.0, "startup": 0.180, "active": 0.100, "recovery": 0.300,
		"hitbox_size": Vector2(80.0, 52.0), "hitbox_offset": Vector2(48.0, 4.0),
		"hitstun": 0.34, "blockstun": 0.20, "hitstop": 5, "block_hitstop": 2,
		"knockback": Vector2(220.0, -60.0),
		"chain_into": PackedStringArray(["air_special"]),
		"max_chains": 1,
		"slash_color": Color(1.0, 0.35, 0.2, 0.9), "slash_rotation": 0.1,
	})

	_moves["air_special"] = _mk({
		"id": "air_special", "display_name": "Clavada", "kind": "special", "airborne": true,
		"damage": 20.0, "startup": 0.260, "active": 0.130, "recovery": 0.440,
		"hitbox_size": Vector2(70.0, 60.0), "hitbox_offset": Vector2(40.0, 30.0),
		"hitstun": 0.46, "blockstun": 0.24, "hitstop": 6, "block_hitstop": 3,
		"knockback": Vector2(140.0, 420.0),
		"chain_into": PackedStringArray(), "max_chains": 0, "is_ender": true,
		"slash_color": Color(0.8, 0.45, 1.0, 0.9), "slash_rotation": 1.3,
	})
