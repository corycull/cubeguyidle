extends Control
## Draws a cube procedurally from its genome: size, material, colour,
## pattern, eyes, mouth, edges, appendages, and a few trait cosmetics.
## Set egg_mode to draw it as an unhatched egg instead.

const SIZE_SCALE := [0.62, 0.72, 0.82, 0.9, 0.96, 1.0, 1.06]

var cube: Dictionary = {}
var egg_mode := false
var egg_ready := false
var egg_gift := false
var animate := false
var _t := 0.0

func setup(c: Dictionary, anim: bool = false) -> void:
	cube = c
	animate = anim
	set_process(anim)
	queue_redraw()

func _ready() -> void:
	set_process(animate)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _ellipse(center: Vector2, rx: float, ry: float, n: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _draw() -> void:
	if cube.is_empty():
		return
	if egg_mode:
		_draw_egg()
		return
	var sz := int(cube.get("size", 1))
	var s: float = min(size.x, size.y) * 0.33 * SIZE_SCALE[clampi(sz, 0, 6)]
	var bob := sin(_t * 2.2) * s * 0.05 if animate else 0.0
	var c := Vector2(size.x * 0.5, size.y * 0.47 + bob)
	var rarity := int(cube.get("rarity", 0))
	var rcol: Color = TraitDB.rarity_color(rarity)
	if rarity >= 2:
		var pulse := 0.5 + 0.5 * sin(_t * 3.0) if animate else 0.5
		draw_circle(c, s * 1.45, Color(rcol, 0.10 + 0.08 * pulse))
		draw_arc(c, s * 1.45, 0.0, TAU, 48, Color(rcol, 0.35), 2.0, true)
	draw_colored_polygon(_ellipse(Vector2(c.x, c.y + s * 1.18 - bob), s * 0.95, s * 0.22), Color(0, 0, 0, 0.25))

	var base := Color(str(cube.get("color", "ffd43b")))
	var mat := int(cube.get("material", 0))
	match mat:
		0: base = base.lerp(Color("c8a26b"), 0.55)
		2: base = base.lerp(Color("808080"), 0.5)
		3: base = base.darkened(0.15)
		5: base = base.lerp(Color("f4a6b8"), 0.6)
		7: base = base.lerp(Color("5b5470"), 0.7)
	var alpha := 0.8 if mat == 1 else 1.0
	var w := s * 0.866
	var top_pt := Vector2(c.x, c.y - s)
	var tl := Vector2(c.x - w, c.y - s * 0.5)
	var tr := Vector2(c.x + w, c.y - s * 0.5)
	var bl := Vector2(c.x - w, c.y + s * 0.5)
	var br := Vector2(c.x + w, c.y + s * 0.5)
	var bot := Vector2(c.x, c.y + s)
	var faces := {
		"top": [tl, top_pt - tl, c - tl],
		"left": [tl, c - tl, Vector2(0, s)],
		"right": [c, tr - c, Vector2(0, s)],
	}
	_draw_appendages_back(faces, s)
	var top_col := Color(base.lightened(0.28), alpha)
	var left_col := Color(base, alpha)
	var right_col := Color(base.darkened(0.25), alpha)
	draw_colored_polygon(PackedVector2Array([top_pt, tr, c, tl]), top_col)
	draw_colored_polygon(PackedVector2Array([tl, c, bot, bl]), left_col)
	draw_colored_polygon(PackedVector2Array([c, tr, br, bot]), right_col)
	_draw_material(mat, faces, base, s)
	_draw_pattern(int(cube.get("pattern", 0)), faces, base, s)
	if mat == 1:
		draw_colored_polygon(PackedVector2Array([_fp(faces.top, 0.2, 0.15), _fp(faces.top, 0.45, 0.15), _fp(faces.top, 0.45, 0.3), _fp(faces.top, 0.2, 0.3)]), Color(1, 1, 1, 0.45))
	_draw_edges(c, top_pt, tl, tr, bl, br, bot, base, s)
	_draw_face(faces, s)
	_draw_appendages_front(faces, s)
	_draw_cosmetics(faces, s)

func _fp(face: Array, u: float, v: float) -> Vector2:
	return face[0] + face[1] * u + face[2] * v

func _draw_material(mat: int, faces: Dictionary, base: Color, s: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cube.get("id", 1)) * 31 + 7
	match mat:
		0: # cardboard tape
			draw_line(_fp(faces.top, 0.5, 0.0), _fp(faces.top, 0.5, 1.0), Color("e8d6a8"), s * 0.12)
		2: # granite speckles
			for f in ["top", "left", "right"]:
				for i in 14:
					draw_circle(_fp(faces[f], rng.randf_range(0.05, 0.95), rng.randf_range(0.05, 0.95)), s * 0.025, Color(0.1, 0.1, 0.1, 0.5) if i % 2 == 0 else Color(1, 1, 1, 0.4))
		3: # velvet sheen
			draw_line(_fp(faces.left, 0.1, 0.2), _fp(faces.left, 0.9, 0.35), Color(1, 1, 1, 0.12), s * 0.15)
		4: # lasagna layers
			var cols := [Color("f4a261"), Color("c1121f"), Color("ffe8a3")]
			for f in ["left", "right"]:
				for i in 6:
					var v0 := i / 6.0
					var v1 := (i + 1) / 6.0
					var col: Color = cols[i % 3]
					draw_colored_polygon(PackedVector2Array([_fp(faces[f], 0, v0), _fp(faces[f], 1, v0), _fp(faces[f], 1, v1), _fp(faces[f], 0, v1)]), Color(col.darkened(0.2 if f == "right" else 0.0), 0.85))
		5: # ham marbling
			for f in ["top", "left", "right"]:
				for i in 3:
					var a := _fp(faces[f], rng.randf_range(0.1, 0.4), rng.randf_range(0.1, 0.9))
					var b := _fp(faces[f], rng.randf_range(0.6, 0.9), rng.randf_range(0.1, 0.9))
					draw_line(a, b, Color(1, 1, 1, 0.45), s * 0.04)
		6: # stained glass
			var glass := ["ff6b6b", "ffd43b", "4dabf7", "51cf66", "da77f2"]
			for f in ["top", "left", "right"]:
				for gu in 3:
					for gv in 3:
						var col := Color(glass[(gu + gv * 2 + f.length()) % glass.size()])
						var u0 := gu / 3.0
						var v0 := gv / 3.0
						var poly := PackedVector2Array([_fp(faces[f], u0, v0), _fp(faces[f], u0 + 0.333, v0), _fp(faces[f], u0 + 0.333, v0 + 0.333), _fp(faces[f], u0, v0 + 0.333)])
						draw_colored_polygon(poly, Color(col.darkened(0.25 if f == "right" else 0.0), 0.85))
						poly.append(poly[0])
						draw_polyline(poly, Color(0.1, 0.1, 0.1, 0.9), 2.0)
		7: # pure regret: a little rain cloud
			var cl := _fp(faces.top, 0.5, 0.5) + Vector2(0, -s * 0.9)
			draw_circle(cl, s * 0.16, Color(0.4, 0.4, 0.45, 0.8))
			draw_circle(cl + Vector2(s * 0.15, 0.03 * s), s * 0.13, Color(0.4, 0.4, 0.45, 0.8))
			for i in 3:
				draw_line(cl + Vector2((i - 1) * s * 0.1, s * 0.14), cl + Vector2((i - 1) * s * 0.1 - 3, s * 0.3), Color(0.5, 0.7, 1.0, 0.8), 2.0)

func _draw_pattern(pat: int, faces: Dictionary, base: Color, s: float) -> void:
	var ink := Color(base.darkened(0.45), 0.45)
	var light := Color(base.lightened(0.5), 0.5)
	match pat:
		1: # stripes
			for f in ["left", "right"]:
				for i in range(1, 5):
					draw_line(_fp(faces[f], i / 5.0, 0.0), _fp(faces[f], i / 5.0, 1.0), ink, s * 0.07)
		2: # dots
			for f in ["top", "left", "right"]:
				for du in 3:
					for dv in 3:
						draw_circle(_fp(faces[f], 0.2 + du * 0.3, 0.2 + dv * 0.3), s * 0.05, light)
		3: # plaid
			for f in ["left", "right", "top"]:
				for i in range(1, 4):
					draw_line(_fp(faces[f], i / 4.0, 0.0), _fp(faces[f], i / 4.0, 1.0), ink, s * 0.05)
					draw_line(_fp(faces[f], 0.0, i / 4.0), _fp(faces[f], 1.0, i / 4.0), Color(1, 0.2, 0.2, 0.35), s * 0.04)
		4: # checker
			for f in ["top", "left", "right"]:
				for cu in 4:
					for cv in 4:
						if (cu + cv) % 2 == 0:
							var u0 := cu / 4.0
							var v0 := cv / 4.0
							draw_colored_polygon(PackedVector2Array([_fp(faces[f], u0, v0), _fp(faces[f], u0 + 0.25, v0), _fp(faces[f], u0 + 0.25, v0 + 0.25), _fp(faces[f], u0, v0 + 0.25)]), Color(0, 0, 0, 0.18))
		5: # stock photo watermark
			var font := ThemeDB.fallback_font
			for f in ["left", "right"]:
				var p := _fp(faces[f], 0.08, 0.55)
				draw_string(font, p, "STOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.28), Color(1, 1, 1, 0.45))

func _draw_edges(c: Vector2, top_pt: Vector2, tl: Vector2, tr: Vector2, bl: Vector2, br: Vector2, bot: Vector2, base: Color, s: float) -> void:
	var edge := int(cube.get("edge", 0))
	var line_col := base.darkened(0.6)
	var width := 3.0
	match edge:
		1: width = 3.5
		2: width = 6.0
		3: width = 2.0
	var outline := PackedVector2Array([top_pt, tr, br, bot, bl, tl, top_pt])
	draw_polyline(outline, line_col, width, true)
	draw_line(c, tl, line_col, width * 0.7, true)
	draw_line(c, tr, line_col, width * 0.7, true)
	draw_line(c, bot, line_col, width * 0.7, true)
	match edge:
		1: # bevelled highlight
			draw_line(tl.lerp(c, 0.05), top_pt.lerp(c, 0.05), Color(1, 1, 1, 0.4), 2.0)
		3: # frayed fuzz
			for i in 10:
				var p := tl.lerp(bl, i / 10.0)
				draw_line(p, p + Vector2(-s * 0.06, (i % 2) * 4.0 - 2.0), line_col, 1.5)
		4: # lightly buttered
			draw_line(tl, top_pt, Color(1.0, 0.88, 0.4, 0.85), 4.0, true)
			draw_line(top_pt, tr, Color(1.0, 0.88, 0.4, 0.85), 4.0, true)

func _draw_face(faces: Dictionary, s: float) -> void:
	var eyes := int(cube.get("eyes", 2))
	var blink := animate and fmod(_t, 4.0) < 0.12
	var per_row := mini(eyes, 4)
	var rows := int(ceil(eyes / 4.0)) if eyes > 0 else 0
	var er := s * (0.11 if eyes <= 2 else (0.085 if eyes <= 4 else 0.06))
	var idx := 0
	for row in rows:
		var in_row := mini(per_row, eyes - idx)
		for i in in_row:
			var u := 0.5 if in_row == 1 else lerpf(0.25, 0.75, float(i) / float(in_row - 1))
			var v := 0.36 - (rows - 1) * 0.08 + row * 0.16
			var p := _fp(faces.left, u, v)
			if blink:
				draw_line(p - Vector2(er, 0), p + Vector2(er, 0), Color(0.1, 0.1, 0.1), 3.0)
			else:
				draw_circle(p, er, Color.WHITE)
				draw_circle(p + Vector2(er * 0.25, er * 0.1), er * 0.55, Color(0.08, 0.08, 0.1))
				draw_circle(p + Vector2(er * 0.05, -er * 0.25), er * 0.18, Color.WHITE)
			if idx == 0 and float(cube.get("flags", {}).get("black_eye_until", 0.0)) > Time.get_unix_time_from_system():
				draw_arc(p, er * 1.5, 0.0, TAU, 20, Color(0.45, 0.2, 0.55, 0.8), 4.0)
			idx += 1
	var m := _fp(faces.left, 0.5, 0.74)
	var dark := Color(0.12, 0.08, 0.1)
	match int(cube.get("mouth", 0)):
		0: draw_arc(m + Vector2(0, -s * 0.06), s * 0.13, 0.35, PI - 0.35, 12, dark, 3.0, true)
		1: draw_line(m - Vector2(s * 0.12, 0), m + Vector2(s * 0.12, 0), dark, 3.0, true)
		2: draw_arc(m, s * 0.06, 0.0, TAU, 14, dark, 3.0, true)
		3:
			var pts := PackedVector2Array()
			for i in 9:
				var a := lerpf(0.15, PI - 0.15, i / 8.0)
				pts.append(m + Vector2(-cos(a) * s * 0.15, sin(a) * s * 0.11 - s * 0.03))
			draw_colored_polygon(pts, dark)
			draw_line(m + Vector2(-s * 0.12, -s * 0.02), m + Vector2(s * 0.12, -s * 0.02), Color.WHITE, 3.0)
		4: draw_arc(m + Vector2(0, s * 0.08), s * 0.12, PI + 0.4, TAU - 0.4, 12, dark, 3.0, true)
		5:
			var rect := Rect2(m - Vector2(s * 0.14, s * 0.05), Vector2(s * 0.28, s * 0.1))
			draw_rect(rect, Color.WHITE)
			draw_rect(rect, dark, false, 2.0)
			for i in range(1, 4):
				var x := rect.position.x + rect.size.x * i / 4.0
				draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), dark, 1.5)

