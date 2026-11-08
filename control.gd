extends Control

const BASE = "http://127.0.0.1:8000"
const PLOT_SIZE = Vector2(160, 140)

@onready var plots_grid = $VBoxContainer/Plots
@onready var inv_label = $VBoxContainer/InventoryLabel

# Fallback look if a sprite file is missing
const STAGE_STYLE = {
	"empty":    {"h": 0,  "color": Color.TRANSPARENT},
	"seedling": {"h": 20, "color": Color("6bbf59")},
	"growing":  {"h": 45, "color": Color("3f9e3f")},
	"ready":    {"h": 70, "color": Color("e8c53a")},
}

func _ready():
	$RefreshTimer.timeout.connect(refresh)
	refresh()

# One temporary HTTPRequest per call
func api(method, path, callback = null):
	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(
		func(_r, code, _h, body):
			req.queue_free()
			if callback:
				callback.call(code, JSON.parse_string(body.get_string_from_utf8()))
	)
	req.request(BASE + path, ["Content-Type: application/json"], method, "")

func refresh():
	api(HTTPClient.METHOD_GET, "/plots", _draw_plots)
	api(HTTPClient.METHOD_GET, "/inventory", _draw_inventory)

func _draw_plots(code, plots):
	if code != 200: return
	for child in plots_grid.get_children():
		child.queue_free()
	for p in plots:
		plots_grid.add_child(make_plot(p))

func _draw_inventory(code, items):
	if code != 200: return
	var t = "Inventory: "
	for i in items:
		t += "%s x%d  " % [i["name"], i["quantity"]]
	inv_label.text = t

func make_plot(p) -> Control:
	var holder = Control.new()
	holder.custom_minimum_size = PLOT_SIZE

	# Soil
	var soil = ColorRect.new()
	soil.color = Color("6b4423")
	soil.size = PLOT_SIZE
	holder.add_child(soil)

	# Crop: sprite if the file exists, otherwise a colored bar
	var stage = p["stage"]
	var path = "res://sprites/%s.png" % stage
	if stage != "empty":
		if ResourceLoader.exists(path):
			var tex = TextureRect.new()
			tex.texture = load(path)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tex.size = Vector2(100, 100)
			tex.position = Vector2(30, 20)
			holder.add_child(tex)
		else:
			var style = STAGE_STYLE[stage]
			var crop = ColorRect.new()
			crop.color = style["color"]
			crop.size = Vector2(24, style["h"])
			crop.position = Vector2(PLOT_SIZE.x / 2 - 12, PLOT_SIZE.y - 20 - style["h"])
			holder.add_child(crop)

	# Text label
	var label = Label.new()
	var crop_name = p["crop_name"] if p["crop_name"] != null else "Empty"
	label.text = "%s\n%s" % [crop_name, stage]
	label.position = Vector2(6, 4)
	holder.add_child(label)

	# Invisible button over the whole square so it's clickable
	var btn = Button.new()
	btn.flat = true
	btn.size = PLOT_SIZE
	btn.pressed.connect(_on_plot_pressed.bind(p["plot_id"], stage))
	holder.add_child(btn)

	return holder

func _on_plot_pressed(plot_id, stage):
	if stage == "empty":
		api(HTTPClient.METHOD_POST, "/plots/%d/plant/1" % plot_id, func(_c, _b): refresh())
	elif stage == "ready":
		api(HTTPClient.METHOD_POST, "/plots/%d/harvest" % plot_id, func(_c, _b): refresh())
