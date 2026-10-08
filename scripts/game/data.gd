extends RefCounted
## Everything you can earn, buy and become, from a pile of flyers to an oil
## company. One game day passes every DAY seconds.

const DAY := 4.0
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

## Districts of the city: people passing by per day, how well-off they are
## (1 poor … 5 rich), and how expensive rent is compared to the outskirts.
const DISTRICTS := {
	"outskirts": {"name": "Окраина", "traffic": 60.0, "wealth": 1, "rent": 1.0, "color": Color("#4a5d3a")},
	"campus": {"name": "Студенческий квартал", "traffic": 100.0, "wealth": 2, "rent": 1.6, "color": Color("#3a5a6b")},
	"sleepy": {"name": "Спальный район", "traffic": 80.0, "wealth": 2, "rent": 1.4, "color": Color("#5b4a6b")},
	"center": {"name": "Центр", "traffic": 180.0, "wealth": 4, "rent": 4.0, "color": Color("#6b4a3a")},
	"business": {"name": "Деловой квартал", "traffic": 140.0, "wealth": 5, "rent": 5.0, "color": Color("#3a4a6b")},
	"embankment": {"name": "Набережная", "traffic": 150.0, "wealth": 5, "rent": 6.0, "color": Color("#2f5d63")},
}
## Daily rent of a small, medium and large place before the district factor.
const RENT := {"S": 8.0, "M": 30.0, "L": 150.0}
const SIZE_NAMES := {"S": "маленькое", "M": "среднее", "L": "большое"}

## Places for rent on the map, in map coordinates (1000 × 1300).
const PLOTS := [
	{"id": 0, "d": "outskirts", "size": "S", "pos": Vector2(120, 1080)},
	{"id": 1, "d": "outskirts", "size": "S", "pos": Vector2(290, 1170)},
	{"id": 2, "d": "outskirts", "size": "M", "pos": Vector2(200, 990)},
	{"id": 3, "d": "outskirts", "size": "L", "pos": Vector2(380, 1010)},
	{"id": 4, "d": "sleepy", "size": "S", "pos": Vector2(650, 1170)},
	{"id": 5, "d": "sleepy", "size": "M", "pos": Vector2(820, 1080)},
	{"id": 6, "d": "sleepy", "size": "M", "pos": Vector2(620, 1010)},
	{"id": 7, "d": "sleepy", "size": "L", "pos": Vector2(880, 920)},
	{"id": 8, "d": "campus", "size": "S", "pos": Vector2(110, 700)},
	{"id": 9, "d": "campus", "size": "S", "pos": Vector2(280, 780)},
	{"id": 10, "d": "campus", "size": "M", "pos": Vector2(200, 640)},
	{"id": 11, "d": "campus", "size": "M", "pos": Vector2(320, 650)},
	{"id": 12, "d": "center", "size": "S", "pos": Vector2(520, 760)},
	{"id": 13, "d": "center", "size": "M", "pos": Vector2(680, 700)},
	{"id": 14, "d": "center", "size": "M", "pos": Vector2(530, 630)},
	{"id": 15, "d": "center", "size": "L", "pos": Vector2(640, 540)},
	{"id": 16, "d": "center", "size": "L", "pos": Vector2(820, 680)},
	{"id": 17, "d": "business", "size": "M", "pos": Vector2(720, 330)},
	{"id": 18, "d": "business", "size": "L", "pos": Vector2(880, 230)},
	{"id": 19, "d": "business", "size": "L", "pos": Vector2(860, 430)},
	{"id": 20, "d": "embankment", "size": "M", "pos": Vector2(180, 300)},
	{"id": 21, "d": "embankment", "size": "L", "pos": Vector2(360, 200)},
	{"id": 22, "d": "embankment", "size": "L", "pos": Vector2(470, 370)},
]

