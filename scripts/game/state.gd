extends RefCounted
## The player's life as data: cash, the businesses (venues) at their addresses,
## property, temporary boosts from events, debt, and what a day brings.

const Data := preload("res://scripts/game/data.gd")
const Venue := preload("res://scripts/game/venue.gd")

var cash := Data.START_CASH
var day := 1
## Businesses the player runs (see venue.gd).
var venues: Array = []
## Property id -> true.
var owned := {}
## [[multiplier, days left], …]: events making customers come more or less.
var boosts: Array = []
var debt_days := 0
var best_worth := 0.0
var bankrupt := false
var _next_id := 1
## Totals of the last day for the header.
var last_day := {"cash": 0.0, "profit": 0.0}


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


func venue(id: int) -> Dictionary:
	for v in venues:
		if v["id"] == id:
			return v
	return {}


func venue_at(plot: int) -> Dictionary:
	for v in venues:
		if v["plot"] == plot:
			return v
	return {}


func upkeep() -> float:
	var total := 0.0
	for id in owned:
		total += Data.property(id)["upkeep"]
	return total


## Cash plus what businesses and property would sell for.
func worth() -> float:
	var w := cash
	for v in venues:
		w += Venue.value(v) + v["stock"] * Venue.kind(v)["unit"]
	for id in owned:
		w += Data.property(id)["price"] * 0.6
	return w


## One day passes. Returns the cash change.
func next_day() -> float:
	var before := cash
	var profit := 0.0
	# Status (prestige from property) brings more customers everywhere.
	var crowd := boost() * (1.0 + prestige())
	for v in venues:
		_auto_restock(v)
		var r := Venue.day(v, crowd)
		cash += r["cash"]
		profit += r["profit"]
	cash -= upkeep()
	profit -= upkeep()
	day += 1
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
	last_day = {"cash": cash - before, "profit": profit}
	return cash - before


## A manager orders goods for five days when less than two are left.
func _auto_restock(v: Dictionary) -> void:
	if not Venue.has_manager(v) or not Venue.uses_stock(v):
		return
	var r := Venue.restock(v, 5)
	if v["stock"] < r["qty"] * 0.4 and cash >= r["cost"]:
		cash -= r["cost"]
		v["stock"] += r["qty"]


# --- Running a business ------------------------------------------------------------

## Opens a business on a free plot. `ready` sets it up as a going concern.
func open_venue(type: String, plot: int, price: float, ready := false) -> Dictionary:
	if cash < price or not venue_at(plot).is_empty():
		return {}
	cash -= price
	var v := Venue.make(_next_id, type, plot, price)
	_next_id += 1
	if ready:
		v["reno"] = 1
		var serve: Dictionary = Venue.kind(v)["roles"][0]
		v["staff"][serve["id"]] = maxi(1, ceili(Venue.demand(v) / serve["cap"]))
		if Venue.uses_stock(v):
			v["stock"] = ceilf(minf(Venue.demand(v), Venue.capacity(v)) * 3.0)
	venues.append(v)
	return v


func hire(v: Dictionary, role: String, delta: int) -> bool:
	var n: int = v["staff"].get(role, 0) + delta
	var limit := 1 if role == "manager" else Data.MAX_STAFF
	if n < 0 or n > limit:
		return false
	v["staff"][role] = n
	return true


func buy_stock(v: Dictionary, days: int) -> bool:
	var r := Venue.restock(v, days)
	if cash < r["cost"]:
		return false
	cash -= r["cost"]
	v["stock"] += r["qty"]
	return true


func renovation_cost(v: Dictionary) -> float:
	if v["reno"] >= Data.RENOVATION.size() - 1:
		return -1.0
	return Venue.kind(v)["price"] * Data.RENOVATION[v["reno"] + 1]["cost"]


func renovate(v: Dictionary) -> bool:
	var c := renovation_cost(v)
	if c < 0.0 or cash < c or v["closed"] > 0:
		return false
	cash -= c
	v["reno"] += 1
	v["closed"] = Data.RENOVATION[v["reno"]]["days"]
	v["invested"] += c
	return true


func sell_venue(v: Dictionary, price := -1.0) -> float:
	var got := Venue.value(v) if price < 0.0 else price
	cash += got + v["stock"] * Venue.kind(v)["unit"] * 0.5
	venues.erase(v)
	return got


func buy_property(id: String, price := -1.0) -> bool:
	var p: float = Data.property(id)["price"] if price < 0.0 else price
	if owned.has(id) or cash < p:
		return false
	cash -= p
	owned[id] = true
	return true


## Applies what an event did. `amount` is the event's sum, `biz` the venue id.
func apply(outcome: Dictionary, amount: float, biz: int) -> void:
	cash += outcome.get("cash", 0.0) * amount
	if outcome.has("boost"):
		boosts.append([outcome["boost"][0], outcome["boost"][1]])
	var v := venue(biz)
	if v.is_empty():
		return
	if outcome.has("level"):
		v["rating"] = clampf(v["rating"] + 0.8 * outcome["level"], 1.0, 5.0)
	if outcome.get("sell", false):
		sell_venue(v, amount)
	if outcome.has("quit"):
		for r in Venue.kind(v)["roles"]:
			if v["staff"].get(r["id"], 0) > 0:
				v["staff"][r["id"]] -= 1
				break


func to_dict() -> Dictionary:
	return {"cash": cash, "day": day, "venues": venues, "owned": owned.keys(), "boosts": boosts,
		"debt_days": debt_days, "best_worth": best_worth, "next_id": _next_id,
		"saved_at": Time.get_unix_time_from_system()}


static func from_dict(d: Dictionary) -> RefCounted:
	var s: RefCounted = load("res://scripts/game/state.gd").new()
	s.cash = d.get("cash", Data.START_CASH)
	s.day = d.get("day", 1)
	s.venues = d.get("venues", [])
	for v in s.venues:
		v["id"] = int(v["id"])
		v["plot"] = int(v["plot"])
		v["reno"] = int(v["reno"])
		v["price_lv"] = int(v["price_lv"])
		v["ads"] = int(v["ads"])
		v["closed"] = int(v["closed"])
		for r in v["staff"]:
			v["staff"][r] = int(v["staff"][r])
	for id in d.get("owned", []):
		s.owned[id] = true
	s.boosts = d.get("boosts", [])
	s.debt_days = d.get("debt_days", 0)
	s.best_worth = d.get("best_worth", 0.0)
	s._next_id = d.get("next_id", 1)
	return s
