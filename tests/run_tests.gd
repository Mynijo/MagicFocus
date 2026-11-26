extends SceneTree
## Führt alle Tests aus: jede Methode `test_*` jeder Sammlung in tests/suites/.
## Ausführen:  godot --headless --path <projekt> -s res://tests/run_tests.gd
## Exit-Code 0 = alles grün. Auch Skriptfehler während der Tests zählen als Fehler.

const SUITE_DIR := "res://tests/suites/"


## Zählt Fehler der Engine (z. B. Skriptfehler), die sonst nur ausgegeben würden.
class ErrorCounter extends Logger:
	var errors := 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		errors += 1


func _init() -> void:
	var content := load("res://content/crafting_content.tres") as CraftingContent
	var counter := ErrorCounter.new()
	OS.add_logger(counter)
	var checks := 0
	var failures := 0
	var files := Array(DirAccess.get_files_at(SUITE_DIR)).filter(func(f: String) -> bool: return f.ends_with(".gd"))
	files.sort()
	for file: String in files:
		var script := load(SUITE_DIR + file) as GDScript
		if script == null or not script.can_instantiate():
			print("FEHLER: %s lässt sich nicht laden." % file)
			failures += 1
			continue
		var suite: TestSuite = script.new()
		suite.content = content
		suite.tree = self
		for method in suite.get_method_list():
			if String(method.name).begins_with("test_"):
				suite.current = "%s/%s" % [file.get_basename(), method.name]
				suite.call(method.name)
		checks += suite.checks
		failures += suite.failures
	OS.remove_logger(counter)
	if counter.errors > 0:
		print("FEHLER: %d Skript- oder Engine-Fehler während der Tests (siehe oben)." % counter.errors)
	print("\n%d Prüfungen, %d Fehler" % [checks, failures + counter.errors])
	quit(1 if failures + counter.errors > 0 else 0)
