class_name Fighter
extends CharacterBody2D

## Combatiente 2D modular.
##
## Reúne: movimiento (caminar, doble salto, agacharse, dash), máquina de estados,
## ataques basados en datos (MoveLibrary) con fases startup/active/recovery,
## encadenado de golpes (chains) con ventanas de ventaja, sistema de combos con
## escalado anti-loop, bloqueo direccional en tierra y aire, lanzadera/juggle,
## invulnerabilidad, hitstop y representación en pixel art.
##
## El resto del juego se comunica con él mediante señales.

# ---------------------------------------------------------------------------
# Señales
# ---------------------------------------------------------------------------
signal health_changed(current: float, maximum: float)
signal died(loser)
signal hit_landed(attacker, move_id: String, blocked: bool, impact_position: Vector2, hitstop_frames: int)
signal combo_updated(fighter, hits: int, total_damage: float, combo_name: String)
signal combo_finished(fighter)

# ---------------------------------------------------------------------------
# Estados
# ---------------------------------------------------------------------------
enum State { IDLE, WALK, JUMP, CROUCH, DASH, ATTACK, HITSTUN, KO }

# ---------------------------------------------------------------------------
# Propiedades exportadas
# ---------------------------------------------------------------------------
@export var player_name: String = "JUGADOR 1"
@export var player_index: int = 1
@export var is_ai: bool = false
@export var max_health: float = 100.0
@export var use_pixel_art: bool = true
@export var body_color: Color = Color(0.9, 0.26, 0.3, 1.0):
	set(value):
		body_color = value
		_apply_body_color()

# ---------------------------------------------------------------------------
# Constantes de movimiento
# ---------------------------------------------------------------------------
const SPEED: float = 300.0
const GROUND_ACCEL: float = 2600.0
const AIR_ACCEL: float = 1500.0
const FRICTION: float = 2400.0
const GRAVITY: float = 1600.0
const JUGGLE_GRAVITY_MULT: float = 0.5
const MAX_FALL_SPEED: float = 1300.0
const JUMP_VELOCITY: float = -560.0
const MAX_JUMPS: int = 2                 # doble salto
const AIR_ACTIONS: int = 3               # ataques aéreos por tiempo en el aire

const DASH_SPEED: float = 760.0
const DASH_DURATION: float = 0.16
const DASH_COOLDOWN: float = 0.55
const DASH_END_DRAG: float = 0.4

const STAND_HEIGHT: float = 100.0
const CROUCH_HEIGHT: float = 55.0
const BODY_WIDTH: float = 44.0
const FEET_OFFSET: float = 50.0

const BLOCK_DAMAGE_MULT: float = 0.15
const BLOCK_PUSH := Vector2(120.0, -30.0)
const BLOCK_STUN: float = 0.09

## Poses de pixel art por id de movimiento.
const ATTACK_POSES := {
	"light": "light", "medium": "medium", "heavy": "heavy", "special": "special",
	"low_kick": "medium", "advancing_blow": "heavy",
	"air_light": "air_light", "air_medium": "air_medium",
	"air_heavy": "air_heavy", "air_special": "air_special",
}

# ---------------------------------------------------------------------------
# Estado interno
# ---------------------------------------------------------------------------
var health: float = 100.0
var facing: int = 1
var state: State = State.IDLE
var opponent: Fighter = null
var is_blocking: bool = false

var _move_dir: float = 0.0
var _want_jump: bool = false
var _want_crouch: bool = false
var _want_dash: bool = false
var _want_attack_button: String = ""

var _dash_timer: float = 0.0
var _dash_cooldown: float = 0.0
var _hitstun_timer: float = 0.0
var _block_flash: float = 0.0
var _invuln_timer: float = 0.0
var _hitstop: int = 0
var _juggle_timer: float = 0.0
var _jumps_used: int = 0
var _air_actions_left: int = AIR_ACTIONS
var _anim_time: float = 0.0
var _crouched: bool = false

# Ataque actual / encadenado
var _current_move: MoveData = null
var _attack_phase: String = ""          # "startup" | "active" | "recovery"
var _attack_timer: float = 0.0
var _hit_targets: Array = []
var _hit_confirmed: bool = false
var _chains_used: Dictionary = {}       # id -> nº de veces usado en la cadena actual

