extends Node
## Every trait in the vertical slice: the 50-trait base pool plus the 25
## exclusive traits for modes 1-5. Numeric "mods" stack additively; keys set to
## 1 are special behaviours handled in game_state.gd.

const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "Glitched", "Platonic"]
const RARITY_COLORS := [
	Color("a3a8b4"), Color("5fd06f"), Color("4f9cff"), Color("b26bff"), Color("ffad1f"),
	Color("ff4f8b"), Color("3fe0d6"), Color("c8ff3d"), Color("ffffff")]
const RARITY_WEIGHT := [0.5, 1.0, 2.0, 3.5, 5.0, 7.0, 9.0, 11.0, 13.0]
const BASE_ROLL_WEIGHTS := [55.0, 25.0, 12.0, 6.0, 2.0]

const MODE_NAMES := {1: "The Ranch", 2: "The Wilds", 3: "Nesting Boxes", 4: "Gym of Corners", 5: "Trading Post"}

var traits := {}
var base_ids: Array = []
var by_mode := {}
var base_by_rarity := {}

func _init() -> void:
	_build_base()
	_build_modes()
	for id in base_ids:
		var r: int = traits[id].rarity
		if not base_by_rarity.has(r):
			base_by_rarity[r] = []
		base_by_rarity[r].append(id)

func _t(id: String, nm: String, rarity: int, kind: String, inh: String, desc: String, mods: Dictionary = {}, mode: int = 0) -> void:
	traits[id] = {"id": id, "name": nm, "rarity": rarity, "kind": kind, "inh": inh, "desc": desc, "mods": mods, "mode": mode}
	if mode == 0:
		base_ids.append(id)
	else:
		if not by_mode.has(mode):
			by_mode[mode] = []
		by_mode[mode].append(id)

func get_trait(id: String) -> Dictionary:
	return traits.get(id, {})

func rarity_name(r: int) -> String:
	return RARITY_NAMES[clampi(r, 0, RARITY_NAMES.size() - 1)]

func rarity_color(r: int) -> Color:
	return RARITY_COLORS[clampi(r, 0, RARITY_COLORS.size() - 1)]

## Rolls a base-pool trait. luck > 0 shifts odds toward rarer tiers.
func roll_base_trait(rng: RandomNumberGenerator, luck: float, exclude: Array = []) -> String:
	var weights: Array = []
	var total := 0.0
	for i in BASE_ROLL_WEIGHTS.size():
		var w: float = BASE_ROLL_WEIGHTS[i] * pow(1.0 + luck, i)
		weights.append(w)
		total += w
	for _attempt in 12:
		var roll := rng.randf() * total
		var tier := 0
		for i in weights.size():
			roll -= weights[i]
			if roll <= 0.0:
				tier = i
				break
		var pool: Array = base_by_rarity[tier]
		var pick: String = pool[rng.randi() % pool.size()]
		if not exclude.has(pick):
			return pick
	return ""

