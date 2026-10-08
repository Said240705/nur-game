extends "res://scripts/work/minigame.gd"
## Businessman and magnate: close deals. Read each document and sign the clean
## ones; reject those hiding a trap. Signing a trap is expensive — practice
## for the contracts you sign when buying a business.

const TIME := 6.0
const CLEAN := [
	"Поставка оборудования в течение 30 дней",
	"Оплата двумя частями после приёмки",
	"Гарантия на работы — 12 месяцев",
	"Скидка 5% при оплате вперёд",
	"Доставка за счёт поставщика",
	"Обучение персонала включено в цену",
	"Расторжение по соглашению сторон",
	"Цена фиксирована на весь срок договора",
	"Ежемесячный отчёт о выполнении работ",
	"Техническая поддержка круглосуточно",
]
const TRAPS := [
	"Штраф 300% от суммы за любую задержку",
	"Оплата переводом на счёт в офшоре",
	"Всё ваше имущество переходит в залог",
	"Вы погашаете долги предыдущего владельца",
	"Договор нельзя расторгнуть 50 лет",
	"Поставщик вправе менять цену без согласия",
	"Предоплата 100%, срок поставки не указан",
]

var _lines: Array = []
var _bad := false
var _left := TIME
var _number := 100
var _slide := 0.0


func setup() -> void:
	_new_doc()


func _new_doc() -> void:
	var pool := CLEAN.duplicate()
	pool.shuffle()
	_lines = pool.slice(0, 4)
	_bad = randf() < 0.45
	if _bad:
		_lines[randi() % 4] = TRAPS[randi() % TRAPS.size()]
	_left = TIME
	_number = randi_range(100, 999)
	_slide = 1.0


func step(delta: float) -> void:
	_slide = maxf(0.0, _slide - delta * 4.0)
	_left -= delta
	if _left <= 0.0:
		give(0.0, _paper().get_center(), "Партнёр не дождался")
		_new_doc()


func _paper() -> Rect2:
	return Rect2(size.x * 0.06 + _slide * size.x, 80, size.x * 0.88, size.y - 330)


func _buttons() -> Array[Rect2]:
	var y := size.y - 200
	return [Rect2(size.x * 0.06, y, size.x * 0.42, 150), Rect2(size.x * 0.52, y, size.x * 0.42, 150)]


func tap(at: Vector2) -> void:
	var b := _buttons()
	var where := _paper().get_center()
	if b[1].has_point(at):
		if _bad:
			give(-pay * 4.0, where, "Подвох! Ты подписал ловушку")
		else:
			give(pay, where, "Подписано")
		_new_doc()
	elif b[0].has_point(at):
		if _bad:
			give(pay * 1.5, where, "Ловушка раскрыта!")
		else:
			give(-pay, where, "Упустил хорошую сделку")
		_new_doc()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#2a2234"))
	var p := _paper()
	rounded(p, Color("#f7f3e8"), 18)
	text("ДОГОВОР № %d" % _number, Vector2(p.get_center().x, p.position.y + 60), 40, Color("#2b2d42"), 900)
	draw_line(p.position + Vector2(50, 100), Vector2(p.end.x - 50, p.position.y + 100), Color(0, 0, 0, 0.2), 3)
	var y := p.position.y + 150
	for i in _lines.size():
		var f := UI.font(600)
		draw_string(f, Vector2(p.position.x + 50, y), "%d. %s" % [i + 1, _lines[i]], HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 100, 34, Color("#3a3a48"))
		y += 64
	# Signature line and a timer.
	draw_line(Vector2(p.end.x - 360, p.end.y - 70), Vector2(p.end.x - 60, p.end.y - 70), Color(0, 0, 0, 0.4), 3)
	var k := clampf(_left / TIME, 0.0, 1.0)
	rounded(Rect2(p.position.x + 50, p.end.y - 84, (p.size.x - 480) * k, 14), GREEN.lerp(RED, 1.0 - k), 7)
	var b := _buttons()
	rounded(b[0], RED, 75)
	text("Отклонить", b[0].get_center(), 44, Color.WHITE, 900)
	rounded(b[1], GREEN, 75)
	text("Подписать", b[1].get_center(), 44, Color("#0b3b2a"), 900)
	hint("Читай внимательно: в некоторых договорах спрятан подвох")
