using Godot;

abstract public partial class InteractionTool : RefCounted
{
    // Called when the tool is used by the player.
    // Returns true if it was successfuly used.
    abstract public bool Use(Player player);
}
