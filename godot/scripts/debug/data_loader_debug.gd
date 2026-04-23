extends Node

## Debug entry point for DataRegistry.
## Attach this to a small scene and run it from the editor.

func _ready() -> void:
	var registry := DataRegistry.new()
	var ok := registry.load_all_design_data()

	print("[DataLoaderDebug] load_all_design_data() => %s" % ok)
	if not ok:
		print("[DataLoaderDebug] One or more files failed validation. See errors above.")
		return

	# Print a compact summary for quick sanity checks.
	var counts := registry.get_record_counts()
	var keys := counts.keys()
	keys.sort()
	for key in keys:
		print("[DataLoaderDebug] %s: %d" % [key, counts[key]])
