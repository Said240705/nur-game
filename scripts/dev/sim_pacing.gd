extends SceneTree
## Plays the economy with a simple greedy player and prints when milestones
## arrive, to check the pacing:
##   godot --headless --script res://scripts/dev/sim_pacing.gd

const Mine := preload("res://scripts/game/mine.gd")


func _init() -> void:
	var m: RefCounted = Mine.new()
	var t := 0.0
	var dt := 0.1
	var seen := {}
	while t < 3.0 * 3600.0:
		# An engaged player taps every idle worker…
		for i in m.shafts.size():
			m.tap("shaft:%d" % i)
		m.tap("lift")
		m.tap("cart")
		m.tick(dt)
		m.events.clear()
		t += dt
		# …hires managers first, then opens shafts, then buys the cheapest level.
		var ids := ["cart", "lift"]
		for i in m.shafts.size():
			ids.append("shaft:%d" % i)
		for id in ids:
			if not m.has_manager(id) and m.hire(id):
				_mark(seen, "manager " + id, t)
		if m.next_shaft_cost() > 0.0 and m.coins >= m.next_shaft_cost() * 1.0:
			m.open_shaft()
			_mark(seen, "shaft %d" % m.shafts.size(), t)
		var best_id := ""
		var best_cost := INF
		for id in ids:
			var c: float = m.cost(id)
			if c < best_cost:
				best_cost = c
				best_id = id
		if best_cost <= m.coins * 0.5:
			m.upgrade(best_id)
	print("after 3h: coins %s, income %s/s, levels lift %d cart %d" % [m.coins, m.income(), m.level("lift"), m.level("cart")])
	quit()


func _mark(seen: Dictionary, what: String, t: float) -> void:
	if not seen.has(what):
		seen[what] = t
		print("%6.0f s  %s" % [t, what])
