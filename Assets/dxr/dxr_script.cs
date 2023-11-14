using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.UI;
using static UnityEngine.Experimental.Rendering.RayTracingAccelerationStructure;

public class dxr_script : MonoBehaviour
{
	// Start is called before the first frame update
	RayTracingAccelerationStructure accelerationStructure;
	RASSettings settings;
	public Renderer[] r;
	public RayTracingShader rayTracingShader;
	Camera c;
	public RenderTexture _output;
	public RawImage image;
	public Transform Lig;
	void Start()
	{
		c = Camera.main;
		settings = new RASSettings();
		settings.managementMode = ManagementMode.Manual;
		settings.rayTracingModeMask = RayTracingModeMask.Everything;

		accelerationStructure = new RayTracingAccelerationStructure(settings);

		foreach (var item in r)
		{
			accelerationStructure.AddInstance(item);
		}
		accelerationStructure.Build();

		print(accelerationStructure.GetSize());

		rayTracingShader.SetAccelerationStructure("g_SceneAccelStruct", accelerationStructure);
		rayTracingShader.SetFloat("g_Zoom", Mathf.Tan(Mathf.Deg2Rad * c.fieldOfView * 0.5f));


		_output = new RenderTexture(c.pixelWidth, c.pixelHeight, 0);
		_output.enableRandomWrite = true;
		_output.Create();
		rayTracingShader.SetTexture("g_Output", _output);
		rayTracingShader.SetShaderPass("Test");
		image.texture = _output;
	}

	// Update is called once per frame
	void Update()
	{
		foreach (var item in r)
		{
			accelerationStructure.UpdateInstanceTransform(item);
		}

		accelerationStructure.Build();
		Shader.SetGlobalVector("_Lp", Lig.position);
		rayTracingShader.Dispatch("MainRayGenShader", c.pixelWidth, c.pixelHeight,1, c);
	}
}
