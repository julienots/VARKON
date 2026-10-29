extends Control
## In-game legal documents (privacy policy, terms, purchases, code of conduct, minors, credits)
## loaded from data/legal.json, which is generated from docs/legal/*.md.


func setup(p: Dictionary) -> void:
	var doc := str(p.get("doc", "privacy"))
	UIScreen.background(self, Color("#3a5fa8"))
	var root := UIScreen.frame(self, tr("DOC_" + doc.to_upper()), null, false)
	var data := {}
	var f := FileAccess.open("res://data/legal.json", FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			data = parsed
	var lang := str(Settings.get_v("language"))
	var text := str(data.get(doc, {}).get(lang, data.get(doc, {}).get("fr", tr("LBL_NONE"))))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.text = text
	rt.fit_content = true
	rt.scroll_active = false
	rt.add_theme_font_size_override("normal_font_size", int(18 * UI.ts()))
	rt.add_theme_font_size_override("bold_font_size", int(20 * UI.ts()))
	rt.add_theme_font_override("bold_font", UI.font("bold"))
	rt.add_theme_color_override("default_color", UI.TEXT)
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel := UI.panel_box()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(UI.scroll(rt))
	root.add_child(panel)
