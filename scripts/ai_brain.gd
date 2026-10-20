class_name AIBrain
extends RefCounted

## IA básica para el combatiente controlado por la máquina.
##
## Devuelve un diccionario de "intención" con el mismo formato que el input
## humano, de modo que el controlador del personaje es agnóstico a quién lo
## maneja. Sabe usar los tres tipos de ataque, el especial, el doble salto y el
## bloqueo aéreo.

var _decision_timer: float = 0.0
var _action: String = "approach"
var _rng := RandomNumberGenerator.new()

const APPROACH_RANGE: float = 120.0
const ATTACK_RANGE: float = 92.0


func _init() -> void:
	_rng.randomize()


func think(self_f, opp, delta: float) -> Dictionary:
	var cmd := {
		"move_dir": 0.0,
		"jump": false,
		"crouch": false,
		"dash": false,
		"attack": "",
	}

	if self_f == null or opp == null:
		return cmd
	if self_f.is_ko() or opp.is_ko():
		return cmd

	var dx: float = opp.global_position.x - self_f.global_position.x
	var dist: float = absf(dx)
	var toward: float = signf(dx)
	var airborne: bool = not self_f.is_on_floor()

	# Reacción defensiva: si el rival ataca cerca, retroceder para bloquear
	# (funciona igual en tierra y en el aire).
	if dist < ATTACK_RANGE + 34.0 and opp.is_attacking():
		if _rng.randf() < 0.7:
			cmd["move_dir"] = -toward
			return cmd

	# Refrescar el "plan" cada cierto tiempo aleatorio.
	_decision_timer -= delta
	if _decision_timer <= 0.0:
		_decision_timer = _rng.randf_range(0.10, 0.30)
		_action = _choose_action(dist, airborne)

	match _action:
		"approach":
			cmd["move_dir"] = toward
			if airborne and dist > 90.0 and _rng.randf() < 0.25:
				cmd["jump"] = true   # doble salto para perseguir
		"retreat":
			cmd["move_dir"] = -toward
			cmd["crouch"] = dist > 220.0
		"jump":
			cmd["move_dir"] = toward
			if self_f.is_on_floor() or _rng.randf() < 0.3:
				cmd["jump"] = true
		"dash":
			cmd["move_dir"] = toward
			cmd["dash"] = true
		"attack":
			if dist < ATTACK_RANGE + (14.0 if airborne else 0.0):
				cmd["attack"] = _pick_attack(airborne)
			else:
				cmd["move_dir"] = toward
				if airborne:
					cmd["attack"] = _pick_attack(true) if dist < 110.0 else ""
		"block":
			cmd["move_dir"] = -toward

	return cmd


func _choose_action(dist: float, airborne: bool) -> String:
	var r: float = _rng.randf()

	if airborne:
		if dist < 110.0 and r < 0.6:
			return "attack"
		return "approach"

	if dist > APPROACH_RANGE:
		if r < 0.72:
			return "approach"
		elif r < 0.84:
			return "jump"
		elif r < 0.92:
			return "dash"
		return "block"

	if dist > 50.0:
		if r < 0.62:
			return "attack"
		elif r < 0.8:
			return "approach"
		return "retreat"

	if r < 0.4:
		return "attack"
	if r < 0.6:
		return "retreat"
	return "approach"


func _pick_attack(airborne: bool) -> String:
	var r: float = _rng.randf()
	if airborne:
		if r < 0.45:
			return "light"
		elif r < 0.75:
			return "medium"
		elif r < 0.9:
			return "heavy"
		return "special"
	if r < 0.4:
		return "light"
	elif r < 0.68:
		return "medium"
	elif r < 0.88:
		return "heavy"
	return "special"
