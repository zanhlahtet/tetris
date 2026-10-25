class_name GameSession
extends RefCounted
## Game session/controller. Owns the Board and (from later milestones) the
## active piece, bag, gravity timing, scoring and level. Consumes abstract
## input commands; never touches rendering or input devices.

var board: Board = Board.new()
