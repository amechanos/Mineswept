extends Node

# ── Config ────────────────────────────────────────────────────────────────────
const IMAGE_FOLDER = "res://tarot/cards/"
const DEFAULT_ROWS = 4
const DEFAULT_COLS = 6

# ── Entry point ───────────────────────────────────────────────────────────────
func load_shard_library() -> void:
	Global.shardLibrary.clear()

	var dir := DirAccess.open(IMAGE_FOLDER)
	if dir == null:
		push_error("ShardLibrary: Cannot open folder: %s" % IMAGE_FOLDER)
		return

	dir.list_dir_begin()
	var filename := dir.get_next()

	while filename != "":
		if not dir.current_is_dir() and _is_image(filename):
			_process_image(IMAGE_FOLDER + filename, filename)
		filename = dir.get_next()

	dir.list_dir_end()
	print("ShardLibrary: loaded %d puzzles." % Global.shardLibrary.size())

# ── Per-image processing ──────────────────────────────────────────────────────
func _process_image(path: String, filename: String) -> void:
	# Load texture
	var texture: Texture2D = load(path)
	if texture == null:
		push_warning("ShardLibrary: Failed to load texture at %s" % path)
		return

	var key = filename.get_basename()

	var rows = 5
	var cols = 3

	var cutter := JigsawCutter.new()
	cutter.tab_size = min(
		float(texture.get_width())  / cols,
		float(texture.get_height()) / rows
	) * 0.18

	var shards: Array[shardData] = cutter.cut_image(texture, rows, cols)

	for shard in shards:
		shard.card = key

	Global.shardLibrary[key] = shards

# ── Helpers ───────────────────────────────────────────────────────────────────
func _is_image(name: String) -> bool:
	var ext := name.get_extension().to_lower()
	return ext in ["png", "jpg", "jpeg", "webp"]
