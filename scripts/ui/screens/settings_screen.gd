extends Control
## Settings. Every option is persisted in user://settings.cfg and read by a system.

var tab := "graphics"
var body: VBoxContainer


func setup(p: Dictionary) -> void:
	tab = str(p.get("tab", "graphics"))
	UIScreen.background(self, Color("#3a5fa8"))
	var root := UIScreen.frame(self, tr("MENU_SETTINGS"), null, false)
	var th := UI.hbox()
	root.add_child(th)
	set_meta("tabs", th)
	var panel := UI.panel_box()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body = UI.vbox(10)
	panel.add_child(UI.scroll(body))
	root.add_child(panel)
	_refresh()


func _set_tab(t: String) -> void:
	tab = t
	_refresh()


func _refresh() -> void:
	var th: HBoxContainer = get_meta("tabs")
	UIScreen.clear(th)
	UIScreen.tabs(th, ["graphics", "audio", "controls", "access", "gameplay", "notifs", "account"], tab, _set_tab).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIScreen.clear(body)
	match tab:
		"graphics":
			_choice("SET_QUALITY", "quality", [[0, "Q_LOW"], [1, "Q_MEDIUM"], [2, "Q_HIGH"]])
			_toggle("SET_SHADOWS", "shadows")
			_toggle("SET_PARTICLES", "particles")
			_toggle("SET_EFFECTS", "effects")
			_choice("SET_FPS", "fps_limit", [[30, "30 FPS"], [60, "60 FPS"]])
			_toggle("SET_BATTERY", "battery_saver")
			body.add_child(UI.para(tr("NOTE_GRAPHICS"), 14))
		"audio":
			_slider("SET_VOL_MASTER", "vol_master")
			_slider("SET_VOL_MUSIC", "vol_music")
			_slider("SET_VOL_SFX", "vol_sfx")
			_slider("SET_VOL_VOICE", "vol_voice")
			_toggle("SET_VIBRATION", "vibration")
		"controls":
			_choice("SET_BUTTON_SIZE", "button_scale", [[0.85, "SIZE_SMALL"], [1.0, "SIZE_NORMAL"], [1.2, "SIZE_LARGE"]])
			_toggle("SET_LEFT_HANDED", "hud_left_handed")
			_toggle("SET_CONFIRM_IMPORTANT", "confirm_important")
		"access":
			_choice("SET_TEXT_SIZE", "text_scale", [[0.9, "SIZE_SMALL"], [1.0, "SIZE_NORMAL"], [1.15, "SIZE_LARGE"], [1.3, "SIZE_XL"]])
			_toggle("SET_CONTRAST", "high_contrast")
			_toggle("SET_REDUCE_FLASH", "reduce_flashes")
			_toggle("SET_REDUCE_SHAKE", "reduce_shake")
			_toggle("SET_LIMIT_ANIM", "limit_animations")
			_toggle("SET_SOUND_INDICATORS", "sound_indicators")
		"gameplay":
			_choice("SET_LANGUAGE", "language", [["fr", "Français"], ["en", "English"]])
			_toggle("SET_TUTORIALS", "tutorials")
			_toggle("SET_DAMAGE_NUMBERS", "damage_numbers")
			_toggle("SET_RANGE", "range_indicators")
			_toggle("SET_CONFIRM_SPEND", "confirm_spend")
		"notifs":
			_toggle("SET_NOTIF_REWARDS", "notif_rewards")
			_toggle("SET_NOTIF_EVENTS", "notif_events")
			_toggle("SET_NOTIF_PROGRESS", "notif_progress")
			body.add_child(UI.para(tr("NOTE_NOTIFICATIONS"), 15, Color("#9ad7ff")))
		"account":
			_account()
	if tab != "account":
		body.add_child(UI.button(tr("BTN_RESET_SETTINGS"), func() -> void:
			Router.confirm(tr("CONFIRM_RESET_SETTINGS"), func() -> void:
				Settings.reset_defaults()
				_apply_ui_change()), "secondary", 300))


func _row(label_key: String) -> HBoxContainer:
	var h := UI.hbox(12)
	var l := UI.label(tr(label_key), 19)
	l.custom_minimum_size.x = 420
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	body.add_child(h)
	return h


