class_name Balance
extends RefCounted
## Änderungen aus dem Editor: nur abweichende Einträge als JSON in user://balance.json,
## beim Start über die Inhalte gelegt (Gravuren, Gem-Formen, Foki, Kampfregeln).
## Die Inhalte selbst (content/, vom Generator erzeugt) bleiben unverändert.
##
## Ablauf: Jede Szene ruft `ensure_applied()`. Beim ersten Aufruf werden die Standardwerte
## gemerkt, die Datei angewendet und die Begriffe neu gebaut. Der Editor ändert die
## Ressourcen direkt und ruft danach `save()`; `reset(key)` stellt den Standard wieder her.
## Schlüssel: "engraving/<id>", "gem/<id>", "focus/<id>", "rules".

const CONTENT_PATH := "res://content/crafting_content.tres"
const RULES_PATH := "res://content/combat_rules.tres"
const GEM_FIELDS := ["radius", "max_base", "max_element", "body_radius"]
const FOCUS_FIELDS := ["max_gems", "max_dots", "max_element_dots"]
const ENGRAVING_FIELDS := ["note", "target", "transfer_to_main", "radius_factor", "inner_radius_factor",
	"inner_multiplier", "max_size"]

## Datei mit den Änderungen (Tests setzen einen eigenen Pfad).
static var path := "user://balance.json"
## Schlüssel -> Standardwerte (wie `serialize`)
static var _defaults := {}
static var _applied := false


static func content() -> CraftingContent:
	return load(CONTENT_PATH)


static func rules() -> CombatRules:
	return load(RULES_PATH)


## Einmal pro Programmlauf: Standardwerte merken, Änderungen anwenden, Begriffe bauen.
static func ensure_applied() -> void:
	if _applied:
		return
	_applied = true
	var c := content()
	var r := rules()
	for key: String in keys(c):
		_defaults[key] = serialize(resource_for(key, c, r))
	var data := _read()
	for key: String in data:
		var target := resource_for(key, c, r)
		if target != null and data[key] is Dictionary:
			deserialize(target, data[key])
	GlossaryBuilder.build(c, r)


## Alle bearbeitbaren Einträge.
static func keys(c: CraftingContent) -> PackedStringArray:
	var result := PackedStringArray(["rules"])
	for e in c.engravings:
		result.append("engraving/" + e.id)
	for g in c.gems:
		result.append("gem/" + g.id)
	for f in c.foci:
		result.append("focus/" + f.id)
	return result


static func resource_for(key: String, c: CraftingContent, r: CombatRules) -> Resource:
	var id := StringName(key.get_slice("/", 1))
	match key.get_slice("/", 0):
		"rules":
			return r
		"engraving":
			return c.get_engraving(id)
		"gem":
			return c.get_gem(id)
		"focus":
			return c.get_focus(id)
	return null


## Weicht der Eintrag vom Standard ab?
static func is_changed(key: String) -> bool:
	var target := resource_for(key, content(), rules())
	return _defaults.has(key) and target != null and \
		JSON.stringify(serialize(target)) != JSON.stringify(_defaults[key])


## Schreibt alle abweichenden Einträge und baut die Begriffe neu.
static func save() -> Error:
	var c := content()
	var r := rules()
	var data := {}
	for key: String in keys(c):
		if is_changed(key):
			data[key] = serialize(resource_for(key, c, r))
	GlossaryBuilder.build(c, r)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	return OK


## Stellt den Standard eines Eintrags wieder her und speichert.
static func reset(key: String) -> void:
	var target := resource_for(key, content(), rules())
	if target != null and _defaults.has(key):
		deserialize(target, _defaults[key])
	save()


# --- Umwandlung ----------------------------------------------------------------