var combo := ComboSystem.new()
var _prev_combo_hits: int = 0

var _ai_brain: AIBrain = null

# ---------------------------------------------------------------------------
# Nodos
# ---------------------------------------------------------------------------
@onready var body_rect: ColorRect = $Body
@onready var sprite: Sprite2D = $Sprite
@onready var slash: ColorRect = $Slash
@onready var body_collision: CollisionShape2D = $BodyCollision
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hurtbox_collision: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var hitbox: Hitbox = $Hitbox
@onready var hitbox_collision: CollisionShape2D = $Hitbox/CollisionShape2D


func _ready() -> void:
	# Formas propias por instancia (los SubResource se comparten entre instancias).
	body_collision.shape = body_collision.shape.duplicate()
	hurtbox_collision.shape = hurtbox_collision.shape.duplicate()
	hitbox_collision.shape = hitbox_collision.shape.duplicate()

	hitbox.fighter = self
	hurtbox.fighter = self

	body_rect.visible = not use_pixel_art
	sprite.visible = use_pixel_art
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(PixelArt.PIXEL_SCALE, PixelArt.PIXEL_SCALE)
	slash.visible = false

	_apply_body_color()
	_apply_height(STAND_HEIGHT)
	_refresh_sprite()
	set_health(max_health)


func _physics_process(delta: float) -> void:
	# Hitstop: congelación breve y casi imperceptible al impactar.
	if _hitstop > 0:
		_hitstop -= 1
		return

	if _invuln_timer > 0.0:
		_invuln_timer -= delta
	_tick_timers(delta)

	if state == State.KO:
		_apply_gravity(delta)
		move_and_slide()
		_apply_height_if_changed(false)
		_update_visuals()
		return

	_gather_input(delta)
	_update_facing()
	_update_blocking()
	_process_attack(delta)
	_process_movement(delta)
	move_and_slide()
	_apply_height_if_changed(state == State.CROUCH)
	_update_visuals()

	# Detectar el final del combo para avisar (p. ej. al HUD).
	if _prev_combo_hits > 0 and combo.hits == 0:
		combo_finished.emit(self)
	_prev_combo_hits = combo.hits


# ===========================================================================
# Entrada (humano o IA)
# ===========================================================================
func _gather_input(delta: float) -> void:
	_move_dir = 0.0
	_want_jump = false
	_want_crouch = false
	_want_dash = false
	_want_attack_button = ""

	if is_ai:
		if _ai_brain == null:
			_ai_brain = AIBrain.new()
		var cmd: Dictionary = _ai_brain.think(self, opponent, delta)
		_move_dir = cmd.get("move_dir", 0.0)
		_want_jump = cmd.get("jump", false)
		_want_crouch = cmd.get("crouch", false)
		_want_dash = cmd.get("dash", false)
		_want_attack_button = cmd.get("attack", "")
		return

	var p: String = "p%d" % player_index
	if _pressed(p + "_left"):
		_move_dir -= 1.0
	if _pressed(p + "_right"):
		_move_dir += 1.0
	_want_jump = _just_pressed(p + "_jump")
	_want_crouch = _pressed(p + "_crouch")
	_want_dash = _just_pressed(p + "_dash")
	if _just_pressed(p + "_light"):
		_want_attack_button = "light"
	elif _just_pressed(p + "_medium"):
		_want_attack_button = "medium"
	elif _just_pressed(p + "_heavy"):
		_want_attack_button = "heavy"
	elif _just_pressed(p + "_special"):
		_want_attack_button = "special"


func _pressed(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)


func _just_pressed(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)


## Traduce un botón a un id de movimiento según el estado (tierra/aire) y la dirección.
func _resolve_move(button: String) -> String:
	if not is_on_floor():
		match button:
			"light": return "air_light"
			"medium": return "air_medium"
			"heavy": return "air_heavy"
			"special": return "air_special"
		return ""
	match button:
		"light":
			return "light"
		"medium":
			return "low_kick" if _want_crouch else "medium"
		"heavy":
			return "advancing_blow" if signi(_move_dir) == facing else "heavy"
		"special":
			return "special"
	return ""