func _draw_appendages_back(faces: Dictionary, s: float) -> void:
	var app := int(cube.get("appendage", 0))
	if app == 4: # wings
		var flap := 1.0 + 0.15 * sin(_t * 9.0) if animate else 1.0
		var lp := _fp(faces.left, 0.0, 0.3)
		var rp := _fp(faces.right, 1.0, 0.3)
		draw_colored_polygon(_ellipse(lp + Vector2(-s * 0.35, -s * 0.15), s * 0.45 * flap, s * 0.22), Color(1, 1, 1, 0.85))
		draw_colored_polygon(_ellipse(rp + Vector2(s * 0.35, -s * 0.15), s * 0.45 * flap, s * 0.22), Color(1, 1, 1, 0.85))

func _draw_appendages_front(faces: Dictionary, s: float) -> void:
	var app := int(cube.get("appendage", 0))
	var feet := [_fp(faces.left, 0.3, 1.0), _fp(faces.left, 0.85, 1.0), _fp(faces.right, 0.6, 1.0)]
	var dark := Color(0.15, 0.12, 0.15)
	match app:
		1, 2:
			var length := s * (0.22 if app == 1 else 0.48)
			var step := sin(_t * 6.0) * s * 0.04 if animate else 0.0
			for i in feet.size():
				var f: Vector2 = feet[i]
				var off := step if i % 2 == 0 else -step
				draw_line(f, f + Vector2(off, length), dark, 5.0 if app == 1 else 7.0, true)
				draw_colored_polygon(_ellipse(f + Vector2(off + s * 0.05, length), s * 0.09, s * 0.05), dark)
		3:
			for f in feet:
				var p: Vector2 = f + Vector2(0, s * 0.1)
				draw_circle(p, s * 0.16, dark)
				draw_circle(p, s * 0.07, Color(0.75, 0.75, 0.8))
				var a := _t * 5.0 if animate else 0.0
				draw_line(p, p + Vector2(cos(a), sin(a)) * s * 0.14, Color(0.75, 0.75, 0.8), 2.0)
		5:
			var shoulder := _fp(faces.right, 0.85, 0.45)
			var ang := -0.9 + (0.5 * sin(_t * 5.0) if animate else 0.0)
			var hand := shoulder + Vector2(cos(ang), sin(ang)) * s * 0.55
			draw_line(shoulder, hand, dark, 5.0, true)
			draw_circle(hand, s * 0.08, Color(1, 1, 1))
			draw_arc(hand, s * 0.08, 0, TAU, 12, dark, 2.0)

