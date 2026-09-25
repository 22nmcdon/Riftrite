extends GutTest
## Guards the pinned toolchain. If this fails, the engine version changed;
## upgrade on purpose (see "Pinned versions" in CLAUDE.md), then update this test.


func test_engine_is_pinned_version() -> void:
	var info: Dictionary = Engine.get_version_info()
	assert_eq(info["major"], 4, "Godot major version")
	assert_eq(info["minor"], 7, "Godot minor version")
	assert_eq(info["patch"], 2, "Godot patch version")
