extends Control
## Builds the whole UI in code: top bar, narrator, one screen per mode,
## bottom navigation, popups, toasts and the hatch/capture reveal.

const CubeView := preload("res://scripts/cube_view.gd")

const BG := Color("1d1a2b")
const PANEL := Color("2b2640")
const PANEL2 := Color("3a3356")
const BTN := Color("4a4272")
const ACCENT := Color("ffcc4d")
const TEXT := Color("f4f1ff")
const DIM := Color("a9a2cc")
const GOOD := Color("6ee7a0")
const BAD := Color("ff7a8a")

const SCREENS := [
	{"id": "ranch", "label": "Ranch", "mode": 1},
	{"id": "wilds", "label": "Wilds", "mode": 2},
	{"id": "nest", "label": "Nest", "mode": 3},
	{"id": "gym", "label": "Gym", "mode": 4},
	{"id": "trade", "label": "Trade", "mode": 5},
	{"id": "codex", "label": "Codex", "mode": 0},
]
const JOB_TEXT := {"": "Idle in the barn", "pen": "Working in a pen", "gym": "Training at the Gym", "team": "On the expedition team", "nest": "In a Nesting Box"}

var screen := "ranch"
var content_scroll: ScrollContainer
var content: VBoxContainer
var squares_label: Label
var rate_label: Label
var roster_label: Label
var narrator_label: Label
var nav_buttons := {}
var overlay: Control
var popup_panel: PanelContainer
var popup_box: VBoxContainer
var toast_box: VBoxContainer
var dyn: Array = []
var popup_dyn: Array = []
var reveal_queue: Array = []
var _dirty := false
var _haggle := {}

func _ready() -> void:
	theme = _make_theme()
	_build_shell()
	Game.structure_changed.connect(_on_structure)
	Game.toast.connect(show_toast)
	Game.reveal.connect(_on_reveal)
	Game.welcome_back.connect(_on_welcome)
	_rebuild()

func _process(_delta: float) -> void:
	squares_label.text = "%s Squares" % Game.fmt(Game.squares)
	rate_label.text = "+%s / sec" % Game.fmt(Game.rate)
	roster_label.text = "Cubes %d/%d" % [Game.cubes.size(), Game.roster_cap()]
	narrator_label.text = Game.narrator_line
	_run_dyn(dyn)
	_run_dyn(popup_dyn)

func _run_dyn(list: Array) -> void:
	for d in list:
		var n = d.node
		if not is_instance_valid(n):
			continue
		var v = d.fn.call()
		match d.kind:
			"text": n.text = str(v)
			"value": n.value = float(v)
			"disabled": n.disabled = bool(v)
			"color": n.add_theme_color_override("font_color", v)

func _on_structure() -> void:
	if not _dirty:
		_dirty = true
		_rebuild.call_deferred()

# ------------------------------------------------------------------ theme + shell

