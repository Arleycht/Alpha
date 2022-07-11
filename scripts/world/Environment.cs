using Godot;

public partial class Environment : WorldEnvironment
{
    [Export]
    public float Angle = 70.0f;
    [Export]
    public float Time = 7.0f;
    [Export]
    public NodePath EnvironmentPath;

    private DirectionalLight3D Sun;

    public override void _Ready()
    {
        Sun = GetNode<DirectionalLight3D>("Sun");
    }

    public override void _PhysicsProcess(float delta)
    {
        Time = Mathf.Wrap(Time, 0.0f, 24.0f);

        float t = Time * Mathf.Pi / 12.0f;
        Quaternion quaternion = new Quaternion(new Vector3(1, 0, 0), Mathf.Deg2Rad(Angle));
        quaternion *= new Quaternion(new Vector3(0, 1, 0), t);

        Sun.Transform = new Transform3D(quaternion, Sun.Position);
        Sun.LightEnergy = Mathf.Clamp(Sun.Transform.basis.z.y, 0.0f, 1.0f);
    }
}
