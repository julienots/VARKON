extends Control
## Shop: daily offers, chests, equipment, cosmetics, event items (war tokens), season pass link,
## free daily reward. Real-money products are not configured in this build and cannot be bought.

var section := "daily"
var body: VBoxContainer

const SECTIONS := ["daily", "chests", "weapons", "armors", "accessories", "auras", "cosmetics", "event", "crystals", "pass"]
const SECTION_COLORS := {
	"daily": Color("#ff9f1a"), "chests": Color("#e8b21f"), "weapons": Color("#ef4a3a"), "armors": Color("#3d8ef0"),
	"accessories": Color("#9b5cf5"), "auras": Color("#1fbfb0"), "cosmetics": Color("#f0509a"), "event": Color("#d0552a"),
	"crystals": Color("#2fb5ff"), "pass": Color("#7a4fe0"),
}


func setup(p: Dictionary) -> void:
	section = str(p.get("section", "daily"))
	UIScreen.background(self, Color("#c23a8a"))
	var root := UIScreen.frame(self, tr("MENU_SHOP"), null, true, ["gold", "crystals", "war_tokens"])
	var h := UI.hbox(14)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(h)
	var side := UI.vbox(7)
	var sc := UI.scroll(side)
	sc.custom_minimum_size.x = 214
	sc.size_flags_horizontal = Control.SIZE_FILL
	h.add_child(sc)
	set_meta("side", side)
	body = UI.vbox(12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(body)
	EventBus.resources_changed.connect(_refresh)
	_refresh()


func _set_section(s: String) -> void:
	section = s
	Audio.play_sfx("ui_open")
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var side: VBoxContainer = get_meta("side")
	UIScreen.clear(side)
	for s in SECTIONS:
		var col: Color = SECTION_COLORS[s]
		var b := UI.button(tr("SHOP_" + s.to_upper()), _set_section.bind(s), "secondary", 200, 50)
		b.add_theme_font_size_override("font_size", int(18 * UI.ts()))
		b.add_theme_stylebox_override("normal", UI.candy(col if s == section else col.darkened(0.18)))
		b.add_theme_stylebox_override("hover", UI.candy(col.lightened(0.1)))
		b.add_theme_stylebox_override("pressed", UI.candy(col, true))
		if s == section:
			b.custom_minimum_size.x = 210
		side.add_child(b)
	UIScreen.clear(body)
	var col2: Color = SECTION_COLORS[section]
	var head := UI.hbox(12)
	var rib := UI.ribbon(tr("SHOP_" + section.to_upper()), col2, 26)
	rib.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(rib)
	if section == "daily":
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", UI.box(Color("#14193a"), Color.WHITE, 20, 2, 14))
		pill.add_child(UI.label(tr("LBL_DAILY_RESET") % UI.time_fmt(_seconds_to_midnight()), 17, Color.WHITE, "bold"))
		head.add_child(pill)
	body.add_child(head)
	match section:
		"daily":
			_free_daily()
			_offer_grid(Game.shop.daily_offers())
		"pass":
			_pass_card()
		"crystals":
			var warn := PanelContainer.new()
			warn.add_theme_stylebox_override("panel", UI.tile(Color("#e0503a"), 12))
			warn.add_child(UI.para(tr("DESC_IAP_DISABLED"), 17, Color.WHITE))
			body.add_child(warn)
			_offer_grid(_section_offers("crystals"))
		_:
			_offer_grid(_section_offers(section))


func _seconds_to_midnight() -> float:
	var t := Time.get_time_dict_from_system()
	return 86400.0 - (int(t.hour) * 3600 + int(t.minute) * 60 + int(t.second))


func _section_offers(sid: String) -> Array:
	for s in DB.economy.shop.sections:
		if s.id == sid:
			return s.offers
	return []


func _free_daily() -> void:
	var avail: bool = Game.shop.free_daily_available()
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.tile(Color("#3fbf2f") if avail else Color("#5a6a8a"), 14))
	var h := UI.hbox(16)
	var icon := ChestIcon.make(Color(DB.chests[str(DB.economy.shop.free_daily.chest)].color), 76)
	h.add_child(icon)
	var v := UI.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.title(tr("LBL_FREE_DAILY"), 24))
	var rw: Array = []
	for k in DB.economy.shop.free_daily.keys():
		rw.append(DB.any_name(str(DB.economy.shop.free_daily[k])) if k == "chest" else "%d %s" % [int(DB.economy.shop.free_daily[k]), DB.resource_name(k)])
	v.add_child(UI.label(" + ".join(rw), 17, Color.WHITE, "bold"))
	h.add_child(v)
	var b := UI.button(tr("BTN_CLAIM") if avail else tr("LBL_CLAIMED"), func() -> void:
		var e: Array = Game.shop.claim_free_daily()
		UI.show_rewards(e)
		_refresh(), "primary", 190, 60)
	b.disabled = not avail
	h.add_child(b)
	card.add_child(h)
	body.add_child(card)
	if avail and not Settings.get_v("limit_animations"):
		icon.pivot_offset = Vector2(38, 38)
		var tw := icon.create_tween().set_loops()
		tw.tween_property(icon, "rotation", 0.08, 0.25)
		tw.tween_property(icon, "rotation", -0.08, 0.25)
		tw.tween_property(icon, "rotation", 0.0, 0.2)
		tw.tween_interval(1.2)