# ===========================================================================
# Utilidades de estado
# ===========================================================================
func is_ko() -> bool:
	return state == State.KO


func is_attacking() -> bool:
	return state == State.ATTACK


func is_in_hitstun() -> bool:
	return state == State.HITSTUN


func is_invulnerable() -> bool:
	return _invuln_timer > 0.0


func _update_facing() -> void:
	if opponent == null:
		return
	if state == State.ATTACK or state == State.HITSTUN or state == State.DASH:
		return
	var dx: float = opponent.global_position.x - global_position.x
	if absf(dx) > 4.0:
		facing = signi(dx)


func _tick_timers(delta: float) -> void:
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	_hitstun_timer = maxf(_hitstun_timer - delta, 0.0)
	_block_flash = maxf(_block_flash - delta, 0.0)
	_juggle_timer = maxf(_juggle_timer - delta, 0.0)
	_anim_time += delta
	combo.update(delta)


func _update_blocking() -> void:
	var can_block: bool = (
		state == State.IDLE or state == State.WALK
		or state == State.JUMP or state == State.CROUCH
	)
	# Bloqueo direccional en tierra Y en aire: mantener la dirección opuesta al rival.
	is_blocking = (
		can_block
		and _move_dir != 0.0
		and signi(_move_dir) == -facing
	)


# ===========================================================================
# Ataques y encadenado
# ===========================================================================
func _start_attack(move_id: String) -> bool:
	var md: MoveData = MoveLibrary.get_move(move_id)
	if md == null:
		return false

	# Los movimientos aéreos consumen "acciones aéreas" para evitar spam.
	if md.airborne and _air_actions_left <= 0:
		return false
	if md.airborne:
		_air_actions_left -= 1

	# Al empezar un combo nuevo, se limpia el registro de cadenas.
	if combo.hits == 0:
		_chains_used.clear()

	state = State.ATTACK
	_current_move = md
	_attack_phase = "startup"
	_attack_timer = 0.0
	_hit_targets.clear()
	_hit_confirmed = false
	is_blocking = false

	_chains_used[md.id] = int(_chains_used.get(md.id, 0)) + 1
	combo.push_input(md.id, md.airborne)

	if md.invuln > 0.0:
		_invuln_timer = maxf(_invuln_timer, md.invuln)

	if is_on_floor():
		if md.momentum != 0.0:
			velocity.x = facing * md.momentum
		else:
			velocity.x *= 0.25
	return true


## Intenta cancelar el ataque actual en el siguiente (solo si el golpe conectó).
func _try_chain() -> bool:
	if not _hit_confirmed or _want_attack_button == "":
		return false
	if _current_move == null or _current_move.is_ender:
		return false

	var next_id: String = _resolve_move(_want_attack_button)
	if next_id == "" or not _current_move.chain_into.has(next_id):
		return false

	var next_md: MoveData = MoveLibrary.get_move(next_id)
	if next_md == null:
		return false
	if int(_chains_used.get(next_id, 0)) >= next_md.max_chains:
		return false

	return _start_attack(next_id)


func _process_attack(delta: float) -> void:
	if state != State.ATTACK:
		return

	if _try_chain():
		return

	_attack_timer += delta
	var md: MoveData = _current_move
	var startup: float = md.startup
	var active_end: float = startup + md.active
	var total: float = active_end + md.recovery

	if _attack_timer < startup:
		_attack_phase = "startup"
		hitbox.set_active(false)
	elif _attack_timer < active_end:
		if _attack_phase != "active":
			_attack_phase = "active"
			_hit_targets.clear()
			_configure_hitbox(md)
			hitbox.set_active(true)
		_resolve_hit(md)
	else:
		if _attack_phase != "recovery":
			_attack_phase = "recovery"
			hitbox.set_active(false)
		if _attack_timer >= total:
			_end_attack()


func _configure_hitbox(md: MoveData) -> void:
	var shape := hitbox_collision.shape as RectangleShape2D
	if shape:
		shape.size = md.hitbox_size
	hitbox_collision.position = Vector2(md.hitbox_offset.x * facing, md.hitbox_offset.y)


