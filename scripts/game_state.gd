extends Node
## All game state and rules for the modes 1-5 vertical slice.
## The UI only reads this state and calls the public action methods.

signal structure_changed
signal toast(text: String)
signal reveal(cube: Dictionary, headline: String)
signal welcome_back(summary: Dictionary)

const CubeLib := preload("res://scripts/cube_lib.gd")
const SAVE_PATH := "user://cube_guy_save.json"
const SAVE_VERSION := 1
const OFFLINE_CAP := 86400.0
const ENCOUNTER_INTERVAL := 60.0
const OFFLINE_CAP_WORKAHOLIC := 259200.0

const ZONES := ["The Backyard", "Office Supply Closet", "Suburban Cul-de-Sac", "The Mall Food Court",
	"IKEA (you cannot leave)", "Sewer of Small Dice", "Board Game Graveyard", "Legally Distinct Block Plains",
	"The Cube Dimension", "Bermuda Rectangle", "Inside a Puzzle Cube", "Ancient Egypt (Pyramid Territory)",
	"The Lost & Found", "A Very Large Sock Drawer", "Abandoned Dice Casino", "The Shipping Container Sea",
	"Grandma's Sugar Cube Bowl", "The Ice Cube Tray Glacier", "The Server Room", "Your Own Ranch, But Evil"]

const TOOLS := [
	{"id": "net", "name": "Butterfly Net", "zone": 0, "cost": 0.0, "power": 1.0, "hint": "Free. Weak against anything bigger than Dice."},
	{"id": "box", "name": "Cardboard Box", "zone": 2, "cost": 4.0, "power": 1.25, "hint": "Cubes can't resist a box. Smart ones notice."},
	{"id": "lasso", "name": "Lasso", "zone": 5, "cost": 15.0, "power": 1.5, "hint": "Bonus against cubes with legs."},
	{"id": "trombone", "name": "Sad Trombone", "zone": 9, "cost": 45.0, "power": 1.85, "hint": "Crushes morale. Extra good on Main Characters."},
	{"id": "audit", "name": "Tax Audit", "zone": 14, "cost": 120.0, "power": 1.4, "hint": "Guaranteed on cubes that Owe Money."},
]

const UPGRADES := {
	"pen": {"name": "New Pen", "desc": "Another pen for cubes to loaf in", "base": 60.0, "growth": 4.5, "max": 5, "mode": 1},
	"pen_cap": {"name": "Bigger Pens", "desc": "+1 cube per pen", "base": 40.0, "growth": 3.2, "max": 7, "mode": 1},
	"barn": {"name": "Barn Extension", "desc": "+8 roster space", "base": 80.0, "growth": 3.0, "max": 10, "mode": 1},
	"boots": {"name": "Hiking Boots", "desc": "+10% expedition power", "base": 100.0, "growth": 3.0, "max": 10, "mode": 2},
	"net": {"name": "Stronger Nets", "desc": "+5% capture chance", "base": 90.0, "growth": 2.8, "max": 10, "mode": 2},
	"nest": {"name": "Nesting Box", "desc": "Breed another pair at once", "base": 150.0, "growth": 6.0, "max": 5, "mode": 3},
	"heater": {"name": "Incubator Jazz", "desc": "-12% incubation time", "base": 120.0, "growth": 3.5, "max": 5, "mode": 3},
	"incubator": {"name": "Bigger Incubator", "desc": "+4 egg capacity", "base": 200.0, "growth": 4.0, "max": 5, "mode": 3},
	"gym": {"name": "Gym Membership", "desc": "+1 Gym slot", "base": 250.0, "growth": 5.0, "max": 5, "mode": 4},
	"cgu_polish": {"name": "CGU: Corner Polish", "desc": "+10% all Squares (infinite)", "base": 1500.0, "growth": 2.0, "max": 999, "mode": 1},
	"cgu_compass": {"name": "CGU: Existential Compass", "desc": "+5% expedition power (infinite)", "base": 2500.0, "growth": 2.1, "max": 999, "mode": 2},
	"cgu_vigor": {"name": "CGU: Hybrid Vigor", "desc": "+1% child stats (infinite)", "base": 4000.0, "growth": 2.1, "max": 999, "mode": 3},
	"cgu_protein": {"name": "CGU: Protein Grout", "desc": "+10% training speed (infinite)", "base": 5000.0, "growth": 1.9, "max": 999, "mode": 4},
	"cgu_charm": {"name": "CGU: Haggling Lessons", "desc": "+5% trade prices (infinite)", "base": 6000.0, "growth": 1.9, "max": 999, "mode": 5},
}

const MILESTONES := {
	1: {"label": "Lifetime Squares", "goals": [500.0, 100000.0, 10000000.0, 1000000000.0, 100000000000.0]},
	2: {"label": "Wilds zones cleared", "goals": [2.0, 5.0, 10.0, 15.0, 20.0]},
	3: {"label": "Eggs hatched", "goals": [3.0, 20.0, 80.0, 250.0, 700.0]},
	4: {"label": "Stat points trained", "goals": [100.0, 2000.0, 30000.0, 400000.0, 5000000.0]},
	5: {"label": "Trades completed", "goals": [1.0, 10.0, 50.0, 200.0, 600.0]},
}
const MILESTONE_NAMES := ["First clear", "Bronze", "Silver", "Gold", "Mastery"]

const TRADERS := [
	{"id": "barry", "name": "Barry the Bartering Box", "blurb": "Buys anything. Pays like it's a favour.", "mult": 0.6},
	{"id": "madame", "name": "Madame Hexahedra", "blurb": "Only Haunted or Rare+ cubes. Pays in cash and prophecy.", "mult": 1.6},
	{"id": "collector", "name": "The Collector", "blurb": "Wants one specific trait today. Pays absurdly.", "mult": 6.0},
]

const NARRATOR := [
	"Remember: cubes are not food. Mostly.",
	"Gary would like you to know his children are 'competitively priced'.",
	"Nobody knows how cubes reproduce. Please stop asking the Nesting Boxes.",
	"A cube looked at me funny. I think it was the Haunted one.",
	"Fun fact: every cube is a lottery ticket. Most lottery tickets are Damp.",
	"The Wilds are dangerous. Bring a box. Cubes love boxes.",
	"Your ranch smells faintly of toast. That's a trait, not a problem.",
	"Pyramids have been spotted near Zone 12. Stay vigilant.",
	"Have you considered breeding two Hard Workers? Have you considered a hobby?",
	"The Gym of Corners is open 24/7. The cubes are not happy about this.",
	"Barry says he's 'not lowballing, just being realistic'. Barry is lowballing.",
	"I've been told to remind you that the Spa is definitely a spa.",
]