## Kinds of business. `cls` is the clientele (1 cheap … 5 luxury): it does best
## where people's wealth matches. `ticket` is the average bill, `unit` what one
## sale costs in goods (0 = a service without stock), `reach` the share of
## passers-by who might come in. Roles: "serve" workers serve `cap` clients a day,
## "quality" ones lift the rating, the manager also restocks by himself.
const BUSINESSES := [
	{"id": "shawarma", "name": "Ларёк с шаурмой", "size": "S", "cls": 1, "price": 300.0, "ticket": 4.0, "unit": 1.4, "reach": 0.6,
	"client": "клиентов", "color": Color("#ff9a3c"), "roles": [
		{"id": "cook", "name": "Шаурмист", "kind": "serve", "cap": 15.0, "salary": 10.0},
		{"id": "clean", "name": "Уборщица", "kind": "quality", "salary": 6.0}]},
	{"id": "wash", "name": "Автомойка", "size": "M", "cls": 2, "price": 3000.0, "ticket": 14.0, "unit": 2.4, "reach": 0.3,
	"client": "машин", "color": Color("#33c8ff"), "roles": [
		{"id": "washer", "name": "Мойщик", "kind": "serve", "cap": 8.0, "salary": 21.0},
		{"id": "admin", "name": "Администратор", "kind": "quality", "salary": 14.0}]},
	{"id": "coffee", "name": "Кофейня", "size": "M", "cls": 3, "price": 1.8e4, "ticket": 5.0, "unit": 1.5, "reach": 1.35,
	"client": "гостей", "color": Color("#b07a52"), "roles": [
		{"id": "barista", "name": "Бариста", "kind": "serve", "cap": 55.0, "salary": 60.0},
		{"id": "waiter", "name": "Официант", "kind": "serve", "cap": 45.0, "salary": 50.0},
		{"id": "clean", "name": "Уборщица", "kind": "quality", "salary": 35.0}]},
	{"id": "clothes", "name": "Магазин одежды", "size": "M", "cls": 3, "price": 1e5, "ticket": 60.0, "unit": 30.0, "reach": 0.8,
	"client": "покупателей", "color": Color("#ff5fa2"), "roles": [
		{"id": "seller", "name": "Продавец", "kind": "serve", "cap": 50.0, "salary": 650.0},
		{"id": "guard", "name": "Охранник", "kind": "quality", "salary": 400.0}]},
	{"id": "restaurant", "name": "Ресторан", "size": "L", "cls": 4, "price": 6e5, "ticket": 45.0, "unit": 16.0, "reach": 2.4,
	"client": "гостей", "color": Color("#ff5c6c"), "roles": [
		{"id": "chef", "name": "Повар", "kind": "serve", "cap": 140.0, "salary": 1400.0},
		{"id": "waiter", "name": "Официант", "kind": "serve", "cap": 120.0, "salary": 1150.0},
		{"id": "head", "name": "Шеф-повар", "kind": "quality", "salary": 850.0}]},
	{"id": "gym", "name": "Фитнес-клуб", "size": "L", "cls": 3, "price": 3e6, "ticket": 60.0, "unit": 3.0, "reach": 6.0,
	"client": "посетителей", "color": Color("#3ee08f"), "roles": [
		{"id": "coach", "name": "Тренер", "kind": "serve", "cap": 350.0, "salary": 4600.0},
		{"id": "admin", "name": "Администратор", "kind": "quality", "salary": 2700.0}]},
	{"id": "hotel", "name": "Отель", "size": "L", "cls": 5, "price": 2e7, "ticket": 400.0, "unit": 80.0, "reach": 5.0,
	"client": "гостей", "color": Color("#c264ff"), "roles": [
		{"id": "maid", "name": "Горничная", "kind": "serve", "cap": 190.0, "salary": 16700.0},
		{"id": "porter", "name": "Портье", "kind": "quality", "salary": 10000.0}]},
	{"id": "it", "name": "IT-компания", "size": "L", "cls": 5, "price": 1.5e8, "ticket": 5e4, "unit": 0.0, "reach": 0.37,
	"client": "заказов", "color": Color("#6b7dff"), "roles": [
		{"id": "dev", "name": "Программист", "kind": "serve", "cap": 7.4, "salary": 8.1e4},
		{"id": "lead", "name": "Тимлид", "kind": "quality", "salary": 4.9e4}]},
	{"id": "bank", "name": "Банк", "size": "L", "cls": 5, "price": 1e9, "ticket": 5e5, "unit": 0.0, "reach": 0.22,
	"client": "сделок", "color": Color("#f5c451"), "roles": [
		{"id": "fin", "name": "Финансист", "kind": "serve", "cap": 4.4, "salary": 4.86e5},
		{"id": "lawyer", "name": "Юрист", "kind": "quality", "salary": 2.9e5}]},
	{"id": "oil", "name": "Нефтяная компания", "size": "L", "cls": 1, "price": 8e9, "ticket": 2e6, "unit": 2e5, "reach": 0.6,
	"client": "танкеров", "color": Color("#4a4f6e"), "roles": [
		{"id": "driller", "name": "Буровик", "kind": "serve", "cap": 10.0, "salary": 4.4e6},
		{"id": "geo", "name": "Геолог", "kind": "quality", "salary": 2.6e6}]},
]
## Every business can also take a manager: he restocks by himself and lifts the rating.
const MANAGER := {"id": "manager", "name": "Управляющий", "kind": "manager"}
const MAX_STAFF := 8

## Renovation levels: cost as a share of the business price, days closed,
## how much more inviting the place becomes, and the rating it adds.
const RENOVATION := [
	{"name": "Без ремонта", "cost": 0.0, "days": 0, "appeal": 0.7, "rating": 0.0},
	{"name": "Косметический", "cost": 0.3, "days": 2, "appeal": 1.0, "rating": 0.4},
	{"name": "Хороший", "cost": 0.8, "days": 4, "appeal": 1.25, "rating": 0.8},
	{"name": "Дизайнерский", "cost": 2.0, "days": 6, "appeal": 1.5, "rating": 1.2},
]
const PRICES := [
	{"name": "Очень дёшево", "mult": 0.7}, {"name": "Дёшево", "mult": 0.85}, {"name": "Нормально", "mult": 1.0},
	{"name": "Дорого", "mult": 1.2}, {"name": "Очень дорого", "mult": 1.45},
]
const ADS := [
	{"name": "Нет", "cost": 0.0, "effect": 1.0}, {"name": "Листовки", "cost": 0.02, "effect": 1.15},
	{"name": "Соцсети", "cost": 0.05, "effect": 1.3}, {"name": "Билборды", "cost": 0.1, "effect": 1.45},
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


## All roles of a kind of business, the manager included.
static func roles(b: Dictionary) -> Array:
	return b["roles"] + [manager_role(b)]


static func manager_role(b: Dictionary) -> Dictionary:
	var m := MANAGER.duplicate()
	m["salary"] = b["roles"][0]["salary"] * 1.5
	return m


static func plot(id: int) -> Dictionary:
	return PLOTS[id]


static func plot_rent(p: Dictionary) -> float:
	return RENT[p["size"]] * DISTRICTS[p["d"]]["rent"]


## Electricity and water per day: equipment runs on power, clients use water.
static func power(b: Dictionary) -> float:
	return b["ticket"] * b["roles"][0]["cap"] * 0.06


static func water(b: Dictionary) -> float:
	return b["ticket"] * b["roles"][0]["cap"] * 0.02


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