## Bearbeitbare Werte einer Ressource als JSON-taugliches Dictionary.
static func serialize(resource: Resource) -> Dictionary:
	if resource is EngravingDef:
		return _serialize_engraving(resource)
	if resource is GemDef:
		return _fields(resource, GEM_FIELDS)
	if resource is FocusDef:
		var data := _fields(resource, FOCUS_FIELDS)
		data["allowed_elements"] = Array(resource.allowed_elements).map(func(id: StringName) -> String: return String(id))
		data["shape"] = _fields(resource.shape, number_fields(resource.shape))
		return data
	if resource is CombatRules:
		return _fields(resource, number_fields(resource))
	return {}


static func deserialize(resource: Resource, data: Dictionary) -> void:
	if resource is EngravingDef:
		_deserialize_engraving(resource, data)
	elif resource is FocusDef:
		_set_fields(resource, data, FOCUS_FIELDS)
		var allowed: Array[StringName] = []
		for id in data.get("allowed_elements", []):
			allowed.append(StringName(id))
		resource.allowed_elements = allowed
		_set_fields(resource.shape, data.get("shape", {}), number_fields(resource.shape))
	elif resource is GemDef:
		_set_fields(resource, data, GEM_FIELDS)
	elif resource is CombatRules:
		_set_fields(resource, data, number_fields(resource))


## Namen aller Zahlen-Eigenschaften aus dem Skript (Kampfregeln, Fokus-Formen).
static func number_fields(object: Object) -> PackedStringArray:
	var names := PackedStringArray()
	for property in object.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.type in [TYPE_FLOAT, TYPE_INT]:
			names.append(property.name)
	return names


static func _serialize_engraving(e: EngravingDef) -> Dictionary:
	var data := _fields(e, ENGRAVING_FIELDS)
	data["element_factors"] = _string_keys(e.element_factors)
	data["base_stats"] = _string_keys(e.base_stats)
	var rule_list := []
	for rule in e.rules:
		rule_list.append({ source = rule.source, element = String(rule.element_id), per_n = rule.per_n,
			stat = String(rule.stat), amount = rule.amount, min_count = rule.min_count, cap = rule.cap })
	data["rules"] = rule_list
	return data


static func _deserialize_engraving(e: EngravingDef, data: Dictionary) -> void:
	_set_fields(e, data, ENGRAVING_FIELDS)
	e.element_factors = _name_keys(data.get("element_factors", {}))
	e.base_stats = _name_keys(data.get("base_stats", {}))
	var rule_list: Array[ScalingRule] = []
	for entry: Dictionary in data.get("rules", []):
		var rule := ScalingRule.new()
		rule.source = int(entry.get("source", ScalingRule.Source.POINTS))
		rule.element_id = StringName(entry.get("element", ""))
		rule.per_n = int(entry.get("per_n", 1))
		rule.stat = StringName(entry.get("stat", "damage"))
		rule.amount = float(entry.get("amount", 1.0))
		rule.min_count = int(entry.get("min_count", 0))
		rule.cap = float(entry.get("cap", 0.0))
		rule_list.append(rule)
	e.rules = rule_list


static func _fields(object: Object, names: Array) -> Dictionary:
	var data := {}
	for field: String in names:
		data[field] = object.get(field)
	return data


## Setzt die Felder aus `data`; Zahlen bekommen den Typ des Feldes (JSON kennt nur float).
static func _set_fields(object: Object, data: Dictionary, names: Array) -> void:
	for field: String in names:
		if not data.has(field):
			continue
		var current: Variant = object.get(field)
		var value: Variant = data[field]
		if current is int:
			value = int(value)
		elif current is float:
			value = float(value)
		elif current is bool:
			value = bool(value)
		object.set(field, value)


static func _string_keys(values: Dictionary) -> Dictionary:
	var out := {}
	for key in values:
		out[String(key)] = float(values[key])
	return out


static func _name_keys(values: Dictionary) -> Dictionary:
	var out := {}
	for key in values:
		out[StringName(key)] = float(values[key])
	return out


static func _read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}