var rng := RandomNumberGenerator.new()
var lib

var squares := 0.0
var lifetime_squares := 0.0
var cubes: Array = []
var next_id := 1
var pens: Array = []
var nests: Array = []
var eggs: Array = []
var gym: Array = []
var team: Array = []
var zone := 0
var max_zone := 0
var zones_cleared := 0
var zone_progress := 0.0
var encounters: Array = []
var encounter_timer := 30.0
var upgrades := {}
var unlocked := {1: true, 2: true, 3: false, 4: false, 5: false}
var milestones := {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
var counters := {"eggs_hatched": 0, "trades": 0, "captures": 0, "train_points": 0.0, "acquired": 0, "rocks": 0}
var codex := {}
var hourly_accum := 0.0
var next_audit := 7200.0
var trader_cooldown := {}
var trader_favs := {}
var favs_day := -1
var gary_stock: Array = []
var gary_restock_at := 0.0
var deal_ready_at := 0.0
var last_tick := 0.0
var narrator_line := ""

var rate := 0.0
var _accum := 0.0
var _save_accum := 0.0
var _narrator_accum := 0.0
var _global_squares := 0.0
var _loaded := false
## Debug/testing: shifts the game clock forward (seconds).
var time_offset := 0.0

func _ready() -> void:
	rng.randomize()
	lib = CubeLib.new(TraitDB)
	if not load_game():
		new_game()
	_loaded = true
	narrator_line = NARRATOR[rng.randi() % NARRATOR.size()]

func _notification(what: int) -> void:
	if not _loaded:
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		save_game()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		var away := now() - last_tick
		if away > 60.0:
			_apply_offline(away)

func now() -> float:
	return Time.get_unix_time_from_system() + time_offset

# ------------------------------------------------------------------ setup

func new_game() -> void:
	squares = 30.0
	lifetime_squares = 0.0
	cubes.clear()
	next_id = 1
	pens = [[]]
	nests = []
	eggs.clear()
	gym = []
	team.clear()
	upgrades = {}
	for k in UPGRADES:
		upgrades[k] = 0
	zone = 0
	max_zone = 0
	zones_cleared = 0
	zone_progress = 0.0
	encounters = []
	encounter_timer = 30.0
	unlocked = {1: true, 2: true, 3: false, 4: false, 5: false}
	milestones = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
	counters = {"eggs_hatched": 0, "trades": 0, "captures": 0, "train_points": 0.0, "acquired": 0, "rocks": 0}
	codex = {}
	hourly_accum = 0.0
	trader_cooldown = {}
	gary_stock = []
	gary_restock_at = 0.0
	deal_ready_at = 0.0
	var c1: Dictionary = lib.new_wild(rng, _take_id(), 0, 0.0)
	c1.name = "Cubert"
	c1.traits = ["hard_worker"]
	c1.color = "ffd43b"
	c1.size = 1
	c1.appendage = 1
	c1.origin = "starter"
	c1.rarity = lib.compute_rarity(c1)
	var c2: Dictionary = lib.new_wild(rng, _take_id(), 0, 0.0)
	c2.name = "Squarah"
	c2.traits = ["fidgety"]
	c2.color = "4dabf7"
	c2.size = 1
	c2.origin = "starter"
	c2.rarity = lib.compute_rarity(c2)
	# Fixed starter stats so Zone 1 is always clearable and the first minute feels the same for everyone.
	for s in lib.STATS:
		c1.base[s] = 10.0
		c1.potential[s] = 25.0
		c2.base[s] = 11.0
		c2.potential[s] = 28.0
	c1.base["CRN"] = 12.0
	c1.rarity = lib.compute_rarity(c1)
	c2.rarity = lib.compute_rarity(c2)
	_add_cube(c1)
	_add_cube(c2)
	assign_pen(c1.id, 0)
	assign_team(c2.id)
	last_tick = now()
	next_audit = rng.randf_range(5400.0, 10800.0)
	_check_unlocks()
	toast.emit("Welcome to the ranch. Those two cubes are all you have. Don't get attached. Get attached.")

func _take_id() -> int:
	next_id += 1
	return next_id - 1

func _add_cube(c: Dictionary) -> void:
	cubes.append(c)
	counters.acquired += 1
	for t in c.traits:
		codex[t] = true

# ------------------------------------------------------------------ queries

func get_cube(id: int) -> Dictionary:
	for c in cubes:
		if int(c.id) == id:
			return c
	return {}

func roster_cap() -> int:
	return 15 + 8 * int(upgrades.get("barn", 0))

func pen_cap() -> int:
	return 3 + int(upgrades.get("pen_cap", 0))

func nest_count() -> int:
	return 1 + int(upgrades.get("nest", 0))

func gym_count() -> int:
	return 1 + int(upgrades.get("gym", 0))

func incubator_cap() -> int:
	return 6 + 4 * int(upgrades.get("incubator", 0))

func upgrade_cost(id: String) -> float:
	var u: Dictionary = UPGRADES[id]
	return u.base * pow(u.growth, int(upgrades.get(id, 0)))

func cube_mods(c: Dictionary) -> Dictionary:
	var m := {}
	for t in c.traits:
		var tm: Dictionary = TraitDB.get_trait(t).get("mods", {})
		for k in tm:
			m[k] = float(m.get(k, 0.0)) + float(tm[k])
	return m

func has_flag(c: Dictionary, key: String) -> bool:
	for t in c.traits:
		if TraitDB.get_trait(t).get("mods", {}).has(key):
			return true
	return false

func any_owned_with(key: String) -> bool:
	for c in cubes:
		if has_flag(c, key):
			return true
	return false

func owned_sum(key: String) -> float:
	var total := 0.0
	for c in cubes:
		total += float(cube_mods(c).get(key, 0.0))
	return total

func eff_stat(c: Dictionary, s: String) -> float:
	var m := cube_mods(c)
	var raw := float(c.base.get(s, 0.0)) + float(c.trained.get(s, 0.0))
	if m.has("average"):
		raw = lib.stat_avg(c)
	var mult: float = 1.0 + float(m.get(s, 0.0)) + float(m.get("all", 0.0))
	if m.has("overachiever"):
		var hi := ""
		var lo := ""
		for st in lib.STATS:
			var v := float(c.base[st]) + float(c.trained[st])
			if hi == "" or v > float(c.base[hi]) + float(c.trained[hi]):
				hi = st
			if lo == "" or v < float(c.base[lo]) + float(c.trained[lo]):
				lo = st
		if s == hi:
			mult += 0.15
		elif s == lo:
			mult -= 0.05
	return max(0.0, raw * mult)

func cube_output(c: Dictionary, offline: bool = false) -> float:
	if c.job != "pen" or int(c.pen) < 0 or int(c.pen) >= pens.size():
		return 0.0
	var m := cube_mods(c)
	var pen: Array = pens[int(c.pen)]
	var base := 0.25 + eff_stat(c, "CRN") * 0.06
	var mult := 1.0 + float(m.get("squares", 0.0)) + eff_stat(c, "VIB") / 500.0
	if offline:
		mult += float(m.get("offline", 0.0))
	var support := false
	for oid in pen:
		if int(oid) != int(c.id) and has_flag(get_cube(int(oid)), "emotional_support"):
			support = true
	for oid in pen:
		if int(oid) == int(c.id):
			continue
		var v := float(cube_mods(get_cube(int(oid))).get("pen_squares", 0.0))
		if v < 0.0 and support:
			v = 0.0
		mult += v
	if m.has("landlord"):
		mult += min(0.30, 0.02 * pen.size())
	if m.has("homebody") and now() - float(c.pen_since) >= 86400.0:
		mult += 0.15
	if m.has("night_owl"):
		var hour: int = Time.get_datetime_dict_from_system().hour
		mult += 0.30 if (hour >= 20 or hour < 6) else -0.15
	mult += _global_squares
	var out := base * maxf(0.05, mult)
	if m.has("barn_burner") and int(Time.get_datetime_dict_from_system().minute) < 10:
		out *= 2.0
	if float(c.flags.get("black_eye_until", 0.0)) > now():
		out *= 0.5
	return out

func compute_rate(offline: bool = false) -> float:
	_global_squares = 0.0
	for c in cubes:
		if c.job == "pen":
			_global_squares += float(cube_mods(c).get("global_squares", 0.0))
	var total := 0.0
	for c in cubes:
		total += cube_output(c, offline)
	return total * (1.0 + 0.10 * int(upgrades.get("cgu_polish", 0)))

func team_power() -> float:
	var p := 0.0
	for id in team:
		var c := get_cube(int(id))
		if c.is_empty():
			continue
		p += (eff_stat(c, "HFT") + eff_stat(c, "WBL") + eff_stat(c, "SMT")) / 3.0
	return p * (1.0 + 0.10 * int(upgrades.get("boots", 0)) + 0.05 * int(upgrades.get("cgu_compass", 0)))

func zone_req(z: int) -> float:
	return 8.0 * pow(1.6, z)

func team_mod(key: String) -> float:
	var total := 0.0
	for id in team:
		total += float(cube_mods(get_cube(int(id))).get(key, 0.0))
	return total

func tool_unlocked(t: Dictionary) -> bool:
	return max_zone >= int(t.zone)

func tool_cost(t: Dictionary, w: Dictionary) -> float:
	return float(t.cost) * (1.0 + float(w.get("zone", 0)) * 0.8)

func capture_chance(w: Dictionary, t: Dictionary) -> float:
	if t.id == "audit" and w.traits.has("owes_money"):
		return 1.0
	var z := int(w.get("zone", 0))
	var power := float(t.power) * (1.0 + team_mod("capture") + 0.05 * int(upgrades.get("net", 0)))
	match t.id:
		"net":
			if int(w.size) > 1:
				power *= 0.35
		"box":
			if eff_stat(w, "SMT") > 20.0 + z * 8.0:
				power *= 0.6
		"lasso":
			if int(w.appendage) == 1 or int(w.appendage) == 2:
				power *= 1.4
		"trombone":
			if w.traits.has("main_character"):
				power *= 1.5
	var resist := 1.0 + int(w.rarity) * 0.45 + eff_stat(w, "HFT") / (30.0 + z * 14.0)
	return clampf(0.6 * power / resist, 0.03, 0.95)

func trade_price(c: Dictionary, trader: Dictionary) -> float:
	var mult := float(trader.mult)
	if trader.id == "barry" and any_owned_with("barry"):
		mult = 1.0
	var p: float = lib.value(c) * mult * (1.0 + eff_stat(c, "CHA") / 400.0) * (1.0 + owned_sum("trade") + 0.05 * int(upgrades.get("cgu_charm", 0)))
	var fav: String = trader_favs.get(trader.id, "")
	if fav != "" and c.traits.has(fav):
		p *= 2.0
	return p

func trader_accepts(c: Dictionary, trader: Dictionary) -> bool:
	if c.job != "":
		return false
	match trader.id:
		"madame":
			return c.traits.has("haunted") or int(c.rarity) >= 2
		"collector":
			return c.traits.has(trader_favs.get("collector_want", ""))
	return true

func trader_available(tid: String) -> bool:
	return float(trader_cooldown.get(tid, 0.0)) <= now()

func milestone_progress(mode: int) -> float:
	match mode:
		1: return lifetime_squares
		2: return float(zones_cleared)
		3: return float(counters.eggs_hatched)
		4: return float(counters.train_points)
		5: return float(counters.trades)
	return 0.0

# ------------------------------------------------------------------ tick

func _process(delta: float) -> void:
	_accum += delta
	_save_accum += delta
	_narrator_accum += delta
	if _accum >= 0.25:
		var t := now()
		var dt := clampf(t - last_tick, 0.0, 5.0)
		last_tick = t
		_accum = 0.0
		tick(dt, false)
	if _save_accum >= 20.0:
		_save_accum = 0.0
		save_game()
	if _narrator_accum >= 40.0:
		_narrator_accum = 0.0
		narrator_line = NARRATOR[rng.randi() % NARRATOR.size()]

func tick(dt: float, offline: bool) -> Dictionary:
	var report := {"squares": 0.0, "eggs": 0, "encounters": 0, "zones": 0}
	rate = compute_rate(false)
	var r := compute_rate(true) if offline else rate
	var gain := r * dt
	squares += gain
	lifetime_squares += gain
	report.squares = gain
	_tick_gym(dt)
	report.eggs = _tick_nests(dt)
	var exp_report := _tick_wilds(dt)
	report.encounters = exp_report.encounters
	report.zones = exp_report.zones
	hourly_accum += dt
	while hourly_accum >= 3600.0:
		hourly_accum -= 3600.0
		_run_hour(offline)
	next_audit -= dt
	if next_audit <= 0.0:
		next_audit = rng.randf_range(5400.0, 10800.0)
		_irs_audit()
	_refresh_traders()
	_check_milestones()
	_check_unlocks()
	return report

func _tick_gym(dt: float) -> void:
	var aura := 0.0
	for slot in gym:
		var gc := get_cube(int(slot.cube))
		if not gc.is_empty():
			aura += float(cube_mods(gc).get("gym_aura", 0.0))
	for slot in gym:
		var c := get_cube(int(slot.cube))
		if c.is_empty():
			continue
		var s: String = slot.stat
		var m := cube_mods(c)
		var own_aura := float(m.get("gym_aura", 0.0))
		var speed := (0.06 + float(c.base[s]) * 0.004) * (1.0 + float(m.get("train", 0.0)) + aura - own_aura + eff_stat(c, "SMT") / 400.0) * (1.0 + 0.10 * int(upgrades.get("cgu_protein", 0)))
		var cap := float(c.potential[s]) * (1.5 if m.has("peak_form") else 1.0)
		var before := float(c.trained[s])
		var after: float = min(cap, before + speed * dt)
		c.trained[s] = after
		var gained := after - before
		counters.train_points += gained
		if m.has("swole") and s != "CRN":
			c.trained["CRN"] = float(c.trained["CRN"]) + gained * 0.1

func breed_duration(a: Dictionary, b: Dictionary) -> float:
	var fert := (eff_stat(a, "FRT") + eff_stat(b, "FRT")) / 2.0
	var d := 480.0 / (1.0 + fert / 80.0)
	var speed := float(cube_mods(a).get("breed_speed", 0.0)) + float(cube_mods(b).get("breed_speed", 0.0))
	d *= 1.0 - min(0.8, speed)
	if (has_flag(a, "part_bread") and int(b.material) == 4) or (has_flag(b, "part_bread") and int(a.material) == 4):
		d /= 3.0
	if has_flag(a, "time_blind") or has_flag(b, "time_blind"):
		d /= rng.randf_range(0.5, 3.0)
	return max(10.0, d)

func incubation_time(egg_cube: Dictionary, parents: Array) -> float:
	var t := 90.0 * (1.0 + int(egg_cube.rarity) * 0.5) * pow(0.88, int(upgrades.get("heater", 0)))
	for p in parents:
		if p.is_empty():
			continue
		if has_flag(p, "clumsy"):
			t *= 1.2
		t *= 1.0 - float(cube_mods(p).get("incubate", 0.0))
	return t

func _tick_nests(dt: float) -> int:
	var laid := 0
	for n in nests:
		var a := get_cube(int(n.a))
		var b := get_cube(int(n.b))
		if a.is_empty() or b.is_empty():
			n.left = 0.0
			continue
		if eggs.size() >= incubator_cap():
			continue
		n.left = float(n.left) - dt
		if float(n.left) > 0.0:
			continue
		n.left = breed_duration(a, b)
		if (has_flag(a, "hypochondriac") or has_flag(b, "hypochondriac")) and rng.randf() < 0.1:
			toast.emit("%s skipped breeding due to 'symptoms'." % (a.name if has_flag(a, "hypochondriac") else b.name))
			continue
		laid += _lay_clutch(a, b)
	return laid

func _lay_clutch(a: Dictionary, b: Dictionary) -> int:
	var fert := (eff_stat(a, "FRT") + eff_stat(b, "FRT")) / 2.0
	var count := 1
	var bonus := fert / 200.0 + float(cube_mods(a).get("eggs", 0.0)) + float(cube_mods(b).get("eggs", 0.0))
	if rng.randf() < bonus:
		count += 1
	for p in [a, b]:
		var pm := cube_mods(p)
		if rng.randf() < float(pm.get("twins", 0.0)):
			count += 1
		if pm.has("extra_egg"):
			count += 1
	count = mini(count, 4)
	var extra_mut := float(cube_mods(a).get("mutation", 0.0)) + float(cube_mods(b).get("mutation", 0.0))
	var force := false
	for p in [a, b]:
		if has_flag(p, "natural20") and float(p.flags.get("n20_at", 0.0)) <= now():
			p.flags["n20_at"] = now() + 86400.0
			force = true
	var made := 0
	for i in count:
		if eggs.size() >= incubator_cap():
			break
		var res: Dictionary = lib.breed(rng, _take_id(), a, b, extra_mut, force and i == 0, 0.01 * int(upgrades.get("cgu_vigor", 0)))
		var child: Dictionary = res.child
		eggs.append({"cube": child, "hatch_at": now() + incubation_time(child, [a, b]), "mutated": res.mutated, "gift": ""})
		made += 1
	if made > 0:
		structure_changed.emit()
	return made

func _tick_wilds(dt: float) -> Dictionary:
	var out := {"encounters": 0, "zones": 0}
	if team.is_empty():
		return out
	var power := team_power()
	var req := zone_req(zone)
	var ratio := power / req
	if ratio >= 1.0:
		zone_progress += dt / 90.0 * minf(5.0, pow(ratio, 1.2))
	if zone_progress >= 1.0:
		zone_progress = 0.0
		out.zones += 1
		_clear_zone()
	if ratio < 0.5:
		return out
	encounter_timer -= dt * (1.0 + team_mod("encounter") + minf(1.0, (ratio - 1.0) * 0.25))
	if encounter_timer <= 0.0:
		encounter_timer = ENCOUNTER_INTERVAL
		if encounters.size() < 6:
			encounters.append(_spawn_wild(false))
			out.encounters += 1
			structure_changed.emit()
	return out

func _clear_zone() -> void:
	if zone == max_zone and zones_cleared <= zone:
		zones_cleared = zone + 1
		var boss := (zone + 1) % 5 == 0
		if zone < ZONES.size() - 1:
			max_zone += 1
			zone = max_zone
			toast.emit("Zone cleared! %s is now open." % ZONES[zone])
		else:
			toast.emit("You've cleared the final zone. The Wilds respect you now. Mostly.")
		if boss and encounters.size() < 8:
			encounters.append(_spawn_wild(true))
			toast.emit("A Wild Boss blocks the path home. Capture it if you dare.")
		structure_changed.emit()
	else:
		var bounty := zone_req(zone) * 6.0
		squares += bounty
		lifetime_squares += bounty

func _spawn_wild(boss: bool) -> Dictionary:
	var luck := zone * 0.03 + team_mod("rare_find")
	if boss:
		luck += 0.8
	var w: Dictionary = lib.new_wild(rng, 0, zone, luck)
	w["zone"] = zone
	if boss:
		w.name = "Wild Boss " + w.name
		for s in lib.STATS:
			w.base[s] = snappedf(float(w.base[s]) * 1.8, 0.1)
			w.potential[s] = snappedf(float(w.potential[s]) * 1.8, 0.1)
		w.size = max(int(w.size), 4)
		w.rarity = lib.compute_rarity(w)
	if team_mod("call_wild") > 0.0 and rng.randf() < 0.05:
		var pool: Array = TraitDB.base_by_rarity[4]
		var t: String = pool[rng.randi() % pool.size()]
		if not w.traits.has(t):
			if w.traits.size() >= 3:
				w.traits[0] = t
			else:
				w.traits.append(t)
			w.rarity = lib.compute_rarity(w)
		toast.emit("Call of the Wild! Something legendary followed your team home.")
	return w

func _run_hour(offline: bool) -> void:
	var r := maxf(rate, 1.0)
	for c in cubes.duplicate():
		var m := cube_mods(c)
		if m.has("owes_money") and rng.randf() < 0.3:
			if rng.randf() < 0.5:
				squares += r * 300.0
				_notify(offline, "%s came back from 'a meeting' with %s Squares." % [c.name, fmt(r * 300.0)])
			else:
				c.flags["black_eye_until"] = now() + 3600.0
				_notify(offline, "%s came back with a black eye. -50%% output for an hour." % c.name)
		if m.has("fetch") and float(c.flags.get("fetch_at", 0.0)) <= now():
			c.flags["fetch_at"] = now() + 86400.0
			squares += r * 400.0
			_notify(offline, "%s fetched a bag of %s Squares from the Wilds. Good cube." % [c.name, fmt(r * 400.0)])
		if m.has("klepto") and float(c.flags.get("klepto_at", 0.0)) <= now():
			c.flags["klepto_at"] = now() + 604800.0
			squares += r * 900.0
			_notify(offline, "%s 'found' %s Squares. Barry is looking for his wallet." % [c.name, fmt(r * 900.0)])
		if m.has("haunted") and rng.randf() < 0.08:
			_notify(offline, "%s moaned at 3am. Your menus feel slightly rearranged." % c.name)
		var flee := (m.has("escape") and rng.randf() < 0.02) or (m.has("roll_away") and rng.randf() < 0.01 / 24.0)
		if flee and c.job != "team" and not m.has("immortal") and encounters.size() < 8:
			_detach(c)
			cubes.erase(c)
			c["zone"] = zone
			encounters.append(c)
			_notify(offline, "%s escaped to the Wilds! It's waiting in your encounters, smugly." % c.name)
			structure_changed.emit()

func _irs_audit() -> void:
	if any_owned_with("tax_exempt"):
		toast.emit("The Cube IRS arrived, saw your Tax Exempt cube, and left in shame.")
		return
	var loss := squares * 0.10
	squares -= loss
	toast.emit("CUBE IRS AUDIT! They took %s Squares. Breed a Tax Exempt cube." % fmt(loss))

func _notify(offline: bool, text: String) -> void:
	if not offline:
		toast.emit(text)

func _refresh_traders() -> void:
	var day := int(now() / 86400.0)
	if day != favs_day:
		favs_day = day
		var drng := RandomNumberGenerator.new()
		drng.seed = day * 7919 + 13
		for tr in TRADERS:
			trader_favs[tr.id] = TraitDB.base_ids[drng.randi() % TraitDB.base_ids.size()]
		var wants: Array = []
		for id in TraitDB.base_ids:
			if int(TraitDB.get_trait(id).rarity) <= 2:
				wants.append(id)
		trader_favs["collector_want"] = wants[drng.randi() % wants.size()]
	if gary_restock_at <= now() or gary_stock.is_empty():
		restock_gary()

func restock_gary() -> void:
	gary_stock.clear()
	for i in 3:
		var w: Dictionary = lib.new_wild(rng, 0, max_zone, 0.3 + max_zone * 0.03)
		w["zone"] = max_zone
		gary_stock.append(w)
	gary_restock_at = now() + 14400.0
	structure_changed.emit()

func _check_milestones() -> void:
	for mode in MILESTONES:
		if not unlocked.get(mode, false):
			continue
		var idx: int = milestones[mode]
		var goals: Array = MILESTONES[mode].goals
		if idx >= goals.size():
			continue
		if milestone_progress(mode) >= goals[idx]:
			milestones[mode] = idx + 1
			_award_trait_egg(mode, idx)

func _award_trait_egg(mode: int, idx: int) -> void:
	var tid: String = TraitDB.by_mode[mode][idx]
	var tr := TraitDB.get_trait(tid)
	var w: Dictionary = lib.new_wild(rng, _take_id(), max_zone, 0.4 + idx * 0.3)
	if w.traits.size() >= 3:
		w.traits[0] = tid
	else:
		w.traits.append(tid)
	w.origin = "gift"
	w.rarity = lib.compute_rarity(w)
	eggs.append({"cube": w, "hatch_at": now(), "mutated": false, "gift": tid})
	toast.emit("%s %s milestone! A gift egg with the %s trait '%s' is in your incubator." % [TraitDB.MODE_NAMES[mode], MILESTONE_NAMES[idx], TraitDB.rarity_name(tr.rarity), tr.name])
	structure_changed.emit()

func _check_unlocks() -> void:
	var changed := false
	if not unlocked[3] and cubes.size() >= 2:
		unlocked[3] = true
		changed = true
		nests = [{"a": -1, "b": -1, "left": 0.0}]
		toast.emit("NEW MODE: Nesting Boxes. Put two cubes behind the curtain. Don't ask questions.")
	if not unlocked[4] and int(counters.acquired) >= 10:
		unlocked[4] = true
		changed = true
		gym = [{"cube": -1, "stat": "CRN"}]
		toast.emit("NEW MODE: Gym of Corners. Your cubes can finally get swole.")
	if not unlocked[5] and max_zone >= 4:
		unlocked[5] = true
		changed = true
		toast.emit("NEW MODE: Trading Post. Barry is already lowballing you.")
	while nests.size() < nest_count() and unlocked[3]:
		nests.append({"a": -1, "b": -1, "left": 0.0})
	while gym.size() < gym_count() and unlocked[4]:
		gym.append({"cube": -1, "stat": "CRN"})
	while pens.size() < 1 + int(upgrades.get("pen", 0)):
		pens.append([])
	if changed:
		structure_changed.emit()

# ------------------------------------------------------------------ actions

func _detach(c: Dictionary) -> void:
	match c.job:
		"pen":
			var p := int(c.pen)
			if p >= 0 and p < pens.size():
				pens[p].erase(int(c.id))
		"gym":
			for slot in gym:
				if int(slot.cube) == int(c.id):
					slot.cube = -1
		"team":
			team.erase(int(c.id))
		"nest":
			for n in nests:
				if int(n.a) == int(c.id):
					n.a = -1
					n.left = 0.0
				if int(n.b) == int(c.id):
					n.b = -1
					n.left = 0.0
	c.job = ""
	c.pen = -1

func unassign(id: int) -> void:
	var c := get_cube(id)
	if c.is_empty():
		return
	_detach(c)
	structure_changed.emit()

func assign_pen(id: int, pen_index: int) -> bool:
	var c := get_cube(id)
	if c.is_empty() or pen_index < 0 or pen_index >= pens.size():
		return false
	if pens[pen_index].size() >= pen_cap():
		toast.emit("That pen is full. Cubes have personal space now, apparently.")
		return false
	_detach(c)
	pens[pen_index].append(id)
	c.job = "pen"
	c.pen = pen_index
	c.pen_since = now()
	structure_changed.emit()
	return true

func assign_team(id: int) -> bool:
	var c := get_cube(id)
	if c.is_empty():
		return false
	if team.size() >= 3:
		toast.emit("Expedition teams max out at 3. The van only has 3 seats.")
		return false
	_detach(c)
	team.append(id)
	c.job = "team"
	structure_changed.emit()
	return true

func assign_gym(id: int, slot_index: int, stat: String) -> bool:
	var c := get_cube(id)
	if c.is_empty() or slot_index < 0 or slot_index >= gym.size():
		return false
	var old := get_cube(int(gym[slot_index].cube))
	if not old.is_empty():
		_detach(old)
	_detach(c)
	gym[slot_index].cube = id
	gym[slot_index].stat = stat
	c.job = "gym"
	structure_changed.emit()
	return true

func set_gym_stat(slot_index: int, stat: String) -> void:
	gym[slot_index].stat = stat
	structure_changed.emit()

func assign_nest(id: int, box: int, side: String) -> bool:
	var c := get_cube(id)
	if c.is_empty() or box < 0 or box >= nests.size():
		return false
	var n: Dictionary = nests[box]
	var other := get_cube(int(n.b if side == "a" else n.a))
	if not other.is_empty() and (has_flag(c, "snob") and int(other.rarity) < int(c.rarity) or has_flag(other, "snob") and int(c.rarity) < int(other.rarity)):
		toast.emit("Snob refuses this partner. Find someone of equal or higher rarity.")
		return false
	var old := get_cube(int(n[side]))
	if not old.is_empty():
		_detach(old)
	_detach(c)
	n[side] = id
	c.job = "nest"
	if int(n.a) >= 0 and int(n.b) >= 0:
		n.left = breed_duration(get_cube(int(n.a)), get_cube(int(n.b)))
	structure_changed.emit()
	return true

func buy_upgrade(id: String) -> bool:
	var u: Dictionary = UPGRADES[id]
	if int(upgrades.get(id, 0)) >= int(u.max):
		return false
	var cost := upgrade_cost(id)
	if squares < cost:
		return false
	squares -= cost
	upgrades[id] = int(upgrades.get(id, 0)) + 1
	_check_unlocks()
	structure_changed.emit()
	return true

func set_zone(z: int) -> void:
	zone = clampi(z, 0, max_zone)
	zone_progress = 0.0
	structure_changed.emit()

func try_capture(enc_index: int, tool_id: String) -> Dictionary:
	if enc_index < 0 or enc_index >= encounters.size():
		return {"ok": false, "msg": "It's gone."}
	var w: Dictionary = encounters[enc_index]
	var t: Dictionary = {}
	for tt in TOOLS:
		if tt.id == tool_id:
			t = tt
	if t.is_empty() or not tool_unlocked(t):
		return {"ok": false, "msg": "You don't have that tool yet."}
	if cubes.size() >= roster_cap():
		return {"ok": false, "msg": "Your barn is full. Release or sell a cube first."}
	var cost := tool_cost(t, w)
	if squares < cost:
		return {"ok": false, "msg": "Not enough Squares for that."}
	squares -= cost
	if rng.randf() < capture_chance(w, t):
		encounters.remove_at(enc_index)
		w.id = _take_id()
		w.job = ""
		w.pen = -1
		w.erase("zone")
		if w.origin != "bred" and w.origin != "starter" and w.origin != "gift":
			w.origin = "wild"
		_add_cube(w)
		counters.captures += 1
		structure_changed.emit()
		reveal.emit(w, "CAUGHT!")
		return {"ok": true, "msg": "Caught %s!" % w.name}
	var fled := rng.randf() < 0.35
	if fled:
		encounters.remove_at(enc_index)
		structure_changed.emit()
		var taunts := ["%s fled, but not before making a rude face.", "%s escaped and joined a rival rancher.", "%s rolled away laughing."]
		return {"ok": false, "msg": taunts[rng.randi() % taunts.size()] % w.name, "fled": true}
	var mocks := ["%s dodged and mocked your technique.", "%s is unimpressed. Try again.", "%s wiggled free. Its edges are slippery."]
	return {"ok": false, "msg": mocks[rng.randi() % mocks.size()] % w.name}

func release_encounter(enc_index: int) -> void:
	if enc_index >= 0 and enc_index < encounters.size():
		encounters.remove_at(enc_index)
		structure_changed.emit()

func hatch(egg_index: int) -> bool:
	if egg_index < 0 or egg_index >= eggs.size():
		return false
	var e: Dictionary = eggs[egg_index]
	if float(e.hatch_at) > now():
		return false
	if cubes.size() >= roster_cap():
		toast.emit("Your barn is full. The egg refuses to hatch into a crowded barn.")
		return false
	eggs.remove_at(egg_index)
	var c: Dictionary = e.cube
	_add_cube(c)
	if e.gift == "":
		counters.eggs_hatched += 1
	structure_changed.emit()
	var headline := "IT HATCHED!"
	if e.mutated:
		headline = "MUTATION!"
	if e.gift != "":
		headline = "GIFT EGG!"
	reveal.emit(c, headline)
	return true

func release_cube(id: int) -> Dictionary:
	var c := get_cube(id)
	if c.is_empty():
		return {"ok": false, "msg": ""}
	if has_flag(c, "immortal"):
		return {"ok": false, "msg": "%s refuses to leave. It's Accidentally Immortal." % c.name}
	if cubes.size() <= 1:
		return {"ok": false, "msg": "You can't release your last cube. That would just be sad."}
	var refund: float = lib.value(c) * 0.2
	_detach(c)
	cubes.erase(c)
	squares += refund
	structure_changed.emit()
	return {"ok": true, "msg": "%s returned to the Wilds and left %s Squares as a thank-you note." % [c.name, fmt(refund)]}

func rename_cube(id: int, new_name: String) -> void:
	var c := get_cube(id)
	if c.is_empty():
		return
	var nm := new_name.strip_edges().left(24)
	if nm != "":
		c.name = nm
		structure_changed.emit()

## Haggle step: returns storm-off chance for the next push.
func storm_chance(pushes: int) -> float:
	var ch := 0.10 + 0.13 * pushes
	if any_owned_with("smooth"):
		ch *= 0.6
	return clampf(ch, 0.0, 0.95)

func sell_cube(id: int, trader_id: String, pushes: int) -> Dictionary:
	var c := get_cube(id)
	var trader: Dictionary = {}
	for tr in TRADERS:
		if tr.id == trader_id:
			trader = tr
	if c.is_empty() or trader.is_empty() or not trader_accepts(c, trader) or not trader_available(trader_id):
		return {"ok": false, "msg": "No deal."}
	if cubes.size() <= 1:
		return {"ok": false, "msg": "You can't sell your last cube."}
	var price := trade_price(c, trader) * pow(1.12, pushes)
	if has_flag(c, "dramatic"):
		price *= rng.randf_range(0.75, 1.25)
	var bonus := ""
	if any_owned_with("deal") and deal_ready_at <= now():
		deal_ready_at = now() + 86400.0
		price *= 3.0
		bonus = " Deal of a Lifetime: triple payout!"
	_detach(c)
	cubes.erase(c)
	squares += price
	counters.trades += 1
	structure_changed.emit()
	return {"ok": true, "msg": "Sold %s to %s for %s Squares.%s" % [c.name, trader.name, fmt(price), bonus]}

func haggle_push(trader_id: String, pushes: int) -> bool:
	## Returns true if the trader stormed off.
	if rng.randf() < storm_chance(pushes):
		trader_cooldown[trader_id] = now() + 600.0
		structure_changed.emit()
		return true
	return false

func buy_rock() -> Dictionary:
	var cost := 10.0 + 25.0 * max_zone
	if squares < cost:
		return {"ok": false, "msg": "A Child wants %s Squares for the rock. You can't afford a rock." % fmt(cost)}
	squares -= cost
	counters.trades += 1
	counters.rocks += 1
	if rng.randf() < 0.05 and eggs.size() < incubator_cap() + 2:
		var w: Dictionary = lib.new_wild(rng, _take_id(), max_zone, 1.6 + max_zone * 0.08)
		w.origin = "rock"
		w.rarity = lib.compute_rarity(w)
		eggs.append({"cube": w, "hatch_at": now(), "mutated": false, "gift": ""})
		structure_changed.emit()
		return {"ok": true, "msg": "The rock cracked open. It was an EGG the whole time!"}
	var lines := ["It's a rock.", "It's a rock. A Child seems very proud of it.", "Still a rock. You now own %d rocks." % counters.rocks, "It's a rock, but a really nice one."]
	return {"ok": true, "msg": lines[rng.randi() % lines.size()]}

func buy_from_gary(index: int) -> Dictionary:
	if index < 0 or index >= gary_stock.size():
		return {"ok": false, "msg": "Sold out."}
	var w: Dictionary = gary_stock[index]
	var price: float = lib.value(w) * 1.6
	if squares < price:
		return {"ok": false, "msg": "Gary says that's not enough. Gary's children are 'premium'."}
	if cubes.size() >= roster_cap():
		return {"ok": false, "msg": "Your barn is full."}
	squares -= price
	gary_stock.remove_at(index)
	w.id = _take_id()
	w.origin = "shop"
	w.erase("zone")
	_add_cube(w)
	counters.trades += 1
	structure_changed.emit()
	reveal.emit(w, "PURCHASED!")
	return {"ok": true, "msg": "You bought %s. Gary waves goodbye to his child." % w.name}

func gary_restock_cost() -> float:
	return 50.0 * pow(1.6, max_zone)

func paid_restock() -> bool:
	var cost := gary_restock_cost()
	if squares < cost:
		return false
	squares -= cost
	restock_gary()
	return true

# ------------------------------------------------------------------ offline + save

func _apply_offline(away: float) -> void:
	var cap := OFFLINE_CAP_WORKAHOLIC if any_owned_with("workaholic") else OFFLINE_CAP
	var span := clampf(away, 0.0, cap)
	var total := {"squares": 0.0, "eggs": 0, "encounters": 0, "zones": 0, "seconds": span, "capped": away > cap}
	var step := 60.0
	var remaining := span
	while remaining > 0.0:
		var dt := minf(step, remaining)
		remaining -= dt
		var r := tick(dt, true)
		total.squares += r.squares
		total.eggs += r.eggs
		total.encounters += r.encounters
		total.zones += r.zones
	last_tick = now()
	if span >= 60.0:
		welcome_back.emit(total)
	structure_changed.emit()

func save_game() -> void:
	last_tick = now()
	var data := {
		"version": SAVE_VERSION, "squares": squares, "lifetime_squares": lifetime_squares,
		"cubes": cubes, "next_id": next_id, "pens": pens, "nests": nests, "eggs": eggs, "gym": gym,
		"team": team, "zone": zone, "max_zone": max_zone, "zones_cleared": zones_cleared,
		"zone_progress": zone_progress, "encounters": encounters, "encounter_timer": encounter_timer,
		"upgrades": upgrades, "unlocked": unlocked, "milestones": milestones, "counters": counters,
		"codex": codex, "hourly_accum": hourly_accum, "next_audit": next_audit,
		"trader_cooldown": trader_cooldown, "gary_stock": gary_stock, "gary_restock_at": gary_restock_at,
		"deal_ready_at": deal_ready_at, "last_tick": last_tick,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = parsed
	squares = float(d.get("squares", 0.0))
	lifetime_squares = float(d.get("lifetime_squares", 0.0))
	cubes = []
	for c in d.get("cubes", []):
		cubes.append(_norm_cube(c))
	next_id = int(d.get("next_id", 1))
	pens = []
	for p in d.get("pens", [[]]):
		var arr: Array = []
		for id in p:
			arr.append(int(id))
		pens.append(arr)
	nests = []
	for n in d.get("nests", []):
		nests.append({"a": int(n.a), "b": int(n.b), "left": float(n.left)})
	eggs = []
	for e in d.get("eggs", []):
		eggs.append({"cube": _norm_cube(e.cube), "hatch_at": float(e.hatch_at), "mutated": bool(e.get("mutated", false)), "gift": str(e.get("gift", ""))})
	gym = []
	for g in d.get("gym", []):
		gym.append({"cube": int(g.cube), "stat": str(g.stat)})
	team = []
	for id in d.get("team", []):
		team.append(int(id))
	zone = int(d.get("zone", 0))
	max_zone = int(d.get("max_zone", 0))
	zones_cleared = int(d.get("zones_cleared", 0))
	zone_progress = float(d.get("zone_progress", 0.0))
	encounters = []
	for w in d.get("encounters", []):
		var nw := _norm_cube(w)
		nw["zone"] = int(w.get("zone", 0))
		encounters.append(nw)
	encounter_timer = float(d.get("encounter_timer", 20.0))
	upgrades = {}
	for k in UPGRADES:
		upgrades[k] = int(d.get("upgrades", {}).get(k, 0))
	unlocked = {}
	milestones = {}
	for m in [1, 2, 3, 4, 5]:
		unlocked[m] = bool(d.get("unlocked", {}).get(str(m), m <= 2))
		milestones[m] = int(d.get("milestones", {}).get(str(m), 0))
	var cn: Dictionary = d.get("counters", {})
	for k in counters:
		counters[k] = cn.get(k, counters[k])
	counters.eggs_hatched = int(counters.eggs_hatched)
	counters.trades = int(counters.trades)
	counters.captures = int(counters.captures)
	counters.acquired = int(counters.acquired)
	counters.rocks = int(counters.rocks)
	counters.train_points = float(counters.train_points)
	codex = d.get("codex", {})
	hourly_accum = float(d.get("hourly_accum", 0.0))
	next_audit = float(d.get("next_audit", 7200.0))
	trader_cooldown = d.get("trader_cooldown", {})
	gary_stock = []
	for w in d.get("gary_stock", []):
		var gw := _norm_cube(w)
		gw["zone"] = int(w.get("zone", 0))
		gary_stock.append(gw)
	gary_restock_at = float(d.get("gary_restock_at", 0.0))
	deal_ready_at = float(d.get("deal_ready_at", 0.0))
	last_tick = float(d.get("last_tick", now()))
	_sanitize_times()
	_check_unlocks()
	var away := now() - last_tick
	if away > 60.0:
		_apply_offline.call_deferred(away)
	else:
		last_tick = now()
	return true

## Guards against the device clock jumping backwards: no saved timer may sit
## further in the future than its longest legitimate duration.
func _sanitize_times() -> void:
	var t := now()
	if last_tick > t:
		last_tick = t
	for e in eggs:
		e.hatch_at = minf(float(e.hatch_at), t + 3600.0)
	for k in trader_cooldown.keys():
		trader_cooldown[k] = minf(float(trader_cooldown[k]), t + 600.0)
	gary_restock_at = minf(gary_restock_at, t + 14400.0)
	deal_ready_at = minf(deal_ready_at, t + 86400.0)
	for c in cubes:
		for key in ["n20_at", "fetch_at", "black_eye_until"]:
			if c.flags.has(key):
				c.flags[key] = minf(float(c.flags[key]), t + 86400.0)
		if c.flags.has("klepto_at"):
			c.flags["klepto_at"] = minf(float(c.flags["klepto_at"]), t + 604800.0)
		c.pen_since = minf(float(c.pen_since), t)

func _norm_cube(c: Dictionary) -> Dictionary:
	var out: Dictionary = lib.blank_cube(int(c.get("id", 0)))
	for k in c:
		out[k] = c[k]
	for k in ["id", "gen", "rarity", "size", "material", "pattern", "eyes", "mouth", "edge", "appendage", "slots", "pen"]:
		out[k] = int(out[k])
	var parents: Array = []
	for p in out.parents:
		parents.append(int(p))
	out.parents = parents
	var traits: Array = []
	for t in out.traits:
		traits.append(str(t))
	out.traits = traits
	for key in ["base", "trained", "potential"]:
		var src: Dictionary = out[key]
		var dst := {}
		for s in lib.STATS:
			dst[s] = float(src.get(s, 0.0))
		out[key] = dst
	return out

func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	new_game()
	structure_changed.emit()

# ------------------------------------------------------------------ format

func fmt(x: float) -> String:
	var neg := x < 0.0
	x = absf(x)
	var s := ""
	if x < 1000.0:
		s = str(snappedf(x, 0.1)) if x < 100.0 else str(int(x))
	else:
		var suffixes := ["K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
		var e := int(floor(log(x) / log(1000.0)))
		if e - 1 < suffixes.size():
			s = "%.2f%s" % [x / pow(1000.0, e), suffixes[e - 1]]
		else:
			var exp10 := int(floor(log(x) / log(10.0)))
			s = "%.2fe%d" % [x / pow(10.0, exp10), exp10]
	return ("-" if neg else "") + s

func fmt_time(sec: float) -> String:
	sec = max(0.0, sec)
	if sec < 60.0:
		return "%ds" % int(sec)
	if sec < 3600.0:
		return "%dm %02ds" % [int(sec / 60.0), int(sec) % 60]
	return "%dh %02dm" % [int(sec / 3600.0), int(sec / 60.0) % 60]
