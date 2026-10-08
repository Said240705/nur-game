extends RefCounted
## One business at one address, and what happens there in a day.
##
## Who comes in: passers-by of the district × the share this kind of business
## attracts × how well it fits the district's wealth × how inviting the
## renovation is × rating × price × advertising, with a bit of chance.
## Who is served: no more than the staff can handle and the stock allows.
## What it costs: salaries, rent, electricity, water and advertising every day,
## open or not; goods are paid for when stock is bought.

const Data := preload("res://scripts/game/data.gd")


static func make(id: int, type: String, plot: int, price: float) -> Dictionary:
	var staff := {}
	for r in Data.roles(Data.business(type)):
		staff[r["id"]] = 0
	return {"id": id, "type": type, "plot": plot, "reno": 0, "staff": staff, "price_lv": 2, "ads": 0,
		"stock": 0.0, "rating": 3.0, "closed": 0, "extra_rent": 0.0, "invested": price, "report": {}, "expect": 0.0}


static func kind(v: Dictionary) -> Dictionary:
	return Data.business(v["type"])


static func district(v: Dictionary) -> Dictionary:
	return Data.DISTRICTS[Data.plot(v["plot"])["d"]]


static func title(v: Dictionary) -> String:
	return "%s · %s" % [kind(v)["name"], district(v)["name"]]


static func uses_stock(v: Dictionary) -> bool:
	return kind(v)["unit"] > 0.0


static func capacity(v: Dictionary) -> float:
	var c := 0.0
	for r in kind(v)["roles"]:
		if r["kind"] == "serve":
			c += r["cap"] * v["staff"].get(r["id"], 0)
	return c


static func quality_staff(v: Dictionary) -> int:
	var n := 0
	for r in kind(v)["roles"]:
		if r["kind"] == "quality":
			n += v["staff"].get(r["id"], 0)
	return mini(n, 2)


static func has_manager(v: Dictionary) -> bool:
	return v["staff"].get("manager", 0) > 0


## How well the clientele fits the people living around (1 = perfect).
static func fit(v: Dictionary) -> float:
	return maxf(0.15, 1.0 - 0.25 * absi(district(v)["wealth"] - kind(v)["cls"]))


static func demand(v: Dictionary, boost := 1.0) -> float:
	var b := kind(v)
	var d := district(v)
	var price_f := pow(Data.PRICES[v["price_lv"]]["mult"], -1.5)
	return d["traffic"] * b["reach"] * fit(v) * Data.RENOVATION[v["reno"]]["appeal"] * (0.5 + v["rating"] / 5.0) \
		* price_f * Data.ADS[v["ads"]]["effect"] * boost


## The average bill: richer districts pay a little more.
static func ticket(v: Dictionary) -> float:
	return kind(v)["ticket"] * (0.8 + 0.1 * district(v)["wealth"]) * Data.PRICES[v["price_lv"]]["mult"]


static func salaries(v: Dictionary) -> float:
	var total := 0.0
	for r in Data.roles(kind(v)):
		total += r["salary"] * v["staff"].get(r["id"], 0)
	return total


static func rent(v: Dictionary) -> float:
	return Data.plot_rent(Data.plot(v["plot"])) + v["extra_rent"]


static func ads_cost(v: Dictionary) -> float:
	var b := kind(v)
	return Data.ADS[v["ads"]]["cost"] * b["ticket"] * district(v)["traffic"] * b["reach"]


## Why the place cannot work today, or "" if it can.
static func blocker(v: Dictionary) -> String:
	if v["closed"] > 0:
		return "Ремонт: ещё %d дн." % v["closed"]
	if capacity(v) <= 0.0:
		return "Нет персонала — найми сотрудников"
	if uses_stock(v) and v["stock"] < 1.0:
		return "Склад пуст — закупи товар"
	return ""


## Goods for `days` of expected demand; a week's order comes 10% cheaper.
static func restock(v: Dictionary, days: int) -> Dictionary:
	var expect := maxf(v["expect"], minf(demand(v), capacity(v)) if capacity(v) > 0.0 else demand(v))
	var qty := ceilf(maxf(expect, 5.0) * days)
	var cost: float = qty * kind(v)["unit"] * (0.9 if days >= 7 else 1.0)
	return {"qty": qty, "cost": cost}


## Plays out one day; returns the report. `boost` comes from life events.
static func day(v: Dictionary, boost: float) -> Dictionary:
	var b := kind(v)
	var why := blocker(v)
	var want := demand(v, boost) * randf_range(0.85, 1.15)
	var served := 0.0
	if why == "":
		served = minf(want, capacity(v))
		if uses_stock(v):
			served = minf(served, v["stock"])
		served = floorf(served) if served >= 1.0 else served
	var revenue := served * ticket(v)
	var goods: float = served * b["unit"]
	if uses_stock(v):
		v["stock"] = maxf(0.0, v["stock"] - served)
	var open := why == "" or why.begins_with("Склад")
	var load := served / maxf(capacity(v), 1.0)
	var power: float = Data.power(b) * (0.8 + 0.2 * v["reno"]) * (1.0 if open else 0.3)
	var water: float = Data.water(b) * (0.3 + 0.7 * clampf(load, 0.0, 1.0))
	var ads := ads_cost(v) if v["closed"] <= 0 else 0.0
	var costs := salaries(v) + rent(v) + power + water + ads
	var lost := maxf(0.0, want - served) if why == "" or why.begins_with("Склад") else 0.0
	# The rating drifts toward what the place deserves.
	if v["closed"] <= 0 and capacity(v) > 0.0:
		var target: float = 1.6 + Data.RENOVATION[v["reno"]]["rating"] + quality_staff(v) * 0.5 + (0.3 if has_manager(v) else 0.0)
		var expensive := maxi(0, v["price_lv"] - 2)
		target -= expensive * 0.45 * (1.0 - v["reno"] / 3.0)
		target += maxi(0, 2 - v["price_lv"]) * 0.15
		target -= clampf(lost / maxf(want, 1.0), 0.0, 1.0) * 1.8
		v["rating"] = clampf(v["rating"] + (clampf(target, 1.0, 5.0) - v["rating"]) * 0.15, 1.0, 5.0)
	if v["closed"] > 0:
		v["closed"] -= 1
	v["expect"] = lerpf(v["expect"], minf(want, maxf(capacity(v), 1.0)), 0.5) if v["expect"] > 0.0 else minf(want, maxf(capacity(v), 1.0))
	var report := {"revenue": revenue, "goods": goods, "salaries": salaries(v), "rent": rent(v), "power": power,
		"water": water, "ads": ads, "served": served, "want": want, "lost": lost, "why": why,
		"cash": revenue - costs, "profit": revenue - goods - costs}
	v["report"] = report
	return report


## What the business would sell for.
static func value(v: Dictionary) -> float:
	return v["invested"] * 0.6
