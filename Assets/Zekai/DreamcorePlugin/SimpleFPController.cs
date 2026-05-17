using UnityEngine;

// The script automatically adds a CharacterController component to the object, as it handles collision detection.
[RequireComponent(typeof(CharacterController))]
public class SimpleFPController : MonoBehaviour
{
    [Header("Movement Settings")]
    [Tooltip("Horizontal movement speed (WASD).")]
    public float moveSpeed = 5.0f;
    [Tooltip("Vertical elevation speed (Q/E).")]
    public float upDownSpeed = 3.0f;

    [Header("Look Settings")]
    [Tooltip("Mouse sensitivity.")]
    public float mouseSensitivity = 2.0f;

    private CharacterController m_Controller;
    private Transform m_CameraTransform;
    private float m_VerticalRotation = 0f;

    void Start()
    {
        m_Controller = GetComponent<CharacterController>();

        // Get the main camera's Transform (assuming the camera is a child object)
        m_CameraTransform = Camera.main.transform;

        // --- Core Setup: Set default dimensions for the CharacterController ---
        // Ensure appropriate height and radius to prevent clipping through walls or falling off floor tiles
        m_Controller.height = 1.8f;   // 1.8 meters tall
        m_Controller.radius = 0.3f;   // 0.3 meters radius

        // --- Core Fix: Lock the cursor (Note: uses CursorLockMode) ---
        // Clicking into the Game window hides and locks the cursor to the center for smooth look control
        Cursor.lockState = CursorLockMode.Locked;
        Cursor.visible = false;
    }

    void Update()
    {
        // === 1. Handle Mouse Look Logic ===
        float mouseX = Input.GetAxis("Mouse X") * mouseSensitivity;
        float mouseY = Input.GetAxis("Mouse Y") * mouseSensitivity;

        // Horizontal rotation: Rotate the object itself along the Y-axis
        transform.Rotate(Vector3.up * mouseX);

        // Vertical rotation: Rotate the camera along the X-axis
        m_VerticalRotation -= mouseY;
        // Clamp vertical rotation to prevent the camera from flipping upside down (-90 to 90 degrees)
        m_VerticalRotation = Mathf.Clamp(m_VerticalRotation, -90f, 90f);
        m_CameraTransform.localRotation = Quaternion.Euler(m_VerticalRotation, 0f, 0f);


        // === 2. Handle WASD Movement Logic ===
        float horizontal = Input.GetAxis("Horizontal"); // A/D
        float vertical = Input.GetAxis("Vertical");     // W/S

        // Calculate the movement vector based on the player's facing direction
        Vector3 moveDir = transform.right * horizontal + transform.forward * vertical;

        // Ensure horizontal movement remains strictly on the flat plane, regardless of look pitch
        moveDir.y = 0;
        moveDir.Normalize(); // Normalize the vector to prevent faster diagonal movement


        // === 3. Handle Q/E Elevation Logic ===
        float elevation = 0;
        if (Input.GetKey(KeyCode.E)) // Press E to ascend
        {
            elevation = 1f;
        }
        else if (Input.GetKey(KeyCode.Q)) // Press Q to descend
        {
            elevation = -1f;
        }

        // === 4. Combine and Apply All Movements ===
        // Final velocity vector = Horizontal velocity + Vertical elevation velocity
        Vector3 finalVelocity = (moveDir * moveSpeed) + (Vector3.up * elevation * upDownSpeed);

        // Execute the actual movement (includes built-in collision checking)
        m_Controller.Move(finalVelocity * Time.deltaTime);


        // --- Debug Tool: Press Esc to toggle cursor lock state (Note: uses CursorLockMode) ---
        if (Input.GetKeyDown(KeyCode.Escape))
        {
            // Toggle cursor lock state
            if (Cursor.lockState == CursorLockMode.Locked)
            {
                Cursor.lockState = CursorLockMode.None;
                Cursor.visible = true;
            }
            else
            {
                Cursor.lockState = CursorLockMode.Locked;
                Cursor.visible = false;
            }
        }
    }
}