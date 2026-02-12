class_name UITheme
extends RefCounted

# Panel / card backgrounds
const PANEL_BG = Color(0.12, 0.12, 0.16)
const CARD_BG = Color(0.16, 0.16, 0.2)
const BORDER = Color(0.3, 0.3, 0.35)
const HUD_BG = Color(0.08, 0.08, 0.12, 0.85)

# Text colors
const TEXT_SECONDARY = Color(0.7, 0.7, 0.7)
const TEXT_MUTED = Color(0.5, 0.5, 0.55)

# Button colors
const BTN_NORMAL = Color(0.22, 0.24, 0.28)
const BTN_HOVER = Color(0.28, 0.3, 0.34)
const BTN_PRESSED = Color(0.18, 0.2, 0.24)

# Font sizes
const TITLE = 18
const BODY = 14
const SMALL = 12
const TINY = 10

# Spacing
const TIGHT = 4
const NORMAL = 8
const RELAXED = 12
const WIDE = 16


static func create_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_content_margin_all(WIDE)
	style.set_corner_radius_all(8)
	style.border_color = BORDER
	style.set_border_width_all(1)
	return style


static func create_card_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.set_content_margin_all(10)
	style.set_corner_radius_all(4)
	return style


static func create_button_style(color: Color = BTN_NORMAL) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.set_corner_radius_all(4)
	return style


static func style_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", create_button_style(BTN_NORMAL))
	btn.add_theme_stylebox_override("hover", create_button_style(BTN_HOVER))
	btn.add_theme_stylebox_override("pressed", create_button_style(BTN_PRESSED))


static func create_close_button() -> Button:
	var btn = Button.new()
	btn.text = "X"
	btn.custom_minimum_size = Vector2(32, 32)
	style_button(btn)
	return btn
