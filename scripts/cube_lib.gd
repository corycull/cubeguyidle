extends RefCounted
## Cube genetics: generating wild cubes, breeding, rarity and value.
## A cube is a plain Dictionary so it saves to JSON with no conversion.

const STATS := ["CRN", "HFT", "WBL", "CHA", "FRT", "SMT", "VIB"]
const STAT_NAMES := {"CRN": "Cornerness", "HFT": "Heft", "WBL": "Wobble", "CHA": "Charisma", "FRT": "Fertility", "SMT": "Smarts", "VIB": "Vibe"}
const SIZES := ["Pebble", "Dice", "Toaster", "Fridge", "Shed", "Cathedral", "Moon"]
const SIZE_WEIGHTS := [22.0, 26.0, 22.0, 14.0, 9.0, 5.0, 2.0]
const MATERIALS := ["Cardboard", "Jelly", "Granite", "Velvet", "Lasagna", "Ham", "Stained Glass", "Pure Regret"]
const MATERIAL_WEIGHTS := [28.0, 18.0, 16.0, 12.0, 9.0, 8.0, 6.0, 3.0]
const PATTERNS := ["Plain", "Stripes", "Dots", "Plaid", "Checker", "Stock Photo Watermark"]
const PATTERN_WEIGHTS := [40.0, 18.0, 16.0, 11.0, 10.0, 5.0]
const MOUTHS := ["Smile", "Flat", "O", "Grin", "Frown", "Teeth"]
const EDGES := ["Sharp", "Bevelled", "Rounded", "Frayed", "Lightly Buttered"]
const APPENDAGES := ["None", "Tiny Legs", "Big Legs", "Wheels", "Wings", "A Single Arm That Waves"]
const APPENDAGE_WEIGHTS := [40.0, 18.0, 10.0, 14.0, 8.0, 10.0]
const PALETTE := ["ff6b6b", "ffa94d", "ffd43b", "a9e34b", "51cf66", "38d9a9", "3bc9db", "4dabf7",
	"748ffc", "9775fa", "da77f2", "f783ac", "e9c46a", "8d6e63", "ced4da", "343a40"]
const NAME_A := ["Cub", "Box", "Squa", "Corn", "Blo", "Edg", "Hex", "Dic", "Grou", "Tes", "Bric", "Cra", "Toas", "Plin", "Mon", "Ker"]
const NAME_B := ["ert", "ina", "o", "bert", "ster", "athan", "ley", "ius", "ette", "y", "kins", "bo", "ward", "ara", "on", "ith"]
const TITLES := ["", "", "", "", "Sir ", "Lady ", "Little ", "Big ", "Dr. ", "Lord ", "Mx. "]

var db

func _init(trait_db) -> void:
	db = trait_db

func _pick_weighted(rng: RandomNumberGenerator, weights: Array, luck: float = 0.0) -> int:
	var total := 0.0
	var ws: Array = []
	for i in weights.size():
		var w: float = weights[i] * pow(1.0 + luck, float(i) / max(1.0, weights.size() - 1.0) * 3.0)
		ws.append(w)
		total += w
	var roll := rng.randf() * total
	for i in ws.size():
		roll -= ws[i]
		if roll <= 0.0:
			return i
	return ws.size() - 1

func make_name(rng: RandomNumberGenerator) -> String:
	return TITLES[rng.randi() % TITLES.size()] + NAME_A[rng.randi() % NAME_A.size()] + NAME_B[rng.randi() % NAME_B.size()]

func blank_cube(id: int) -> Dictionary:
	return {
		"id": id, "name": "Cube", "gen": 0, "rarity": 0,
		"size": 1, "material": 0, "color": "ffd43b", "pattern": 0, "eyes": 2, "mouth": 0, "edge": 0, "appendage": 0,
		"base": {}, "trained": {}, "potential": {}, "traits": [], "slots": 3, "parents": [],
		"born": Time.get_unix_time_from_system(), "job": "", "pen": -1, "pen_since": 0.0,
		"origin": "wild", "flags": {}
	}

