extends RefCounted
## Best score, settings and the round in progress, in one small file.
## In the browser user:// lives in the site's storage.

const PATH := "user://save.cfg"


static func _file() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	return cfg


static func get_value(key: String, default: Variant) -> Variant:
	return _file().get_value("save", key, default)


static func set_value(key: String, value: Variant) -> void:
	var cfg := _file()
	cfg.set_value("save", key, value)
	cfg.save(PATH)