func _pass_card() -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.tile(Color("#7a4fe0"), 18))
	var v := UI.vbox(10)
	v.add_child(UI.title(DB.txt(DB.season), 30))
	v.add_child(UI.para(tr("DESC_PASS_SHOP") % int(DB.season.premium_price.crystals), 18, Color.WHITE))
	var go := UI.button(tr("MENU_PASS"), func() -> void: Router.goto("pass"), "primary", 260, 62)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(go)
	card.add_child(v)
	body.add_child(card)


func _offer_grid(offers: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for o in offers:
		grid.add_child(_offer_card(o))
	body.add_child(UI.scroll(grid))


func _offer_info(o: Dictionary) -> Dictionary:
	## name, rarity, desc, picture entry for any offer type
	var ref := str(o.get("ref", ""))
	match str(o.kind):
		"item":
			var d: Dictionary = DB.items[ref]
			return {"name": DB.txt(d), "rarity": d.rarity, "desc": DB.txt(d, "desc"), "slot": DB.slot_name(d.slot), "cosmetic": d.get("cosmetic", false), "pic": {"type": "item", "id": ref}}
		"chest":
			var c: Dictionary = DB.chests[ref]
			return {"name": DB.txt(c), "rarity": c.rarity, "desc": DB.txt(c, "desc"), "pic": {"type": "chest", "id": ref}}
		"cosmetic":
			var cd: Dictionary = DB.cosmetics[ref]
			return {"name": DB.txt(cd), "rarity": cd.rarity, "desc": tr("COSKIND_" + str(cd.kind).to_upper()), "pic": {"type": "cosmetic", "id": ref}}
		"material":
			var md: Dictionary = DB.materials[ref]
			return {"name": DB.txt(md), "rarity": md.rarity, "desc": DB.txt(md, "desc"), "pic": {"type": "material", "id": ref}}
		"resource":
			return {"name": "%d %s" % [int(o.amount), DB.resource_name(ref)], "rarity": "rare", "desc": DB.txt(DB.resources[ref], "desc"), "pic": {"type": "resource", "id": ref}}
		"card_copies":
			var cc: Dictionary = DB.cards[ref]
			return {"name": "%s x%d" % [DB.txt(cc), int(o.amount)], "rarity": cc.rarity, "desc": DB.txt(cc, "desc"), "pic": {"type": "card", "id": ref}}
		"iap":
			return {"name": "%d %s" % [int(o.amount), DB.resource_name("crystals")], "rarity": "rare", "desc": tr("DESC_IAP_ITEM"), "pic": {"type": "resource", "id": "crystals"}}
	return {"name": "?", "rarity": "common", "desc": "", "pic": {}}


func _offer_card(o: Dictionary) -> Control:
	var info := _offer_info(o)
	var rcol := DB.rarity_color(info.rarity)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.tile(rcol.darkened(0.05), 10))
	p.custom_minimum_size = Vector2(300, 300)
	var v := UI.vbox(4)
	p.add_child(v)
	var top := UI.hbox(6)
	top.add_child(UI.rarity_badge(info.rarity, 12))
	top.add_child(UI.spacer())
	if info.get("cosmetic", false):
		top.add_child(UI.label(tr("LBL_COSMETIC"), 13, Color.WHITE, "bold"))
	elif info.has("slot"):
		top.add_child(UI.label(str(info.slot), 13, Color.WHITE, "bold"))
	v.add_child(top)
	# Spotlight with the picture
	var spot := CenterContainer.new()
	spot.custom_minimum_size = Vector2(0, 118)
	var glow := Panel.new()
	glow.custom_minimum_size = Vector2(112, 112)
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(1, 1, 1, 0.28)
	gsb.set_corner_radius_all(56)
	glow.add_theme_stylebox_override("panel", gsb)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spot.add_child(glow)
	var pic: Control = CardView.make(str(info.pic.id), Vector2(80, 106)) if info.pic.get("type", "") == "card" else UI.reward_icon(info.pic, 100)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spot.add_child(pic)
	v.add_child(spot)
	if o.kind == "card_copies" or o.kind == "resource":
		var qty := UI.label("x%d" % int(o.amount), 22, Color.WHITE, "display")
		qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.add_child(qty)
	var nl := UI.label(str(info.name), 19, Color.WHITE, "display")
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.add_theme_constant_override("outline_size", 6)
	v.add_child(nl)
	var dl := UI.para(str(info.desc), 13, Color(1, 1, 1, 0.9))
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dl.max_lines_visible = 2
	v.add_child(dl)
	if o.has("limit") and not o.get("daily", false):
		var ll := UI.label(tr("LBL_LIMIT") % [Game.shop.purchased(o.id), int(o.limit)], 13, Color.WHITE)
		ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(ll)
	var row := UI.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if o.kind == "item":
		var ref: String = o.ref
		row.add_child(UI.icon_button("info", _preview.bind(ref), 52, tr("BTN_PREVIEW")))
	var why: String = Game.shop.availability(o)
	if o.kind == "iap":
		var na := UI.button(tr("LBL_IAP_PRICE_NA"), func() -> void: Router.error("ERR_IAP_UNAVAILABLE"), "grey", 200, 52)
		row.add_child(na)
	elif why in ["ERR_SOLD_OUT", "ERR_ALREADY_OWNED"]:
		var so := UI.button(tr(why), func() -> void: pass, "grey", 200, 52)
		so.disabled = true
		row.add_child(so)
	else:
		var pb := UI.price_button(o.price, _buy.bind(o), 190, 52)
		row.add_child(pb)
	v.add_child(row)
	return p


