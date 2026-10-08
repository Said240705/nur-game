extends RefCounted
## The purchase agreement for a business. Most clauses are boilerplate; now and
## then the seller slips in a trap, worded as blandly as the rest:
##   debt   — you take over the seller's debts (paid at once),
##   rent   — you pay the seller rent for the premises every day, forever,
##   repair — the place is shut for repairs for some days.
## Sometimes there is a pleasant surprise instead: stock left for you.

const Data := preload("res://scripts/game/data.gd")

const BOILERPLATE := [
	"Продавец передаёт Покупателю бизнес «{biz}» со всем оборудованием, вывеской и клиентской базой.",
	"Стоимость сделки составляет {price}. Оплата производится в момент подписания настоящего договора.",
	"Персонал сохраняет рабочие места на прежних условиях не менее шести месяцев.",
	"Продавец гарантирует, что бизнес не находится под арестом и не участвует в судебных спорах.",
	"Стороны подтверждают, что не имеют друг к другу иных претензий.",
	"Договор вступает в силу с момента подписания и составлен в двух экземплярах.",
]


## A contract for buying `biz` at `price`; `risky` deals hide traps more often.
static func make(biz: String, price: float, risky: bool) -> Dictionary:
	var b := Data.business(biz)
	var clauses := []
	for c in BOILERPLATE:
		clauses.append(c.replace("{biz}", b["name"]).replace("{price}", Data.money(price)))
	var trap := {}
	var roll := randf()
	var trap_chance := 0.5 if risky else 0.3
	if roll < trap_chance:
		match randi() % 3:
			0:
				var debt := roundf(price * randf_range(0.4, 0.9))
				trap = {"kind": "debt", "value": debt,
					"text": "Покупатель принимает на себя обязательства Продавца перед поставщиками и кредиторами в размере %s." % Data.money(debt)}
			1:
				var rent := roundf(b["income"] * randf_range(0.35, 0.7))
				trap = {"kind": "rent", "value": rent,
					"text": "Помещение остаётся в собственности Продавца; Покупатель вносит арендную плату %s в день бессрочно." % Data.money(rent)}
			2:
				var days := randi_range(8, 15)
				trap = {"kind": "repair", "value": float(days),
					"text": "Объект передаётся в текущем техническом состоянии; деятельность возобновляется после ремонта сроком %d дней." % days}
	elif roll > 0.85:
		var stock := roundf(price * randf_range(0.1, 0.25))
		trap = {"kind": "bonus", "value": stock,
			"text": "Продавец оставляет Покупателю складской запас товара на сумму %s." % Data.money(stock)}
	if not trap.is_empty():
		clauses.insert(randi_range(2, 4), trap["text"])
	var numbered := []
	for i in clauses.size():
		numbered.append("%d. %s" % [i + 1, clauses[i]])
	return {"biz": biz, "price": price, "clauses": numbered, "trap": trap}


## Whether the contract has a clause that hurts the buyer.
static func is_bad(c: Dictionary) -> bool:
	return not c["trap"].is_empty() and c["trap"]["kind"] != "bonus"


## Puts what was signed into effect; returns a sentence about it, or "".
static func apply(c: Dictionary, s: RefCounted) -> String:
	var t: Dictionary = c["trap"]
	if t.is_empty():
		return ""
	var biz: String = c["biz"]
	match t["kind"]:
		"debt":
			s.cash -= t["value"]
			return "Ты подписал не читая: к бизнесу прилагались долги. −%s" % Data.money(t["value"])
		"rent":
			s.rents[biz] = t["value"]
			return "Помещение не твоё: теперь ты платишь продавцу аренду %s каждый день." % Data.money(t["value"])
		"repair":
			s.repairs[biz] = int(t["value"])
			return "Бизнес на ремонте: %d дней без дохода." % int(t["value"])
		"bonus":
			s.cash += t["value"]
			return "Приятный сюрприз: продавец оставил товар на %s!" % Data.money(t["value"])
	return ""