## A wild cube for zone z (0-based). luck shifts traits and attributes rarer.
func new_wild(rng: RandomNumberGenerator, id: int, zone: int, luck: float) -> Dictionary:
	var c := blank_cube(id)
	c.name = make_name(rng)
	var mean := 8.0 * pow(1.17, zone)
	for s in STATS:
		var v: float = max(1.0, rng.randfn(mean, mean * 0.3))
		c.base[s] = snappedf(v, 0.1)
		c.trained[s] = 0.0
		c.potential[s] = snappedf(v * rng.randf_range(1.5, 3.0), 0.1)
	c.size = _pick_weighted(rng, SIZE_WEIGHTS, luck * 0.5)
	c.material = _pick_weighted(rng, MATERIAL_WEIGHTS, luck)
	c.pattern = _pick_weighted(rng, PATTERN_WEIGHTS, luck)
	c.appendage = _pick_weighted(rng, APPENDAGE_WEIGHTS, luck * 0.5)
	c.color = PALETTE[rng.randi() % PALETTE.size()]
	c.eyes = _roll_eyes(rng)
	c.mouth = rng.randi() % MOUTHS.size()
	c.edge = rng.randi() % EDGES.size()
	var n_traits := 1
	if rng.randf() < 0.45 + luck * 0.1:
		n_traits += 1
	if rng.randf() < 0.15 + luck * 0.1:
		n_traits += 1
	for _i in n_traits:
		var t: String = db.roll_base_trait(rng, luck, c.traits)
		if t != "":
			c.traits.append(t)
	c.rarity = compute_rarity(c)
	return c

