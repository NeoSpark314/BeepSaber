shader_type spatial;

varying vec3 object_pos;
uniform sampler2D viewport;

void vertex() {
	object_pos = VERTEX * 2.0 + vec3(0.5);
}

void fragment() {
	vec3 a = min(object_pos, vec3(1.0) - object_pos);
	
	float u = min(min(a.x, a.y), a.z);
	u = smoothstep(u, 0.05, 1.0);
	ALBEDO = texture(viewport,UV).rgb;
	EMISSION = vec3(u);
}