extends Control

signal monitor_clicked
signal phone_clicked
signal books_clicked
signal email_clicked
signal laptop_clicked
signal door_clicked

@onready var email_badge: Button = %EmailBadge
@onready var phone_glow: ColorRect = %PhoneGlow
@onready var _monitor_btn: Button = %MonitorBtn

# Monitor area for zoom calculation
var monitor_rect: Rect2
var _is_zoomed: bool = false

func _ready():
	# Compute monitor_rect from the MonitorBtn node position/size
	monitor_rect = Rect2(_monitor_btn.position, _monitor_btn.size)

	# Connect button signals
	_monitor_btn.pressed.connect(func(): monitor_clicked.emit())
	%PhoneBtn.pressed.connect(func(): phone_clicked.emit())
	%BooksBtn.pressed.connect(func(): books_clicked.emit())
	email_badge.pressed.connect(func(): email_clicked.emit())
	%LaptopBtn.pressed.connect(func(): laptop_clicked.emit())
	%DoorBtn.pressed.connect(func(): door_clicked.emit())

func set_email_badge_count(n: int):
	if n <= 0:
		email_badge.visible = false
	else:
		email_badge.visible = true
		email_badge.text = str(n)

func set_phone_glowing(on: bool):
	phone_glow.visible = on

func zoom_to_monitor() -> Tween:
	_is_zoomed = true
	# Calculate zoom so monitor fills viewport
	var viewport_size = get_viewport_rect().size
	var monitor_center = monitor_rect.position + monitor_rect.size / 2.0
	var target_scale = 2.5
	pivot_offset = monitor_center
	var target_pos = position + (viewport_size / 2.0 - monitor_center) * target_scale + monitor_center - monitor_center * target_scale

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2(target_scale, target_scale), 0.3)
	tween.parallel().tween_property(self, "position", target_pos, 0.3)
	return tween

func zoom_to_desk() -> Tween:
	_is_zoomed = false
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3)
	tween.parallel().tween_property(self, "position", Vector2.ZERO, 0.3)
	return tween