func _build_base() -> void:
	# --- Common (15) ---
	_t("hard_worker", "Hard Worker", 0, "Positive", "D", "+10% Squares", {"squares": 0.10})
	_t("sleepy", "Sleepy", 0, "Mixed", "R", "-50% output, +100% offline output", {"squares": -0.5, "offline": 1.0})
	_t("owes_money", "Owes Money", 0, "Mixed", "C", "Randomly leaves; returns with Squares or a black eye", {"owes_money": 1})
	_t("lazy", "Lazy", 0, "Negative", "D", "-15% Squares, +5% mood for pen mates (\"it's thriving\")", {"squares": -0.15, "pen_squares": 0.05})
	_t("chunky", "Chunky", 0, "Positive", "D", "+10% Heft", {"HFT": 0.10})
	_t("fidgety", "Fidgety", 0, "Mixed", "R", "+10% Wobble, -10% Smarts", {"WBL": 0.10, "SMT": -0.10})
	_t("shy", "Shy", 0, "Negative", "R", "-20% Charisma; +10% output while you're offline", {"CHA": -0.20, "offline": 0.10})
	_t("toast", "Smells Faintly of Toast", 0, "Positive", "D", "+5% output for every cube in its pen", {"pen_squares": 0.05})
	_t("dog", "Thinks It's a Dog", 0, "Positive", "R", "Fetches something from the Wilds once a day", {"fetch": 1})
	_t("hat", "Has a Little Hat Already", 0, "Positive", "R", "Comes with a free tiny hat", {"hat": 1})
	_t("clumsy", "Clumsy", 0, "Negative", "D", "Knocks over its eggs (they survive, offended): +20% incubation time", {"clumsy": 1})
	_t("picky", "Picky Eater", 0, "Negative", "R", "-10% training speed (won't eat the protein grout)", {"train": -0.10})
	_t("loud", "Loud", 0, "Mixed", "D", "+10% Charisma, -5% output for pen mates", {"CHA": 0.10, "pen_squares": -0.05})
	_t("corporate", "Corporate", 0, "Mixed", "D", "+3% Squares; schedules meetings that slow pen mates 2%", {"squares": 0.03, "pen_squares": -0.02})
	_t("damp", "Damp", 0, "Negative", "C", "-5% all stats. Nobody knows why", {"all": -0.05})
	# --- Uncommon (12) ---
	_t("allergic", "Allergic to Corners", 1, "Negative", "R", "Sneezes constantly; -10% Cornerness", {"CRN": -0.10})
	_t("podcast", "Podcast Host", 1, "Negative", "D", "+10% own Smarts, -10% output for pen mates", {"SMT": 0.10, "pen_squares": -0.10})
	_t("part_bread", "Part Bread", 1, "Positive", "R", "Breeds 3x faster with Lasagna cubes", {"part_bread": 1})
	_t("gym_rat", "Gym Rat", 1, "Positive", "D", "+25% Gym training speed", {"train": 0.25})
	_t("escape", "Escape Artist", 1, "Negative", "D", "2% chance per hour to flee to the Wilds (recapturable)", {"escape": 1})
	_t("lucky_dice", "Lucky Dice", 1, "Positive", "C", "+5% mutation chance in its eggs", {"mutation": 0.05})
	_t("snob", "Snob", 1, "Mixed", "R", "Won't breed with lower-rarity partners; +10% child stats when it does", {"snob": 1})
	_t("night_owl", "Night Owl", 1, "Mixed", "R", "+30% output at night, -15% by day", {"night_owl": 1})
	_t("overachiever", "Overachiever", 1, "Positive", "D", "+15% to its highest stat, -5% to its lowest", {"overachiever": 1})
	_t("hypochondriac", "Hypochondriac", 1, "Negative", "R", "Skips 10% of breeding sessions due to \"symptoms\"", {"hypochondriac": 1})
	_t("emotional_support", "Emotional Support Cube", 1, "Positive", "R", "Pen mates ignore all negative mood effects", {"emotional_support": 1})
	_t("glass_edges", "Glass Edges", 1, "Mixed", "D", "+20% Charisma, -30% Heft", {"CHA": 0.20, "HFT": -0.30})
	# --- Rare (10) ---
	_t("main_character", "Main Character", 2, "Mixed", "D", "+10% Charisma; pen mates are mildly annoyed (-3% output)", {"CHA": 0.10, "pen_squares": -0.03})
	_t("haunted", "Haunted", 2, "Mixed", "C", "+5% Squares; occasionally moans at 3am", {"squares": 0.05, "haunted": 1})
	_t("load_bearing", "Emotionally Load-Bearing", 2, "Mixed", "R", "+20% output for pen mates", {"pen_squares": 0.20})
	_t("search_history", "Knows Your Search History", 2, "Mixed", "R", "+50% Smarts, -20% Charisma (unsettling)", {"SMT": 0.50, "CHA": -0.20})
	_t("immortal", "Accidentally Immortal", 2, "Mixed", "D", "Can't be released into the Wilds (it walks back). Traders will still take it", {"immortal": 1})
	_t("twins", "Twins Energy", 2, "Positive", "R", "15% chance of twin eggs", {"twins": 0.15})
	_t("klepto", "Kleptomaniac", 2, "Mixed", "C", "Steals Squares from NPC traders once a week", {"klepto": 1})
	_t("workaholic", "Workaholic", 2, "Positive", "D", "Raises the offline progress cap to 72 hours", {"workaholic": 1})
	_t("ego_death", "Ego Death", 2, "Negative", "R", "+30% Smarts; refuses to be admired (-50% Charisma)", {"SMT": 0.30, "CHA": -0.50})
	_t("gold_plated", "Gold Plated", 2, "Positive", "R", "+50% sale value to traders", {"sell": 0.50})
	# --- Epic (8) ---
	_t("forbidden_geometry", "Forbidden Geometry", 3, "Positive", "R", "Counts as two cubes for breeding: +1 egg per clutch", {"extra_egg": 1})
	_t("tax_exempt", "Tax Exempt", 3, "Positive", "R", "Immune to the Cube IRS Audit event (protects the whole ranch)", {"tax_exempt": 1})
	_t("natural20", "Rolled a Natural 20", 3, "Positive", "C", "Its next clutch is guaranteed a mutation (recharges daily)", {"natural20": 1})
	_t("cursed_heirloom", "Cursed Heirloom", 3, "Mixed", "D", "+40% all stats; its children get one fewer trait slot", {"all": 0.40, "cursed": 1})
	_t("contagious", "Contagious Enthusiasm", 3, "Positive", "D", "+5% output for pen mates", {"pen_squares": 0.05})
	_t("sphere_curious", "Sphere-Curious", 3, "Mixed", "C", "+50% Wobble; 1% daily chance to roll away", {"WBL": 0.50, "roll_away": 1})
	_t("black_hole", "Black Hole Appetite", 3, "Negative", "D", "+30% Heft; eats the pen's snacks (-5% output for pen mates)", {"HFT": 0.30, "pen_squares": -0.05})
	_t("dramatic", "Dramatic", 3, "Mixed", "D", "+20% Charisma; traders pay +/-25% at random", {"CHA": 0.20, "dramatic": 1})
	# --- Legendary (5) ---
	_t("other_side", "Has Seen The Other Side", 4, "Positive", "R", "On an expedition, wild cubes roll much rarer traits", {"rare_find": 0.6})
	_t("average", "Aggressively Average", 4, "Positive", "R", "All stats set to its own average; counts one rarity tier higher", {"average": 1, "rarity_up": 1})
	_t("influencer", "Influencer", 4, "Positive", "D", "Its offspring sell for 30% more", {"influencer": 1})
	_t("time_blind", "Time Blind", 4, "Mixed", "C", "Its breeding timers run at a random 0.5x to 3x speed", {"time_blind": 1})
	_t("chosen", "The Chosen One", 4, "Positive", "R", "+25% all stats; the narrator calls it by name", {"all": 0.25, "chosen": 1})