func _sb(col: Color, radius: int = 16, ph: int = 14, pv: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(radius)
	s.content_margin_left = ph
	s.content_margin_right = ph
	s.content_margin_top = pv
	s.content_margin_bottom = pv
	return s

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 24
	t.set_stylebox("normal", "Button", _sb(BTN))
	t.set_stylebox("hover", "Button", _sb(BTN.lightened(0.12)))
	t.set_stylebox("pressed", "Button", _sb(ACCENT))
	t.set_stylebox("disabled", "Button", _sb(Color("2f2a47")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", BG)
	t.set_color("font_disabled_color", "Button", Color(DIM, 0.6))
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_stylebox("panel", "PanelContainer", _sb(PANEL, 20, 16, 14))
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("background", "ProgressBar", _sb(Color("16131f"), 10, 0, 0))
	t.set_stylebox("fill", "ProgressBar", _sb(ACCENT, 10, 0, 0))
	t.set_stylebox("normal", "LineEdit", _sb(Color("16131f"), 12))
	t.set_stylebox("focus", "LineEdit", _sb(Color("16131f"), 12))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("panel", "PopupMenu", _sb(PANEL2, 14, 10, 10))
	t.set_font_size("font_size", "PopupMenu", 26)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	var grab := _sb(Color(DIM, 0.4), 6, 0, 0)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", _sb(Color(0, 0, 0, 0), 6, 4, 0))
	return t

func _build_shell() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe_top := 36
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", safe_top)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _sb(PANEL2, 22, 20, 14))
	root.add_child(top)
	var top_row := HBoxContainer.new()
	top.add_child(top_row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 0)
	top_row.add_child(left)
	squares_label = _lbl("", 36, ACCENT)
	left.add_child(squares_label)
	rate_label = _lbl("", 20, DIM)
	left.add_child(rate_label)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_child(right)
	var title := _lbl("CUBE GUY IDLE", 18, TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(title)
	roster_label = _lbl("", 20, DIM)
	roster_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(roster_label)

	narrator_label = _lbl("", 18, DIM, true)
	narrator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(narrator_label)

	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(content_scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	content_scroll.add_child(content)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 6)
	root.add_child(nav)
	for s in SCREENS:
		var b := Button.new()
		b.text = s.label
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 76)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_set_screen.bind(s.id))
		nav.add_child(b)
		nav_buttons[s.id] = b

	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	popup_panel = PanelContainer.new()
	popup_panel.add_theme_stylebox_override("panel", _sb(PANEL, 24, 18, 18))
	popup_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_panel.offset_left = 20
	popup_panel.offset_right = -20
	popup_panel.offset_top = 90
	popup_panel.offset_bottom = -90
	overlay.add_child(popup_panel)
	var ps := ScrollContainer.new()
	ps.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	popup_panel.add_child(ps)
	popup_box = VBoxContainer.new()
	popup_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_box.add_theme_constant_override("separation", 12)
	ps.add_child(popup_box)

	toast_box = VBoxContainer.new()
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toast_box.offset_top = 150
	toast_box.offset_left = 24
	toast_box.offset_right = -24
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_theme_constant_override("separation", 8)
	add_child(toast_box)

# ------------------------------------------------------------------ small builders

func _lbl(text: String, fsize: int = 24, col: Color = TEXT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _btn(text: String, cb: Callable, fsize: int = 22, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 60)
	b.add_theme_font_size_override("font_size", fsize)
	b.disabled = not enabled
	b.pressed.connect(cb)
	return b

func _dyn(list: Array, node: Node, fn: Callable, kind: String = "text") -> void:
	list.append({"node": node, "fn": fn, "kind": kind})

func _section(parent: Container, title: String, subtitle: String = "") -> VBoxContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	if title != "":
		v.add_child(_lbl(title, 28, ACCENT))
	if subtitle != "":
		v.add_child(_lbl(subtitle, 19, DIM, true))
	return v

func _row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	return h

func _cube_view(c: Dictionary, px: int, anim: bool = false) -> Control:
	var v := CubeView.new()
	v.custom_minimum_size = Vector2(px, px)
	v.setup(c, anim)
	return v

func _trait_names(c: Dictionary, hide_after: int = 99) -> String:
	var names: Array = []
	for i in c.traits.size():
		if i >= hide_after:
			names.append("???")
		else:
			names.append(TraitDB.get_trait(c.traits[i]).get("name", "?"))
	return ", ".join(names) if names.size() > 0 else "No traits"

func _cube_row(parent: Container, c: Dictionary, buttons: Array, extra: Callable = Callable(), hide_after: int = 99, list = null) -> VBoxContainer:
	if list == null:
		list = dyn
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(PANEL2, 18, 12, 10))
	parent.add_child(p)
	var h := _row()
	p.add_child(h)
	h.add_child(_cube_view(c, 116))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)
	var rcol := TraitDB.rarity_color(int(c.rarity))
	var name_btn := Button.new()
	name_btn.text = c.name
	name_btn.flat = true
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.add_theme_color_override("font_color", rcol)
	name_btn.add_theme_color_override("font_hover_color", rcol.lightened(0.2))
	name_btn.add_theme_font_size_override("font_size", 26)
	if int(c.id) > 0 and not Game.get_cube(int(c.id)).is_empty():
		name_btn.pressed.connect(show_cube_details.bind(int(c.id)))
	else:
		name_btn.pressed.connect(show_preview.bind(c, hide_after))
	v.add_child(name_btn)
	v.add_child(_lbl("%s  -  %s %s" % [TraitDB.rarity_name(int(c.rarity)), Game.lib.SIZES[int(c.size)], Game.lib.MATERIALS[int(c.material)]], 18, DIM))
	v.add_child(_lbl(_trait_names(c, hide_after), 19, TEXT, true))
	if extra.is_valid():
		var el := _lbl("", 19, GOOD)
		v.add_child(el)
		_dyn(list, el, extra)
	if buttons.size() > 0:
		var bh := HFlowContainer.new()
		bh.add_theme_constant_override("h_separation", 8)
		bh.add_theme_constant_override("v_separation", 8)
		v.add_child(bh)
		for b in buttons:
			var bt := _btn(b[0], b[1], 20, b.size() < 3 or bool(b[2]))
			bt.custom_minimum_size = Vector2(0, 54)
			bh.add_child(bt)
	return v

func _upgrades(mode: int) -> void:
	var sec := _section(content, "Upgrades")
	for id in Game.UPGRADES:
		var u: Dictionary = Game.UPGRADES[id]
		if int(u.mode) != mode:
			continue
		var h := _row()
		sec.add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var lvl := int(Game.upgrades.get(id, 0))
		var lv_text := ("Lv %d" % lvl) if int(u.max) >= 999 else ("Lv %d/%d" % [lvl, int(u.max)])
		v.add_child(_lbl("%s  (%s)" % [u.name, lv_text], 22))
		v.add_child(_lbl(u.desc, 18, DIM))
		if lvl >= int(u.max):
			h.add_child(_lbl("MAX", 22, GOOD))
			continue
		var b := _btn(Game.fmt(Game.upgrade_cost(id)), _buy.bind(id), 20)
		b.custom_minimum_size = Vector2(150, 60)
		h.add_child(b)
		_dyn(dyn, b, func(): return Game.squares < Game.upgrade_cost(id), "disabled")

func _buy(id: String) -> void:
	if Game.buy_upgrade(id):
		show_toast("Bought %s." % Game.UPGRADES[id].name)

# ------------------------------------------------------------------ navigation

func _set_screen(id: String) -> void:
	for s in SCREENS:
		if s.id == id and int(s.mode) > 0 and not Game.unlocked.get(int(s.mode), false):
			show_toast(_lock_hint(int(s.mode)))
			return
	screen = id
	_rebuild()
	content_scroll.scroll_vertical = 0

func _lock_hint(mode: int) -> String:
	match mode:
		3: return "Locked: own 2 cubes to unlock the Nesting Boxes."
		4: return "Locked: acquire 10 cubes to unlock the Gym (%d/10)." % int(Game.counters.acquired)
		5: return "Locked: reach Zone 5 in the Wilds to unlock the Trading Post."
	return "Locked."

func _rebuild() -> void:
	_dirty = false
	var scroll := content_scroll.scroll_vertical
	for ch in content.get_children():
		ch.queue_free()
	dyn.clear()
	for s in SCREENS:
		var b: Button = nav_buttons[s.id]
		var locked: bool = int(s.mode) > 0 and not Game.unlocked.get(int(s.mode), false)
		b.text = s.label if not locked else s.label + "\n(locked)"
		b.add_theme_font_size_override("font_size", 20 if not locked else 15)
		if s.id == screen:
			b.add_theme_stylebox_override("normal", _sb(ACCENT))
			b.add_theme_color_override("font_color", BG)
		else:
			b.add_theme_stylebox_override("normal", _sb(BTN if not locked else Color("2f2a47")))
			b.add_theme_color_override("font_color", TEXT if not locked else DIM)
	match screen:
		"ranch": _build_ranch()
		"wilds": _build_wilds()
		"nest": _build_nest()
		"gym": _build_gym()
		"trade": _build_trade()
		"codex": _build_codex()
	_restore_scroll.call_deferred(scroll)

func _restore_scroll(v: int) -> void:
	await get_tree().process_frame
	content_scroll.scroll_vertical = v

# ------------------------------------------------------------------ ranch

func _build_ranch() -> void:
	var head := _section(content, "The Ranch", "Cubes in pens make Squares. Pen mates boost (or annoy) each other through their traits.")
	var rl := _lbl("", 22, GOOD)
	head.add_child(rl)
	_dyn(dyn, rl, func(): return "Ranch output: %s Squares/sec" % Game.fmt(Game.rate))
	for i in Game.pens.size():
		var pen: Array = Game.pens[i]
		var sec := _section(content, "Pen %d  (%d/%d)" % [i + 1, pen.size(), Game.pen_cap()])
		for id in pen:
			var c := Game.get_cube(int(id))
			if c.is_empty():
				continue
			var cid := int(id)
			_cube_row(sec, c, [["Remove", Game.unassign.bind(cid)]], func(): return "+%s/sec" % Game.fmt(Game.cube_output(Game.get_cube(cid))))
		if pen.size() < Game.pen_cap():
			var pi := i
			sec.add_child(_btn("+ Add a cube to this pen", func(): _open_picker("Pick a cube for Pen %d" % (pi + 1), _idle_filter, func(cid): Game.assign_pen(cid, pi))))
	var idle: Array = []
	for c in Game.cubes:
		if c.job == "":
			idle.append(c)
	var barn := _section(content, "Barn  (%d idle)" % idle.size(), "Idle cubes do nothing. Tap a name for details.")
	if idle.is_empty():
		barn.add_child(_lbl("Everyone's working. Suspiciously productive.", 20, DIM))
	for c in idle:
		var cid := int(c.id)
		_cube_row(barn, c, [["To pen", _quick_pen.bind(cid)], ["Expedition", func(): Game.assign_team(cid)]])
	_upgrades(1)

func _idle_filter(c: Dictionary) -> bool:
	return c.job == ""

func _quick_pen(id: int) -> void:
	for i in Game.pens.size():
		if Game.pens[i].size() < Game.pen_cap():
			Game.assign_pen(id, i)
			return
	show_toast("All pens are full. Buy a New Pen or Bigger Pens.")

func _open_picker(title: String, filter: Callable, on_pick: Callable, info: Callable = Callable()) -> void:
	var box := open_popup(title)
	var any := false
	var list: Array = Game.cubes.duplicate()
	list.sort_custom(func(a, b): return int(a.rarity) > int(b.rarity))
	for c in list:
		if not filter.call(c):
			continue
		any = true
		var cid := int(c.id)
		var label := "Pick"
		if info.is_valid():
			label = str(info.call(c))
		_cube_row(box, c, [[label, func(): close_popup(); on_pick.call(cid)]], Callable(), 99, popup_dyn)
	if not any:
		box.add_child(_lbl("No eligible cubes. Catch or hatch more, or free one up from its job.", 22, DIM, true))

# ------------------------------------------------------------------ wilds

func _build_wilds() -> void:
	var z := Game.zone
	var sec := _section(content, "The Wilds", "Send a team of up to 3 cubes to explore. Heft, Wobble and Smarts set team power.")
	var zr := _row()
	sec.add_child(zr)
	var prev := _btn("<", func(): Game.set_zone(z - 1), 26, z > 0)
	prev.custom_minimum_size = Vector2(70, 70)
	zr.add_child(prev)
	var zv := VBoxContainer.new()
	zv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zr.add_child(zv)
	var zn := _lbl(Game.ZONES[z], 26, TEXT, true)
	zn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zv.add_child(zn)
	var zs := _lbl("Zone %d of %d" % [z + 1, Game.ZONES.size()] + ("  (farming: bounty on clear)" if z < Game.max_zone else ""), 18, DIM, true)
	zs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zv.add_child(zs)
	var nxt := _btn(">", func(): Game.set_zone(z + 1), 26, z < Game.max_zone)
	nxt.custom_minimum_size = Vector2(70, 70)
	zr.add_child(nxt)
	var pl := _lbl("", 21)
	sec.add_child(pl)
	_dyn(dyn, pl, func(): return "Team power %s  vs  zone needs %s" % [Game.fmt(Game.team_power()), Game.fmt(Game.zone_req(Game.zone))])
	_dyn(dyn, pl, func(): return GOOD if Game.team_power() >= Game.zone_req(Game.zone) else (ACCENT if Game.team_power() >= Game.zone_req(Game.zone) * 0.4 else BAD), "color")
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(0, 26)
	pb.max_value = 1.0
	pb.show_percentage = false
	sec.add_child(pb)
	_dyn(dyn, pb, func(): return Game.zone_progress, "value")
	var st := _lbl("", 18, DIM, true)
	sec.add_child(st)
	_dyn(dyn, st, _wilds_status)

	var tsec := _section(content, "Expedition Team  (%d/3)" % Game.team.size())
	for id in Game.team:
		var c := Game.get_cube(int(id))
		if c.is_empty():
			continue
		var cid := int(id)
		_cube_row(tsec, c, [["Recall", Game.unassign.bind(cid)]], func(): var cc := Game.get_cube(cid); return "Power %s" % Game.fmt((Game.eff_stat(cc, "HFT") + Game.eff_stat(cc, "WBL") + Game.eff_stat(cc, "SMT")) / 3.0))
	if Game.team.size() < 3:
		tsec.add_child(_btn("+ Add a cube to the team", func(): _open_picker("Pick an explorer", _idle_filter, func(cid): Game.assign_team(cid), func(c): return "Power %s" % Game.fmt((Game.eff_stat(c, "HFT") + Game.eff_stat(c, "WBL") + Game.eff_stat(c, "SMT")) / 3.0))))

	var esec := _section(content, "Encounters  (%d/6)" % Game.encounters.size(), "Wild cubes show one trait. The rest are a surprise. Bosses appear every 5th zone.")
	if Game.encounters.is_empty():
		esec.add_child(_lbl("Nothing yet. Your team is rustling bushes.", 20, DIM))
	for i in Game.encounters.size():
		var w: Dictionary = Game.encounters[i]
		var buttons: Array = []
		for t in Game.TOOLS:
			if not Game.tool_unlocked(t):
				continue
			var chance := Game.capture_chance(w, t)
			var cost := Game.tool_cost(t, w)
			var txt := "%s %d%%" % [t.name, int(round(chance * 100.0))]
			if cost > 0.0:
				txt += " (%s)" % Game.fmt(cost)
			buttons.append([txt, _capture.bind(i, t.id), Game.squares >= cost])
		buttons.append(["Let go", Game.release_encounter.bind(i)])
		_cube_row(esec, w, buttons, Callable(), 1)
	var tools := _section(content, "Capture Tools")
	for t in Game.TOOLS:
		var ok := Game.tool_unlocked(t)
		tools.add_child(_lbl(("%s: %s" % [t.name, t.hint]) if ok else ("%s: unlocks at Zone %d" % [t.name, int(t.zone) + 1]), 19, TEXT if ok else DIM, true))
	_upgrades(2)

func _wilds_status() -> String:
	if Game.team.is_empty():
		return "No team assigned. The Wilds are untouched, and smug about it."
	var ratio := Game.team_power() / Game.zone_req(Game.zone)
	if ratio < 0.5:
		return "Your team is getting bullied by Pebbles. No encounters until it has at least half the power this zone needs. Try an earlier zone."
	if ratio < 1.0:
		return "Too weak to clear this zone, but still finding cubes. Train or breed stronger explorers to push on."
	return "Exploring nicely. Next encounter in about %s." % Game.fmt_time(Game.encounter_timer / (1.0 + Game.team_mod("encounter")))

func _capture(i: int, tool_id: String) -> void:
	var r := Game.try_capture(i, tool_id)
	if not r.ok:
		show_toast(r.msg)

# ------------------------------------------------------------------ nest

func _build_nest() -> void:
	_section(content, "Nesting Boxes", "Two cubes go behind a tasteful curtain. Eggs come out. Children average their parents' stats and may inherit their traits. Rare mutations add new ones.")
	for i in Game.nests.size():
		var n: Dictionary = Game.nests[i]
		var sec := _section(content, "Nesting Box %d" % (i + 1))
		for side in ["a", "b"]:
			var c := Game.get_cube(int(n[side]))
			var bi := i
			var sd: String = side
			if c.is_empty():
				sec.add_child(_btn("+ Pick parent %s" % ("A" if side == "a" else "B"), func(): _open_picker("Pick a parent", _idle_filter, func(cid): Game.assign_nest(cid, bi, sd))))
			else:
				_cube_row(sec, c, [["Remove", Game.unassign.bind(int(c.id))]])
		var a := Game.get_cube(int(n.a))
		var b := Game.get_cube(int(n.b))
		if not a.is_empty() and not b.is_empty():
			var tl := _lbl("", 21, GOOD, true)
			sec.add_child(tl)
			var bi2 := i
			_dyn(dyn, tl, func(): return _nest_status(bi2))
	var eggs_sec := _section(content, "Incubator  (%d/%d eggs)" % [Game.eggs.size(), Game.incubator_cap()], "Egg spots hint at the baby's colour. Gift eggs from milestones are gold.")
	if Game.eggs.is_empty():
		eggs_sec.add_child(_lbl("No eggs. The incubator hums with disappointment.", 20, DIM))
	else:
		var all := _btn("Hatch all ready eggs", _hatch_all)
		eggs_sec.add_child(all)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		eggs_sec.add_child(grid)
		for ei in Game.eggs.size():
			var e: Dictionary = Game.eggs[ei]
			var cell := VBoxContainer.new()
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(cell)
			var ev := CubeView.new()
			ev.custom_minimum_size = Vector2(170, 150)
			ev.egg_mode = true
			ev.egg_gift = str(e.gift) != ""
			ev.egg_ready = float(e.hatch_at) <= Game.now()
			ev.setup(e.cube, ev.egg_ready)
			cell.add_child(ev)
			var hatch_at := float(e.hatch_at)
			var tl := _lbl("", 18, DIM)
			tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(tl)
			_dyn(dyn, tl, func(): return "READY" if hatch_at <= Game.now() else Game.fmt_time(hatch_at - Game.now()))
			var hb := _btn("Hatch", _hatch_one.bind(e), 20)
			cell.add_child(hb)
			_dyn(dyn, hb, func(): return hatch_at > Game.now(), "disabled")
	_upgrades(3)

func _nest_status(i: int) -> String:
	if i >= Game.nests.size():
		return ""
	var n: Dictionary = Game.nests[i]
	if Game.eggs.size() >= Game.incubator_cap():
		return "Paused: the incubator is full. Hatch some eggs."
	return "Next clutch in %s" % Game.fmt_time(float(n.left))

func _hatch_one(e: Dictionary) -> void:
	var idx := Game.eggs.find(e)
	if idx >= 0:
		Game.hatch(idx)

func _hatch_all() -> void:
	var i := 0
	var hatched := 0
	while i < Game.eggs.size():
		if float(Game.eggs[i].hatch_at) <= Game.now():
			if not Game.hatch(i):
				break
			hatched += 1
		else:
			i += 1
	if hatched == 0:
		show_toast("No eggs are ready yet. Patience. Eggs can smell fear.")

# ------------------------------------------------------------------ gym

func _build_gym() -> void:
	_section(content, "Gym of Corners", "Cubes train one stat at a time up to their hidden Potential. A bit of training leaks into their children.")
	for i in Game.gym.size():
		var slot: Dictionary = Game.gym[i]
		var sec := _section(content, "Gym Slot %d" % (i + 1))
		var c := Game.get_cube(int(slot.cube))
		var si := i
		if c.is_empty():
			sec.add_child(_btn("+ Add a cube", func(): _open_picker("Who's getting swole?", _idle_filter, func(cid): Game.assign_gym(cid, si, "CRN"))))
			continue
		var cid := int(c.id)
		_cube_row(sec, c, [["Remove", Game.unassign.bind(cid)]])
		var h := _row()
		sec.add_child(h)
		h.add_child(_lbl("Training:", 22))
		var ob := OptionButton.new()
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ob.custom_minimum_size = Vector2(0, 60)
		for s in Game.lib.STATS:
			ob.add_item(Game.lib.STAT_NAMES[s])
		ob.selected = Game.lib.STATS.find(slot.stat)
		ob.item_selected.connect(func(idx): Game.set_gym_stat(si, Game.lib.STATS[idx]))
		h.add_child(ob)
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(0, 24)
		pb.show_percentage = false
		pb.max_value = 1.0
		sec.add_child(pb)
		_dyn(dyn, pb, func(): return _gym_ratio(si), "value")
		var tl := _lbl("", 19, GOOD)
		sec.add_child(tl)
		_dyn(dyn, tl, func(): return _gym_text(si))
	_upgrades(4)

func _gym_cap(c: Dictionary, s: String) -> float:
	return float(c.potential[s]) * (1.5 if Game.has_flag(c, "peak_form") else 1.0)

func _gym_ratio(i: int) -> float:
	var slot: Dictionary = Game.gym[i]
	var c := Game.get_cube(int(slot.cube))
	if c.is_empty():
		return 0.0
	return float(c.trained[slot.stat]) / max(0.01, _gym_cap(c, slot.stat))

func _gym_text(i: int) -> String:
	var slot: Dictionary = Game.gym[i]
	var c := Game.get_cube(int(slot.cube))
	if c.is_empty():
		return ""
	var s: String = slot.stat
	var tr := float(c.trained[s])
	var cap := _gym_cap(c, s)
	if tr >= cap - 0.01:
		return "%s maxed at +%s. Pick another stat!" % [Game.lib.STAT_NAMES[s], Game.fmt(tr)]
	return "%s: base %s, trained +%s / %s" % [Game.lib.STAT_NAMES[s], Game.fmt(float(c.base[s])), Game.fmt(tr), Game.fmt(cap)]

# ------------------------------------------------------------------ trade

func _build_trade() -> void:
	_section(content, "Trading Post", "Sell idle cubes to NPC traders. Charisma raises prices. Haggle for more, but watch for their tells.")
	var insider := Game.any_owned_with("insider")
	for tr in Game.TRADERS:
		var sec := _section(content, tr.name, tr.blurb)
		if tr.id == "collector":
			var want := TraitDB.get_trait(Game.trader_favs.get("collector_want", ""))
			sec.add_child(_lbl("Today's want: %s" % want.get("name", "?"), 22, ACCENT))
		if insider:
			var fav := TraitDB.get_trait(Game.trader_favs.get(tr.id, ""))
			sec.add_child(_lbl("Insider Info: secretly pays double for %s" % fav.get("name", "?"), 19, GOOD, true))
		var stl := _lbl("", 19, BAD)
		sec.add_child(stl)
		var tid: String = tr.id
		_dyn(dyn, stl, func(): return "" if Game.trader_available(tid) else "Stormed off. Back in %s." % Game.fmt_time(float(Game.trader_cooldown.get(tid, 0.0)) - Game.now()))
		var trader: Dictionary = tr
		var ob := _btn("Offer a cube", func(): _open_picker("Sell to %s" % trader.name, func(c): return Game.trader_accepts(c, trader), func(cid): _open_haggle(cid, trader), func(c): return "Offer: %s" % Game.fmt(Game.trade_price(c, trader))))
		sec.add_child(ob)
		_dyn(dyn, ob, func(): return not Game.trader_available(tid), "disabled")
	var child := _section(content, "A Child", "Offers you a rock. It's probably a rock.")
	child.add_child(_btn("Buy the rock (%s)" % Game.fmt(10.0 + 25.0 * Game.max_zone), func(): show_toast(Game.buy_rock().msg)))
	var gary := _section(content, "Gary's Cube Emporium", "Gary is a cube. Gary is selling his own children and does not want to talk about it.")
	var gl := _lbl("", 19, DIM)
	gary.add_child(gl)
	_dyn(dyn, gl, func(): return "Restocks in %s" % Game.fmt_time(Game.gary_restock_at - Game.now()))
	for i in Game.gary_stock.size():
		var w: Dictionary = Game.gary_stock[i]
		var price: float = Game.lib.value(w) * 1.6
		_cube_row(gary, w, [["Buy (%s)" % Game.fmt(price), _gary_buy.bind(i), Game.squares >= price]])
	gary.add_child(_btn("Restock now (%s)" % Game.fmt(Game.gary_restock_cost()), func(): if not Game.paid_restock(): show_toast("Not enough Squares. Gary is unmoved.")))

func _gary_buy(i: int) -> void:
	var r := Game.buy_from_gary(i)
	if not r.ok:
		show_toast(r.msg)

func _open_haggle(cid: int, trader: Dictionary) -> void:
	_haggle = {"cid": cid, "trader": trader, "pushes": 0}
	_draw_haggle()

func _draw_haggle() -> void:
	var c := Game.get_cube(int(_haggle.cid))
	if c.is_empty():
		close_popup()
		return
	var trader: Dictionary = _haggle.trader
	var pushes: int = _haggle.pushes
	var box := open_popup("Haggling with %s" % trader.name)
	var cv := _cube_view(c, 220, true)
	box.add_child(cv)
	box.add_child(_lbl(c.name, 28, TraitDB.rarity_color(int(c.rarity))))
	var price := Game.trade_price(c, trader) * pow(1.12, pushes)
	box.add_child(_lbl("Current offer: %s Squares" % Game.fmt(price), 30, ACCENT))
	var ch := Game.storm_chance(pushes)
	var tell := "Looks relaxed. Smells like a bargain."
	if ch >= 0.65:
		tell = "Visibly vibrating. One more push and they're gone."
	elif ch >= 0.45:
		tell = "Nervous edge-wiggling intensifies."
	elif ch >= 0.25:
		tell = "A bead of sweat forms on one edge."
	box.add_child(_lbl("Tell: " + tell, 22, DIM, true))
	box.add_child(_btn("Accept %s" % Game.fmt(price), _haggle_accept))
	box.add_child(_btn("Haggle (+12%)", _haggle_push))
	box.add_child(_btn("Walk away", close_popup))

func _haggle_accept() -> void:
	var r := Game.sell_cube(int(_haggle.cid), _haggle.trader.id, int(_haggle.pushes))
	close_popup()
	show_toast(r.msg)

func _haggle_push() -> void:
	if Game.haggle_push(_haggle.trader.id, int(_haggle.pushes)):
		close_popup()
		show_toast("%s stormed off! Come back in 10 minutes." % _haggle.trader.name)
		return
	_haggle.pushes = int(_haggle.pushes) + 1
	_draw_haggle()

# ------------------------------------------------------------------ codex

func _build_codex() -> void:
	var ms := _section(content, "Mode Milestones", "Each mode awards 5 exclusive traits, delivered as gold gift eggs.")
	for mode in [1, 2, 3, 4, 5]:
		var info: Dictionary = Game.MILESTONES[mode]
		var open: bool = Game.unlocked.get(mode, false)
		ms.add_child(_lbl(TraitDB.MODE_NAMES[mode] + ("" if open else "  (locked)"), 24, TEXT if open else DIM))
		var done: int = Game.milestones[mode]
		for i in 5:
			var tr := TraitDB.get_trait(TraitDB.by_mode[mode][i])
			var goal: float = info.goals[i]
			var line := "%s %s: %s %s -> %s (%s)" % ["[x]" if i < done else "[ ]", Game.MILESTONE_NAMES[i], Game.fmt(goal), info.label, tr.name, TraitDB.rarity_name(tr.rarity)]
			ms.add_child(_lbl(line, 18, TraitDB.rarity_color(tr.rarity) if i < done else DIM, true))
		if done < 5 and open:
			var pl := _lbl("", 18, GOOD)
			ms.add_child(pl)
			var m: int = mode
			_dyn(dyn, pl, func(): return "Progress: %s / %s" % [Game.fmt(Game.milestone_progress(m)), Game.fmt(Game.MILESTONES[m].goals[mini(Game.milestones[m], 4)])])
	var total := TraitDB.traits.size()
	var cs := _section(content, "Trait Codex  (%d/%d discovered)" % [Game.codex.size(), total], "Discover traits by owning cubes that carry them.")
	for r in 5:
		cs.add_child(_lbl(TraitDB.rarity_name(r), 22, TraitDB.rarity_color(r)))
		var names: Array = []
		for id in TraitDB.base_ids:
			if int(TraitDB.get_trait(id).rarity) == r:
				names.append(TraitDB.get_trait(id).name if Game.codex.has(id) else "???")
		cs.add_child(_lbl(", ".join(names), 18, TEXT, true))
	var st := _section(content, "Stats")
	st.add_child(_lbl("Cubes captured: %d\nEggs hatched: %d\nTrades: %d\nRocks owned: %d\nLifetime Squares: %s" % [Game.counters.captures, Game.counters.eggs_hatched, Game.counters.trades, Game.counters.rocks, Game.fmt(Game.lifetime_squares)], 20))
	var danger := _section(content, "Settings")
	danger.add_child(_btn("Reset save (can't be undone)", _confirm_reset))

func _confirm_reset() -> void:
	var box := open_popup("Reset everything?")
	box.add_child(_lbl("This deletes your ranch, your cubes, and every rock. There is no undo.", 22, TEXT, true))
	box.add_child(_btn("Yes, start over", func(): close_popup(); Game.reset_save()))
	box.add_child(_btn("No, keep my cubes", close_popup))

# ------------------------------------------------------------------ popups

func open_popup(title: String) -> VBoxContainer:
	for ch in popup_box.get_children():
		ch.queue_free()
	popup_dyn.clear()
	overlay.visible = true
	var h := _row()
	popup_box.add_child(h)
	var t := _lbl(title, 28, ACCENT, true)
	h.add_child(t)
	var x := _btn("X", close_popup, 24)
	x.custom_minimum_size = Vector2(64, 64)
	h.add_child(x)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	popup_box.add_child(body)
	return body

func close_popup() -> void:
	overlay.visible = false
	popup_dyn.clear()
	for ch in popup_box.get_children():
		ch.queue_free()
	if not reveal_queue.is_empty():
		var next: Array = reveal_queue.pop_front()
		_show_reveal.call_deferred(next[0], next[1])

func show_cube_details(id: int) -> void:
	var c := Game.get_cube(id)
	if c.is_empty():
		return
	var box := open_popup("Cube Details")
	_fill_cube_info(box, c, 99)
	box.add_child(_lbl("Status: %s" % JOB_TEXT.get(c.job, ""), 20, DIM))
	var rn := _row()
	box.add_child(rn)
	var le := LineEdit.new()
	le.text = c.name
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.custom_minimum_size = Vector2(0, 60)
	rn.add_child(le)
	rn.add_child(_btn("Rename", func(): Game.rename_cube(id, le.text); show_cube_details(id), 20))
	var acts := HFlowContainer.new()
	acts.add_theme_constant_override("h_separation", 8)
	acts.add_theme_constant_override("v_separation", 8)
	box.add_child(acts)
	if c.job != "":
		acts.add_child(_btn("Unassign", func(): Game.unassign(id); show_cube_details(id), 20))
	if c.job != "pen":
		acts.add_child(_btn("To pen", func(): close_popup(); _quick_pen(id), 20))
	if c.job != "team":
		acts.add_child(_btn("Expedition", func(): close_popup(); Game.assign_team(id), 20))
	acts.add_child(_btn("Release (+%s)" % Game.fmt(Game.lib.value(c) * 0.2), func(): _confirm_release(id), 20))

func show_preview(c: Dictionary, hide_after: int) -> void:
	var box := open_popup("A wild cube")
	_fill_cube_info(box, c, hide_after)

func _fill_cube_info(box: VBoxContainer, c: Dictionary, hide_after: int) -> void:
	var cv := _cube_view(c, 280, true)
	box.add_child(cv)
	var rcol := TraitDB.rarity_color(int(c.rarity))
	var nl := _lbl(c.name, 34, rcol)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(nl)
	var sub := _lbl("%s  -  Generation %d  -  %s" % [TraitDB.rarity_name(int(c.rarity)), int(c.gen), str(c.origin).capitalize()], 20, DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var L = Game.lib
	box.add_child(_lbl("Size: %s   Material: %s\nPattern: %s   Eyes: %d\nMouth: %s   Edges: %s\nAppendage: %s\nTrade value: about %s Squares" % [
		L.SIZES[int(c.size)], L.MATERIALS[int(c.material)], L.PATTERNS[int(c.pattern)], int(c.eyes),
		L.MOUTHS[int(c.mouth)], L.EDGES[int(c.edge)], L.APPENDAGES[int(c.appendage)], Game.fmt(L.value(c))], 20, TEXT, true))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	box.add_child(grid)
	for h in ["Stat", "Base + trained", "Potential"]:
		grid.add_child(_lbl(h, 18, DIM))
	for s in L.STATS:
		grid.add_child(_lbl(L.STAT_NAMES[s], 20))
		grid.add_child(_lbl("%s + %s" % [Game.fmt(float(c.base[s])), Game.fmt(float(c.trained[s]))], 20))
		grid.add_child(_lbl(Game.fmt(float(c.potential[s])) if hide_after >= 99 else "???", 20, DIM))
	box.add_child(_lbl("Traits (%d/%d slots)" % [c.traits.size(), int(c.slots)], 24, ACCENT))
	for i in c.traits.size():
		if i >= hide_after:
			box.add_child(_lbl("???  -  catch it to find out", 20, DIM))
			continue
		var tr := TraitDB.get_trait(c.traits[i])
		var inh: String = {"D": "Dominant", "R": "Recessive", "C": "Chaotic"}.get(tr.inh, "")
		var src := "" if int(tr.mode) == 0 else "  -  From %s" % TraitDB.MODE_NAMES[int(tr.mode)]
		box.add_child(_lbl("%s  (%s, %s, %s)%s" % [tr.name, TraitDB.rarity_name(tr.rarity), tr.kind, inh, src], 21, TraitDB.rarity_color(tr.rarity), true))
		box.add_child(_lbl(tr.desc, 19, DIM, true))

func _confirm_release(id: int) -> void:
	var c := Game.get_cube(id)
	var box := open_popup("Release %s?" % c.name)
	box.add_child(_lbl("It returns to the Wilds forever. You get a small thank-you in Squares.", 22, TEXT, true))
	box.add_child(_btn("Release", func(): close_popup(); show_toast(Game.release_cube(id).msg)))
	box.add_child(_btn("Keep it", close_popup))

func _on_reveal(c: Dictionary, headline: String) -> void:
	if overlay.visible:
		reveal_queue.append([c, headline])
		return
	_show_reveal(c, headline)

func _show_reveal(c: Dictionary, headline: String) -> void:
	if overlay.visible:
		reveal_queue.append([c, headline])
		return
	var box := open_popup(headline)
	var rcol := TraitDB.rarity_color(int(c.rarity))
	var banner := _lbl("%s!" % TraitDB.rarity_name(int(c.rarity)).to_upper(), 46, rcol)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(banner)
	var cv := _cube_view(c, 300, true)
	cv.pivot_offset = Vector2(150, 150)
	cv.scale = Vector2(0.1, 0.1)
	box.add_child(cv)
	var tw := create_tween()
	tw.tween_property(cv, "scale", Vector2(1.15, 1.15), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(cv, "scale", Vector2(1.0, 1.0), 0.15)
	banner.modulate = Color(1, 1, 1, 0)
	var tw2 := create_tween()
	tw2.tween_interval(0.25)
	tw2.tween_property(banner, "modulate", Color.WHITE, 0.3)
	var nl := _lbl(c.name, 32, TEXT)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(nl)
	for t in c.traits:
		var tr := TraitDB.get_trait(t)
		var l := _lbl("%s - %s" % [tr.name, tr.desc], 20, TraitDB.rarity_color(tr.rarity), true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
	var row := _row()
	box.add_child(row)
	var ok := _btn("Nice", close_popup)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ok)
	var cid := int(c.id)
	var det := _btn("Details", func(): reveal_queue.clear(); show_cube_details(cid))
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(det)

func _on_welcome(s: Dictionary) -> void:
	var box := open_popup("Welcome back!")
	box.add_child(_lbl("You were away for %s%s." % [Game.fmt_time(float(s.seconds)), " (offline progress capped)" if s.capped else ""], 22, TEXT, true))
	box.add_child(_lbl("Squares earned: %s" % Game.fmt(float(s.squares)), 28, ACCENT))
	box.add_child(_lbl("Eggs laid: %d\nNew encounters: %d\nZones cleared: %d" % [s.eggs, s.encounters, s.zones], 22))
	box.add_child(_lbl("The cubes kept working. Some of them even meant it.", 20, DIM, true))
	box.add_child(_btn("Back to the ranch", close_popup))

func show_toast(text: String) -> void:
	if toast_box.get_child_count() >= 3:
		toast_box.get_child(0).queue_free()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(Color("120f1c", 0.95), 16, 16, 12))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _lbl(text, 21, TEXT, true)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	toast_box.add_child(p)
	var tw := create_tween()
	tw.tween_interval(3.8)
	tw.tween_property(p, "modulate", Color(1, 1, 1, 0), 0.5)
	tw.tween_callback(p.queue_free)
