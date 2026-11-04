// Glowing seam of the pixel dissolve (see dissolve.gdshader).
shader_type canvas_item;
render_mode unshaded;

#define SEAM
#include "res://shaders/fx/dissolve.gdshaderinc"
