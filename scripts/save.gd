extends RefCounted
## Checkpoints, so the player never has to watch the prologue again.
## One small file in user:// (in the browser it lives in the site's storage).

const PATH := "user://save.cfg"
## Checkpoints in story order, with the name shown on "Continue".
const NAMES := {
	"lev_phone": "Пролог · телефон Льва",
	"mira_locked": "Пролог · посылка",
	"chapter_one": "Глава 1 · Посылка",
}


static func store(checkpoint: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "checkpoint", checkpoint)
	cfg.save(PATH)


## The last checkpoint reached, or "" for a new game.
static func load_checkpoint() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return ""
	var c: String = cfg.get_value("game", "checkpoint", "")
	return c if NAMES.has(c) else ""


static func clear() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