func _draw_cosmetics(faces: Dictionary, s: float) -> void:
	var traits: Array = cube.get("traits", [])
	var crown := _fp(faces.top, 0.5, 0.5)
	if traits.has("hat"):
		var brim := crown + Vector2(0, -s * 0.05)
		draw_colored_polygon(_ellipse(brim, s * 0.3, s * 0.09), Color(0.1, 0.1, 0.12))
		draw_rect(Rect2(brim + Vector2(-s * 0.17, -s * 0.38), Vector2(s * 0.34, s * 0.38)), Color(0.1, 0.1, 0.12))
		draw_rect(Rect2(brim + Vector2(-s * 0.17, -s * 0.12), Vector2(s * 0.34, s * 0.07)), Color("e2457a"))
	if traits.has("chosen") or traits.has("ranch_royalty"):
		draw_arc(crown + Vector2(0, -s * 0.75), s * 0.28, 0, TAU, 32, Color(1.0, 0.85, 0.3, 0.9), 4.0, true)
	if traits.has("haunted"):
		var g := _fp(faces.right, 1.0, 0.0) + Vector2(s * 0.25, -s * 0.2 + (sin(_t * 2.0) * 5.0 if animate else 0.0))
		draw_circle(g, s * 0.13, Color(1, 1, 1, 0.55))
		draw_rect(Rect2(g + Vector2(-s * 0.13, 0), Vector2(s * 0.26, s * 0.16)), Color(1, 1, 1, 0.55))
		draw_circle(g + Vector2(-s * 0.04, -s * 0.02), s * 0.025, Color(0, 0, 0, 0.7))
		draw_circle(g + Vector2(s * 0.05, -s * 0.02), s * 0.025, Color(0, 0, 0, 0.7))
	if traits.has("damp"):
		for i in 3:
			var d := _fp(faces.left, 0.2 + i * 0.3, 0.95) + Vector2(0, fmod(_t * 20.0 + i * 13.0, 18.0) if animate else 6.0)
			draw_circle(d, s * 0.035, Color(0.4, 0.7, 1.0, 0.8))