func _resolve_hit(md: MoveData) -> void:
	for area in hitbox.get_overlapping_areas():
		if not (area is Hurtbox):
			continue
		var target: Fighter = (area as Hurtbox).fighter
		if target == null or target == self or target.health <= 0.0:
			continue
		if _hit_targets.has(target) or target.is_invulnerable():
			continue

		_hit_targets.append(target)
		_hit_confirmed = true

		var blocked: bool = target.try_block(self)
		var info: Dictionary = _build_hit_info(md, blocked)
		var dealt: float = target.take_hit(self, info)

		var combo_name: String = ""
		if blocked:
			combo.on_block()
		else:
			combo_name = String(info.get("combo_name", ""))
			combo.on_hit(dealt, combo_name)
			combo_updated.emit(self, combo.hits, combo.total_damage, combo.named_combo)

		var midpoint: Vector2 = (global_position + target.global_position) * 0.5
		hit_landed.emit(self, md.id, blocked, midpoint, int(info.get("hitstop", 2)))

		if bool(info.get("escape", false)):
			combo.reset()
			combo_finished.emit(self)


func _build_hit_info(md: MoveData, blocked: bool) -> Dictionary:
	var info := {
		"move_id": md.id,
		"blocked": blocked,
		"damage": md.damage,
		"hitstun": md.hitstun,
		"knockback": md.knockback,
		"launcher": md.launcher,
		"hitstop": md.hitstop,
		"escape": false,
		"combo_name": "",
	}

	if blocked:
		info["damage"] = md.damage * BLOCK_DAMAGE_MULT
		info["hitstun"] = md.blockstun
		info["launcher"] = false
		info["hitstop"] = md.block_hitstop
		return info

	# Receta de combo (solo si los golpes previos conectaron).
	var recipe: Dictionary = combo.match_recipe(md.airborne)
	if not recipe.is_empty():
		info["combo_name"] = recipe["name"]
		info["damage"] = md.damage * ComboRecipes.finisher_bonus(recipe)

	# Escalado anti-loop.
	var scale: float = combo.damage_scale()
	info["damage"] = float(info["damage"]) * scale
	info["hitstun"] = md.hitstun * combo.hitstun_scale()
	info["knockback"] = md.knockback * combo.knockback_scale()

	# Tope de combo: la víctima escapa con un empuje fuerte.
	if combo.is_maxed():
		info["escape"] = true
		info["damage"] = md.damage * 0.2
		info["knockback"] = Vector2(460.0, -430.0)
		info["hitstun"] = 0.6
		info["launcher"] = true

	return info


## Devuelve `true` si este combatiente está bloqueando un ataque que viene de frente.
func try_block(attacker: Fighter) -> bool:
	if state == State.KO or state == State.HITSTUN or state == State.ATTACK or state == State.DASH:
		return false
	if not is_blocking:
		return false
	var from_dir: int = signi(attacker.global_position.x - global_position.x)
	return from_dir == facing


func _end_attack() -> void:
	state = State.IDLE if is_on_floor() else State.JUMP
	_current_move = null
	_attack_phase = ""
	_attack_timer = 0.0
	hitbox.set_active(false)


func _interrupt_attack() -> void:
	hitbox.set_active(false)
	if state == State.ATTACK:
		_end_attack()