func _buy(o: Dictionary) -> void:
	var why: String = Game.shop.availability(o)
	if why != "":
		Router.error(why)
		return
	var info := _offer_info(o)
	Router.confirm_spend(tr("CONFIRM_BUY") % str(info.name), o.price, func() -> void:
		var e: Array = Game.shop.buy(o.id)
		if e.is_empty():
			Router.error(Game.shop.availability(o) if Game.shop.availability(o) != "" else "ERR_PURCHASE")
		else:
			Audio.play_sfx("coin")
			UI.show_rewards(e, tr("LBL_PURCHASED"))
		_refresh())


func _preview(item_id: String) -> void:
	var d: Dictionary = DB.items[item_id]
	var p := UI.panel_box()
	p.custom_minimum_size = Vector2(520, 560)
	var v := UI.vbox(8)
	p.add_child(v)
	v.add_child(UI.title(DB.txt(d), 26))
	var kp := KingPreview.new()
	kp.override_visuals = {d.slot: d.visual.duplicate()}
	kp.custom_minimum_size = Vector2(480, 400)
	v.add_child(kp)
	var stats: Array = []
	for k in d.stats.keys():
		stats.append("%s %+d" % [tr("ST_" + str(k).to_upper()), int(d.stats[k])])
	v.add_child(UI.para(", ".join(stats) if not stats.is_empty() else tr("LBL_COSMETIC_ONLY"), 16, UI.TEXT))
	v.add_child(UI.button(tr("BTN_CLOSE"), Router.close_popup, "secondary", 160))
	Router.popup(p)
