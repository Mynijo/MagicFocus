class_name FocusStore
extends RefCounted
## Gespeicherte Foki des Spielers: JSON-Dateien mit IDs in user://foci/
## (Format siehe FocusInstance.to_dict). Genutzt von Werkstatt und Arena.

const SAVE_DIR := "user://foci/"
const EXTENSION := ".json"


## Namen aller gespeicherten Foki (ohne Endung), alphabetisch.
static func list_names() -> PackedStringArray:
	var names := PackedStringArray()
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		return names
	for file in DirAccess.get_files_at(SAVE_DIR):
		if file.ends_with(EXTENSION):
			names.append(file.get_basename())
	names.sort()
	return names


static func path_for(focus_name: String) -> String:
	return SAVE_DIR + focus_name + EXTENSION


## Gibt OK oder den Fehlercode zurück.
static func save(focus: FocusInstance, focus_name: String) -> Error:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(path_for(focus_name), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(focus.to_dict(), "\t"))
	file.close()
	return OK


## Lädt einen Fokus; Probleme stehen in `warnings`. null, wenn er nicht geladen werden kann.
static func load_focus(focus_name: String, content: CraftingContent, warnings: Array[String]) -> FocusInstance:
	var path := path_for(focus_name)
	if not FileAccess.file_exists(path):
		warnings.append("Fokus „%s“ nicht gefunden." % focus_name)
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		warnings.append("Die Datei von „%s“ ist beschädigt." % focus_name)
		return null
	return FocusInstance.from_dict(data, content, warnings)


static func delete(focus_name: String) -> Error:
	return DirAccess.remove_absolute(path_for(focus_name))
