extends RefCounted
## The numbers behind the mine: what each ore is worth, what every upgrade
## costs and gives, and how to print huge amounts short (1.2K, 3.4M, …).
## Prices grow a little faster than what a level gives, so each station slowly
## gets expensive and opening the next, richer shaft is the big leap; every 25
## levels a station doubles its output, a moment to aim for.

const ORES := [
	{"name": "Уголь", "color": Color("#5b5f6e"), "unlock": 0.0, "base": 15.0, "cost": 10.0},
	{"name": "Медь", "color": Color("#e07b39"), "unlock": 1.5e3, "base": 120.0, "cost": 250.0},
	{"name": "Железо", "color": Color("#a7b4c7"), "unlock": 5e4, "base": 960.0, "cost": 6e3},
	{"name": "Серебро", "color": Color("#dfe7f2"), "unlock": 1.6e6, "base": 7.7e3, "cost": 1.5e5},
	{"name": "Золото", "color": Color("#ffcf3f"), "unlock": 5e7, "base": 6.1e4, "cost": 3.6e6},
	{"name": "Рубин", "color": Color("#ff3d6e"), "unlock": 1.6e9, "base": 4.9e5, "cost": 9e7},
	{"name": "Изумруд", "color": Color("#2ee59d"), "unlock": 5e10, "base": 3.9e6, "cost": 2.2e9},
	{"name": "Сапфир", "color": Color("#3d8bff"), "unlock": 1.6e12, "base": 3.1e7, "cost": 5.5e10},
	{"name": "Аметист", "color": Color("#b45cff"), "unlock": 5e13, "base": 2.5e8, "cost": 1.4e12},
	{"name": "Алмаз", "color": Color("#bff6ff"), "unlock": 1.6e15, "base": 2e9, "cost": 3.4e13},
]

## Seconds a miner needs to walk to the rock, dig and come back.
const WALK := 1.1
const DIG := 1.8
const PRICE_GROWTH := 1.15
const OUTPUT_GROWTH := 1.11
const MILESTONE := 25
## At most this much time counts while the game is closed.
const OFFLINE_CAP := 4.0 * 3600.0


static func milestone(level: int) -> float:
	return pow(2.0, floorf(level / float(MILESTONE)))


# --- Shafts -----------------------------------------------------------------

static func shaft_output(i: int, level: int) -> float:
	return ORES[i]["base"] * pow(OUTPUT_GROWTH, level - 1) * milestone(level)


static func shaft_cost(i: int, level: int) -> float:
	return ORES[i]["cost"] * pow(PRICE_GROWTH, level - 1)


static func shaft_manager_cost(i: int) -> float:
	return ORES[i]["cost"] * 4.0


static func shaft_cycle() -> float:
	return WALK * 2.0 + DIG


# --- Elevator ---------------------------------------------------------------

static func lift_capacity(level: int) -> float:
	return 60.0 * pow(OUTPUT_GROWTH, level - 1) * milestone(level)


## Shafts per second.
static func lift_speed(level: int) -> float:
	return 1.6 * (1.0 + 0.02 * mini(level - 1, 100))


static func lift_cost(level: int) -> float:
	return 25.0 * pow(PRICE_GROWTH, level - 1)


const LIFT_MANAGER := 80.0
const LIFT_LOAD_TIME := 0.3


# --- Warehouse --------------------------------------------------------------

static func cart_capacity(level: int) -> float:
	return 60.0 * pow(OUTPUT_GROWTH, level - 1) * milestone(level)


## Seconds to walk one way between the pile and the shop.
static func cart_walk(level: int) -> float:
	return 1.5 / (1.0 + 0.02 * mini(level - 1, 100))


static func cart_cost(level: int) -> float:
	return 20.0 * pow(PRICE_GROWTH, level - 1)


const CART_MANAGER := 50.0


# --- Display ----------------------------------------------------------------

const SUFFIXES := ["", "K", "M", "B", "T"]


## 950, 1.2K, 34.5M, 2.1B, 7T, then aa, ab, … for the truly rich.
static func short(v: float) -> String:
	if v < 1000.0:
		return str(int(floorf(v)))
	var tier := int(floorf(log(v) / log(1000.0)))
	var scaled := v / pow(1000.0, tier)
	var suffix: String
	if tier < SUFFIXES.size():
		suffix = SUFFIXES[tier]
	else:
		var n := tier - SUFFIXES.size()
		suffix = char(97 + n / 26 % 26) + char(97 + n % 26)
	var digits := 2 if scaled < 10.0 else (1 if scaled < 100.0 else 0)
	var text := String.num(floorf(scaled * pow(10.0, digits)) / pow(10.0, digits), digits)
	return text + suffix
