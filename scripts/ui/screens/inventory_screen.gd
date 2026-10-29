extends Control
## Central inventory: cards, equipment, cosmetics, materials, chests, resources with filters
## (type, rarity, family, slot, equipped) and detail sheets including origin.

var f_kind := ""
var f_rarity := ""
var f_family := ""
var f_equipped := false
var f_sort := "rarity"
var grid: GridContainer


func setup(_p: Dictionary) -> void:
	UIScreen.background(self, Color("#5a52c8"))
	var root := UIScreen.frame(self, tr("MENU_INVENTORY"))
	var filters := UI.hbox(8)
	root.add_child(filters)
	set_meta("filters", filters)
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	root.add_child(UI.scroll(grid))
	EventBus.inventory_changed.connect(_refresh)
	_refresh()


func _option(items: Array, current: String, cb: Callable, w := 190) -> OptionButton:
	var o := OptionButton.new()
	for i in items.size():
		o.add_item(str(items[i][1]))
		o.set_item_metadata(i, items[i][0])
		if items[i][0] == current:
			o.select(i)
	o.item_selected.connect(func(i: int) -> void: cb.call(str(o.get_item_metadata(i))))
	o.custom_minimum_size = Vector2(w, 46)
	return o


func _refresh() -> void:
	if not is_inside_tree():
		return
	var filters: HBoxContainer = get_meta("filters")
	UIScreen.clear(filters)
	var kinds := [["", tr("FILTER_ALL_TYPES")], ["item", tr("INV_ITEMS")], ["card", tr("INV_CARDS")], ["cosmetic", tr("INV_COSMETICS")],
		["material", tr("INV_MATERIALS")], ["chest", tr("INV_CHESTS")], ["resource", tr("INV_RESOURCES")]]
	filters.add_child(_option(kinds, f_kind, func(v: String) -> void:
		f_kind = v
		_refresh()))
	var rars := [["", tr("FILTER_ALL_RARITIES")]]
	for r in DB.RARITY_ORDER:
		rars.append([r, DB.rarity_name(r)])
	filters.add_child(_option(rars, f_rarity, func(v: String) -> void:
		f_rarity = v
		_refresh()))
	var fams := [["", tr("FILTER_ALL_FAMILIES")]]
	for f in DB.families.keys():
		fams.append([f, DB.family_name(f)])
	filters.add_child(_option(fams, f_family, func(v: String) -> void:
		f_family = v
		_refresh()))
	filters.add_child(_option([["rarity", tr("SORT_RARITY")], ["level", tr("SORT_LEVEL")], ["name", tr("SORT_NAME")], ["count", tr("SORT_COUNT")]], f_sort, func(v: String) -> void:
		f_sort = v
		_refresh(), 170))
	var eq := CheckButton.new()
	eq.text = tr("FILTER_EQUIPPED")
	eq.button_pressed = f_equipped
	eq.toggled.connect(func(v: bool) -> void:
		f_equipped = v
		_refresh())
	filters.add_child(eq)
	UIScreen.clear(grid)
	var entries: Array = Game.inventory.all_entries()
	var shown: Array = []
	for e in entries:
		if f_kind != "" and e.kind != f_kind:
			continue
		if f_rarity != "" and e.rarity != f_rarity:
			continue
		if f_family != "" and e.get("family", "") != f_family:
			continue
		if f_equipped and not e.equipped:
			continue
		shown.append(e)
	shown.sort_custom(func(a, b):
		match f_sort:
			"level": return int(a.get("level", 0)) > int(b.get("level", 0))
			"name": return str(a.name) < str(b.name)
			"count": return int(a.count) > int(b.count)
		return DB.rarity_rank(a.rarity) > DB.rarity_rank(b.rarity))
	for e in shown:
		grid.add_child(_cell(e))
	if shown.is_empty():
		grid.add_child(UI.label(tr("LBL_NONE"), 18, UI.TEXT_DIM))


