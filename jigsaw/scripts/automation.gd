class_name JigsawCutter
extends RefCounted

const EDGE_FLAT = 0
const EDGE_TAB = 1
const EDGE_BLANK = 2

@export var tab_size: float = 32
@export var edge_segments: int = 36  # Controls flat-edge smoothness; geometric tabs use ~1/4 of this per section

func cut_image(texture: Texture2D, rows: int, cols: int) -> Array[shardData]:
	var result: Array[shardData] = []
	var img_w = float(texture.get_width())
	var img_h = float(texture.get_height())
	var piece_w = img_w / cols
	var piece_h = img_h / rows

	# 1. Generate edge patterns (now stores Dictionaries so neighboring pieces share exact parameters)
	var bottom_edges: Array[Array] = []
	var right_edges: Array[Array] = []

	for r in rows:
		bottom_edges.append([])
		right_edges.append([])
		for c in cols:
			bottom_edges[r].append({"type": EDGE_FLAT} if r == rows - 1 else _random_edge_data())
			right_edges[r].append({"type": EDGE_FLAT} if c == cols - 1 else _random_edge_data())

	# 2. Build each piece
	for r in rows:
		for c in cols:
			var data := shardData.new()
			data.grid_pos = Vector2i(c, r)
			data.piece_size = Vector2(piece_w, piece_h)

			var nominal_x = c * piece_w
			var nominal_y = r * piece_h

			# Determine this piece's 4 edge types
			var top_edge = {"type": EDGE_FLAT} if r == 0 else _inverse_edge(bottom_edges[r - 1][c])
			var right_edge = right_edges[r][c]
			var bottom_edge = bottom_edges[r][c]
			var left_edge = {"type": EDGE_FLAT} if c == 0 else _inverse_edge(right_edges[r][c - 1])

			data.is_edge = (top_edge.type == EDGE_FLAT or bottom_edge.type == EDGE_FLAT or 
							left_edge.type == EDGE_FLAT or right_edge.type == EDGE_FLAT)

			# Generate polygon & UVs
			var poly = PackedVector2Array()
			var uv = PackedVector2Array()

			var add_edge = func(p0: Vector2, p1: Vector2, edge_data: Dictionary, outward: Vector2):
				var pts = _generate_edge(p0, p1, edge_data, outward)
				for p in pts:
					poly.append(p)
					uv.append(Vector2(nominal_x + p.x, nominal_y + p.y))

			var tl = Vector2(0, 0)
			var tr = Vector2(piece_w, 0)
			var br = Vector2(piece_w, piece_h)
			var bl = Vector2(0, piece_h)

			# Top (left → right)
			add_edge.call(tl, tr, top_edge, Vector2(0, -1))
			
			# Right (top → bottom) — skip first corner (already added)
			var r_pts = _generate_edge(tr, br, right_edge, Vector2(1, 0))
			for i in range(1, r_pts.size()):
				poly.append(r_pts[i])
				uv.append(Vector2(nominal_x + r_pts[i].x, nominal_y + r_pts[i].y))
				
			# Bottom (right → left)
			var b_pts = _generate_edge(br, bl, bottom_edge, Vector2(0, 1))
			for i in range(1, b_pts.size()):
				poly.append(b_pts[i])
				uv.append(Vector2(nominal_x + b_pts[i].x, nominal_y + b_pts[i].y))
				
			# Left (bottom → top)
			var l_pts = _generate_edge(bl, tl, left_edge, Vector2(-1, 0))
			for i in range(1, l_pts.size()):
				poly.append(l_pts[i])
				uv.append(Vector2(nominal_x + l_pts[i].x, nominal_y + l_pts[i].y))

			# Center polygon around centroid so rotation feels natural
			var centroid = _centroid(poly)
			for i in poly.size():
				poly[i] -= centroid
			
			data.polygon = poly
			data.uv = uv
			data.centroid = centroid 
			result.append(data)

	return result

func _random_edge_data() -> Dictionary:
	return {
		"type": EDGE_TAB if randf() > 0.5 else EDGE_BLANK,
		"peak_t": randf_range(0.4, 0.6) # Safely jitter the tab slightly off-center
	}

# Properly mirrors the geometry so opposing cuts align perfectly
func _inverse_edge(edge: Dictionary) -> Dictionary:
	if edge.type == EDGE_FLAT: return {"type": EDGE_FLAT}
	
	var inv_type = EDGE_BLANK if edge.type == EDGE_TAB else EDGE_TAB
	return {
		"type": inv_type,
		"peak_t": 1.0 - edge.peak_t # Invert peak offset because edge is drawn in opposite direction
	}

# Generates points along one edge with geometric jigsaw profile
func _generate_edge(start: Vector2, end: Vector2, edge_data: Dictionary, outward: Vector2) -> PackedVector2Array:
	var pts = PackedVector2Array()
	var vec = end - start
	var type = edge_data.type
	
	if type == EDGE_FLAT:
		for i in edge_segments + 1:
			var t = float(i) / edge_segments
			pts.append(start + vec * t)
		return pts
	
	# --- GEOMETRIC TRIANGULAR TAB / BLANK ---
	var margin = 0          # Fix: Tab takes up the middle 30% of the edge
	var peak_t = edge_data.peak_t  # Fix: Use the shared, mirrored offset
	var segs = max(2, edge_segments / 4)
	
	# Fix: Invert the outward direction if this is a BLANK (so it cuts into the piece)
	var actual_outward = outward if type == EDGE_TAB else -outward
	
	# Key vertices of the triangular profile
	var base_start = start + vec * margin
	var peak = start + vec * peak_t + actual_outward * tab_size
	var base_end = end - vec * margin
	
	# Section 1: flat margin (start → base_start)
	for i in segs + 1:
		var t = float(i) / segs
		pts.append(start.lerp(base_start, t))
	
	# Section 2: rising leg (base_start → peak)
	for i in range(1, segs + 1):
		var t = float(i) / segs
		pts.append(base_start.lerp(peak, t))
	
	# Section 3: falling leg (peak → base_end)
	for i in range(1, segs + 1):
		var t = float(i) / segs
		pts.append(peak.lerp(base_end, t))
	
	# Section 4: flat margin (base_end → end)
	for i in range(1, segs + 1):
		var t = float(i) / segs
		pts.append(base_end.lerp(end, t))
	
	return pts

func _centroid(poly: PackedVector2Array) -> Vector2:
	var c = Vector2.ZERO
	for p in poly:
		c += p
	return c / poly.size()
