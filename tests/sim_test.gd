extends Node
## Headless playtest bot. Fast-forwards the game clock and plays like a
## reasonable player: fills pens, explores, captures, breeds, hatches, trains,
## trades and buys upgrades. Prints pacing and fails loudly on bad state.
## Run: godot --headless --path . res://tests/sim.tscn [-- --hours=30]
## Exits with code 1 if any check fails, so CI can gate on it.

const STEP := 5.0
const DEFAULT_HOURS := 30.0

var log_lines: Array = []
var unlock_times := {}
var milestone_log: Array = []
var errors := 0
var debug_fails := 0

func _ready() -> void:
	Game.reset_save()
	Game.toast.connect(func(t): if t.begins_with("NEW MODE") or t.find("milestone") >= 0: milestone_log.append("[%s] %s" % [_clock(), t]))
	var hours := DEFAULT_HOURS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hours="):
			hours = float(arg.get_slice("=", 1))
	var total := hours * 3600.0
	var elapsed := 0.0
	var next_report := 0.0
	while elapsed < total:
		Game.time_offset += STEP
		Game.last_tick = Game.now() - STEP
		Game.tick(STEP, false)
		Game.last_tick = Game.now()
		elapsed += STEP
		if int(elapsed) % 20 == 0:
			_play()
		_validate()
		if elapsed >= next_report:
			next_report += 7200.0
			_report()
	_report()
	var ready := 0
	for e in Game.eggs:
		if float(e.hatch_at) <= Game.now():
			ready += 1
	print("eggs ready at end: %d/%d, idle cubes: %d, roster %d/%d" % [ready, Game.eggs.size(), _idle().size(), Game.cubes.size(), Game.roster_cap()])
	print("upgrades: %s" % str(Game.upgrades))
	print("\n=== MILESTONES & UNLOCKS ===")
	for m in milestone_log:
		print(m)
	_save_roundtrip()
	_offline_test()
	print("\nERRORS: %d" % errors)
	get_tree().quit(1 if errors > 0 else 0)

func _clock() -> String:
	return Game.fmt_time(Game.time_offset)

func _report() -> void:
	var rar := {}
	for c in Game.cubes:
		var r := TraitDB.rarity_name(int(c.rarity))
		rar[r] = int(rar.get(r, 0)) + 1
	print("[%s] sq=%s rate=%s/s cubes=%d zone=%d/%d power=%s req=%s eggs=%d hatched=%d trades=%d captures=%d train=%s maxgen=%d ms=%s rar=%s" % [
		_clock(), Game.fmt(Game.squares), Game.fmt(Game.rate), Game.cubes.size(), Game.zone + 1, Game.max_zone + 1,
		Game.fmt(Game.team_power()), Game.fmt(Game.zone_req(Game.zone)), Game.eggs.size(), Game.counters.eggs_hatched,
		Game.counters.trades, Game.counters.captures, Game.fmt(Game.counters.train_points), _max_gen(), str(Game.milestones.values()), str(rar)])

func _max_gen() -> int:
	var g := 0
	for c in Game.cubes:
		g = max(g, int(c.gen))
	return g

func _idle() -> Array:
	var out: Array = []
	for c in Game.cubes:
		if c.job == "":
			out.append(c)
	return out

func _score_output(c: Dictionary) -> float:
	return Game.eff_stat(c, "CRN") + Game.eff_stat(c, "VIB") * 0.3

func _score_explore(c: Dictionary) -> float:
	return Game.eff_stat(c, "HFT") + Game.eff_stat(c, "WBL") + Game.eff_stat(c, "SMT")

