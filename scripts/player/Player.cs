using Godot;

public partial class Player : Node3D
{
    public delegate void WorldChangedHandler();

    [Signal]
    public event WorldChangedHandler WorldChanged
    {
        add { Connect(nameof(WorldChanged), value); }
        remove { Disconnect(nameof(WorldChanged), value); }
    }

    public World World
    {
        get
        {
            return World;
        }
        set
        {
            EmitSignal(nameof(WorldChanged), value);
            World = value;
        }
    }
    public Daemon Daemon { get; private set; }

    public override void _Ready()
    {
        Daemon = new Daemon
        {
            Name = "PlayerDaemon"
        };
        AddChild(Daemon);
    }
}
