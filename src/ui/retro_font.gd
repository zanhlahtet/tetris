class_name RetroFont
extends RefCounted
## The bundled pixel font (Pixelify Sans, SIL OFL; see assets/fonts/OFL.txt).
## Controls get the regular weight through the project's default theme font;
## drawn text and emphasised labels use `bold()`.

const PATH := "res://assets/fonts/PixelifySans.ttf"

static var _bold: FontVariation = null


static func regular() -> Font:
	return load(PATH) as Font


static func bold() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = regular()
		_bold.variation_opentype = {&"wght": 700}
	return _bold
