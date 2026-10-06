extends RefCounted
## Every line of the prologue in one place, ready for voice-over and translation.

const TITLE := "БЫЛА В СЕТИ"
const SUBTITLE := "Детектив внутри чужого телефона"
const TAP_TO_START := "Коснись, чтобы начать"

## Cold open: a glimpse of the end, then back in time.
const COLD_OPEN_WHISPER := "— Лев… не надо…"
const HOURS_BEFORE := "72 ЧАСА НАЗАД"

## Lev's inner voice over the city.
const CITY_VOICE := [
	"В этом городе я нашёл сорок три пропавших человека.",
	"Сорок три.",
	"Но не того, кого искал больше всех.",
]
const FACE_VOICE := [
	"Лев Арсланов. Когда-то меня называли лучшим детективом этого города.",
	"Теперь меня называют по-разному. Чаще всего — должником.",
	"Сегодня ровно пять лет, как пропала Вера.",
]

const GOAL_LOOK := "Осмотрись в телефоне Льва"
const GOAL_CODE := "Код — день, когда ты перестал быть детективом"
const SWITCH_TO_LEV := "Телефон Льва"
const SWITCH_TO_MIRA := "Телефон Миры"

## Lev's thoughts when he opens something that matters to him.
const THOUGHTS := {
	"chat:vera": "Пять лет я открываю этот чат каждую ночь. Как будто она вот-вот ответит.",
	"chat:sergey": "Олег. Опять Олег. Как тогда.",
	"news:mira": "Девятнадцать лет. Дело ведёт Олег Ремезов. Конечно, ведёт.",
	"note:case_v": "«С курсом». Я так и не узнал, с каким.",
	"note:badge": "Этот день я помню лучше, чем свой день рождения.",
	"vm:vm_sergey": "Как с Верой… Серёга, лучше бы ты не звонил.",
	"photo:watch": "Без двенадцати одиннадцать. Время, когда она перестала отвечать.",
}

const DOORBELL := "Звонок в дверь."
const OPEN_DOOR := "Открыть"
const HALLWAY_VOICE := [
	"Без четверти полночь. Гостей я не жду. Друзей у меня не осталось.",
	"На лестнице никого. Только коробка на коврике.",
	"Внутри — чужой телефон. И записка.",
]
const NOTE_TEXT := "Лучшему детективу этого города.\n\nНайди её.\nПолиции не звони — они уже испортили одно твоё дело.\n\nP.S. Код — день, когда ты перестал быть детективом."
const AFTER_NOTE := "«Одно твоё дело». Кто бы это ни написал — он знает про Веру."
const WRONG_CODE := "Не то. Думай, Лев. Тот день ты помнишь лучше любого другого."

const CHAPTER := "ГЛАВА 1"
const CHAPTER_NAME := "Посылка"
const UNLOCKED_VOICE := "Открылся. Значит, тот, кто прислал телефон, знает обо мне больше, чем мне хотелось бы."
const TO_BE_CONTINUED := "Продолжение следует"
