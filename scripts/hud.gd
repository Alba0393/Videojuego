class_name HUD
extends CanvasLayer

## Interfaz de combate: barras de vida, pips de ronda, temporizador, mensajes
## centrales y contador de combos. Todo con ColorRect y Label (sin texturas).

@onready var p1_fill: ColorRect = $Root/P1Bar/Fill
@onready var p2_fill: ColorRect = $Root/P2Bar/Fill
@onready var p1_name: Label = $Root/P1Bar/Name
@onready var p2_name: Label = $Root/P2Bar/Name
@onready var p1_pips: HBoxContainer = $Root/P1Bar/Pips
@onready var p2_pips: HBoxContainer = $Root/P2Bar/Pips
@onready var p1_combo: Label = $Root/P1Bar/Combo
@onready var p2_combo: Label = $Root/P2Bar/Combo
@onready var timer_label: Label = $Root/TimerLabel
@onready var message: Label = $Root/CenterMessage
@onready var flash: ColorRect = $Root/Flash

const PIP_EMPTY := Color(0.25, 0.25, 0.30, 1.0)
const PIP_FILLED := Color(0.95, 0.80, 0.25, 1.0)
const HEALTH_GOOD := Color(0.25, 0.90, 0.35, 1.0)
const HEALTH_MID := Color(0.95, 0.80, 0.20, 1.0)
const HEALTH_LOW := Color(0.90, 0.20, 0.20, 1.0)

var _p1_fill_max: float = 1.0
var _p2_fill_max: float = 1.0
var _msg_token: int = 0


func _ready() -> void:
	_p1_fill_max = maxf(p1_fill.size.x, 1.0)
	_p2_fill_max = maxf(p2_fill.size.x, 1.0)
	message.visible = false
	p1_combo.visible = false
	p2_combo.visible = false
	timer_label.text = ""
	flash.modulate = Color(1, 1, 1, 0)


func setup(rounds_to_win: int, name1: String, name2: String) -> void:
	p1_name.text = name1
	p2_name.text = name2
	_build_pips(p1_pips, rounds_to_win, HBoxContainer.ALIGNMENT_BEGIN)
	_build_pips(p2_pips, rounds_to_win, HBoxContainer.ALIGNMENT_END)


func _build_pips(container: HBoxContainer, count: int, alignment: BoxContainer.AlignmentMode) -> void:
	for child in container.get_children():
		child.queue_free()
	container.alignment = alignment
	for i in count:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(18.0, 18.0)
		pip.color = PIP_EMPTY
		container.add_child(pip)


func update_health(player: int, current: float, maximum: float) -> void:
	var ratio: float = clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
	if player == 1:
		p1_fill.size = Vector2(_p1_fill_max * ratio, p1_fill.size.y)
		p1_fill.color = _health_color(ratio)
	else:
		var w: float = _p2_fill_max * ratio
		p2_fill.size = Vector2(w, p2_fill.size.y)
		p2_fill.position = Vector2(3.0 + (_p2_fill_max - w), p2_fill.position.y)
		p2_fill.color = _health_color(ratio)


func _health_color(ratio: float) -> Color:
	if ratio > 0.5:
		return HEALTH_MID.lerp(HEALTH_GOOD, (ratio - 0.5) / 0.5)
	return HEALTH_LOW.lerp(HEALTH_MID, ratio / 0.5)


func update_rounds(p1_wins: int, p2_wins: int) -> void:
	_paint_pips(p1_pips, p1_wins)
	_paint_pips(p2_pips, p2_wins)


func _paint_pips(container: HBoxContainer, wins: int) -> void:
	var i: int = 0
	for pip in container.get_children():
		if pip is ColorRect:
			(pip as ColorRect).color = PIP_FILLED if i < wins else PIP_EMPTY
		i += 1


func set_timer(seconds: float) -> void:
	timer_label.text = "%d" % ceili(seconds)
	timer_label.modulate = Color(0.95, 0.95, 0.95, 1.0) if seconds > 10.0 else Color(1.0, 0.35, 0.35, 1.0)


## Actualiza el contador de combo. Solo se muestra a partir de 2 golpes.
func set_combo(player: int, hits: int, total_damage: float, combo_name: String) -> void:
	var label: Label = p1_combo if player == 1 else p2_combo
	if hits < 2:
		label.visible = false
		return
	label.visible = true
	var text: String = "%d GOLPES  ·  %d dmg" % [hits, int(round(total_damage))]
	if combo_name != "":
		text += "\n" + combo_name
	label.text = text


func clear_combo(player: int) -> void:
	var label: Label = p1_combo if player == 1 else p2_combo
	label.visible = false


## Destello de pantalla breve (impactos fuertes).
func flash_screen(color: Color, strength: float) -> void:
	flash.color = color
	flash.modulate = Color(1, 1, 1, clampf(strength, 0.0, 1.0))
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.16)


## Muestra un mensaje central durante `duration` segundos.
## Un mensaje nuevo cancela el temporizador del anterior.
func show_announcement(text: String, duration: float) -> void:
	_msg_token += 1
	var token: int = _msg_token
	message.text = text
	message.visible = true
	message.modulate = Color(1, 1, 1, 1)
	await get_tree().create_timer(duration, false).timeout
	if token == _msg_token:
		message.visible = false
