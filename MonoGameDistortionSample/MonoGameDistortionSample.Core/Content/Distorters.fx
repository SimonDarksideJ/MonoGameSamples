//-----------------------------------------------------------------------------
// Distorters.fx
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

// common parameters
float4x4 WorldViewProjection;
float4x4 WorldView;
float DistortionScale;
float Time;


//-----------------------------------------------------------------------------
//
// Displacement Mapping
//
//-----------------------------------------------------------------------------

struct PositionColorTextured
{
   float4 Position : POSITION;
   float4 Color : COLOR0;
   float2 TexCoord : TEXCOORD;
};

PositionColorTextured TransformAndTexture_VertexShader(PositionColorTextured input)
{
    PositionColorTextured output;
    
    output.Position = mul(input.Position, WorldViewProjection);
    output.Color = input.Color;
    output.TexCoord = input.TexCoord;
    
    return output;
}

texture2D DisplacementMap;
sampler2D DisplacementMapSampler = sampler_state
{
    texture = <DisplacementMap>;
};

float4 Textured_PixelShader(PositionColorTextured input) : COLOR
{
    float4 color = tex2D(DisplacementMapSampler, input.TexCoord);
    
    // Ignore the blue channel    
    return float4(color.rg, 0, color.a);
}

technique DisplacementMapped
{
    pass
    {
        VertexShader = compile VS_SHADERMODEL TransformAndTexture_VertexShader();
        PixelShader = compile PS_SHADERMODEL Textured_PixelShader();
    }
}


//-----------------------------------------------------------------------------
//
// Heat-Haze Displacement
//
//-----------------------------------------------------------------------------

struct PositionPosition
{
    float4 Position : POSITION;
        
    // the pixel shader does not have direct access to the position of the pixel
    // being shaded, so we must pass this information through from the vertex shader
    float4 PositionAsTexCoord : TEXCOORD;
};

PositionPosition TransformAndCopyPosition_VertexShader(PositionColorTextured input)
{
    PositionPosition output;
    
    output.Position = mul(input.Position, WorldViewProjection);
    output.PositionAsTexCoord = output.Position;
    
    return output;
}

float4 HeatHaze_PixelShader(PositionColorTextured input) : COLOR
{
    float2 displacement;
    displacement.x = sin(input.TexCoord.x / 60 + Time * 1.5) * sin(input.TexCoord.x / 10) *
        cos(input.TexCoord.x / 50);
    displacement.y = sin(input.TexCoord.y / 50 - Time * 2.75);
    displacement *= DistortionScale;
    displacement = (displacement + float2(1, 1)) / 2;
    
    return float4(displacement, 0, 1);
}

technique HeatHaze
{
    pass
    {
        VertexShader = compile VS_SHADERMODEL TransformAndCopyPosition_VertexShader();
        PixelShader = compile PS_SHADERMODEL HeatHaze_PixelShader();
    }
}


//-----------------------------------------------------------------------------
//
// Pull-In Displacement
//
//-----------------------------------------------------------------------------

struct PositionNormal
{
   float4 Position : POSITION;
   float3 Normal : NORMAL;
};

struct PositionDisplacement
{
   float4 Position : POSITION;
   float2 Displacement : TEXCOORD;
};

PositionDisplacement PullIn_VertexShader(PositionNormal input)
{
   PositionDisplacement output;

   output.Position = mul(input.Position, WorldViewProjection);
   float3 normalWV = mul(input.Normal, WorldView);
   normalWV.y = -normalWV.y;
   
   float amount = dot(normalWV, float3(0,0,1)) * DistortionScale;
   output.Displacement = float2(.5,.5) + float2(amount * normalWV.xy);

   return output;   
}

float4 DisplacementPassthrough_PixelShader(PositionColorTextured input) : COLOR
{  
   return float4(input.TexCoord, 0, 1);
}

technique PullIn
{
    pass
    {
        VertexShader = compile VS_SHADERMODEL PullIn_VertexShader();
        PixelShader = compile PS_SHADERMODEL DisplacementPassthrough_PixelShader();
    }
}


//-----------------------------------------------------------------------------
//
// Zero Displacement (provided for reference)
//
//-----------------------------------------------------------------------------


float4 TransformOnly_VertexShader(PositionColorTextured input) : POSITION
{
    return mul(input.Position, WorldViewProjection);
}

float4 ZeroDisplacement_PixelShader(PositionColorTextured input) : COLOR
{
    return float4(.5, .5, 0, 0);
}

technique ZeroDisplacement
{
    pass
    {
        VertexShader = compile VS_SHADERMODEL TransformOnly_VertexShader();
        PixelShader = compile PS_SHADERMODEL ZeroDisplacement_PixelShader();
    }
}