// The shared soft toon material (see soft_toon.tres): base color, optional
// texture, soft shading steps, a warm shadow tint. The outline is its next pass
// (soft_toon_outline.gdshader). soft_toon_double.gdshader is the same, seen
// from both sides.
shader_type spatial;

#include "res://assets/shaders/soft_toon_surface.gdshaderinc"