func _build_modes() -> void:
	# Mode 1: The Ranch
	_t("homebody", "Homebody", 0, "Positive", "D", "+15% Squares after 24 hours in the same pen", {"homebody": 1}, 1)
	_t("fence_sitter", "Fence Sitter", 1, "Positive", "R", "Counts as being in two pens: +8% output for pen mates", {"pen_squares": 0.08}, 1)
	_t("landlord", "Landlord", 2, "Positive", "D", "+2% Squares per cube in its pen (max +30%)", {"landlord": 1}, 1)
	_t("barn_burner", "Barn Burner", 3, "Positive", "R", "Doubles its output from :00 to :10 every hour", {"barn_burner": 1}, 1)
	_t("ranch_royalty", "Ranch Royalty", 4, "Positive", "D", "+20% Squares ranch-wide while it's in a pen", {"global_squares": 0.20}, 1)
	# Mode 2: The Wilds
	_t("trail_mix", "Trail Mix", 0, "Positive", "D", "+10% expedition encounter rate", {"encounter": 0.10}, 2)
	_t("feral", "Feral", 1, "Mixed", "D", "+20% Heft and Wobble, -20% Charisma", {"HFT": 0.20, "WBL": 0.20, "CHA": -0.20}, 2)
	_t("bait", "Bait", 2, "Positive", "R", "Wild cubes are 25% more likely to approach its team", {"encounter": 0.25}, 2)
	_t("apex", "Apex Predator of Shapes", 3, "Positive", "R", "+15% capture chance for its expedition team", {"capture": 0.15}, 2)
	_t("call_wild", "Call of the Wild", 4, "Positive", "R", "5% chance per encounter that a Legendary-trait cube follows it home", {"call_wild": 1}, 2)
	# Mode 3: Nesting Boxes
	_t("broody", "Broody", 0, "Positive", "D", "+10% chance of an extra egg", {"eggs": 0.10}, 3)
	_t("overprotective", "Overprotective Parent", 1, "Positive", "R", "Its eggs incubate 25% faster", {"incubate": 0.25}, 3)
	_t("matchmaker", "Matchmaker's Pet", 2, "Positive", "R", "+15% trait pass chance for its partner", {"partner_pass": 0.15}, 3)
	_t("grandparent", "Grandparent Energy", 3, "Positive", "D", "+5% stats for its children", {"child_stats": 0.05}, 3)
	_t("fertile", "Fertile Ground", 4, "Positive", "R", "-50% breeding time for any pair it's in", {"breed_speed": 0.50}, 3)
	# Mode 4: Gym of Corners
	_t("warm_up", "Warm-Up Routine", 0, "Positive", "D", "+10% training speed", {"train": 0.10}, 4)
	_t("protein", "Protein Breath", 1, "Mixed", "D", "+25% training speed; pen mates -5% output", {"train": 0.25, "pen_squares": -0.05}, 4)
	_t("trainer", "Personal Trainer", 2, "Positive", "R", "+15% training speed for every other cube in the Gym", {"gym_aura": 0.15}, 4)
	_t("swole", "Swole Edges", 3, "Positive", "R", "Training also raises its Cornerness by 10% of the gain", {"swole": 1}, 4)
	_t("peak_form", "Peak Form", 4, "Positive", "R", "Raises its training cap by 50%", {"peak_form": 1}, 4)
	# Mode 5: Trading Post
	_t("haggler", "Haggler", 0, "Positive", "D", "+5% on every trade", {"trade": 0.05}, 5)
	_t("smooth_talker", "Smooth Talker", 1, "Positive", "R", "Haggling is 40% less likely to make traders storm off", {"smooth": 1}, 5)
	_t("insider", "Insider Info", 2, "Positive", "R", "Reveals every trader's hidden favourite trait", {"insider": 1}, 5)
	_t("barrys_fav", "Barry's Favorite", 3, "Positive", "R", "Barry stops lowballing. Barry is confused by his own feelings", {"barry": 1}, 5)
	_t("deal", "Deal of a Lifetime", 4, "Positive", "R", "Once a day, one sale pays triple", {"deal": 1}, 5)
