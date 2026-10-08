extends RefCounted
## The mine as plain data and a clock. Ore flows in three steps:
##   shafts: a miner walks to the rock, digs, carries the ore back to his crate;
##   lift: rides down, empties the crates into its cage, brings the ore up;
##   cart: a worker carries the ore from the pile at the top to the shop and sells it.
## Without a manager a station only works when tapped; with one it never stops.
## The slowest step limits the income, which is what makes upgrades a choice.

const Eco := preload("res://scripts/game/economy.gd")
const UNLOAD_TIME := 0.5
const BOOST_TIME := 120.0
const BOOST_COOLDOWN := 300.0

var coins := 0.0
var shafts: Array = []
var lift := {}
var cart := {}
## Ore waiting at the top of the lift for the cart.
var pile := 0.0
## Unix time until which sales are doubled, and when the boost can be used again.
var boost_until := 0.0
var boost_ready_at := 0.0
## What happened this frame, for the picture and the sound: {"kind", "amount", "at"}.
var events: Array = []


func _init() -> void:
	shafts.append(_new_shaft())
	lift = {"level": 1, "manager": false, "load": 0.0, "phase": "idle", "y": -1.0, "target": -1, "t": 0.0}
	cart = {"level": 1, "manager": false, "carry": 0.0, "phase": "idle", "t": 0.0}


func _new_shaft() -> Dictionary:
	return {"level": 1, "manager": false, "stock": 0.0, "phase": "idle", "t": 0.0}


static func now() -> float:
	return Time.get_unix_time_from_system()


func boost_factor() -> float:
	return 2.0 if now() < boost_until else 1.0


func start_boost() -> bool:
	if now() < boost_ready_at:
		return false
	boost_until = now() + BOOST_TIME
	boost_ready_at = now() + BOOST_TIME + BOOST_COOLDOWN
	return true


# --- Clock ----------------------------------------------------------------------

func tick(delta: float) -> void:
	for i in shafts.size():
		_tick_shaft(i, delta)
	_tick_lift(delta)
	_tick_cart(delta)


func _tick_shaft(i: int, delta: float) -> void:
	var s: Dictionary = shafts[i]
	if s["phase"] == "idle":
		if not s["manager"]:
			return
		s["phase"] = "walk"
		s["t"] = 0.0
	s["t"] += delta
	match s["phase"]:
		"walk":
			if s["t"] >= Eco.WALK:
				s["phase"] = "dig"
				s["t"] -= Eco.WALK
		"dig":
			if s["t"] >= Eco.DIG:
				s["phase"] = "back"
				s["t"] -= Eco.DIG
		"back":
			if s["t"] >= Eco.WALK:
				var got := Eco.shaft_output(i, s["level"])
				s["stock"] += got
				s["phase"] = "idle"
				s["t"] = 0.0
				events.append({"kind": "deposit", "amount": got, "at": i})


func _tick_lift(delta: float) -> void:
	match lift["phase"]:
		"idle":
			if lift["manager"] and _next_stop(-1) >= 0:
				_send_lift()
		"move":
			var target := float(lift["target"])
			var step := Eco.lift_speed(lift["level"]) * delta
			lift["y"] = move_toward(lift["y"], target, step)
			if is_equal_approx(lift["y"], target):
				lift["phase"] = "unload" if lift["target"] < 0 else "load"
				lift["t"] = 0.0
		"load":
			lift["t"] += delta
			if lift["t"] >= Eco.LIFT_LOAD_TIME:
				var s: Dictionary = shafts[lift["target"]]
				var room: float = Eco.lift_capacity(lift["level"]) - lift["load"]
				var take := minf(room, s["stock"])
				s["stock"] -= take
				lift["load"] += take
				var full: bool = lift["load"] >= Eco.lift_capacity(lift["level"]) - 0.001
				lift["target"] = -1 if full else _next_stop(lift["target"])
				lift["phase"] = "move"
		"unload":
			lift["t"] += delta
			if lift["t"] >= UNLOAD_TIME:
				pile += lift["load"]
				if lift["load"] > 0.0:
					events.append({"kind": "lift", "amount": lift["load"], "at": -1})
				lift["load"] = 0.0
				lift["phase"] = "idle"


## The next shaft below `from` that has ore waiting, or -1 (go up).
func _next_stop(from: int) -> int:
	for j in range(from + 1, shafts.size()):
		if shafts[j]["stock"] > 0.0:
			return j
	return -1


func _send_lift() -> void:
	var first := _next_stop(-1)
	lift["target"] = first if first >= 0 else 0
	lift["phase"] = "move"


func _tick_cart(delta: float) -> void:
	var walk := Eco.cart_walk(cart["level"])
	match cart["phase"]:
		"idle":
			if cart["manager"] and pile > 0.0:
				cart["phase"] = "go"
				cart["t"] = 0.0
		"go":
			cart["t"] += delta
			if cart["t"] >= walk:
				var take := minf(Eco.cart_capacity(cart["level"]), pile)
				pile -= take
				cart["carry"] = take
				cart["phase"] = "return"
				cart["t"] -= walk
		"return":
			cart["t"] += delta
			if cart["t"] >= walk:
				var earned: float = cart["carry"] * boost_factor()
				coins += earned
				cart["carry"] = 0.0
				cart["phase"] = "idle"
				if earned > 0.0:
					events.append({"kind": "sold", "amount": earned, "at": -2})


# --- Taps -----------------------------------------------------------------------