func _toggle(label_key: String, key: String) -> void:
	var h := _row(label_key)
	var c := CheckButton.new()
	c.button_pressed = bool(Settings.get_v(key))
	c.toggled.connect(func(v: bool) -> void:
		Settings.set_v(key, v)
		if key in ["high_contrast"]:
			_apply_ui_change())
	h.add_child(c)


func _slider(label_key: String, key: String) -> void:
	var h := _row(label_key)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 1
	s.step = 0.05
	s.value = float(Settings.get_v(key))
	s.custom_minimum_size = Vector2(320, 40)
	var pct := UI.label("%d%%" % int(s.value * 100), 17, UI.GOLD, "bold")
	s.value_changed.connect(func(v: float) -> void:
		Settings.set_v(key, v)
		pct.text = "%d%%" % int(v * 100)
		if key == "vol_sfx":
			Audio.play_sfx("ui_click"))
	h.add_child(s)
	h.add_child(pct)


func _choice(label_key: String, key: String, opts: Array) -> void:
	var h := _row(label_key)
	var cur = Settings.get_v(key)
	for o in opts:
		var val = o[0]
		var selected: bool = str(cur) == str(val) or (typeof(cur) in [TYPE_FLOAT, TYPE_INT] and typeof(val) in [TYPE_FLOAT, TYPE_INT] and absf(float(cur) - float(val)) < 0.001)
		var b := UI.button(tr(o[1]), func() -> void:
			Settings.set_v(key, val)
			if key in ["text_scale", "button_scale", "language"]:
				_apply_ui_change()
			else:
				_refresh(), "primary" if selected else "secondary", 130, 46)
		h.add_child(b)


func _apply_ui_change() -> void:
	UI.rebuild_theme()
	Router.goto("settings", {"tab": tab}, false)


func _account() -> void:
	body.add_child(UI.label(tr("LBL_PROFILE"), 20, UI.GOLD, "title"))
	var h := _row("SET_PLAYER_NAME")
	var le := LineEdit.new()
	le.text = str(Game.state.profile.name)
	le.max_length = 16
	le.custom_minimum_size = Vector2(260, 46)
	h.add_child(le)
	h.add_child(UI.button(tr("BTN_SAVE"), func() -> void:
		var n := le.text.strip_edges()
		if n.length() < 2:
			Router.error("ERR_NAME")
			return
		Game.state.profile.name = n
		Game.save_now()
		EventBus.profile_changed.emit()
		EventBus.notify(tr("TOAST_SAVED"), "success"), "secondary", 140, 46))
	body.add_child(UIScreen.stat_row(tr("LBL_PLAYER_LEVEL"), str(Game.level())))
	body.add_child(UIScreen.stat_row(tr("LBL_CREATED"), Time.get_date_string_from_unix_time(int(Game.state.profile.created))))
	body.add_child(UIScreen.stat_row(tr("LBL_VERSION"), str(ProjectSettings.get_setting("application/config/version")) + "  (save v%d)" % SaveSys.CURRENT_VERSION))
	body.add_child(UIScreen.stat_row(tr("LBL_SAVE_MODE"), tr("LBL_SAVE_LOCAL")))
	body.add_child(UI.para(tr("NOTE_SAVE_LOCAL"), 14))
	var row := UI.hbox(10)
	row.add_child(UI.button(tr("BTN_SAVE_NOW"), func() -> void:
		Game.save_now()
		EventBus.notify(tr("TOAST_SAVED"), "success"), "secondary", 220, 48))
	row.add_child(UI.button(tr("BTN_RESET_PROFILE"), func() -> void:
		Router.confirm(tr("CONFIRM_RESET_PROFILE"), func() -> void:
			Router.confirm(tr("CONFIRM_RESET_PROFILE_2"), func() -> void:
				Game.reset_profile()
				Router.home(), tr("BTN_DELETE"), true), tr("BTN_CONTINUE"), true), "danger", 260, 48))
	body.add_child(row)
	body.add_child(UI.label(tr("LBL_LEGAL"), 20, UI.GOLD, "title"))
	var lr := UI.hbox(8)
	for doc in ["privacy", "terms", "purchases", "conduct", "minors", "credits"]:
		lr.add_child(UI.button(tr("DOC_" + doc.to_upper()), func() -> void: Router.goto("legal", {"doc": doc}), "secondary", 0, 46))
	body.add_child(lr)
	body.add_child(UI.para(tr("NOTE_ONLINE_ACCOUNT"), 14))
