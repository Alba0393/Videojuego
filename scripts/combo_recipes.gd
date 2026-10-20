class_name ComboRecipes
extends RefCounted

## Catálogo de combos por secuencias de botones y su notación para el menú.
##
## Las recetas se evalúan contra el "tail" del buffer de entrada en el momento
## en que un golpe conecta: completar una secuencia da un nombre al combo y un
## pequeño bonus de daño al finisher.

## Notación legible de cada movimiento (para el menú de pausa y el HUD).
const NOTATION := {
	"light": "Ligero (J)",
	"medium": "Medio (K)",
	"heavy": "Pesado (L)",
	"special": "Especial (Ñ)",
	"low_kick": "Abajo + Medio (↓+K)",
	"advancing_blow": "Adelante + Pesado (→+L)",
	"air_light": "Ligero aéreo (J en aire)",
	"air_medium": "Medio aéreo (K en aire)",
	"air_heavy": "Pesado aéreo (L en aire)",
	"air_special": "Especial aéreo (Ñ en aire)",
}

## Notación corta (teclas) para el menú de pausa.
const NOTATION_SHORT := {
	"light": "J",
	"medium": "K",
	"heavy": "L",
	"special": "Ñ",
	"low_kick": "↓+K",
	"advancing_blow": "→+L",
	"air_light": "J (aire)",
	"air_medium": "K (aire)",
	"air_heavy": "L (aire)",
	"air_special": "Ñ (aire)",
}

## Recetas: `seq` es la secuencia de ids de movimiento (el último es el finisher).
const RECIPES := [
	{"name": "Ráfaga rápida", "seq": ["light", "light", "medium"], "air": false},
	{"name": "Barrido ascendente", "seq": ["light", "medium", "heavy"], "air": false},
	{"name": "Cadena completa", "seq": ["light", "medium", "heavy", "special"], "air": false},
	{"name": "Golpe demoledor", "seq": ["medium", "heavy"], "air": false},
	{"name": "Patada baja", "seq": ["low_kick"], "air": false},
	{"name": "Embestida", "seq": ["advancing_blow"], "air": false},
	{"name": "Final ascendente", "seq": ["low_kick", "special"], "air": false},
	{"name": "Ráfaga aérea", "seq": ["air_light", "air_light", "air_medium"], "air": true},
	{"name": "Combo aéreo", "seq": ["air_light", "air_medium", "air_heavy"], "air": true},
	{"name": "Aéreo extendido", "seq": ["air_light", "air_medium", "air_special"], "air": true},
]


## Devuelve la receta cuyo `seq` coincide con el final del buffer, o {} si no hay.
## `air` filtra entre recetas de tierra y de aire.
static func match_tail(buffer_ids: Array, air: bool) -> Dictionary:
	for recipe in RECIPES:
		if recipe["air"] != air:
			continue
		var seq: Array = recipe["seq"]
		if buffer_ids.size() < seq.size():
			continue
		var tail: Array = buffer_ids.slice(buffer_ids.size() - seq.size())
		if tail == seq:
			return recipe
	return {}


## Bonus de daño del finisher según la longitud del combo encadenado.
static func finisher_bonus(recipe: Dictionary) -> float:
	var n: int = (recipe.get("seq", []) as Array).size()
	if n <= 1:
		return 1.0
	return clampf(1.0 + 0.06 * n, 1.0, 1.3)


## Texto de la secuencia con notación legible, p. ej. "Ligero (J)  →  Medio (K)".
static func describe_sequence(seq: Array) -> String:
	var parts := PackedStringArray()
	for id in seq:
		parts.append(NOTATION.get(id, String(id)))
	return "  →  ".join(parts)


## Texto compacto (teclas) para el menú, p. ej. "J · J · K".
static func describe_short(seq: Array) -> String:
	var parts := PackedStringArray()
	for id in seq:
		parts.append(NOTATION_SHORT.get(id, String(id)))
	return " · ".join(parts)