## A tap wakes an idle worker for one round. Returns true if it started.
func tap(id: String) -> bool:
	if id.begins_with("shaft:"):
		var s: Dictionary = shafts[int(id.get_slice(":", 1))]
		if s["phase"] == "idle":
			s["phase"] = "walk"
			s["t"] = 0.0
			return true
	elif id == "lift" and lift["phase"] == "idle":
		_send_lift()
		return true
	elif id == "cart" and cart["phase"] == "idle":
		cart["phase"] = "go"
		cart["t"] = 0.0
		return true
	return false


# --- Upgrades -------------------------------------------------------------------

func level(id: String) -> int:
	return _station(id)["level"]


func has_manager(id: String) -> bool:
	return _station(id)["manager"]


func _station(id: String) -> Dictionary:
	if id.begins_with("shaft:"):
		return shafts[int(id.get_slice(":", 1))]
	return lift if id == "lift" else cart


func _cost_at(id: String, lvl: int) -> float:
	if id.begins_with("shaft:"):
		return Eco.shaft_cost(int(id.get_slice(":", 1)), lvl)
	return Eco.lift_cost(lvl) if id == "lift" else Eco.cart_cost(lvl)


## Price of the next `n` levels together.
func cost(id: String, n := 1) -> float:
	var total := 0.0
	var l := level(id)
	for k in n:
		total += _cost_at(id, l + k)
	return total


## How many levels the coins in hand can buy right now (capped).
func affordable(id: String, cap := 500) -> int:
	var total := 0.0
	var l := level(id)
	var n := 0
	while n < cap:
		total += _cost_at(id, l + n)
		if total > coins:
			break
		n += 1
	return n


func upgrade(id: String, n := 1) -> bool:
	var price := cost(id, n)
	if n <= 0 or price > coins:
		return false
	coins -= price
	_station(id)["level"] += n
	return true


func manager_cost(id: String) -> float:
	if id.begins_with("shaft:"):
		return Eco.shaft_manager_cost(int(id.get_slice(":", 1)))
	return Eco.LIFT_MANAGER if id == "lift" else Eco.CART_MANAGER


func hire(id: String) -> bool:
	var st := _station(id)
	if st["manager"] or manager_cost(id) > coins:
		return false
	coins -= manager_cost(id)
	st["manager"] = true
	return true


func next_shaft_cost() -> float:
	if shafts.size() >= Eco.ORES.size():
		return -1.0
	return Eco.ORES[shafts.size()]["unlock"]


func open_shaft() -> bool:
	var price := next_shaft_cost()
	if price < 0.0 or price > coins:
		return false
	coins -= price
	shafts.append(_new_shaft())
	return true


# --- Rates and time away ----------------------------------------------------------

func shaft_rate(i: int) -> float:
	return Eco.shaft_output(i, shafts[i]["level"]) / Eco.shaft_cycle()


func lift_rate() -> float:
	var depth := float(shafts.size())
	var trip := 2.0 * depth / Eco.lift_speed(lift["level"]) + Eco.LIFT_LOAD_TIME * shafts.size() + UNLOAD_TIME
	return Eco.lift_capacity(lift["level"]) / trip


func cart_rate() -> float:
	return Eco.cart_capacity(cart["level"]) / (2.0 * Eco.cart_walk(cart["level"]))


## Coins per second once everything runs on its own (0 until the lift and the
## shop have managers); the slowest step decides.
func income() -> float:
	if not lift["manager"] or not cart["manager"]:
		return 0.0
	var dug := 0.0
	for i in shafts.size():
		if shafts[i]["manager"]:
			dug += shaft_rate(i)
	return minf(dug, minf(lift_rate(), cart_rate()))


## Runs the managed stations for the time the game was closed; returns the coins earned.
func catch_up(seconds: float) -> float:
	var t := clampf(seconds, 0.0, Eco.OFFLINE_CAP)
	if t < 10.0:
		return 0.0
	for i in shafts.size():
		if shafts[i]["manager"]:
			shafts[i]["stock"] += shaft_rate(i) * t
	if lift["manager"]:
		var budget := lift_rate() * t
		for s in shafts:
			var take := minf(budget, s["stock"])
			s["stock"] -= take
			pile += take
			budget -= take
	var earned := 0.0
	if cart["manager"]:
		earned = minf(cart_rate() * t, pile)
		pile -= earned
		coins += earned
	return earned


# --- Saving -----------------------------------------------------------------------

func to_dict() -> Dictionary:
	var ss := []
	for s in shafts:
		ss.append([s["level"], s["manager"], s["stock"]])
	return {"coins": coins, "pile": pile + lift["load"] + cart["carry"], "shafts": ss,
		"lift": [lift["level"], lift["manager"]], "cart": [cart["level"], cart["manager"]],
		"boost_until": boost_until, "boost_ready_at": boost_ready_at, "saved_at": now()}


## Restores a saved mine; workers start their rounds afresh.
static func from_dict(d: Dictionary) -> RefCounted:
	var m: RefCounted = load("res://scripts/game/mine.gd").new()
	m.coins = d.get("coins", 0.0)
	m.pile = d.get("pile", 0.0)
	m.shafts = []
	for s in d.get("shafts", [[1, false, 0.0]]):
		var sh: Dictionary = m._new_shaft()
		sh["level"] = s[0]
		sh["manager"] = s[1]
		sh["stock"] = s[2]
		m.shafts.append(sh)
	var l: Array = d.get("lift", [1, false])
	m.lift["level"] = l[0]
	m.lift["manager"] = l[1]
	var c: Array = d.get("cart", [1, false])
	m.cart["level"] = c[0]
	m.cart["manager"] = c[1]
	m.boost_until = d.get("boost_until", 0.0)
	m.boost_ready_at = d.get("boost_ready_at", 0.0)
	return m
