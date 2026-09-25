extends GutHookScript
## GUT post-run hook: fail the run if the pre-run hook found scripts that
## don't compile (see tools/gut_pre_run.gd).


func run() -> void:
	var pre_run: GutHookScript = gut.get_pre_run_script_instance()
	if pre_run != null and not pre_run.get("broken").is_empty():
		gut.logger.error("%d script(s) failed to compile; failing the run." % pre_run.get("broken").size())
		set_exit_code(1)
