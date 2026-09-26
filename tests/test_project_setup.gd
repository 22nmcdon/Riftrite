extends GutTest
## Guards the pinned toolchain. If this fails, the engine version changed;
## upgrade on purpose (see "Pinned versions" in CLAUDE.md), then update this test.


func test_engine_is_pinned_version() -> void:
	var info: Dictionary = Engine.get_version_info()
	assert_eq(info["major"], 4, "Godot major version")
	assert_eq(info["minor"], 7, "Godot minor version")
	assert_eq(info["patch"], 2, "Godot patch version")


## The same pinned version everywhere Godot is installed: the cloud-session
## hook and the GitHub workflows (CLAUDE.md, "Pinned versions").
func test_every_install_pins_the_same_version() -> void:
	var files: Array[String] = [".claude/hooks/session-start.sh", ".github/workflows/tests.yml", ".github/workflows/playtest-build.yml"]
	var patterns: Array[String] = ['GODOT_VERSION="4.7.2"', 'GODOT_VERSION: "4.7.2"', 'GODOT_VERSION: "4.7.2"']
	for i: int in files.size():
		var text: String = FileAccess.get_file_as_string("res://" + files[i])
		assert_true(text.contains(patterns[i]), "%s pins %s" % [files[i], patterns[i]])
