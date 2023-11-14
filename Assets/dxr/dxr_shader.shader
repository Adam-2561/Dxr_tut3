Shader "Unlit/dxr_shader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        

    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Lp;
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }

        SubShader
            {
                Pass
                {
                    // RayTracingShader.SetShaderPass must use this name in order to execute the ray tracing shaders from this Pass.
                    Name "Test"

                    Tags{ "LightMode" = "RayTracing" }

                    HLSLPROGRAM

                    #pragma multi_compile_local RAY_TRACING_PROCEDURAL_GEOMETRY

                    #pragma raytracing test
                    #include "UnityRaytracingMeshUtils.cginc"
                    #include "UnityShaderVariables.cginc"
                    float4 _Lp;
                    RaytracingAccelerationStructure g_SceneAccelStruct;

                    struct AttributeData
                    {
                        float2 barycentrics;
                    };

                    struct RayPayload
                    {
                        float4 color;
                    };


                    struct Vertex
                    {
                        float3 position;
                        float3 normal;
                        float2 uv;
                    };
                    struct RayShadow
                    {
                        bool h;
                    };

                    Vertex FetchVertex(uint vertexIndex)
                    {
                        Vertex v;
                        v.position = UnityRayTracingFetchVertexAttribute3(vertexIndex, kVertexAttributePosition);
                        v.normal = UnityRayTracingFetchVertexAttribute3(vertexIndex, kVertexAttributeNormal);
                        v.uv = UnityRayTracingFetchVertexAttribute2(vertexIndex, kVertexAttributeTexCoord0);
                        return v;
                    }

                    Vertex InterpolateVertices(Vertex v0, Vertex v1, Vertex v2, float3 barycentrics)
                    {
                        Vertex v;
                        #define INTERPOLATE_ATTRIBUTE(attr) v.attr = v0.attr * barycentrics.x + v1.attr * barycentrics.y + v2.attr * barycentrics.z
                        INTERPOLATE_ATTRIBUTE(position);
                        INTERPOLATE_ATTRIBUTE(normal);
                        INTERPOLATE_ATTRIBUTE(uv);
                        return v;
                    }
            #if RAY_TRACING_PROCEDURAL_GEOMETRY
                    [shader("intersection")]
                    void IntersectionMain()
                    {
                        AttributeData attr;
                        attr.barycentrics = float2(0, 0);
                        ReportHit(0, 0, attr);
                    }
            #endif

                    [shader("closesthit")]
                    void ClosestHitMain(inout RayPayload payload : SV_RayPayload, AttributeData attribs : SV_IntersectionAttributes)
                    {
                        
                        uint3 triangleIndices = UnityRayTracingFetchTriangleIndices(PrimitiveIndex());

                        Vertex v0, v1, v2;
                        v0 = FetchVertex(triangleIndices.x);
                        v1 = FetchVertex(triangleIndices.y);
                        v2 = FetchVertex(triangleIndices.z);

                        float3 barycentricCoords = float3(1.0 - attribs.barycentrics.x - attribs.barycentrics.y, attribs.barycentrics.x, attribs.barycentrics.y);
                        Vertex v = InterpolateVertices(v0, v1, v2, barycentricCoords);

                        float3 Wp = mul(ObjectToWorld(), float4(v.position, 1));
                        float3 vecToLight = normalize(_Lp.xyz - Wp);

                        RayDesc ray;
                        ray.Origin = Wp;
                        ray.Direction = vecToLight;
                        ray.TMin = 0.01;
                        ray.TMax = 1000.0f;

                        uint missShadowIndex = 1;
                        RayShadow ray_s;
                        ray_s.h = 1;
                        TraceRay(g_SceneAccelStruct,RAY_FLAG_SKIP_CLOSEST_HIT_SHADER | RAY_FLAG_ACCEPT_FIRST_HIT_AND_END_SEARCH, 
                            0xFF, 0, 1, missShadowIndex, ray, ray_s);

                        if (ray_s.h == 1)
                        {
                            payload.color = float4(1, 0, 0, 1);
                        }
                        else
                        {
                            payload.color = float4(0, 0, 1, 1);
                        }

                    }

                    ENDHLSL
                }
            }


}
