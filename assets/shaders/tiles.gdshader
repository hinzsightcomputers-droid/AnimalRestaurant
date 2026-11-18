// Glazed tiles for a kitchen backsplash: cream tiles with soft warm grout, each
// tile a touch lighter or darker than the next, glossy so the lamps catch them
// (the style guide's cream walls). UV2-free: the tile grid comes from the
// mesh's own size, so a longer wall just gets more tiles.
shader_type spatial;

uniform vec3 tile_color : source_color = vec3(0.98, 0.88, 0.7);
uniform vec3 grout_color : source_color = vec3(0.86, 0.74, 0.6);
uniform float tile_size = 0.17;   // Meters.
uniform float grout = 0.03;       // Share of a tile that's grout.

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.31, 289.17))) * 15731.743);
}

void fragment() {
	vec2 grid = vec2(local_pos.x, local_pos.y) / tile_size;
	grid.x += floor(grid.y) * 0.5;  // Brick bond, every other row half a tile over.
	vec2 cell = fract(grid);
	vec2 edge = min(cell, 1.0 - cell);
	float line = 1.0 - smoothstep(grout * 0.5, grout, min(edge.x, edge.y));
	float shade = (hash(floor(grid)) - 0.5) * 0.08;
	vec3 tile = tile_color * (1.0 + shade);
	ALBEDO = mix(tile, grout_color, line);
	ROUGHNESS = mix(0.25, 0.8, line);
	SPECULAR = 0.6;
}
