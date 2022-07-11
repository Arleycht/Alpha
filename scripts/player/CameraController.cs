using Godot;

public partial class CameraController : Node3D
{
    private const float PitchMin = -89.9f * Mathf.Pi / 180.0f;
    private const float PitchMax = 89.9f * Mathf.Pi / 180.0f;

    [Export]
    public float CameraSpeed = 12.0f;
    [Export]
    public float CameraFastSpeed = 24.0f;
    [Export]
    public float CameraDistance = 0.0f;
    [Export]
    public float CameraDistanceMin = 0.0f;
    [Export]
    public float CameraDistanceMax = 10.0f;
    [Export]
    public float CameraDistanceIncrement = 1.0f;
    [Export]
    public Vector2 CameraSensitivity = new Vector2(0.2f, 0.2f);

    private Vector3 WishVector = new Vector3();
    private Vector3 CameraAngles = new Vector3();
    private int TargetY = 0;
    private Vector2 MouseRecoverPosition = new Vector2();
    private bool IsMouseLooking = false;

    public override void _Ready()
    {
        CameraAngles = GlobalTransform.basis.GetEuler();
        TargetY = (int)GlobalTransform.origin.y;
    }

    public override void _Process(float delta)
    {
        Vector3 WishDirection = new Vector3();

        WishDirection.x = Input.GetActionStrength("move_right") - Input.GetActionStrength("move_left");
        WishDirection.z = Input.GetActionStrength("move_down") - Input.GetActionStrength("move_up");

        WishVector = Plane.PlaneXZ.Project(GlobalTransform.basis.x).Normalized() * WishDirection.x;
        WishVector += Plane.PlaneXZ.Project(GlobalTransform.basis.z).Normalized() * WishDirection.z;

        UpdateCamera();
    }

    public override void _PhysicsProcess(float delta)
    {
        Node3D parent = GetParentOrNull<Node3D>();
        
        if (parent == null)
        {
            return;
        }

        Transform3D transform = parent.Transform;
        transform.origin += WishVector.Normalized() * CameraSpeed * delta;
        transform.origin.y = Mathf.Lerp(transform.origin.y, TargetY, delta * 30.0f);
        parent.Transform = transform;
    }

    public override void _Input(InputEvent @event)
    {
        if (Input.IsActionPressed("control"))
        {
            if (@event.IsActionPressed("scroll_up"))
            {
                CameraDistance -= CameraDistanceIncrement;
                GetViewport().SetInputAsHandled();
            }
            else if (@event.IsActionPressed("scroll_down"))
            {
                CameraDistance += CameraDistanceIncrement;
                GetViewport().SetInputAsHandled();
            }
        }
        else
        {
            if (@event.IsActionPressed("scroll_up"))
            {
                TargetY += 1;
                GetViewport().SetInputAsHandled();
            }
            else if (@event.IsActionPressed("scroll_down"))
            {
                TargetY -= 1;
                GetViewport().SetInputAsHandled();
            }
        }

        if (@event is InputEventMouseButton)
        {
            InputEventMouseButton mbEvent = @event as InputEventMouseButton;

            if (mbEvent.IsActionPressed("secondary"))
            {
                MouseRecoverPosition = mbEvent.Position;
            }
            else if (mbEvent.IsActionReleased("secondary"))
            {
                Input.MouseMode = Input.MouseModeEnum.Visible;

                if (IsMouseLooking)
                {
                    Input.WarpMouse(MouseRecoverPosition);
                    GetViewport().SetInputAsHandled();
                }

                IsMouseLooking = false;
            }
        }

        if (@event is InputEventMouseMotion && Input.IsActionPressed("secondary"))
        {
            InputEventMouseMotion mmEvent = @event as InputEventMouseMotion;
            
            if (IsMouseLooking)
            {
                CameraAngles.x -= mmEvent.Relative.y * CameraSensitivity.y * 1e-2f;
                CameraAngles.y -= mmEvent.Relative.x * CameraSensitivity.x * 1e-2f;
                GetViewport().SetInputAsHandled();
            }
            else
            {
                Vector2 deltaPos = mmEvent.Position - MouseRecoverPosition;

                if (deltaPos.LengthSquared() > 25)
                {
                    CameraAngles.x -= deltaPos.y * CameraSensitivity.y * 1e-2f;
                    CameraAngles.y -= deltaPos.x * CameraSensitivity.x * 1e-2f;

                    IsMouseLooking = true;
                    Input.MouseMode = Input.MouseModeEnum.Captured;
                    GetViewport().SetInputAsHandled();
                }
            }
        }
    }

    private void UpdateCamera()
    {
        CameraAngles.x = Mathf.Clamp(CameraAngles.x, PitchMin, PitchMax);
        CameraAngles.y = Mathf.Wrap(CameraAngles.y, 0.0f, Mathf.Tau);

        Quaternion quaternion = new Quaternion(new Vector3(1, 0, 0), CameraAngles.x);
        quaternion *= new Quaternion(new Vector3(0, 1, 0), CameraAngles.y);

        Transform3D transform = new Transform3D();
        transform.basis = new Basis(CameraAngles);
        transform.origin = GlobalTransform.origin;
        GlobalTransform = transform;
    }
}
