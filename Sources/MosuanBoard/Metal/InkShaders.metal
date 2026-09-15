#include <metal_stdlib>
using namespace metal;

struct InkVertex {
    float2 position;
    float4 color;
};

struct Uniforms {
    float2 viewportSize;
};

struct RasterVertex {
    float4 position [[position]];
    float4 color;
};

vertex RasterVertex inkVertex(const device InkVertex *vertices [[buffer(0)]],
                              constant Uniforms &uniforms [[buffer(1)]],
                              uint vertexID [[vertex_id]]) {
    InkVertex input = vertices[vertexID];
    float2 ndc = (input.position / uniforms.viewportSize) * 2.0 - 1.0;
    ndc.y = -ndc.y;

    RasterVertex output;
    output.position = float4(ndc, 0.0, 1.0);
    output.color = input.color;
    return output;
}

fragment float4 inkFragment(RasterVertex input [[stage_in]]) {
    return input.color;
}
