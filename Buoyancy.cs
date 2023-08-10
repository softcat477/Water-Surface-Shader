using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Rigidbody))]
public class Buoyancy : MonoBehaviour
{
    public GameObject[] anchors;

    Rigidbody rb;
    public float volumePerDistance = 1.0f;
    public float dragStrength = 0.1f;

    float PIE = 3.1415926f;
    float G = 9.8f;

    Vector4 params1;
    Vector4 params2;
    Vector4 params3;
    public GameObject waterSurface;
    Material waterSurface_material;

    Vector3 initial_wave_world_position;
    // Start is called before the first frame update
    void Start()
    {
        rb = GetComponent<Rigidbody>();
        initial_wave_world_position = new Vector3(transform.position.x, waterSurface.transform.position.y, transform.position.z);
        waterSurface_material = waterSurface.GetComponent<Renderer>().material;
    }

    void Update() {
        if (waterSurface_material.GetVector("_WaveA") != params1) {
            params1 = waterSurface_material.GetVector("_WaveA");
        }
        if (waterSurface_material.GetVector("_WaveB") != params2) {
            params2 = waterSurface_material.GetVector("_WaveA");
        }
        if (waterSurface_material.GetVector("_WaveC") != params3) {
            params3 = waterSurface_material.GetVector("_WaveA");
        }
    }

    void FixedUpdate()
    {
        Vector3 prev_wave_world_position = initial_wave_world_position;
        Vector3 localPosOnSurface = waterSurface.transform.InverseTransformPoint(prev_wave_world_position);
        Vector3 offset = TrochoidOffset(localPosOnSurface, params1, params2, params3);
        localPosOnSurface += offset;
        Vector3 current_wave_world_position = waterSurface.transform.TransformPoint(localPosOnSurface);

        foreach (GameObject anchor in anchors)
        {
            // Gravity
            rb.AddForceAtPosition(9.8f / anchors.Length * Vector3.down, anchor.transform.position, ForceMode.Acceleration);
            
            if (current_wave_world_position.y >= anchor.transform.position.y) {
                // Buoyancy
                float distance = current_wave_world_position.y - anchor.transform.position.y;
                float volume = distance * volumePerDistance;
                float fup = 1.0f * volume * 9.8f;
                rb.AddForceAtPosition(Vector3.up * fup, anchor.transform.position, ForceMode.Acceleration);

                // Drag
                rb.AddForce(dragStrength * rb.velocity * -1 / anchors.Length, ForceMode.VelocityChange);  
            }
        }

        // Drag
        // rb.AddForce(dragStrength * rb.velocity * -1, ForceMode.VelocityChange);    
    }

    void OnDrawGizmos()
    {
        Gizmos.color = Color.yellow;
        foreach (GameObject anchor in anchors)
        {
            Gizmos.DrawWireSphere(anchor.transform.position, 0.5f);
        }
    }

    float phasor(Vector2 xz, Vector4 pams) {
        float k = 2 * PIE / pams.w;
        float a = pams.y / k;
        float speed = Mathf.Sqrt(G / k);
        
        return a * Mathf.Sin(k * (Vector3.Dot(new Vector2(pams.x, pams.z), xz) + speed * Time.timeSinceLevelLoad));
    }

    float phasorCos(Vector2 xz, Vector4 pams) {
        float k = 2 * PIE / pams.w;
        float a = pams.y / k;
        float speed = Mathf.Sqrt(G / k);
        return a * Mathf.Cos(k * (Vector3.Dot(new Vector2(pams.x, pams.z), xz) + speed * Time.timeSinceLevelLoad));
    }

    Vector3 _trochoidOffset(Vector3 origin, Vector4 pams) {
        Vector3 ret_offset;
        
        ret_offset.y = phasor(new Vector2(origin.x, origin.z), pams);
        float offset = phasorCos(new Vector2(origin.x, origin.z), pams);
        ret_offset.x = (pams.x * (offset));
        ret_offset.z = (pams.z * (offset));
        return ret_offset;
    }

    Vector3 TrochoidOffset(Vector3 origin, Vector4 params1, Vector4 params2, Vector4 params3) {
        Vector3 offset1 = _trochoidOffset(origin, params1);
        Vector3 offset2 = _trochoidOffset(origin, params2);
        Vector3 offset3 = _trochoidOffset(origin, params3);
        
        Vector3 offset_sum = offset1 + offset2 + offset3;
        return offset_sum;
    }
}
