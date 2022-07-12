using Godot;

public partial class Anthropoid : Character
{
    public enum LifeState
    {
        Dead,
        Dying,
        Alive,
    }

    [Signal]
    public delegate void Died(Anthropoid anthropoid);

    public Daemon Daemon { get; private set; }
    public Navigator Navigator { get; private set; }

    public LifeState State = LifeState.Alive;

    public override void _Ready()
    {
        Navigator = new Navigator();
        AddChild(Navigator);
    }

    public override void _PhysicsProcess(float delta)
    {
        if (Daemon == null)
        {
            return;
        }

        if (Daemon.World.IsOutOfBounds(Position))
        {
            State = LifeState.Dead;
            EmitSignal(nameof(Died), this);
            CallDeferred(nameof(QueueFree));
        }

        WishVector = Vector3.Zero;

        UpdateAI();

        base._PhysicsProcess(delta);
    }

    virtual public void MoveTo(Vector3 pos)
    {
        Navigator.MoveTo(pos);
    }

    virtual public void UpdateAI()
    {
        Navigator.Update();
    }
}