func _play() -> void:
	# Hatch eggs (sell weakest idle cube if the barn is full)
	var i := 0
	while i < Game.eggs.size():
		if float(Game.eggs[i].hatch_at) <= Game.now():
			if Game.cubes.size() >= Game.roster_cap():
				if not _sell_weakest():
					break
			if not Game.hatch(i):
				if debug_fails < 5:
					debug_fails += 1
					print("DEBUG hatch failed: roster %d/%d idle %d" % [Game.cubes.size(), Game.roster_cap(), _idle().size()])
				i += 1
		else:
			i += 1
	# Captures: best affordable tool
	var e := 0
	while e < Game.encounters.size():
		var w: Dictionary = Game.encounters[e]
		if Game.cubes.size() >= Game.roster_cap() - 1:
			_sell_weakest()
		var best: Dictionary = {}
		var best_ch := 0.0
		for t in Game.TOOLS:
			if Game.tool_unlocked(t) and Game.squares >= Game.tool_cost(t, w):
				var ch := Game.capture_chance(w, t)
				if ch > best_ch:
					best_ch = ch
					best = t
		if best.is_empty():
			e += 1
			continue
		var before := Game.encounters.size()
		Game.try_capture(e, best.id)
		if Game.encounters.size() == before:
			e += 1
	# Upgrade jobs: swap better idle cubes into pens / team / nests
	_fill_team()
	_fill_pens()
	_fill_nests()
	_fill_gym()
	# Upgrades: buy the cheapest affordable, keep a little cash for tools
	var cheapest := ""
	var cheapest_cost := INF
	for id in Game.UPGRADES:
		var u: Dictionary = Game.UPGRADES[id]
		if not Game.unlocked.get(int(u.mode), false) or int(Game.upgrades[id]) >= int(u.max):
			continue
		var cost := Game.upgrade_cost(id)
		if cost < cheapest_cost:
			cheapest_cost = cost
			cheapest = id
	if cheapest != "" and Game.squares >= cheapest_cost * 1.2:
		Game.buy_upgrade(cheapest)
	# Trade: occasionally haggle once with Madame/Collector, else rock
	if Game.unlocked[5]:
		for tr in Game.TRADERS:
			if tr.id == "barry" or not Game.trader_available(tr.id):
				continue
			for c in _idle():
				if Game.trader_accepts(c, tr) and Game.cubes.size() > 8:
					var pushes := 0
					if not Game.haggle_push(tr.id, 0):
						pushes = 1
						Game.sell_cube(int(c.id), tr.id, pushes)
					break
		if Game.squares > 5000.0 and randf() < 0.05:
			Game.buy_rock()
		if Game.gary_stock.size() > 0 and Game.squares > Game.lib.value(Game.gary_stock[0]) * 5.0 and Game.cubes.size() < Game.roster_cap() - 2:
			Game.buy_from_gary(0)

func _sell_weakest() -> bool:
	var idle := _idle()
	if idle.is_empty():
		return false
	idle.sort_custom(func(a, b): return Game.lib.value(a) < Game.lib.value(b))
	for c in idle:
		if Game.has_flag(c, "immortal"):
			continue
		if Game.unlocked[5] and Game.trader_available("barry"):
			var r := Game.sell_cube(int(c.id), "barry", 0)
			if r.ok:
				return true
		var r2 := Game.release_cube(int(c.id))
		if r2.ok:
			return true
	return false

func _fill_team() -> void:
	var idle := _idle()
	idle.sort_custom(func(a, b): return _score_explore(a) > _score_explore(b))
	for c in idle:
		if Game.team.size() < 3:
			Game.assign_team(int(c.id))
		else:
			var worst := Game.get_cube(int(Game.team[0]))
			for id in Game.team:
				var tc := Game.get_cube(int(id))
				if _score_explore(tc) < _score_explore(worst):
					worst = tc
			if _score_explore(c) > _score_explore(worst) * 1.15:
				Game.unassign(int(worst.id))
				Game.assign_team(int(c.id))

func _fill_pens() -> void:
	var idle := _idle()
	idle.sort_custom(func(a, b): return _score_output(a) > _score_output(b))
	for c in idle:
		var placed := false
		for p in Game.pens.size():
			if Game.pens[p].size() < Game.pen_cap():
				Game.assign_pen(int(c.id), p)
				placed = true
				break
		if placed:
			continue
		var worst: Dictionary = {}
		for p in Game.pens:
			for id in p:
				var pc := Game.get_cube(int(id))
				if worst.is_empty() or _score_output(pc) < _score_output(worst):
					worst = pc
		if not worst.is_empty() and _score_output(c) > _score_output(worst) * 1.15:
			var pen_i := int(worst.pen)
			Game.unassign(int(worst.id))
			Game.assign_pen(int(c.id), pen_i)

