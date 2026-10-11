extends RefCounted
## The player's life as data: cash, the businesses (venues) at their addresses,
## property, temporary boosts from events, debt, and what a day brings.

const Data := preload("res://scripts/game/data.gd")
const Venue := preload("res://scripts/game/venue.gd")
const Cars := preload("res://scripts/game/cars.gd")
const Origin := preload("res://scripts/game/origin.gd")

var cash := Data.START_CASH
## Where the hero started (see origin.gd) and the trouble meter of that start.
var origin := "street"
var mind := 100.0
## Story beats already shown: id -> true.
var story := {}
## Set by a story beat: the trouble melts half as fast from then on.
var calm := false
## What a crisis took when the meter hit zero; -1 when none waits to be shown.
var crisis := -1.0
## Short lines for the screen about what happened during a day.
var news: Array = []
## True while the days the player was away are played out: no crisis then.
var away := false
var day := 1
## Businesses the player runs (see venue.gd).
var venues: Array = []
## Property id -> true (homes and vehicles alike).
var owned := {}
## Vehicles: class id -> the car bought (see cars.gd), with its condition.
var garage := {}
## A vehicle that broke down today and waits for a decision ("" if none).
var pending_break := ""
## [[multiplier, days left], …]: events making customers come more or less.
var boosts: Array = []
var debt_days := 0
## How rested the hero is (0…100); a shift at work takes some.
var energy := 100.0
## During a shift the hero works instead of resting; the shift's energy is
## spent bit by bit while it lasts.
var on_shift := false
var shift_cost := 0.0
var best_worth := 0.0
var bankrupt := false
var _next_id := 1
## Totals of the last day for the header.
var last_day := {"cash": 0.0, "profit": 0.0}


## Money, home and car of a start.
func setup(id: String) -> void:
	origin = id
	var o := Origin.info(id)
	cash = o["cash"]
	if o.has("start_home"):
		owned[o["start_home"]] = true
	if o.has("start_ride"):
		var car := Cars.make(o["start_ride"], false)
		car["issue"] = ""
		car["condition"] = 5
		car["year"] = Cars.YEAR - 1
		car["km"] = 9000
		garage[o["start_ride"]] = car
		owned[o["start_ride"]] = true


func rank() -> int:
	return Data.rank_of(worth())


func rank_name(r: int) -> String:
	return Origin.info(origin)["rank0"] if r == 0 else Data.RANKS[r]["name"]


func has_home() -> bool:
	for id in owned:
		if Data.property(id)["kind"] == "home":
			return true
	return false


## An oligarch's son can buy anything at once; others wait for the status.
func unlocked(p: Dictionary) -> bool:
	return origin == "rich" or rank() >= p["rank"]


func care_cost() -> float:
	return Origin.care_cost(origin, worth())


## Pays for care (a shelter, help for the family, a psychologist).
func care() -> bool:
	var cost := care_cost()
	if cash < cost or mind >= 100.0:
		return false
	cash -= cost
	mind = minf(100.0, mind + Origin.info(origin)["care_gain"])
	return true


## The meter needs no paid care: a homeless hero with a home heals by himself.
func self_healing() -> bool:
	return origin == "street" and has_home()


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


## Energy back per day: a little anyway, more in a better home or on a yacht.
func rest() -> float:
	var r := Data.REST
	for id in owned:
		r += Data.property(id).get("rest", 0.0)
	for cls in _working_vehicles():
		r += Cars.CLASSES[cls]["rest"]
	if mind >= Origin.LOW:
		r += Origin.info(origin).get("home_rest", 0.0)
	else:
		r *= 0.5
	return r


func _working_vehicles() -> Array:
	return garage.keys().filter(func(cls: String) -> bool: return garage[cls]["broken"] <= 0)


## Energy a shift takes: own transport makes getting to work less tiring.
func shift_energy() -> float:
	var e := Data.SHIFT_ENERGY
	for cls in _working_vehicles():
		e -= Cars.CLASSES[cls]["save"]
	return maxf(15.0, e)


func has_car() -> bool:
	return _working_vehicles().any(func(cls: String) -> bool: return cls in ["oldcar", "car", "sportcar"])


## Shift pay multiplier from vehicles; a taxi driver without a car rents one.
func work_mult(game: String) -> float:
	var m := 1.0
	for cls in _working_vehicles():
		m += Cars.CLASSES[cls]["pay"]
	if game == "taxi" and not has_car():
		m *= 0.7
	return m


func can_work() -> bool:
	return energy >= shift_energy()


func start_shift() -> bool:
	if not can_work() or on_shift:
		return false
	on_shift = true
	shift_cost = shift_energy()
	return true


## Spends the share of the shift's energy for `seconds` of work.
func tire(seconds: float) -> void:
	energy = maxf(0.0, energy - shift_cost * seconds / Data.SHIFT_TIME)


func end_shift() -> void:
	on_shift = false


## Buys a vehicle; the old one of the same class is sold for half its price.
func buy_vehicle(car: Dictionary, price: float) -> bool:
	if cash < price:
		return false
	cash -= price
	var cls: String = car["cls"]
	if garage.has(cls):
		cash += garage[cls]["price"] * 0.5
	garage[cls] = car
	owned[cls] = true
	return true


func lose_vehicle(cls: String) -> void:
	garage.erase(cls)
	owned.erase(cls)


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
	if not on_shift:
		energy = minf(100.0, energy + rest())
	# Vehicles in worse shape break down more often.
	for cls in garage:
		var car: Dictionary = garage[cls]
		if car["broken"] > 0:
			car["broken"] -= 1
		elif pending_break == "" and cls != "bike" and randf() < (6 - car["condition"]) * 0.004:
			pending_break = cls
	_melt()
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


## The trouble of the start grows a little every day.
func _melt() -> void:
	var o := Origin.info(origin)
	if self_healing():
		mind = minf(100.0, mind + 2.0)
		return
	mind -= o["melt"] * (0.5 if calm else 1.0)
	# Feeling empty, the oligarch's son buys things he does not need.
	if o.has("impulse") and mind < Origin.LOW and cash > 0.0 and randf() < 0.15:
		var spent := roundf(maxf(20000.0, cash * 0.03) / 100.0) * 100.0
		cash -= spent
		news.append("%s: −%s" % [o["impulse"], Data.money(spent)])
	if mind > 0.0:
		return
	if away:
		mind = 1.0
		return
	var lost: float = maxf(cash, 0.0) * o["crisis_cash"]
	cash -= lost
	energy = 0.0
	mind = 60.0
	crisis = lost


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
		"debt_days": debt_days, "best_worth": best_worth, "next_id": _next_id, "energy": energy, "garage": garage,
		"origin": origin, "mind": mind, "story": story.keys(), "calm": calm,
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
	s.energy = d.get("energy", 100.0)
	s.garage = d.get("garage", {})
	for cls in s.garage:
		s.owned[cls] = true
	s.best_worth = d.get("best_worth", 0.0)
	s._next_id = d.get("next_id", 1)
	# Lives started before the choice of start began on the street.
	s.origin = d.get("origin", "street")
	s.mind = d.get("mind", 100.0)
	for id in d.get("story", ["s_start"]):
		s.story[id] = true
	s.calm = d.get("calm", false)
	return s