# ===========================================================================
# Movimiento
# ===========================================================================
func _process_movement(delta: float) -> void:
	var on_floor := is_on_floor()

	if on_floor:
		_jumps_used = 0
		_air_actions_left = AIR_ACTIONS

	# --- Estados que bloquean el control libre ---
	if state == State.HITSTUN:
		_apply_gravity(delta, JUGGLE_GRAVITY_MULT if _juggle_timer > 0.0 else 1.0)
		# Menos frenado en el aire para que el empuje se lea bien.
		var drag: float = 900.0 if on_floor else 260.0
		velocity.x = move_toward(velocity.x, 0.0, drag * delta)
		if _hitstun_timer <= 0.0:
			state = State.IDLE if on_floor else State.JUMP
		return

	if state == State.DASH:
		_apply_gravity(delta)
		_dash_timer -= delta
		velocity.x = facing * DASH_SPEED
		if _dash_timer <= 0.0:
			state = State.IDLE
			velocity.x *= DASH_END_DRAG
		return

	if state == State.ATTACK:
		_apply_gravity(delta)
		if on_floor:
			# Fricción reducida durante el ataque para conservar el empuje de la Embestida.
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * 0.2 * delta)
			if _current_move != null and _current_move.airborne:
				_end_attack()   # aterrizar cancela el ataque aéreo
		return

	# --- Control libre ---
	var crouching: bool = _want_crouch and on_floor

	# Salto y doble salto
	if _want_jump:
		if on_floor:
			velocity.y = JUMP_VELOCITY
			_jumps_used = 1
			on_floor = false
		elif _jumps_used < MAX_JUMPS:
			velocity.y = JUMP_VELOCITY * 0.92
			_jumps_used += 1

	# Dash
	if _want_dash and _dash_cooldown <= 0.0:
		state = State.DASH
		_dash_timer = DASH_DURATION
		_dash_cooldown = DASH_COOLDOWN
		facing = signi(_move_dir) if _move_dir != 0.0 else facing
		velocity.y = 0.0
		return

	# Ataques
	if _want_attack_button != "" and _start_attack(_resolve_move(_want_attack_button)):
		return

	var speed: float = 0.0 if crouching else SPEED
	var target_speed: float = _move_dir * speed
	var accel: float = GROUND_ACCEL if on_floor else AIR_ACCEL
	if _move_dir != 0.0:
		velocity.x = move_toward(velocity.x, target_speed, accel * delta)
	elif on_floor:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, AIR_ACCEL * 0.4 * delta)

	_apply_gravity(delta)

	if not on_floor:
		state = State.JUMP
	elif crouching:
		state = State.CROUCH
	elif absf(velocity.x) > 5.0:
		state = State.WALK
	else:
		state = State.IDLE


func _apply_gravity(delta: float, mult: float = 1.0) -> void:
	if is_on_floor() and velocity.y >= 0.0:
		velocity.y = 0.0
	else:
		velocity.y = minf(velocity.y + GRAVITY * mult * delta, MAX_FALL_SPEED)


# ===========================================================================
# Daño, vida y KO
# ===========================================================================
func take_hit(attacker: Fighter, info: Dictionary) -> float:
	if state == State.KO:
		return 0.0

	var damage: float = info["damage"]
	set_health(health - damage)

	if bool(info["blocked"]):
		velocity = Vector2(-facing * BLOCK_PUSH.x, minf(velocity.y, BLOCK_PUSH.y))
		_block_flash = 0.12
		_hitstun_timer = maxf(_hitstun_timer, BLOCK_STUN)
		_interrupt_attack()
		if state != State.KO:
			state = State.HITSTUN
	else:
		var dir: float = signf(global_position.x - attacker.global_position.x)
		if dir == 0.0:
			dir = -attacker.facing
		velocity = Vector2(dir * float(info["knockback"].x), float(info["knockback"].y))
		_hitstun_timer = float(info["hitstun"])
		if bool(info["launcher"]) or not is_on_floor():
			_juggle_timer = maxf(_juggle_timer, float(info["hitstun"]))
		_interrupt_attack()
		state = State.HITSTUN

	if bool(info.get("escape", false)):
		_invuln_timer = 0.4

	if health <= 0.0:
		_ko()
	return damage


func set_health(value: float) -> void:
	health = clampf(value, 0.0, max_health)
	health_changed.emit(health, max_health)


func _ko() -> void:
	state = State.KO
	is_blocking = false
	_current_move = null
	_attack_phase = ""
	hitbox.set_active(false)
	combo.reset()
	velocity = Vector2(-facing * 260.0, -260.0)

	var tween := create_tween()
	tween.tween_property(sprite, "rotation", deg_to_rad(85.0 * -facing), 0.5)
	tween.parallel().tween_property(body_rect, "rotation", deg_to_rad(85.0 * -facing), 0.5)

	died.emit(self)


