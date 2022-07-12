using Godot;
using System;

public partial class DigTool : InteractionTool
{
    private Tuple<Vector3i, Vector3i> SelectedPositions = new Tuple<Vector3i, Vector3i>(Vector3i.Zero, Vector3i.Zero);

    public override bool Use(Player player)
    {
        throw new NotImplementedException();
    }
}
