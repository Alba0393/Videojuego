class_name ComboSystem
extends RefCounted

## Estado de combo de un combatiente (atacante).
##
## Responsabilidades:
##  - Guardar un buffer temporal de las entradas de ataque ejecutadas (para las recetas).
##  - Contar golpes y daño del combo actual.
##  - Aplicar el escalado anti-loop: menos daño y hitstun, más knockback por golpe.
##  - Detectar cuándo el combo debe terminar (timeout o tope de golpes).

const MAX_HITS: int = 8              # tope duro de golpes por combo
const COMBO_TIMEOUT: float = 0.55    # si pasa este tiempo sin golpear, el combo se cierra
const BUFFER_TIME: float = 0.40      # vida de cada entrada en el buffer

## Tabla de escalado de daño por número de golpes ya conectados.
const DAMAGE_SCALE := [1.0, 0.85, 0.72, 0.60, 0.50, 0.42, 0.35, 0.30]

var hits: int = 0
var total_damage: float = 0.0
var named_combo: String = ""

var _time_since_hit: float = 0.0
var _buffer: Array = []              # [{ "id": String, "air": bool, "t": float }]


func update(delta: float) -> void:
	_time_since_hit += delta
	for entry in _buffer:
		entry["t"] += delta
	while _buffer.size() > 0 and _buffer[0]["t"] > BUFFER_TIME:
		_buffer.pop_front()

	if hits > 0 and _time_since_hit > COMBO_TIMEOUT:
		reset()


func reset() -> void:
	hits = 0
	total_damage = 0.0
	named_combo = ""
	_time_since_hit = 0.0
	_buffer.clear()


# ---------------------------------------------------------------- Buffer
func push_input(move_id: String, air: bool) -> void:
	_buffer.append({"id": move_id, "air": air, "t": 0.0})


func buffer_ids() -> Array:
	var ids: Array = []
	for entry in _buffer:
		ids.append(entry["id"])
	return ids


func match_recipe(air: bool) -> Dictionary:
	# Solo tiene sentido si ya hay golpes conectados en este combo.
	if hits <= 0:
		return {}
	var recipe: Dictionary = ComboRecipes.match_tail(buffer_ids(), air)
	if recipe.is_empty():
		return {}
	if (recipe["seq"] as Array).size() - 1 > hits:
		return {}
	return recipe


# ---------------------------------------------------------------- Escalado
func damage_scale() -> float:
	return DAMAGE_SCALE[clampi(hits, 0, DAMAGE_SCALE.size() - 1)]


func hitstun_scale() -> float:
	return maxf(0.35, pow(0.86, float(hits)))


func knockback_scale() -> float:
	return 1.0 + 0.14 * float(hits)


# ---------------------------------------------------------------- Eventos
func on_hit(damage: float, combo_name: String = "") -> void:
	hits += 1
	total_damage += damage
	_time_since_hit = 0.0
	if combo_name != "":
		named_combo = combo_name


func on_block() -> void:
	# Un golpe bloqueado no cuenta como parte del combo, pero evita que se cierre.
	_time_since_hit = 0.0


func is_maxed() -> bool:
	return hits >= MAX_HITS