func _fill_nests() -> void:
	if not Game.unlocked[3]:
		return
	var idle := _idle()
	idle.sort_custom(func(a, b): return Game.lib.stat_avg(a) + int(a.rarity) * 10 > Game.lib.stat_avg(b) + int(b.rarity) * 10)
	for n in Game.nests.size():
		for side in ["a", "b"]:
			if int(Game.nests[n][side]) < 0 and not idle.is_empty():
				var c: Dictionary = idle.pop_front()
				Game.assign_nest(int(c.id), n, side)

func _fill_gym() -> void:
	if not Game.unlocked[4]:
		return
	for s in Game.gym.size():
		var slot: Dictionary = Game.gym[s]
		var c := Game.get_cube(int(slot.cube))
		if c.is_empty():
			var idle := _idle()
			if idle.is_empty():
				return
			Game.assign_gym(int(idle[0].id), s, "CRN")
			continue
		var cap := float(c.potential[slot.stat]) * (1.5 if Game.has_flag(c, "peak_form") else 1.0)
		if float(c.trained[slot.stat]) >= cap - 0.01:
			var moved := false
			for st in ["CRN", "HFT", "WBL", "SMT", "FRT", "VIB", "CHA"]:
				var cp := float(c.potential[st]) * (1.5 if Game.has_flag(c, "peak_form") else 1.0)
				if float(c.trained[st]) < cp - 0.01:
					Game.set_gym_stat(s, st)
					moved = true
					break
			if not moved:
				Game.unassign(int(c.id))

func _validate() -> void:
	var seen := {}
	for c in Game.cubes:
		var id := int(c.id)
		if seen.has(id):
			_fail("duplicate cube id %d" % id)
		seen[id] = true
		for s in Game.lib.STATS:
			var v := float(c.base[s])
			if is_nan(v) or is_inf(v) or v < 0.0:
				_fail("bad stat %s=%s on %s" % [s, v, c.name])
		if c.traits.size() > int(c.slots) + 1:
			_fail("too many traits on %s" % c.name)
		match c.job:
			"pen":
				if not Game.pens[int(c.pen)].has(id):
					_fail("%s says pen but not in pen" % c.name)
			"team":
				if not Game.team.has(id):
					_fail("%s says team but not in team" % c.name)
	for p in Game.pens:
		if p.size() > Game.pen_cap():
			_fail("pen over capacity")
		for id in p:
			if Game.get_cube(int(id)).is_empty():
				_fail("pen references missing cube %d" % int(id))
	if Game.team.size() > 3:
		_fail("team too big")
	if is_nan(Game.squares) or Game.squares < -1.0:
		_fail("bad squares %s" % Game.squares)

func _fail(msg: String) -> void:
	errors += 1
	if errors < 20:
		print("FAIL [%s]: %s" % [_clock(), msg])

func _save_roundtrip() -> void:
	var before_cubes := Game.cubes.size()
	var before_sq := Game.squares
	var before_ms := str(Game.milestones)
	Game.save_game()
	Game.load_game()
	if Game.cubes.size() != before_cubes:
		_fail("save roundtrip lost cubes %d -> %d" % [before_cubes, Game.cubes.size()])
	if absf(Game.squares - before_sq) > max(1.0, before_sq * 0.01):
		_fail("save roundtrip squares %s -> %s" % [before_sq, Game.squares])
	if str(Game.milestones) != before_ms:
		_fail("save roundtrip milestones %s -> %s" % [before_ms, str(Game.milestones)])
	_validate()
	print("\nSave/load roundtrip OK: %d cubes, %s squares" % [Game.cubes.size(), Game.fmt(Game.squares)])

func _offline_test() -> void:
	var sq := Game.squares
	var got := {}
	Game.welcome_back.connect(func(s): got.merge(s))
	Game.time_offset += 8 * 3600.0
	Game._apply_offline(8 * 3600.0)
	print("Offline 8h: earned %s squares, %d eggs, %d encounters, %d zones" % [Game.fmt(Game.squares - sq), int(got.get("eggs", 0)), int(got.get("encounters", 0)), int(got.get("zones", 0))])
	if Game.squares <= sq:
		_fail("offline progress earned nothing")
	_validate()
