//-----------------------------------------------------------------------------
// Distort.fx
//
// Microsoft XNA Community Game Platform
// Copyright (C) Microsoft Corporation. All rights reserved.
//-----------------------------------------------------------------------------

#if OPENGL
	#define SV_POSITION POSITION
	#define VS_SHADERMODEL vs_3_0
	#define PS_SHADERMODEL ps_3_0
#else
	#define VS_SHADERMODEL vs_4_0_level_9_1
	#define PS_SHADERMODEL ps_4_0_level_9_1
#endif

Texture2D Texture : register(s0);
sampler SceneTexture : register(s0)
{
    Texture = <Texture>;
};

Texture2D Displacement : register(s1);
sampler DistortionMap : register(s1)
{
    Texture = <Displacement>;
};

#define SAMPLE_COUNT 15
float2 SampleOffsets[SAMPLE_COUNT];
float SampleWeights[SAMPLE_COUNT];

// The Distortion map represents zero displacement as 0.5, but in an 8 bit color
// channel there is no exact value for 0.5. ZeroOffset adjusts for this error.
const float ZeroOffset = 0.5 / 255.0;

struct VertexShaderOutput
{
	float4 Position : SV_POSITION;
	float4 Color : COLOR0;
	float2 TextureCoordinates : TEXCOORD0;
};

float4 Distort_PixelShader(float2 TexCoord : TEXCOORD0, 
    uniform bool distortionBlur) : COLOR0
{
    // Look up the displacement
    float2 displacement = tex2D(DistortionMap, TexCoord).rg;
    
    float4 finalColor = float4(0,0,0,0);
    // We need to constrain the area potentially subjected to the gaussian blur to the
    // distorted parts of the scene texture.  Therefore, we can sample for the color
    // we used to clear the distortion map (black).  We used 0 to avoid any potential
    // rounding errors.
    if ((displacement.x == 0) && (displacement.y == 0))
    {
        finalColor = tex2D(SceneTexture, TexCoord);
    }
    else
    {
        // Convert from [0,1] to [-.5, .5) 
        // .5 is excluded by adjustment for zero
        displacement -= .5 + ZeroOffset;

        if (distortionBlur)
        {
            // Combine a number of weighted displaced-image filter taps
            for (int i = 0; i < SAMPLE_COUNT; i++)
            {
                finalColor += tex2D(SceneTexture, TexCoord.xy + displacement + 
                    SampleOffsets[i]) * SampleWeights[i];
            }
        }
        else
        {
            // Look up the displaced color, without multisampling
            finalColor = tex2D(SceneTexture, TexCoord.xy + displacement);  
        }
    }

    return finalColor;
}

float4 Distort_PixelShaderBlur(VertexShaderOutput input) : COLOR0
{
    return Distort_PixelShader(input.TextureCoordinates, true);
}

float4 Distort_PixelShaderNoBlur(VertexShaderOutput input) : COLOR0
{
    return Distort_PixelShader(input.TextureCoordinates, false);
}

technique Distort
{
    pass
    {
        PixelShader = compile PS_SHADERMODEL Distort_PixelShaderNoBlur();
    }
}

technique DistortBlur
{
    pass
    {
        PixelShader = compile PS_SHADERMODEL Distort_PixelShaderBlur();
    }
};