func _draw_egg() -> void:
	var s: float = min(size.x, size.y) * 0.32
	var wobble := sin(_t * 12.0) * 0.08 if (animate and egg_ready) else 0.0
	var c := Vector2(size.x * 0.5, size.y * 0.52)
	if egg_ready:
		var pulse := 0.5 + 0.5 * sin(_t * 4.0) if animate else 0.6
		draw_circle(c, s * 1.35, Color(1.0, 0.85, 0.3, 0.15 + 0.15 * pulse))
	var pts := PackedVector2Array()
	for i in 36:
		var a := TAU * i / 36.0
		var ry := s * (1.15 if sin(a) < 0.0 else 0.95)
		var p := Vector2(cos(a) * s * 0.82, sin(a) * ry)
		pts.append(c + p.rotated(wobble))
	var shell := Color("ffe08a") if egg_gift else Color("f3e6cc")
	draw_colored_polygon(pts, shell)
	var spot := Color(str(cube.get("color", "999999")))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cube.get("id", 1)) * 17
	for i in 7:
		var p := c + Vector2(rng.randf_range(-0.5, 0.5) * s, rng.randf_range(-0.7, 0.6) * s)
		draw_circle(p, s * rng.randf_range(0.06, 0.13), Color(spot, 0.8))
	pts.append(pts[0])
	draw_polyline(pts, Color(0.35, 0.28, 0.2), 3.0, true)
	if egg_ready:
		draw_line(c + Vector2(-s * 0.4, -s * 0.1), c + Vector2(-s * 0.1, s * 0.05), Color(0.35, 0.28, 0.2), 2.5)
		draw_line(c + Vector2(-s * 0.1, s * 0.05), c + Vector2(s * 0.15, -s * 0.12), Color(0.35, 0.28, 0.2), 2.5)
