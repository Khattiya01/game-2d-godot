shader_type canvas_item;

uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float edge_soft : hint_range(0.01, 0.3) = 0.12;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered) * 2.0; // 0 = center, 1 = edge
	// reveal pixels near center first; grows outward as reveal → 1
	float mask = smoothstep(reveal, reveal - edge_soft, dist);
	COLOR = tex;
	COLOR.a = tex.a * mask;
}
