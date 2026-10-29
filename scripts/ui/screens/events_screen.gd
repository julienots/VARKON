extends Control
## Weekly events. This build is offline: events rotate locally from the device calendar
## and are labelled as local challenges (no online event service exists).


func setup(_p: Dictionary) -> void:
	UIScreen.background(self, Color("#d0552a"))
	var root := UIScreen.frame(self, tr("MENU_EVENTS"))
	root.add_child(UI.para(tr("DESC_EVENTS_LOCAL"), 16, Color("#9ad7ff")))
	var ev: Dictionary = Game.campaign.current_event()
	if ev.is_empty():
		root.add_child(UI.label(tr("LBL_NONE"), 18))
		return
	var p := UI.panel_box(Color("#2a4482"), UI.GOLD)
	var v := UI.vbox(8)
	p.add_child(v)
	v.add_child(UI.label(tr("LBL_THIS_WEEK"), 16, UI.TEXT_DIM, "bold"))
	v.add_child(UI.title(DB.txt(ev), 30))
	v.add_child(UI.para(DB.txt(ev, "desc"), 18, UI.TEXT))
	if ev.has("modifiers"):
		v.add_child(UI.label(str(ev.modifiers.get("text", "")), 17, UI.GOLD, "bold"))
	var parts: Array = []
	for k in ev.reward.keys():
		parts.append("%d %s" % [int(ev.reward[k]), DB.resource_name(k)] if DB.resources.has(k) else DB.any_name(str(ev.reward[k])))
	v.add_child(UI.label(tr("LBL_REWARDS") + " : " + ", ".join(parts), 17, UI.GOLD))
	var done: bool = Game.campaign.event_completed_this_week(ev.id)
	if done:
		v.add_child(UI.label(tr("LBL_EVENT_DONE"), 17, UI.GREEN, "bold"))
	var b := UI.button(tr("BTN_FIGHT") if not done else tr("BTN_REPLAY"), func() -> void:
		var cfg: Dictionary = Game.campaign.event_config(ev)
		if not Game.collection.deck_complete() and not cfg.modifiers.get("no_cards", false):
			Router.error("ERR_DECK_INCOMPLETE")
			return
		Router.start_battle(cfg), "big", 260, 60)
	v.add_child(b)
	root.add_child(p)
	root.add_child(UI.label(tr("LBL_ROTATION"), 18, Color.WHITE, "bold"))
	var list := UI.vbox(4)
	var evs: Array = DB.campaign_json.events
	var cur := int(Game.week_key().substr(1))
	for i in range(1, evs.size()):
		var e2: Dictionary = evs[(cur + i) % evs.size()]
		list.add_child(UI.label("%s  —  %s" % [tr("LBL_IN_WEEKS") % i, DB.txt(e2)], 16, UI.TEXT_DIM))
	root.add_child(UI.scroll(list))