func _roll_eyes(rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	if r < 0.70:
		return 2
	if r < 0.82:
		return 1
	if r < 0.92:
		return 3
	if r < 0.96:
		return 0
	return rng.randi_range(4, 12)

## Rarity comes from total roll quality: traits, stats and rare attributes.
func compute_rarity(c: Dictionary) -> int:
	var pts := 0.0
	var best_trait := 0
	for t in c.traits:
		var tr: Dictionary = db.get_trait(t)
		if tr.is_empty():
			continue
		pts += db.RARITY_WEIGHT[tr.rarity]
		best_trait = max(best_trait, tr.rarity)
	var avg := stat_avg(c, false)
	pts += log(1.0 + avg) / log(10.0) * 2.2
	if c.material >= 6:
		pts += 1.0
	if c.size >= 5:
		pts += 0.8
	if c.eyes >= 4:
		pts += 0.6
	if c.pattern == 5:
		pts += 0.6
	var thresholds := [4.0, 6.5, 9.5, 13.0, 17.0, 22.0, 28.0, 35.0]
	var tier := 0
	for th in thresholds:
		if pts >= th:
			tier += 1
	tier = max(tier, best_trait)
	if c.traits.has("average"):
		tier += 1
	return clampi(tier, 0, 8)

func stat_avg(c: Dictionary, include_trained: bool = true) -> float:
	var total := 0.0
	for s in STATS:
		total += float(c.base.get(s, 0.0))
		if include_trained:
			total += float(c.trained.get(s, 0.0))
	return total / STATS.size()

## Base Square value used by traders. Breeding and rarity both push it up.
func value(c: Dictionary) -> float:
	var v := 15.0 * pow(2.1, c.rarity) * (1.0 + stat_avg(c) / 40.0)
	for t in c.traits:
		var m: Dictionary = db.get_trait(t).get("mods", {})
		v *= 1.0 + float(m.get("sell", 0.0))
	if c.flags.get("influenced", false):
		v *= 1.3
	return v

## Returns {"child": Dictionary, "mutated": bool}. extra_mut adds mutation chance.
func breed(rng: RandomNumberGenerator, id: int, a: Dictionary, b: Dictionary, extra_mut: float, force_mutation: bool, extra_stats: float = 0.0) -> Dictionary:
	var c := blank_cube(id)
	c.name = make_name(rng)
	c.gen = max(int(a.gen), int(b.gen)) + 1
	c.parents = [a.id, b.id]
	c.origin = "bred"
	var child_bonus := extra_stats
	for p in [a, b]:
		for t in p.traits:
			var m: Dictionary = db.get_trait(t).get("mods", {})
			child_bonus += float(m.get("child_stats", 0.0))
			if m.get("snob", 0) == 1:
				child_bonus += 0.10
			if m.get("influencer", 0) == 1:
				c.flags["influenced"] = true
	for s in STATS:
		var mid := (float(a.base[s]) + float(b.base[s])) / 2.0
		# Trained stats leak a little into the next generation, so training matters.
		mid += (float(a.trained.get(s, 0.0)) + float(b.trained.get(s, 0.0))) * 0.05
		var v := mid * rng.randf_range(0.92, 1.14) * (1.0 + child_bonus)
		if rng.randf() < 0.05:
			v *= 1.25  # Hybrid Vigor
		c.base[s] = snappedf(max(1.0, v), 0.1)
		c.trained[s] = 0.0
		c.potential[s] = snappedf(c.base[s] * rng.randf_range(1.5, 3.0), 0.1)
	c.size = _inherit(rng, a.size, b.size, SIZES.size())
	c.material = _inherit(rng, a.material, b.material, MATERIALS.size())
	c.pattern = _inherit(rng, a.pattern, b.pattern, PATTERNS.size())
	c.appendage = _inherit(rng, a.appendage, b.appendage, APPENDAGES.size())
	c.mouth = _inherit(rng, a.mouth, b.mouth, MOUTHS.size())
	c.edge = _inherit(rng, a.edge, b.edge, EDGES.size())
	c.eyes = a.eyes if rng.randf() < 0.5 else b.eyes
	if rng.randf() < 0.05:
		c.eyes = _roll_eyes(rng)
	c.color = _blend_color(rng, a.color, b.color)
	var slots := 3
	if a.traits.has("cursed_heirloom") or b.traits.has("cursed_heirloom"):
		slots = 2
	c.slots = slots
	# Trait inheritance
	var candidates := {}
	for p in [a, b]:
		var partner: Dictionary = b if p == a else a
		var partner_boost := 0.0
		for t in partner.traits:
			partner_boost += float(db.get_trait(t).get("mods", {}).get("partner_pass", 0.0))
		for t in p.traits:
			var tr: Dictionary = db.get_trait(t)
			if tr.is_empty():
				continue
			var chance := 0.30
			match tr.inh:
				"D": chance = 0.60
				"R": chance = 0.30
				"C": chance = 0.50
			chance += partner_boost
			if a.traits.has(t) and b.traits.has(t):
				chance = max(chance, 0.88)
			candidates[t] = max(float(candidates.get(t, 0.0)), chance)
	var keys := candidates.keys()
	keys.shuffle()
	for t in keys:
		if c.traits.size() >= slots:
			break
		if rng.randf() < candidates[t]:
			c.traits.append(t)
	var mutated := false
	var mut_chance := 0.03 + extra_mut
	if force_mutation or rng.randf() < mut_chance:
		var luck: float = 0.6 + int(c.gen) * 0.02
		var t: String = db.roll_base_trait(rng, luck, c.traits)
		if t != "":
			if c.traits.size() >= slots:
				c.traits[rng.randi() % c.traits.size()] = t
			else:
				c.traits.append(t)
			mutated = true
		if rng.randf() < 0.4:
			c.material = _pick_weighted(rng, MATERIAL_WEIGHTS, 2.0)
	c.rarity = compute_rarity(c)
	return {"child": c, "mutated": mutated}

func _inherit(rng: RandomNumberGenerator, x: int, y: int, count: int) -> int:
	var r := rng.randf()
	if r < 0.47:
		return x
	if r < 0.94:
		return y
	return rng.randi() % count

func _blend_color(rng: RandomNumberGenerator, x: String, y: String) -> String:
	var r := rng.randf()
	if r < 0.4:
		return x
	if r < 0.8:
		return y
	if r < 0.95:
		return Color(x).lerp(Color(y), 0.5).to_html(false)
	return PALETTE[rng.randi() % PALETTE.size()]
