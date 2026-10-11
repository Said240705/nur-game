extends RefCounted
## The vehicle market: concrete offers with a model, year, mileage, power,
## owners and condition. Sellers hide problems now and then:
##   legal (found by a registry check): pledged to a bank, stolen, unpaid fines;
##   technical (found by a garage diagnosis): mileage rolled back, after a crash.
## What a vehicle gives: more pay per shift, less tiredness, status, rest.

const Data := preload("res://scripts/game/data.gd")

## Per class: model names, years, power and what owning one gives.
## pay — bonus to shift pay, save — energy saved per shift, rest — energy per day.
const CLASSES := {
	"bike": {"models": ["Stels Navigator", "Forward Sporting", "Merida Big Nine"], "years": [2015, 2025], "hp": [0, 0],
		"pay": 0.15, "save": 5.0, "rest": 0.0, "km_year": 1500.0, "legal": false},
	"oldcar": {"models": ["ВАЗ-2107", "ВАЗ-2114", "Daewoo Nexia", "Renault Logan", "Lada Granta"], "years": [2004, 2014], "hp": [70, 106],
		"pay": 0.2, "save": 8.0, "rest": 0.0, "km_year": 18000.0, "legal": true},
	"car": {"models": ["Kia Rio", "Hyundai Solaris", "Toyota Camry", "VW Polo", "Skoda Octavia"], "years": [2016, 2024], "hp": [110, 200],
		"pay": 0.3, "save": 10.0, "rest": 0.0, "km_year": 15000.0, "legal": true},
	"sportcar": {"models": ["BMW M5", "Porsche 911", "Mercedes-AMG GT", "Audi R8"], "years": [2018, 2025], "hp": [450, 620],
		"pay": 0.4, "save": 12.0, "rest": 1.0, "km_year": 8000.0, "legal": true},
	"yacht": {"models": ["Sunseeker 60", "Princess 65", "Azimut 72"], "years": [2012, 2025], "hp": [1200, 2400],
		"pay": 0.0, "save": 0.0, "rest": 4.0, "km_year": 0.0, "legal": true},
	"jet": {"models": ["Cessna Citation", "Embraer Phenom 300", "Gulfstream G280"], "years": [2010, 2025], "hp": [0, 0],
		"pay": 0.1, "save": 10.0, "rest": 6.0, "km_year": 0.0, "legal": true},
}
const YEAR := 2026

const ISSUES := {
	"pledge": {"legal": true, "found": "В базе: машина в залоге у банка. После покупки банк её заберёт.",
		"hit": "Машина была в залоге у банка. Банк её забрал — деньги пропали."},
	"stolen": {"legal": true, "found": "В базе: машина числится в угоне!",
		"hit": "Машина оказалась угнанной. Полиция её изъяла — деньги пропали."},
	"fines": {"legal": true, "found": "В базе: неоплаченные штрафы прежнего владельца на %s.",
		"hit": "На машине висели штрафы прежнего владельца: −%s."},
	"mileage": {"legal": false, "found": "Диагностика: пробег скручен, реальный — больше в 2–3 раза. Состояние хуже, чем кажется.",
		"hit": "Пробег был скручен: машина изношена сильнее и будет часто ломаться."},
	"crash": {"legal": false, "found": "Диагностика: машина после серьёзного ДТП, кузов восстановлен.",
		"hit": "Машина после ДТП: состояние хуже заявленного, ремонты будут чаще."},
}


static func base(cls: String) -> Dictionary:
	return Data.property(cls)


## Three offers for a class. A `risky` offer (hot deal) hides problems more often.
static func offers(cls: String, n := 3) -> Array:
	var out := []
	for i in n:
		out.append(make(cls, false))
	return out


static func make(cls: String, risky: bool) -> Dictionary:
	var c: Dictionary = CLASSES[cls]
	var year := randi_range(c["years"][0], c["years"][1])
	var age := maxi(0, YEAR - year)
	var km := roundi(age * c["km_year"] * randf_range(0.6, 1.4) / 100.0) * 100
	var condition := clampi(5 - age / 4 + randi_range(-1, 0), 1, 5)
	var hp := randi_range(c["hp"][0], c["hp"][1])
	var owners := clampi(1 + age / 5 + randi_range(0, 1), 1, 6)
	var price: float = base(cls)["price"] * (0.55 + 0.1 * condition) * randf_range(0.9, 1.1)
	var issue := ""
	var chance := 0.5 if risky else 0.25
	if cls != "bike" and randf() < chance:
		var pool: Array = ["pledge", "fines", "mileage", "crash"]
		if cls in ["oldcar", "car", "sportcar"]:
			pool.append("stolen")
		issue = pool[randi() % pool.size()]
	return {"cls": cls, "model": c["models"][randi() % c["models"].size()], "year": year, "km": km, "hp": hp,
		"owners": owners, "condition": condition, "price": roundf(price / 1000.0) * 1000.0, "issue": issue,
		"fines": roundf(price * randf_range(0.1, 0.3) / 100.0) * 100.0, "checked_legal": false, "checked_tech": false, "broken": 0}


static func check_cost(car: Dictionary, legal: bool) -> float:
	return roundf(maxf(3000.0 if legal else 6000.0, car["price"] * (0.01 if legal else 0.02)) / 100.0) * 100.0


## What a check found, or "" if it found nothing of its kind.
static func finding(car: Dictionary, legal: bool) -> String:
	var issue: String = car["issue"]
	if issue == "" or ISSUES[issue]["legal"] != legal:
		return ""
	var text: String = ISSUES[issue]["found"]
	return text % Data.money(car["fines"]) if issue == "fines" else text


## What buying it means, in one line for the offer window.
static func perks(cls: String) -> String:
	var c: Dictionary = CLASSES[cls]
	var parts := []
	if c["pay"] > 0.0:
		parts.append("+%d%% к заработку на сменах" % roundi(c["pay"] * 100.0))
	if c["save"] > 0.0:
		parts.append("смена отнимает на %d энергии меньше" % int(c["save"]))
	if c["rest"] > 0.0:
		parts.append("+%d энергии в день от отдыха" % int(c["rest"]))
	parts.append("клиентов в бизнесах +%d%%" % roundi(base(cls)["prestige"] * 100.0))
	return ", ".join(parts)


## Puts a hidden problem into effect after buying; returns what happened, or "".
## Returns {"text", "lost"}: lost = the vehicle was taken away.
static func surprise(car: Dictionary, s: RefCounted) -> Dictionary:
	var issue: String = car["issue"]
	if issue == "":
		return {}
	var text: String = ISSUES[issue]["hit"]
	match issue:
		"pledge", "stolen":
			return {"text": text, "lost": true}
		"fines":
			s.cash -= car["fines"]
			return {"text": text % Data.money(car["fines"]), "lost": false}
		_:
			car["condition"] = maxi(1, car["condition"] - 2)
			return {"text": text, "lost": false}
