using Godot;

public partial class WorldManager : Node
{
    public readonly PackedScene PlayerScene = GD.Load<PackedScene>("res://scenes/player.tscn");
    public readonly PackedScene EnvironmentScene = GD.Load<PackedScene>("res://scenes//default_environment.tscn");

    [Signal]
    public delegate void WorldChanged();

    public World World { get; private set; }

    public override void _Ready()
    {
        CallDeferred(nameof(InitializeWorld));
    }

    public override void _Notification(int what)
    {
        if (what == NotificationWmCloseRequest)
        {
            
        }
    }

    public void InitializeWorld()
    {
        World = new World();
        GetNode("/root").GetChild(-1).QueueFree();
        GetNode("/root").AddChild(World);

        World.AddChild(EnvironmentScene.Instantiate());

        EmitSignal(nameof(WorldChanged));

        SpawnLocalPlayer();
    }

    public Player SpawnLocalPlayer()
    {
        Player player = PlayerScene.Instantiate<Player>();
        World.AddChild(player);
        return player;
    }
}
