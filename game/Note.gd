extends Spatial
class_name Note

# strucutre of information sourced from the map file for this note instance
# https://bsmg.wiki/mapping/map-format.html#notes-2
var _note;

# the note's velocity toward the player
# currently set to _noteJumpMovementSpeed / 9.0 in main game. I'm not sure what
# the 9.0 is for...
# units: meters / second
var speed = 1.0;
