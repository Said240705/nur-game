extends SceneTree
## Plays the economy with a simple player (taps 3 times a second, buys what pays
## back fastest, answers events at random) and prints when each status arrives:
##   godot --headless --script res://scripts/dev/sim_pacing.gd

const State := preload("res://scripts/game/state.gd")
const Data := preload("res://scripts/game/data.gd")
const Events := preload("res://scripts/game/events.gd")


func _init() -> void:
	for run in 3:
		seed(run + 1)
		var s: RefCounted = State.new()
		var t := 0.0
		var seen := 0
		var next_event := 30.0
		var line := "run %d:" % run
		while t < 4.0 * 3600.0 and not s.bankrupt:
			t += Data.DAY
			for k in 9:
				s.work()
			s.next_day()
			if t >= next_event:
				next_event = t + 31.0
				var e: Dictionary = Events.pick(s, "")
				var choice: Dictionary = e["choices"][randi() % e["choices"].size()]
				s.apply(Events.roll(choice), e["amount"], e["biz_id"])
			_buy(s)
			while seen < s.rank():
				seen += 1
				line += "  %s %dm" % [Data.RANKS[seen]["name"], int(t / 60.0)]
		print(line, "  | bankrupt" if s.bankrupt else "")
	quit()


## Buys the option with the best income per dollar among what it can afford.
func _buy(s: RefCounted) -> void:
	var best := ""
	var best_ratio := 0.0
	for b in Data.BUSINESSES:
		var id: String = b["id"]
		var cost: float
		var gain: float
		if s.businesses.has(id):
			if s.businesses[id] >= Data.MAX_LEVEL:
				continue
			cost = s.upgrade_cost(id)
			gain = b["income"] * 0.35
		else:
			cost = b["price"]
			gain = b["income"]
		if cost <= s.cash and gain / cost > best_ratio:
			best_ratio = gain / cost
			best = id
	if best != "":
		if s.businesses.has(best):
			s.upgrade_business(best)
		else:
			s.buy_business(best)
