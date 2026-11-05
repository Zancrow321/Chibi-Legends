// Pixel dissolve for a dying figure (own work, MIT like the project).
// The sprite burns away in chunky art-pixel blocks from the top down; a
// glowing seam (brighter than white, so it blooms) runs along the edge.
// This file is the body (keeps the scene lighting); dissolve_seam.gdshader
// draws only the seam, unshaded on a copy on top, so it glows even at dusk.
shader_type canvas_item;

#include "res://shaders/fx/dissolve.gdshaderinc"
