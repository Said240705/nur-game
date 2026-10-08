extends RefCounted
## Everything you can earn, buy and become, from a pile of flyers to an oil
## company. One game day passes every DAY seconds.

const DAY := 3.0
const START_CASH := 100.0
## Days in debt before the bank takes everything.
const DEBT_DAYS := 7
const MAX_LEVEL := 10

## Statuses by net worth; each has its own job (a mini-game in scripts/work/)
## and pays more per success.
const RANKS := [
	{"name": "Бездомный", "worth": 0.0, "job": "Раздавать листовки", "pay": 3.0, "game": "flyers"},
	{"name": "Студент", "worth": 1e3, "job": "Курьер", "pay": 8.0, "game": "courier"},
	{"name": "Работяга", "worth": 1e4, "job": "Таксист", "pay": 25.0, "game": "taxi"},
	{"name": "Предприниматель", "worth": 1e5, "job": "Продавать франшизы", "pay": 90.0, "game": "negotiation"},
	{"name": "Миллионер", "worth": 1e6, "job": "Консультировать бизнес", "pay": 350.0, "game": "negotiation"},
	{"name": "Бизнесмен", "worth": 1e7, "job": "Закрывать сделки", "pay": 1.5e3, "game": "papers"},
	{"name": "Магнат", "worth": 1e8, "job": "Проверять контракты холдинга", "pay": 6e3, "game": "papers"},
	{"name": "Олигарх", "worth": 5e8, "job": "Играть на бирже", "pay": 2.5e4, "game": "stocks"},
	{"name": "Миллиардер", "worth": 1e9, "job": "Двигать рынки", "pay": 1e5, "game": "stocks"},
]

## Price, income per day at level 1 and colour of the icon tile.
const BUSINESSES := [
	{"id": "shawarma", "name": "Ларёк с шаурмой", "price": 400.0, "income": 10.0, "color": Color("#ff9a3c")},
	{"id": "wash", "name": "Автомойка", "price": 4e3, "income": 80.0, "color": Color("#33c8ff")},
	{"id": "coffee", "name": "Кофейня", "price": 3e4, "income": 500.0, "color": Color("#b07a52")},
	{"id": "clothes", "name": "Магазин одежды", "price": 2e5, "income": 2.8e3, "color": Color("#ff5fa2")},
	{"id": "restaurant", "name": "Ресторан", "price": 1.5e6, "income": 1.8e4, "color": Color("#ff5c6c")},
	{"id": "gym", "name": "Фитнес-клуб", "price": 1e7, "income": 1e5, "color": Color("#3ee08f")},
	{"id": "hotel", "name": "Отель", "price": 7e7, "income": 6e5, "color": Color("#c264ff")},
	{"id": "it", "name": "IT-компания", "price": 5e8, "income": 3.5e6, "color": Color("#6b7dff")},
	{"id": "bank", "name": "Банк", "price": 3e9, "income": 1.8e7, "color": Color("#f5c451")},
	{"id": "oil", "name": "Нефтяная компания", "price": 2e10, "income": 1e8, "color": Color("#4a4f6e")},
]

## Homes and rides: they cost upkeep every day, but status (prestige) makes
## every business earn more.
const PROPERTY := [
	{"id": "room", "kind": "home", "name": "Комната в общаге", "price": 300.0, "upkeep": 5.0, "prestige": 0.03},
	{"id": "flat", "kind": "home", "name": "Своя квартира", "price": 1.2e4, "upkeep": 60.0, "prestige": 0.06},
	{"id": "house", "kind": "home", "name": "Дом за городом", "price": 3e5, "upkeep": 900.0, "prestige": 0.1},
	{"id": "penthouse", "kind": "home", "name": "Пентхаус", "price": 8e6, "upkeep": 2e4, "prestige": 0.18},
	{"id": "mansion", "kind": "home", "name": "Особняк у моря", "price": 1.5e8, "upkeep": 3e5, "prestige": 0.3},
	{"id": "bike", "kind": "ride", "name": "Велосипед", "price": 150.0, "upkeep": 0.0, "prestige": 0.02},
	{"id": "oldcar", "kind": "ride", "name": "Подержанная машина", "price": 5e3, "upkeep": 30.0, "prestige": 0.04},
	{"id": "car", "kind": "ride", "name": "Новая иномарка", "price": 8e4, "upkeep": 300.0, "prestige": 0.08},
	{"id": "sportcar", "kind": "ride", "name": "Спорткар", "price": 2e6, "upkeep": 6e3, "prestige": 0.15},
	{"id": "yacht", "kind": "ride", "name": "Яхта", "price": 4e7, "upkeep": 1e5, "prestige": 0.25},
	{"id": "jet", "kind": "ride", "name": "Частный самолёт", "price": 6e8, "upkeep": 1.5e6, "prestige": 0.4},
]


static func business(id: String) -> Dictionary:
	for b in BUSINESSES:
		if b["id"] == id:
			return b
	return {}


static func property(id: String) -> Dictionary:
	for p in PROPERTY:
		if p["id"] == id:
			return p
	return {}


## Income per day of a business at a level (each level adds 35% of the base).
static func income_at(b: Dictionary, level: int) -> float:
	return b["income"] * (1.0 + 0.35 * (level - 1))


static func upgrade_cost(b: Dictionary, level: int) -> float:
	return b["price"] * 0.5 * pow(1.45, level - 1)


static func rank_of(worth: float) -> int:
	var r := 0
	for i in RANKS.size():
		if worth >= RANKS[i]["worth"]:
			r = i
	return r


const SUFFIXES := ["", "K", "M", "B", "T"]


## $950, $12.4K, $3.5M, $1.2B.
static func money(v: float) -> String:
	var sign := "-" if v < 0.0 else ""
	v = absf(v)
	if v < 1000.0:
		return sign + "$" + str(int(floorf(v)))
	var tier := mini(int(floorf(log(v) / log(1000.0))), SUFFIXES.size() - 1)
	var scaled := v / pow(1000.0, tier)
	var digits := 2 if scaled < 10.0 else (1 if scaled < 100.0 else 0)
	var text := String.num(floorf(scaled * pow(10.0, digits)) / pow(10.0, digits), digits)
	return sign + "$" + text + SUFFIXES[tier]
