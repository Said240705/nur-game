extends RefCounted
## How blocks look: each palette colour becomes a glossy, bevelled gem texture,
## built once from code. Also a soft round glow for halos and sparks.

const PALETTE := [
	Color("#ff4f7b"), # rose
	Color("#ff9a3c"), # amber
	Color("#ffd447"), # gold
	Color("#3ee6a0"), # mint
	Color("#33c8ff"), # sky
	Color("#6b7dff"), # indigo
	Color("#c264ff"), # violet
]
## Colour index used when the round is over and the board turns to stone.
const STONE := 99
const SIZE := 128

static var _blocks := {}
static var _glow: Texture2D


static func color(i: int) -> Color:
	if i == STONE:
		return Color("#4a4f6e")
	return PALETTE[(i - 1) % PALETTE.size()]


static func block(i: int) -> Texture2D:
	if not _blocks.has(i):
		_blocks[i] = _make_block(color(i))
	return _blocks[i]


## A white radial falloff; tint it when drawing.
static func glow() -> Texture2D:
	if _glow == null:
		var n := 128
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a))
		_glow = ImageTexture.create_from_image(img)
	return _glow


static func _make_block(c: Color) -> Texture2D:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var half := SIZE * 0.5
	var radius := 26.0
	var inset := 2.0
	for y in SIZE:
		for x in SIZE:
			var p := Vector2(x + 0.5, y + 0.5) - Vector2(half, half)
			# Signed distance to a rounded square: negative inside.
			var q := p.abs() - Vector2(half - inset - radius, half - inset - radius)
			var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
			var alpha := clampf(0.5 - d, 0.0, 1.0)
			if alpha <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			# Body: lighter at the top, deeper at the bottom.
			var v := float(y) / SIZE
			var col := c.lightened(0.22).lerp(c.darkened(0.28), v)
			# Bevel: the rim catches light from the top-left and falls into shade bottom-right.
			var rim := 1.0 - clampf(-d / 14.0, 0.0, 1.0)
			var light := -(p.normalized().dot(Vector2(0.55, 0.83)))
			if light > 0.0:
				col = col.lerp(Color.WHITE, light * rim * 0.42)
			else:
				col = col.lerp(c.darkened(0.6), -light * rim * 0.5)
			# Gloss: a soft oval highlight across the upper half.
			var g := Vector2(p.x / (SIZE * 0.34), (p.y + SIZE * 0.2) / (SIZE * 0.17))
			var gl := clampf(1.0 - g.length(), 0.0, 1.0)
			col = col.lerp(Color.WHITE, gl * gl * 0.45)
			# A thin bright line just inside the edge, like polished glass.
			if d > -5.0 and d < -2.5 and p.y < 0.0:
				col = col.lerp(Color.WHITE, 0.25)
			col.a = alpha
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
