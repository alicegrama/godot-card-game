shader_type canvas_item;

uniform vec2 spotlight_pos = vec2(0.5, 0.5);
uniform float spotlight_radius = 0.15;
uniform float softness = 0.02;

void fragment() {
	vec2 uv = UV;

	// Correct for aspect ratio
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 diff = uv - spotlight_pos;
	diff.x *= aspect;

	float dist = length(diff);
	float alpha = smoothstep(spotlight_radius, spotlight_radius + softness, dist);

	vec4 col = COLOR;
	col.a *= alpha;
	COLOR = col;
}
