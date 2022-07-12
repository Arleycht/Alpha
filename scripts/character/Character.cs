using Godot;
using System.Collections.Generic;

public partial class Character : CharacterBody3D
{
    [Export]
    public float MaxSpeed = 3.0f;
    [Export]
    public float JumpHeight = 1.0f;
    [Export]
    public float GroundAcceleration = 50.0f;
    [Export]
    public float AirAcceleration = 20.0f;
    [Export]
    public float GroundFriction = 0.2f;
    [Export]
    public float AirFriction = 0.1f;
    [Export]
    public float GravityAcceleration = -9.8f;
    [Export]
    public Vector3 GravityDirection = new Vector3(0, -1, 0);

    public Vector3 WishVector = new Vector3();
    public bool IsJumping = false;

    protected int GroundFrames = 0;
    protected bool IsJumpBuffered = false;

    public override void _PhysicsProcess(float delta)
    {
        Velocity += GravityDirection * GravityAcceleration;
        UpdateMovement(delta);

        bool collided = MoveAndSlide();

        if (collided)
        {
            HashSet<Object> handled = new HashSet<Object>();
            
            for (int i = 0; i < GetSlideCollisionCount(); ++i)
            {
                KinematicCollision3D collision = GetSlideCollision(i);
                Object collider = collision.GetCollider();
                
                if (collider is Character && !handled.Contains(collider))
                {
                    Character other = (Character)collider;
                    Vector3 direction = other.Position - Position;
                    Vector3 r = Vector3.Forward.Rotated(Vector3.Up, GD.Randf() * Mathf.Pi);
                    other.Velocity += direction.Normalized() + r * 0.5f;
                    handled.Add(collider);
                }
            }
        }

        if (IsOnFloor())
        {
            if (GroundFrames == 0)
            {
                // TODO: Emit landed signal
            }

            IsJumping = false;

            if (IsJumpBuffered)
            {
                Jump();
            }
            else
            {
                GroundFrames++;
            }
        }
        else
        {
            GroundFrames = 0;
        }
    }

    public bool Jump()
    {
        if (IsOnFloor() && !IsJumping)
        {
            Velocity += -GravityDirection * Mathf.Sqrt(GravityAcceleration * JumpHeight * 2.0f);
            // Fix one frame addition of gravity during the start of jumping
            Velocity += -GravityDirection * GravityAcceleration * (float)GetPhysicsProcessDeltaTime();

            IsJumping = true;
            IsJumpBuffered = false;

            return true;
        }

        return false;
    }

    public AABB GetAabb()
    {
        AABB aabb = new AABB();

        foreach (Node child in FindChildren("*", "CollisionShape3D", true))
        {
            aabb.Merge(((CollisionShape3D)child).Shape.GetDebugMesh().GetAabb());
        }

        return aabb;
    }

    private void UpdateMovement(float delta)
    {
        WishVector.y = 0.0f;

        Vector3 wishDirection = WishVector.Normalized();
        float wishStrength = WishVector.Length();

        float acceleration = AirAcceleration;
        float friction = AirFriction;

        if (GroundFrames > 0)
        {
            acceleration = GroundAcceleration;
            friction = GroundFriction;
        }

        acceleration *= delta;

        Plane hPlane = new Plane(UpDirection, 0.0f);
        float prevSpeed = hPlane.Project(Velocity).Length();
        float newSpeed;

        Velocity += wishDirection * wishStrength * acceleration;

        newSpeed = hPlane.Project(Velocity).Length();

        // Separate vertical and horizontal components
        Vector3 h = hPlane.Project(Velocity).Normalized();
        Vector3 v = Velocity - h;

        if (newSpeed > MaxSpeed)
        {
            newSpeed = Mathf.Max(prevSpeed * (1.0f - friction), MaxSpeed);
            friction = 0.0f;
        }

        Velocity = v + h * newSpeed * (1.0f - friction);
    }
}
