extends RefCounted
## Life happens: every half a minute or so a situation asks for a decision.
## Each choice has outcomes with chances, so every decision is a small bet.
##
## Amounts scale with the player: ["cash", share, minimum], ["income", days, minimum],
## ["biz", share of the business price], ["fixed", value].
## Outcome effects: "cash" (times the amount, may be negative), "boost" [income
## multiplier, days], "level" (+1 or -1 for the business in question), "sell" (sell
## it for the amount). Needs: "biz" (owns a business), "rank" (at least that status).

const LIST := [
	{"id": "loan", "title": "Друг в беде", "text": "Старый друг просит одолжить {amt}. Клянётся вернуть вдвое.",
	"amt": ["cash", 0.25, 50.0], "choices": [
		{"label": "Одолжить", "outcomes": [
			{"p": 0.55, "text": "Друг сдержал слово и вернул вдвое!", "cash": 1.0},
			{"p": 0.45, "text": "Друг пропал. Вместе с деньгами.", "cash": -1.0}]},
		{"label": "Отказать", "outcomes": [{"p": 1.0, "text": "Деньги целы. Дружба — под вопросом."}]}]},
	{"id": "crypto", "title": "Крипто-лихорадка", "text": "Все скупают новую монету. Друг говорит: «Залетай, пока не поздно!» Вложить {amt}?",
	"amt": ["cash", 0.3, 50.0], "choices": [
		{"label": "Залететь", "outcomes": [
			{"p": 0.35, "text": "Монета взлетела в 4 раза! Ты гений.", "cash": 3.0},
			{"p": 0.65, "text": "Монета рухнула на 99%. Создатели исчезли.", "cash": -1.0}]},
		{"label": "Пропустить", "outcomes": [{"p": 1.0, "text": "Через неделю монета обнулилась. Или нет — ты уже не узнаешь."}]}]},
	{"id": "tax", "title": "Налоговая проверка", "need": "biz", "text": "Инспектор нашёл ошибки в отчётах «{biz}». Штраф — {amt}.",
	"amt": ["cash", 0.15, 100.0], "choices": [
		{"label": "Заплатить", "outcomes": [{"p": 1.0, "text": "Штраф оплачен. Совесть чиста.", "cash": -1.0}]},
		{"label": "Договориться", "outcomes": [
			{"p": 0.5, "text": "Инспектор оказался понимающим. Отделался мелочью.", "cash": -0.3},
			{"p": 0.5, "text": "Это была проверка на взятку. Двойной штраф!", "cash": -2.0}]}]},
	{"id": "rival", "title": "Конкурент", "need": "biz", "text": "Прямо напротив «{biz}» открылся конкурент с ценами ниже твоих.",
	"amt": ["fixed", 0.0], "choices": [
		{"label": "Снизить цены", "outcomes": [{"p": 1.0, "text": "Клиенты остались, но доход меньше: −20% на 10 дней.", "boost": [0.8, 10]}]},
		{"label": "Ничего не делать", "outcomes": [
			{"p": 0.5, "text": "Конкурент прогорел за месяц. Ха!"},
			{"p": 0.5, "text": "Клиенты ушли к нему. «{biz}» теряет уровень.", "level": -1}]}]},
	{"id": "buyer", "title": "Покупатель", "need": "biz", "text": "Инвестор хочет купить твой «{biz}» за {amt}. Это втрое дороже, чем ты платил.",
	"amt": ["biz", 3.0], "choices": [
		{"label": "Продать", "outcomes": [{"p": 1.0, "text": "Сделка закрыта. Деньги на счету!", "sell": true}]},
		{"label": "Не продаётся", "outcomes": [{"p": 1.0, "text": "Ты не продаёшь своё. Уважаемо."}]}]},
	{"id": "blogger", "title": "Реклама у блогера", "text": "Блогер-миллионник предлагает рекламу за {amt}.",
	"amt": ["income", 3.0, 60.0], "choices": [
		{"label": "Заказать", "outcomes": [
			{"p": 0.7, "text": "Реклама зашла! Доход +50% на 15 дней.", "cash": -1.0, "boost": [1.5, 15]},
			{"p": 0.3, "text": "Блогера отменили за скандал. Деньги сгорели.", "cash": -1.0}]},
		{"label": "Отказаться", "outcomes": [{"p": 1.0, "text": "Сэкономил. Может, и правильно."}]}]},
	{"id": "lottery", "title": "Лотерея", "text": "Бабушка у метро продаёт «счастливый» билет за {amt}.",
	"amt": ["fixed", 100.0], "choices": [
		{"label": "Купить", "outcomes": [
			{"p": 0.04, "text": "ДЖЕКПОТ! Билет выиграл $50 000!", "cash": 499.0},
			{"p": 0.96, "text": "Пусто. Бабушка улыбнулась и исчезла.", "cash": -1.0}]},
		{"label": "Пройти мимо", "outcomes": [{"p": 1.0, "text": "Ты не веришь в удачу. Ты веришь в себя."}]}]},
	{"id": "fire", "title": "Пожар!", "need": "biz", "text": "Ночью в «{biz}» замкнуло проводку. Ремонт обойдётся в {amt}.",
	"amt": ["biz", 0.3], "choices": [
		{"label": "Отремонтировать", "outcomes": [{"p": 1.0, "text": "Всё как новенькое.", "cash": -1.0}]},
		{"label": "Работать как есть", "outcomes": [{"p": 1.0, "text": "Клиенты морщатся от запаха гари. «{biz}» теряет уровень.", "level": -1}]}]},
	{"id": "crisis", "title": "Кризис", "text": "В стране кризис: люди экономят на всём.",
	"amt": ["fixed", 0.0], "choices": [
		{"label": "Переждать", "outcomes": [{"p": 1.0, "text": "Доход −30% на 12 дней. Главное — выжить.", "boost": [0.7, 12]}]},
		{"label": "Урезать зарплаты", "outcomes": [
			{"p": 0.6, "text": "Сэкономил. Доход −15% на 8 дней.", "boost": [0.85, 8]},
			{"p": 0.4, "text": "Лучшие люди ушли к конкурентам. Доход −40% на 10 дней.", "boost": [0.6, 10]}]}]},
	{"id": "startup", "title": "Стартап", "text": "Знакомый айтишник ищет инвестора: «Это новый Uber, только для собак». Нужно {amt}.",
	"amt": ["cash", 0.4, 100.0], "choices": [
		{"label": "Инвестировать", "outcomes": [
			{"p": 0.2, "text": "Его купил Google! Твоя доля выросла в 6 раз!", "cash": 5.0},
			{"p": 0.8, "text": "Собакам не понравилось. Стартап закрыт.", "cash": -1.0}]},
		{"label": "Отказать", "outcomes": [{"p": 1.0, "text": "Собаки остались без такси."}]}]},
	{"id": "heritage", "title": "Наследство", "text": "Звонит нотариус: дальний дядя оставил тебе наследство.",
	"amt": ["worth", 0.3, 300.0], "choices": [
		{"label": "Принять", "outcomes": [
			{"p": 0.7, "text": "Дядя был богат! +{amt}", "cash": 1.0},
			{"p": 0.3, "text": "Наследство — это долги дяди. Пришлось платить.", "cash": -0.15}]},
		{"label": "Отказаться", "outcomes": [{"p": 1.0, "text": "Ты не берёшь чужого. Даже от дяди."}]}]},
	{"id": "casino", "title": "Казино", "text": "Друзья зовут в казино. Поставить {amt} на красное?",
	"amt": ["cash", 0.5, 50.0], "choices": [
		{"label": "На красное!", "outcomes": [
			{"p": 0.47, "text": "Красное! Ставка удвоилась!", "cash": 1.0},
			{"p": 0.53, "text": "Чёрное. Казино всегда в плюсе.", "cash": -1.0}]},
		{"label": "Остаться дома", "outcomes": [{"p": 1.0, "text": "Тихий вечер дома. Деньги целы."}]}]},
	{"id": "wallet", "title": "Находка", "text": "На улице лежит кошелёк. Внутри {amt} и визитка владельца.",
	"amt": ["income", 2.0, 80.0], "choices": [
		{"label": "Вернуть", "outcomes": [
			{"p": 0.6, "text": "Владелец — крупный бизнесмен. Знакомство: доход +25% на 10 дней.", "boost": [1.25, 10]},
			{"p": 0.4, "text": "«Спасибо». И всё. Зато совесть чиста."}]},
		{"label": "Оставить себе", "outcomes": [
			{"p": 0.7, "text": "Никто не видел. +{amt}", "cash": 1.0},
			{"p": 0.3, "text": "Камеры всё видели. Штраф вдвое больше.", "cash": -2.0}]}]},
	{"id": "merge", "title": "Слияние", "need": "biz", "text": "Владелец сети предлагает объединить «{biz}» с его бизнесом.",
	"amt": ["fixed", 0.0], "choices": [
		{"label": "Объединить", "outcomes": [
			{"p": 0.6, "text": "Сеть выросла! «{biz}» получает уровень.", "level": 1},
			{"p": 0.4, "text": "Партнёр увёл клиентов к себе. «{biz}» теряет уровень.", "level": -1}]},
		{"label": "Остаться одному", "outcomes": [{"p": 1.0, "text": "Сам себе хозяин."}]}]},
	{"id": "viral", "title": "Ты в трендах", "need": "biz", "text": "Видео про «{biz}» набрало миллион просмотров!",
	"amt": ["income", 2.0, 50.0], "choices": [
		{"label": "Вложить {amt} в раскрутку", "outcomes": [
			{"p": 0.8, "text": "Очереди на улице! Доход ×2 на 7 дней.", "cash": -1.0, "boost": [2.0, 7]},
			{"p": 0.2, "text": "Хайп быстро прошёл. Доход +30% на 5 дней.", "cash": -1.0, "boost": [1.3, 5]}]},
		{"label": "Просто радоваться", "outcomes": [{"p": 1.0, "text": "Доход +30% на 5 дней.", "boost": [1.3, 5]}]}]},
	{"id": "robbery", "title": "Ограбление", "text": "Пока ты спал, из сейфа пропало {amt}.",
	"amt": ["cash", 0.1, 50.0], "choices": [
		{"label": "Вызвать полицию", "outcomes": [
			{"p": 0.5, "text": "Вора поймали! Деньги вернули."},
			{"p": 0.5, "text": "«Ищем». Деньги не вернули.", "cash": -1.0}]},
		{"label": "Нанять детектива", "outcomes": [
			{"p": 0.8, "text": "Детектив нашёл вора за день. Деньги вернулись, минус гонорар.", "cash": -0.3},
			{"p": 0.2, "text": "Детектив взял гонорар и уехал на море.", "cash": -1.3}]}]},
	{"id": "gold", "title": "Золото со скидкой", "text": "Знакомый продаёт слиток золота на 30% дешевле рынка. Цена — {amt}.",
	"amt": ["cash", 0.3, 100.0], "choices": [
		{"label": "Купить", "outcomes": [
			{"p": 0.6, "text": "Золото настоящее! Перепродал с прибылью.", "cash": 0.5},
			{"p": 0.4, "text": "Это позолоченный свинец.", "cash": -1.0}]},
		{"label": "Отказаться", "outcomes": [{"p": 1.0, "text": "Если звучит слишком хорошо — так и есть."}]}]},
	{"id": "tender", "title": "Госзаказ", "need": "rank:3", "text": "Объявлен большой тендер. Взнос за участие — {amt}.",
	"amt": ["cash", 0.2, 1000.0], "choices": [
		{"label": "Участвовать", "outcomes": [
			{"p": 0.4, "text": "Ты выиграл тендер! Втрое больше взноса.", "cash": 2.0},
			{"p": 0.6, "text": "Тендер достался «своим». Взнос не вернут.", "cash": -1.0}]},
		{"label": "Не связываться", "outcomes": [{"p": 1.0, "text": "Нервы дороже."}]}]},
	{"id": "dip", "title": "Обвал на бирже", "text": "Акции падают, все в панике продают. Купить на дне на {amt}?",
	"amt": ["cash", 0.3, 100.0], "choices": [
		{"label": "Купить на дне", "outcomes": [
			{"p": 0.55, "text": "Рынок отскочил! ×2.5", "cash": 1.5},
			{"p": 0.45, "text": "Дно оказалось не дном.", "cash": -0.6}]},
		{"label": "Не рисковать", "outcomes": [{"p": 1.0, "text": "Ты наблюдаешь со стороны."}]}]},
	{"id": "charity", "title": "Просьба о помощи", "text": "Детский дом просит помочь с ремонтом. Нужно {amt}.",
	"amt": ["cash", 0.05, 30.0], "choices": [
		{"label": "Помочь", "outcomes": [{"p": 1.0, "text": "Тебя показали в новостях. Доход +25% на 10 дней.", "cash": -1.0, "boost": [1.25, 10]}]},
		{"label": "Не сейчас", "outcomes": [{"p": 1.0, "text": "Может, в другой раз."}]}]},
]


