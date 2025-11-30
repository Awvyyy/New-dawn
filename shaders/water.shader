shader_type spatial;
render_mode specular_schlick_ggx, cull_disabled;

uniform vec4 deep_color : source_color = vec4(0.027, 0.121, 0.243, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.117, 0.513, 0.658, 1.0);
uniform float wave_speed = 1.2;
uniform float wave_height = 0.25;
uniform float foam_threshold = 0.65;
uniform float tiling = 3.5;

void vertex() {
    float wave_a = sin((UV.x * tiling + TIME * wave_speed) * 1.4);
    float wave_b = cos((UV.y * tiling - TIME * wave_speed) * 1.7);
    float ripple = sin((UV.x + UV.y) * tiling * 0.5 + TIME * wave_speed * 0.8);
    float displacement = (wave_a + wave_b + ripple) / 3.0;
    VERTEX.y += displacement * wave_height;
    NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
}

void fragment() {
    float flow = sin(UV.y * tiling * 0.5 + TIME * wave_speed * 0.6) * 0.5 + 0.5;
    float depth_mix = clamp(UV.y * 0.15 + 0.4, 0.0, 1.0);
    vec3 water_color = mix(deep_color.rgb, shallow_color.rgb, depth_mix + flow * 0.1);

    float foam = smoothstep(foam_threshold - 0.1, foam_threshold + 0.05, flow);
    ALBEDO = water_color;
    METALLIC = 0.02;
    ROUGHNESS = 0.08 + foam * 0.1;
    EMISSION = mix(water_color * 0.2, vec3(1.0), foam * 0.4);
    SPECULAR = 0.9;
}
