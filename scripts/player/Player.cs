using Godot;

public partial class Player : Node3D
{
    [Signal]
    public delegate void WorldChanged();
    
    public World World { get; private set; }
    public Daemon Daemon { get; private set; }

    public override void _Ready()
    {
        Daemon = new Daemon
        {
            Name = "PlayerDaemon"
        };
        AddChild(Daemon);
    }

    public void SetWorld(World world)
    {
        World = world;
        EmitSignal(nameof(WorldChanged));
    }
}