## Picks an event that fits the player's situation and fills in its numbers.
static func pick(state: RefCounted, last_id: String) -> Dictionary:
	var pool := []
	for e in LIST:
		if e["id"] == last_id:
			continue
		var need: String = e.get("need", "")
		if need == "biz" and state.businesses.is_empty():
			continue
		if need.begins_with("rank:") and state.rank() < int(need.get_slice(":", 1)):
			continue
		pool.append(e)
	var e: Dictionary = pool[randi() % pool.size()].duplicate(true)
	var biz := ""
	if not state.businesses.is_empty():
		var ids: Array = state.businesses.keys()
		biz = ids[randi() % ids.size()]
	e["biz_id"] = biz
	e["amount"] = _amount(e["amt"], state, biz)
	return e


static func _amount(spec: Array, state: RefCounted, biz: String) -> float:
	var Data := preload("res://scripts/game/data.gd")
	match spec[0]:
		"cash":
			return roundf(maxf(state.cash * spec[1], spec[2]))
		"income":
			return roundf(maxf(state.daily_income() * spec[1], spec[2]))
		"worth":
			return roundf(maxf(state.worth() * spec[1], spec[2]))
		"biz":
			return roundf(Data.business(biz)["price"] * spec[1]) if biz != "" else 0.0
	return spec[1]


## Rolls the dice for a choice; returns the outcome that happened.
static func roll(choice: Dictionary) -> Dictionary:
	var r := randf()
	for o in choice["outcomes"]:
		r -= o["p"]
		if r <= 0.0:
			return o
	return choice["outcomes"][-1]
