extends SceneTree
## Plays the economy with a sensible player and prints when each status arrives:
##   godot --headless --script res://scripts/dev/sim_pacing.gd
## The player works (as if tapping the job), opens the most promising business
## on the best free plot, staffs it to meet demand, restocks, renovates and
## hires a manager once he can afford one.

const State := preload("res://scripts/game/state.gd")
const Data := preload("res://scripts/game/data.gd")
const Venue := preload("res://scripts/game/venue.gd")


func _init() -> void:
	if OS.get_cmdline_user_args().has("--table"):
		_table()
		quit()
		return
	for run in 3:
		seed(run + 7)
		var s: RefCounted = State.new()
		var seen := 0
		var line := "run %d:" % run
		var minutes := 0.0
		while minutes < 240.0 and not s.bankrupt:
			s.cash += Data.RANKS[s.rank()]["pay"] * 4.0
			s.next_day()
			minutes += Data.DAY / 60.0
			_manage(s)
			while seen < s.rank():
				seen += 1
				line += "  %s %dm" % [Data.RANKS[seen]["name"], int(minutes)]
		print(line, "  | %d venues, %s" % [s.venues.size(), Data.money(s.worth())], ("  | bankrupt on day %d" % s.day) if s.bankrupt else "")
	quit()


## Best steady profit per day of each kind of business, and where.
func _table() -> void:
	for b in Data.BUSINESSES:
		var best := -INF
		var where := ""
		for p in Data.PLOTS:
			if p["size"] != b["size"]:
				continue
			var v := Venue.make(0, b["id"], p["id"], b["price"])
			v["reno"] = 2
			v["rating"] = 4.0
			v["ads"] = 1
			v["staff"][b["roles"][1]["id"]] = 1
			var serve: Dictionary = b["roles"][0]
			v["staff"][serve["id"]] = mini(Data.MAX_STAFF, ceili(Venue.demand(v) / serve["cap"]))
			v["stock"] = 1e12
			var total := 0.0
			for i in 20:
				v["rating"] = 4.0
				total += Venue.day(v, 1.0)["profit"]
			if total / 20.0 > best:
				best = total / 20.0
				where = Data.DISTRICTS[p["d"]]["name"]
		var invest: float = b["price"] * 1.8
		print("%-18s profit/day %12s  payback %5.0f days  best: %s" % [b["name"], Data.money(best), invest / maxf(best, 1.0), where])


func _manage(s: RefCounted) -> void:
	for v in s.venues:
		var b: Dictionary = Venue.kind(v)
		var serve: Dictionary = b["roles"][0]
		var need := ceili(Venue.demand(v) * 1.05 / serve["cap"])
		var have: int = v["staff"][serve["id"]]
		if have < mini(need, Data.MAX_STAFF) and s.cash > serve["salary"] * 10.0:
			s.hire(v, serve["id"], 1)
		elif have > need + 1:
			s.hire(v, serve["id"], -1)
		var q: Dictionary = b["roles"][1]
		if v["staff"][q["id"]] == 0 and s.cash > q["salary"] * 20.0:
			s.hire(v, q["id"], 1)
		if Venue.uses_stock(v) and v["stock"] < Venue.restock(v, 1)["qty"] * 1.5:
			s.buy_stock(v, 3)
		if not Venue.has_manager(v) and s.cash > Data.manager_role(b)["salary"] * 30.0:
			s.hire(v, "manager", 1)
		var rc: float = s.renovation_cost(v)
		if rc > 0.0 and s.cash > rc * 3.0:
			s.renovate(v)
	# Open the next business: the biggest affordable kind, on its best plot.
	for i in range(Data.BUSINESSES.size() - 1, -1, -1):
		var b: Dictionary = Data.BUSINESSES[i]
		if s.cash < b["price"] * 1.5:
			continue
		var best_plot := -1
		var best_d := 0.0
		for p in Data.PLOTS:
			if p["size"] != b["size"] or not s.venue_at(p["id"]).is_empty():
				continue
			var probe := Venue.make(0, b["id"], p["id"], 0.0)
			var score := Venue.demand(probe) * Venue.ticket(probe) - Data.plot_rent(p) * 3.0
			if score > best_d:
				best_d = score
				best_plot = p["id"]
		if best_plot >= 0:
			s.open_venue(b["id"], best_plot, b["price"])
			break
