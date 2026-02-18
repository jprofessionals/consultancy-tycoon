extends PanelContainer

signal close_requested

var _name_edit: LineEdit
var _name_save_btn: Button
var _passphrase_label: Label
var _status_label: Label
var _leaderboard_toggle: CheckButton
var _username_edit: LineEdit
var _password_edit: LineEdit
var _register_btn: Button

func _ready():
	custom_minimum_size = Vector2(450, 500)
	add_theme_stylebox_override("panel", UITheme.create_panel_style())
	_build_ui()
	refresh()

func _build_ui():
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.NORMAL)
	add_child(vbox)

	# Header row: title + close button
	var header = HBoxContainer.new()
	vbox.add_child(header)

	var title = Label.new()
	title.text = "CLOUD PROFILE"
	title.add_theme_font_size_override("font_size", UITheme.TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = UITheme.create_close_button()
	close_btn.pressed.connect(func(): close_requested.emit())
	header.add_child(close_btn)

	# ── Display Name ──
	var name_section = Label.new()
	name_section.text = "Display Name"
	name_section.add_theme_font_size_override("font_size", UITheme.BODY)
	name_section.add_theme_color_override("font_color", UITheme.TEXT_SECONDARY)
	vbox.add_child(name_section)

	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", UITheme.NORMAL)
	vbox.add_child(name_row)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Your name..."
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_font_size_override("font_size", UITheme.BODY)
	name_row.add_child(_name_edit)

	_name_save_btn = Button.new()
	_name_save_btn.text = "Save"
	UITheme.style_button(_name_save_btn)
	_name_save_btn.pressed.connect(_on_save_name)
	name_row.add_child(_name_save_btn)

	# ── Recovery Passphrase ──
	var pass_section = Label.new()
	pass_section.text = "Recovery Passphrase"
	pass_section.add_theme_font_size_override("font_size", UITheme.BODY)
	pass_section.add_theme_color_override("font_color", UITheme.TEXT_SECONDARY)
	vbox.add_child(pass_section)

	_passphrase_label = Label.new()
	_passphrase_label.text = "Not connected"
	_passphrase_label.add_theme_font_size_override("font_size", UITheme.BODY)
	_passphrase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_passphrase_label)

	# ── Status ──
	_status_label = Label.new()
	_status_label.text = "Offline"
	_status_label.add_theme_font_size_override("font_size", UITheme.SMALL)
	_status_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	vbox.add_child(_status_label)

	# ── Leaderboard Toggle ──
	_leaderboard_toggle = CheckButton.new()
	_leaderboard_toggle.text = "Show on leaderboard"
	_leaderboard_toggle.add_theme_font_size_override("font_size", UITheme.BODY)
	_leaderboard_toggle.toggled.connect(_on_leaderboard_toggled)
	vbox.add_child(_leaderboard_toggle)

	# ── Separator ──
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", UITheme.RELAXED)
	vbox.add_child(sep)

	# ── Account Upgrade ──
	var upgrade_title = Label.new()
	upgrade_title.text = "Create Account (Optional)"
	upgrade_title.add_theme_font_size_override("font_size", UITheme.BODY)
	upgrade_title.add_theme_color_override("font_color", UITheme.TEXT_SECONDARY)
	vbox.add_child(upgrade_title)

	var upgrade_desc = Label.new()
	upgrade_desc.text = "Add a username and password for easier recovery."
	upgrade_desc.add_theme_font_size_override("font_size", UITheme.SMALL)
	upgrade_desc.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	upgrade_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(upgrade_desc)

	_username_edit = LineEdit.new()
	_username_edit.placeholder_text = "Username"
	_username_edit.add_theme_font_size_override("font_size", UITheme.BODY)
	vbox.add_child(_username_edit)

	_password_edit = LineEdit.new()
	_password_edit.placeholder_text = "Password"
	_password_edit.secret = true
	_password_edit.add_theme_font_size_override("font_size", UITheme.BODY)
	vbox.add_child(_password_edit)

	_register_btn = Button.new()
	_register_btn.text = "Create Account"
	UITheme.style_button(_register_btn)
	_register_btn.pressed.connect(_on_register)
	vbox.add_child(_register_btn)

func refresh():
	# Display name
	_name_edit.text = GameState.player_name

	# Passphrase
	if CloudManager.is_authenticated() and CloudManager.passphrase != "":
		_passphrase_label.text = CloudManager.passphrase
	else:
		_passphrase_label.text = "Not connected"

	# Status
	if CloudManager.is_authenticated():
		_status_label.text = "Connected (ID: %s)" % CloudManager.player_id.left(8)
		_status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	else:
		_status_label.text = "Offline"
		_status_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)

	# Leaderboard toggle
	_leaderboard_toggle.set_pressed_no_signal(true)

func _on_save_name():
	var new_name = _name_edit.text.strip_edges()
	if new_name == "":
		return
	GameState.player_name = new_name
	CloudManager.update_display_name(new_name)
	_status_label.text = "Name saved"
	_status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))

func _on_leaderboard_toggled(pressed: bool):
	CloudManager.set_leaderboard_visibility(pressed)

func _on_register():
	var username = _username_edit.text.strip_edges()
	var password = _password_edit.text
	if username == "" or password == "":
		_status_label.text = "Username and password required"
		_status_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		return
	_register_btn.disabled = true
	_register_btn.text = "Creating..."
	var success = await CloudManager.register_account(username, password)
	_register_btn.disabled = false
	_register_btn.text = "Create Account"
	if success:
		_status_label.text = "Account created!"
		_status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		_username_edit.text = ""
		_password_edit.text = ""
	else:
		_status_label.text = "Registration failed. Try a different username."
		_status_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
