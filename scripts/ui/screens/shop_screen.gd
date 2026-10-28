extends Control
## Shop: daily offers, chests, equipment, cosmetics, event items (war tokens), season pass link,
## free daily reward. Real-money products are not configured in this build and cannot be bought.

var section := "daily"
var body: VBoxContainer

const SECTIONS := ["daily", "chests", "weapons", "armors", "accessories", "auras", "cosmetics", "event", "crystals", "pass"]


func setup(p: Dictionary) -> void:
	section = str(p.get("section", "daily"))
	UIScreen.background(self, Color("#16110c"))
	var root := UIScreen.frame(self, tr("MENU_SHOP"), null, true, ["gold", "crystals", "war_tokens"])
	var h := UI.hbox(12)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(h)
	var side := UI.vbox(6)
	for s in SECTIONS:
		side.add_child(UI.button(tr("SHOP_" + s.to_upper()), _set_section.bind(s), "secondary", 200, 46))
	var sc := UI.scroll(side)
	sc.custom_minimum_size.x = 210
	sc.size_flags_horizontal = Control.SIZE_FILL
	h.add_child(sc)
	set_meta("side", side)
	var panel := UI.panel_box()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body = UI.vbox(10)
	panel.add_child(body)
	h.add_child(panel)
	EventBus.resources_changed.connect(_refresh)
	_refresh()


func _set_section(s: String) -> void:
	section = s
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var side: VBoxContainer = get_meta("side")
	for i in SECTIONS.size():
		var b: Button = side.get_child(i)
		b.add_theme_color_override("font_color", UI.GOLD if SECTIONS[i] == section else UI.TEXT)
	UIScreen.clear(body)
	body.add_child(UI.title(tr("SHOP_" + section.to_upper()), 26))
	match section:
		"daily":
			_free_daily()
			body.add_child(UI.label(tr("LBL_DAILY_RESET") % UI.time_fmt(_seconds_to_midnight()), 15, UI.TEXT_DIM))
			_offer_grid(Game.shop.daily_offers())
		"pass":
			body.add_child(UI.para(tr("DESC_PASS_SHOP") % int(DB.season.premium_price.crystals), 17))
			body.add_child(UI.button(tr("MENU_PASS"), func() -> void: Router.goto("pass"), "primary", 240))
		"crystals":
			body.add_child(UI.para(tr("DESC_IAP_DISABLED"), 17, Color("#ff8a70")))
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
	var row := UI.panel_box(Color("#1f2a16"), UI.GREEN)
	var h := UI.hbox(10)
	var l := UI.label(tr("LBL_FREE_DAILY"), 18, UI.GREEN, "bold")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var b := UI.button(tr("BTN_CLAIM") if Game.shop.free_daily_available() else tr("LBL_CLAIMED"), func() -> void:
		var e: Array = Game.shop.claim_free_daily()
		UI.show_rewards(e)
		_refresh(), "green", 180, 46)
	b.disabled = not Game.shop.free_daily_available()
	h.add_child(b)
	row.add_child(h)
	body.add_child(row)


func _offer_grid(offers: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for o in offers:
		grid.add_child(_offer_card(o))
	body.add_child(UI.scroll(grid))


func _offer_info(o: Dictionary) -> Dictionary:
	## name, rarity, desc, origin for any offer type
	var ref := str(o.get("ref", ""))
	match str(o.kind):
		"item":
			var d: Dictionary = DB.items[ref]
			return {"name": DB.txt(d), "rarity": d.rarity, "desc": DB.txt(d, "desc"), "slot": DB.slot_name(d.slot), "cosmetic": d.get("cosmetic", false)}
		"chest":
			var c: Dictionary = DB.chests[ref]
			return {"name": DB.txt(c), "rarity": c.rarity, "desc": DB.txt(c, "desc")}
		"cosmetic":
			var cd: Dictionary = DB.cosmetics[ref]
			return {"name": DB.txt(cd), "rarity": cd.rarity, "desc": tr("COSKIND_" + str(cd.kind).to_upper())}
		"material":
			var md: Dictionary = DB.materials[ref]
			return {"name": DB.txt(md), "rarity": md.rarity, "desc": DB.txt(md, "desc")}
		"resource":
			return {"name": "%d %s" % [int(o.amount), DB.resource_name(ref)], "rarity": "common", "desc": DB.txt(DB.resources[ref], "desc")}
		"card_copies":
			var cc: Dictionary = DB.cards[ref]
			return {"name": "%s x%d" % [DB.txt(cc), int(o.amount)], "rarity": cc.rarity, "desc": DB.txt(cc, "desc")}
		"iap":
			return {"name": "%d %s" % [int(o.amount), DB.resource_name("crystals")], "rarity": "rare", "desc": tr("DESC_IAP_ITEM")}
	return {"name": "?", "rarity": "common", "desc": ""}


func _offer_card(o: Dictionary) -> Control:
	var info := _offer_info(o)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color("#221a13"), DB.rarity_color(info.rarity), 12, 2, 12))
	p.custom_minimum_size = Vector2(300, 220)
	var v := UI.vbox(6)
	p.add_child(v)
	v.add_child(UI.label(str(info.name), 18, DB.rarity_color(info.rarity), "bold"))
	var tags := UI.hbox(6)
	tags.add_child(UI.rarity_badge(info.rarity, 12))
	if info.has("slot"):
		tags.add_child(UI.label(str(info.slot), 13, UI.TEXT_DIM))
	if info.get("cosmetic", false):
		tags.add_child(UI.label(tr("LBL_COSMETIC"), 13, Color("#9ad7ff")))
	v.add_child(tags)
	var dl := UI.para(str(info.desc), 14)
	dl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(dl)
	if o.has("limit") and not o.get("daily", false):
		v.add_child(UI.label(tr("LBL_LIMIT") % [Game.shop.purchased(o.id), int(o.limit)], 13, UI.TEXT_DIM))
	var h := UI.hbox(8)
	if o.kind == "iap":
		h.add_child(UI.label(tr("LBL_IAP_PRICE_NA"), 15, UI.TEXT_DIM, "bold"))
	else:
		h.add_child(UI.cost_row(o.price, 17))
	h.add_child(UI.spacer())
	if o.kind == "item":
		var ref: String = o.ref
		h.add_child(UI.button(tr("BTN_PREVIEW"), _preview.bind(ref), "secondary", 100, 42))
	var why: String = Game.shop.availability(o)
	var b := UI.button(tr("BTN_BUY") if why != "ERR_SOLD_OUT" and why != "ERR_ALREADY_OWNED" else tr(why), _buy.bind(o), "primary", 110, 42)
	b.disabled = why != ""
	h.add_child(b)
	v.add_child(h)
	if why == "ERR_IAP_UNAVAILABLE":
		v.add_child(UI.label(tr("ERR_IAP_UNAVAILABLE"), 13, Color("#ff8a70")))
	return p


func _buy(o: Dictionary) -> void:
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
	v.add_child(UI.title(DB.txt(d), 24))
	var kp := KingPreview.new()
	kp.override_visuals = {d.slot: d.visual.duplicate()}
	kp.custom_minimum_size = Vector2(480, 400)
	v.add_child(kp)
	var stats: Array = []
	for k in d.stats.keys():
		stats.append("%s %+d" % [tr("ST_" + str(k).to_upper()), int(d.stats[k])])
	v.add_child(UI.para(", ".join(stats) if not stats.is_empty() else tr("LBL_COSMETIC_ONLY"), 15, UI.TEXT))
	v.add_child(UI.button(tr("BTN_CLOSE"), Router.close_popup, "secondary", 160))
	Router.popup(p)