## Prepara al combatiente para una nueva ronda.
func reset_for_round(spawn_position: Vector2, look_dir: int) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	facing = look_dir
	state = State.IDLE
	is_blocking = false
	_hitstun_timer = 0.0
	_dash_timer = 0.0
	_dash_cooldown = 0.0
	_invuln_timer = 0.0
	_hitstop = 0
	_juggle_timer = 0.0
	_jumps_used = 0
	_air_actions_left = AIR_ACTIONS
	_current_move = null
	_attack_phase = ""
	_attack_timer = 0.0
	_hit_targets.clear()
	_hit_confirmed = false
	_chains_used.clear()
	hitbox.set_active(false)
	combo.reset()
	_prev_combo_hits = 0
	sprite.rotation = 0.0
	body_rect.rotation = 0.0
	set_health(max_health)
	_crouched = false
	_apply_height(STAND_HEIGHT)
	_apply_body_color()
	_refresh_sprite()


## Congela al combatiente durante `frames` frames (hitstop).
func apply_hitstop(frames: int) -> void:
	_hitstop = maxi(_hitstop, frames)


# ===========================================================================
# Visual (pixel art generado en código)
# ===========================================================================
func _apply_body_color() -> void:
	if is_node_ready():
		body_rect.color = body_color


## Ajusta el cuerpo de colisión y la hurtbox a la postura (de pie / agachado).
func _apply_height(height: float) -> void:
	var center_y: float = FEET_OFFSET - height * 0.5

	var body_shape := body_collision.shape as RectangleShape2D
	if body_shape:
		body_shape.size = Vector2(BODY_WIDTH, height)
	body_collision.position = Vector2(0.0, center_y)

	var hurt_shape := hurtbox_collision.shape as RectangleShape2D
	if hurt_shape:
		hurt_shape.size = Vector2(BODY_WIDTH + 6.0, height + 6.0)
	hurtbox_collision.position = Vector2(0.0, center_y)

	body_rect.offset_left = -BODY_WIDTH * 0.5
	body_rect.offset_right = BODY_WIDTH * 0.5
	body_rect.offset_top = FEET_OFFSET - height
	body_rect.offset_bottom = FEET_OFFSET
	body_rect.pivot_offset = Vector2(BODY_WIDTH * 0.5, height * 0.5)


## Cambia la altura del cuerpo (de pie / agachado) solo cuando es necesario.
func _apply_height_if_changed(crouch: bool) -> void:
	if crouch == _crouched:
		return
	_crouched = crouch
	_apply_height(CROUCH_HEIGHT if crouch else STAND_HEIGHT)


func _current_pose() -> String:
	if state == State.KO:
		return "ko"
	if state == State.HITSTUN:
		return "hurt"
	if is_blocking:
		return "block_air" if not is_on_floor() else "block_ground"
	if state == State.DASH:
		return "dash"
	if state == State.CROUCH:
		return "crouch"
	if state == State.ATTACK:
		return ATTACK_POSES.get(_current_move.id, "light") if _current_move else "light"
	if state == State.JUMP:
		return "jump" if velocity.y < 0.0 else "fall"
	if state == State.WALK:
		return "walk_%d" % (int(_anim_time * 9.0) % 4)
	return "idle_%d" % (int(_anim_time * 2.5) % 2)


func _refresh_sprite() -> void:
	if not use_pixel_art:
		return
	sprite.texture = PixelArt.get_texture(_current_pose(), player_index)
	sprite.flip_h = facing < 0


func _update_visuals() -> void:
	_refresh_sprite()

	# Tinte de estado: blanco al bloquear un golpe, gris al KO.
	var tint := Color(1, 1, 1, 1)
	if _block_flash > 0.0:
		tint = Color(2.0, 2.0, 2.0, 1.0)
	sprite.modulate = tint

	_update_slash()


## Arco de color que aparece en los frames activos para diferenciar cada ataque.
func _update_slash() -> void:
	if state != State.ATTACK or _attack_phase != "active" or _current_move == null:
		slash.visible = false
		return
	var size: Vector2 = _current_move.hitbox_size
	slash.visible = true
	slash.size = size
	slash.pivot_offset = size * 0.5
	slash.position = Vector2(_current_move.hitbox_offset.x * facing, _current_move.hitbox_offset.y) - size * 0.5
	slash.rotation = _current_move.slash_rotation * facing
	slash.color = _current_move.slash_color
