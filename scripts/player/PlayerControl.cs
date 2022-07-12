using Godot;
using System.Collections.Generic;

public enum InteractionMode
{
    Select,
    Dig,
    Build,
}

public partial class PlayerControl : Control
{
    [Signal]
    public delegate void SelectionChanged();

    public Player Player;

    public InteractionMode InteractionMode = InteractionMode.Select;
    public InteractionTool CurrentTool = null;
    public List<Node> Selection = new List<Node>();

    private List<Node3D> Markers = new List<Node3D>();
    private PackedScene Marker = (PackedScene)GD.Load("res://scenes/marker.tscn");

    public override void _Ready()
    {
        Player = GetParentOrNull<Player>();

        if (Player == null)
        {
            Util.LogError("HUD is not parented to a player!");
        }

        foreach (BaseButton button in GetTree().GetNodesInGroup<BaseButton>("mode_buttons"))
        {
            if (button != null)
            {
                button.Pressed += () => OnModeButtonPressed(button);
            }
        }
    }

    public override void _Input(InputEvent @event)
    {
        if (Player.World == null)
        {
            return;
        }

        if (@event.IsActionPressed("primary"))
        {
            if (CurrentTool != null && CurrentTool.Use(Player))
            {
                GetViewport().SetInputAsHandled();
                return;
            }
            else
            {
                // TODO: Move this code to a default selection tool

                RaycastResult r = Util.Raycast(GetViewport().GetCamera3d(), Player.World);

                if (r.HasHit && r.Collider is Anthropoid)
                {
                    // Multiselect
                    if (!Input.IsActionPressed("control"))
                    {
                        Selection.Clear();
                    }

                    Selection.Add(r.Collider);
                    EmitSignal(nameof(SelectionChanged));
                }
            }
        }
        else if (@event.IsActionPressed("secondary"))
        {
            // TODO: Move this code to a default selection tool
            RaycastResult r = Util.Raycast(GetViewport().GetCamera3d(), Player.World);

            if (r.HasHit)
            {
                foreach (Node node in Selection)
                {
                    if (node is Anthropoid anthropoid)
                    {
                        anthropoid.MoveTo(r.Position);
                    }
                }
            }
        }
    }

    private void OnModeButtonPressed(BaseButton button)
    {
        InteractionMode prevMode = InteractionMode;

        switch (button.Name.ToString().ToLower())
        {
            case "dig":
                InteractionMode = InteractionMode.Dig;
                break;
            case "build":
                InteractionMode = InteractionMode.Build;
                break;
        }

        foreach (BaseButton other in GetTree().GetNodesInGroup<BaseButton>("mode_buttons"))
        {
            if (other != null)
            {
                other.ButtonPressed = false;
            }
        }

        if (prevMode == InteractionMode)
        {
            InteractionMode = InteractionMode.Select;
        }
    }

    private void OnSelectionChanged()
    {
        Markers.RemoveAll(node => node == null);

        foreach (Node3D marker in Markers)
        {
            if (!Selection.Contains(marker.GetParent()))
            {
                marker.QueueFree();
            }
        }

        foreach (Node node in Selection)
        {
            if (node is Anthropoid anthropoid)
            {
                Node3D marker = (Node3D)Marker.Instantiate();

                node.AddChild(marker);
                Markers.Add(marker);
            }
        }
    }
}
