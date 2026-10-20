extends Node2D
class_name GameManager

## Orquesta la escena de combate: rondas, HUD, pausa y feedback de impacto.
## Es el único nodo que conoce tanto a los combatientes como a la interfaz.

@export var rounds_to_win: int = 2
@export var round_time: float = 60.0
@export var spawn_p1: Vector2 = Vector2(360.0, 480.0)
@export var spawn_p2: Vector2 = Vector2(792.0, 480.0)

@onready var p1: Fighter = $Fighters/Player1
@onready var p2: Fighter = $Fighters/Player2
@onready var hud: HUD = $HUD
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var effects: Node2D = $Effects
@onready var camera: Camera2D = $Camera2D

# Ajustes de feedback por tipo de golpe: [color chispa, tamaño, shake, flash].
const HIT_FEEDBACK := {
	"light": {"color": Color(1.0, 0.95, 0.6), "size": 12.0, "shake": 2.0, "flash": 0.0},
	"medium": {"color": Color(1.0, 0.70, 0.30), "size": 16.0, "shake": 4.0, "flash": 0.0},
	"heavy": {"color": Color(1.0, 0.40, 0.20), "size": 22.0, "shake": 9.0, "flash": 0.30},
	"special": {"color": Color(0.80, 0.45, 1.0), "size": 28.0, "shake": 12.0, "flash": 0.42},
}
const BLOCK_FEEDBACK := {"color": Color(0.60, 0.85, 1.0), "size": 14.0, "shake": 2.0, "flash": 0.0}

var _wins := [0, 0]
var _round_number: int = 1
var _time_left: float = 0.0
var _round_active: bool = false
var _match_over: bool = false


func _ready() -> void:
	p1.opponent = p2
	p2.opponent = p1

	p1.health_changed.connect(_on_health_changed.bind(1))
	p2.health_changed.connect(_on_health_changed.bind(2))
	p1.died.connect(_on_fighter_died)
	p2.died.connect(_on_fighter_died)
	p1.hit_landed.connect(_on_hit_landed)
	p2.hit_landed.connect(_on_hit_landed)
	p1.combo_updated.connect(_on_combo_updated)
	p2.combo_updated.connect(_on_combo_updated)
	p1.combo_finished.connect(_on_combo_finished)
	p2.combo_finished.connect(_on_combo_finished)

	hud.setup(rounds_to_win, p1.player_name, p2.player_name)
	start_match()


func _process(delta: float) -> void:
	if not _round_active:
		return
	_time_left = maxf(_time_left - delta, 0.0)
	hud.set_timer(_time_left)
	if _time_left <= 0.0:
		_resolve_timeout()


# ===========================================================================
# Flujo de rondas
# ===========================================================================
func start_match() -> void:
	_wins = [0, 0]
	_round_number = 1
	_match_over = false
	_round_active = false
	hud.clear_combo(1)
	hud.clear_combo(2)
	hud.update_rounds(0, 0)
	await _start_round()


func _start_round() -> void:
	_round_active = false
	p1.reset_for_round(spawn_p1, 1)
	p2.reset_for_round(spawn_p2, -1)
	hud.update_health(1, p1.health, p1.max_health)
	hud.update_health(2, p2.health, p2.max_health)
	hud.update_rounds(_wins[0], _wins[1])
	hud.set_timer(round_time)

	hud.show_announcement("ROUND %d" % _round_number, 1.1)
	await get_tree().create_timer(1.3, false).timeout
	hud.show_announcement("¡A PELEAR!", 0.7)

	_time_left = round_time
	_round_active = true


func _on_fighter_died(loser) -> void:
	if not _round_active:
		return
	_round_active = false
	var winner: int = 2 if loser == p1 else 1
	_award_round(winner, "K.O.")


func _resolve_timeout() -> void:
	_round_active = false
	if is_equal_approx(p1.health, p2.health):
		hud.show_announcement("EMPATE", 1.4)
		await get_tree().create_timer(1.8, false).timeout
		await _start_round()
		return
	var winner: int = 1 if p1.health > p2.health else 2
	_award_round(winner, "TIEMPO")


func _award_round(winner: int, reason: String) -> void:
	_wins[winner - 1] += 1
	hud.update_rounds(_wins[0], _wins[1])
	var winner_name: String = p1.player_name if winner == 1 else p2.player_name
	hud.show_announcement("%s  ·  %s" % [reason, winner_name], 1.4)

	await get_tree().create_timer(1.8, false).timeout
	if _wins[0] >= rounds_to_win or _wins[1] >= rounds_to_win:
		_finish_match()
	else:
		_round_number += 1
		await _start_round()


func _finish_match() -> void:
	_match_over = true
	var champion: String = p1.player_name if _wins[0] >= rounds_to_win else p2.player_name
	hud.show_announcement("¡%s GANA EL COMBATE!\nPulsa ENTER para reiniciar" % champion, 9999.0)


func _unhandled_input(event: InputEvent) -> void:
	if _match_over and event.is_action_pressed("ui_accept"):
		start_match()


# ===========================================================================
# Vida y combos (HUD)
# ===========================================================================
func _on_health_changed(current: float, maximum: float, player_index: int) -> void:
	hud.update_health(player_index, current, maximum)


func _player_of(fighter) -> int:
	return 1 if fighter == p1 else 2


func _on_combo_updated(fighter, hits: int, total_damage: float, combo_name: String) -> void:
	hud.set_combo(_player_of(fighter), hits, total_damage, combo_name)


func _on_combo_finished(fighter) -> void:
	hud.clear_combo(_player_of(fighter))


# ===========================================================================
# Feedback de impacto
# ===========================================================================
func _on_hit_landed(attacker, move_id: String, blocked: bool, impact_position: Vector2, hitstop_frames: int) -> void:
	# Hitstop: congela brevemente a ambos combatientes (casi imperceptible).
	attacker.apply_hitstop(hitstop_frames)
	var target = p2 if attacker == p1 else p1
	target.apply_hitstop(hitstop_frames)

	var md: MoveData = MoveLibrary.get_move(move_id)
	var kind: String = md.kind if md != null else "light"
	var feedback: Dictionary = BLOCK_FEEDBACK if blocked else HIT_FEEDBACK.get(kind, HIT_FEEDBACK["light"])

	_spawn_impact(impact_position, feedback, kind, blocked)
	_shake(float(feedback["shake"]))
	if float(feedback["flash"]) > 0.0:
		hud.flash_screen(Color(1, 1, 1), float(feedback["flash"]))


func _spawn_impact(pos: Vector2, feedback: Dictionary, kind: String, blocked: bool) -> void:
	var count: int = 1
	if not blocked and (kind == "heavy" or kind == "special"):
		count = 4

	for i in count:
		var side: float = float(feedback["size"])
		var spark := ColorRect.new()
		spark.color = feedback["color"]
		if i > 0:
			side *= 0.55
			spark.color.a = 0.85
		spark.size = Vector2(side, side)
		spark.pivot_offset = Vector2(side, side) * 0.5
		var jitter := Vector2.ZERO if i == 0 else Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0))
		spark.position = pos + jitter - Vector2(side, side) * 0.5
		effects.add_child(spark)

		var tween := create_tween()
		tween.tween_property(spark, "scale", Vector2(2.4, 2.4), 0.18)
		tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.18)
		tween.tween_callback(spark.queue_free)


func _shake(amount: float) -> void:
	if amount <= 0.0:
		return
	var tween := create_tween()
	tween.tween_property(camera, "offset", Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.02)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.09)
