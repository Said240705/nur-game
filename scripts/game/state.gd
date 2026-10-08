extends RefCounted
## The player's life as data: cash, businesses with levels, property, temporary
## income boosts, debt, and what a day of business brings in and costs.

const Data := preload("res://scripts/game/data.gd")

var cash := Data.START_CASH
var day := 1
## Business id -> level.
var businesses := {}
## Property id -> true.
var owned := {}
## Hidden contract terms the player signed: business id -> rent per day,
## business id -> days closed for repairs.
var rents := {}
var repairs := {}
## [[multiplier, days left], …]
var boosts: Array = []
var debt_days := 0
var best_worth := 0.0
var bankrupt := false


func rank() -> int:
	return Data.rank_of(worth())


func prestige() -> float:
	var p := 0.0
	for id in owned:
		p += Data.property(id)["prestige"]
	return p


func boost() -> float:
	var m := 1.0
	for b in boosts:
		m *= b[0]
	return m


func daily_income() -> float:
	var total := 0.0
	for id in businesses:
		if repairs.get(id, 0) <= 0:
			total += Data.income_at(Data.business(id), businesses[id])
	return total * (1.0 + prestige()) * boost()


func daily_costs() -> float:
	var total := 0.0
	for id in owned:
		total += Data.property(id)["upkeep"]
	for id in rents:
		if businesses.has(id):
			total += rents[id]
	return total


## Cash plus what businesses and property would sell for.
func worth() -> float:
	var w := cash
	for id in businesses:
		var b := Data.business(id)
		w += b["price"] * (1.0 + 0.3 * (businesses[id] - 1)) * 0.8
	for id in owned:
		w += Data.property(id)["price"] * 0.6
	return w


## One day passes. Returns the cash change.
func next_day() -> float:
	var delta := daily_income() - daily_costs()
	cash += delta
	day += 1
	for id in repairs.keys():
		repairs[id] -= 1
		if repairs[id] <= 0:
			repairs.erase(id)
	for b in boosts:
		b[1] -= 1
	boosts = boosts.filter(func(b: Array) -> bool: return b[1] > 0)
	if cash < 0.0:
		debt_days += 1
		if debt_days >= Data.DEBT_DAYS:
			bankrupt = true
	else:
		debt_days = 0
	best_worth = maxf(best_worth, worth())
	return delta


func work_pay() -> float:
	return Data.RANKS[rank()]["pay"]


func buy_business(id: String, price := -1.0) -> bool:
	var b := Data.business(id)
	var p: float = b["price"] if price < 0.0 else price
	if businesses.has(id) or cash < p:
		return false
	cash -= p
	businesses[id] = 1
	return true


func upgrade_cost(id: String) -> float:
	return Data.upgrade_cost(Data.business(id), businesses[id])


func upgrade_business(id: String) -> bool:
	if not businesses.has(id) or businesses[id] >= Data.MAX_LEVEL or cash < upgrade_cost(id):
		return false
	cash -= upgrade_cost(id)
	businesses[id] += 1
	return true


func buy_property(id: String, price := -1.0) -> bool:
	var p: float = Data.property(id)["price"] if price < 0.0 else price
	if owned.has(id) or cash < p:
		return false
	cash -= p
	owned[id] = true
	return true


## Applies what an event did. `amount` is the event's sum, `biz` its business.
func apply(outcome: Dictionary, amount: float, biz: String) -> void:
	cash += outcome.get("cash", 0.0) * amount
	if outcome.has("boost"):
		boosts.append([outcome["boost"][0], outcome["boost"][1]])
	if outcome.has("level") and businesses.has(biz):
		businesses[biz] = clampi(businesses[biz] + outcome["level"], 1, Data.MAX_LEVEL)
	if outcome.get("sell", false) and businesses.has(biz):
		businesses.erase(biz)
		rents.erase(biz)
		repairs.erase(biz)
		cash += amount


func to_dict() -> Dictionary:
	return {"cash": cash, "day": day, "businesses": businesses, "owned": owned.keys(), "boosts": boosts,
		"rents": rents, "repairs": repairs,
		"debt_days": debt_days, "best_worth": best_worth, "saved_at": Time.get_unix_time_from_system()}


static func from_dict(d: Dictionary) -> RefCounted:
	var s: RefCounted = load("res://scripts/game/state.gd").new()
	s.cash = d.get("cash", Data.START_CASH)
	s.day = d.get("day", 1)
	for id in d.get("businesses", {}):
		s.businesses[id] = int(d["businesses"][id])
	for id in d.get("owned", []):
		s.owned[id] = true
	s.boosts = d.get("boosts", [])
	s.rents = d.get("rents", {})
	s.repairs = d.get("repairs", {})
	s.debt_days = d.get("debt_days", 0)
	s.best_worth = d.get("best_worth", 0.0)
	return s