func _cell(e: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color("#2a4482"), DB.rarity_color(e.rarity), 10, 2, 10))
	p.custom_minimum_size = Vector2(290, 92)
	var v := UI.vbox(2)
	p.add_child(v)
	v.add_child(UI.label(str(e.name), 17, DB.rarity_color(e.rarity) if e.kind != "resource" else Color.WHITE, "bold"))
	var sub := tr("INVK_" + str(e.kind).to_upper())
	if e.has("slot"):
		sub += " · " + DB.slot_name(e.slot)
	if e.has("family"):
		sub += " · " + DB.family_name(e.family)
	if e.has("level") and e.kind in ["card", "item"]:
		sub += " · " + tr("LBL_LEVEL") % int(e.level)
	v.add_child(UI.label(sub, 13, UI.TEXT_DIM))
	var h := UI.hbox(6)
	h.add_child(UI.label("x%d" % int(e.count) if e.kind != "resource" else UI.fmt(int(e.count)), 15, Color.WHITE, "bold"))
	if e.equipped:
		h.add_child(UI.label(tr("LBL_EQUIPPED") if e.kind == "item" else tr("LBL_IN_DECK"), 13, UI.GOLD, "bold"))
	v.add_child(h)
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.pressed.connect(func() -> void:
		if Router.drag_dist < 18:
			_detail(e))
	p.add_child(btn)
	return p


func _detail(e: Dictionary) -> void:
	var p := UI.panel_box()
	p.custom_minimum_size = Vector2(600, 0)
	var v := UI.vbox(8)
	p.add_child(v)
	v.add_child(UI.title(str(e.name), 26))
	v.add_child(UI.rarity_badge(e.rarity))
	var desc := ""
	var sources: Array = []
	match str(e.kind):
		"item":
			var d: Dictionary = DB.items[e.id]
			desc = DB.txt(d, "desc")
			sources = d.sources
			var stats: Array = []
			for k in d.stats.keys():
				stats.append("%s %+d" % [tr("ST_" + str(k).to_upper()), int(d.stats[k])])
			if not stats.is_empty():
				v.add_child(UI.label(", ".join(stats), 16, Color("#9ad7ff")))
		"card":
			desc = DB.txt(DB.cards[e.id], "desc")
			sources = ["chest", "shop", "campaign"]
		"cosmetic":
			desc = tr("COSKIND_" + str(DB.cosmetics[e.id].kind).to_upper())
			sources = DB.cosmetics[e.id].sources
		"material":
			desc = DB.txt(DB.materials[e.id], "desc")
			sources = DB.materials[e.id].sources
		"chest":
			desc = DB.txt(DB.chests[e.id], "desc")
			sources = ["campaign", "shop", "pass", "mission"]
		"resource":
			desc = DB.txt(DB.resources[e.id], "desc")
	v.add_child(UI.para(desc, 17, UI.TEXT))
	if not sources.is_empty():
		v.add_child(UI.label(tr("LBL_ORIGIN") + " : " + ", ".join(sources.map(func(x): return tr("SRC_" + str(x).to_upper()))), 15, UI.TEXT_DIM))
	var h := UI.hbox(10)
	match str(e.kind):
		"item":
			h.add_child(UI.button(tr("MENU_KING"), func() -> void:
				Router.close_popup()
				Router.goto("king"), "primary", 200))
		"card":
			h.add_child(UI.button(tr("MENU_COLLECTION"), func() -> void:
				Router.close_popup()
				Router.goto("collection"), "primary", 200))
		"chest":
			h.add_child(UI.button(tr("MENU_CHESTS"), func() -> void:
				Router.close_popup()
				Router.goto("chests"), "primary", 200))
	h.add_child(UI.button(tr("BTN_CLOSE"), Router.close_popup, "secondary", 160))
	v.add_child(h)
	Router.popup(p)
