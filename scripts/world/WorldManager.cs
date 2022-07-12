using Godot;

public partial class WorldManager : Node
{
    public readonly PackedScene PlayerScene = GD.Load<PackedScene>("res://scenes/player.tscn");
    public readonly PackedScene EnvironmentScene = GD.Load<PackedScene>("res://scenes//default_environment.tscn");

    [Signal]
    public delegate void WorldChanged();

    public World World { get; private set; }

    private bool IsQuitting = false;
    private uint QuittingFrames = 0;

    public override void _Ready()
    {
        GetTree().AutoAcceptQuit = false;
        CallDeferred(nameof(InitializeWorld));
    }

    public override void _Process(float delta)
    {
        if (IsQuitting)
        {
            if (QuittingFrames++ > 10)
            {
                GetTree().Quit();
            }
        }
    }

    async public override void _Notification(int what)
    {
        switch ((long)what)
        {
            case NotificationWmCloseRequest:
                World.PropagateCall("_Quit");
                World.QueueFree();
                await ToSignal(World, "tree_exited");
                IsQuitting = true;
                break;
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
